module CFormat = Format
module B = PrintBox

let time_elapsed () = Mtime_clock.elapsed ()

let pp_timestamp ppf () =
  let tz_offset_s = Ptime_clock.current_tz_offset_s () in
  Ptime.(pp_human ~frac_s:6 ?tz_offset_s ()) ppf (Ptime_clock.now ())

let timestamp_to_string () =
  let _ = CFormat.flush_str_formatter () in
  let tz_offset_s = Ptime_clock.current_tz_offset_s () in
  Ptime.(pp_human ~frac_s:6 ?tz_offset_s ()) CFormat.str_formatter (Ptime_clock.now ());
  CFormat.flush_str_formatter ()

let pp_elapsed ppf () =
  let _ = CFormat.flush_str_formatter () in
  let e = time_elapsed () in
  let ns =
    match Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns e with
    | None -> -1
    | Some ns -> ns
  in
  CFormat.fprintf ppf "%a / %dns" Mtime.Span.pp e ns

type time_tagged = Not_tagged | Clock | Elapsed
type elapsed_times = Not_reported | Seconds | Milliseconds | Microseconds | Nanoseconds

type location_format =
  | No_location
  | File_only
  | Beg_line
  | Beg_pos
  | Range_line
  | Range_pos

type log_level =
  | Nothing
  | Prefixed of string array
  | Prefixed_or_result of string array
  | Nonempty_entries
  | Everything

type toc_entry_criteria =
  | Minimal_depth of int
  | Minimal_size of int
  | Minimal_span of Mtime.span
  | And of toc_entry_criteria list
  | Or of toc_entry_criteria list

let toc_entry_passes ~depth ~size ~span criteria =
  let rec loop = function
    | Minimal_depth d -> depth > d
    | Minimal_size s -> size > s
    | Minimal_span sp -> Mtime.Span.compare span sp > 0
    | And conjs -> List.for_all loop conjs
    | Or disjs -> List.exists loop disjs
  in
  loop criteria

let is_prefixed_or_result = function Prefixed_or_result _ -> true | _ -> false

module type Shared_config = sig
  val refresh_ch : unit -> bool
  val debug_ch : unit -> out_channel
  val debug_ch_name : unit -> string
  val snapshot_ch : unit -> unit
  val reset_to_snapshot : unit -> unit
  val table_of_contents_ch : out_channel option
  val time_tagged : time_tagged
  val elapsed_times : elapsed_times
  val location_format : location_format
  val print_entry_ids : bool
  val verbose_entry_ids : bool
  val global_prefix : string
  val split_files_after : int option
  val toc_entry : toc_entry_criteria
end

let elapsed_default = Not_reported

let shared_config ?(time_tagged = Not_tagged) ?(elapsed_times = elapsed_default)
    ?(location_format = Beg_pos) ?(print_entry_ids = false) ?(verbose_entry_ids = false)
    ?(global_prefix = "") ?split_files_after ?(with_table_of_contents = false)
    ?(toc_entry = And []) ?(for_append = true) filename : (module Shared_config) =
  let module Result = struct
    let current_ch_name = ref filename

    let () =
      match split_files_after with
      | Some _ when not for_append ->
          let dirname = Filename.remove_extension filename in
          if not (Sys.file_exists dirname) then Sys.mkdir dirname 0o777;
          Array.iter (fun file -> Sys.remove @@ Filename.concat dirname file)
          @@ Sys.readdir dirname
      | _ -> ()

    let find_ch () =
      match split_files_after with
      | None ->
          if for_append then open_out_gen [ Open_creat; Open_append ] 0o640 filename
          else open_out filename
      | Some _ ->
          let dirname = Filename.remove_extension filename in
          let suffix = Filename.extension filename in
          if not (Sys.file_exists dirname) then Sys.mkdir dirname 0o777;
          let rec find i =
            let fname = Filename.concat dirname @@ Int.to_string i in
            if
              Sys.file_exists (fname ^ ".log")
              || Sys.file_exists (fname ^ ".html")
              || Sys.file_exists (fname ^ ".md")
              || Sys.file_exists fname
            then find (i + 1)
            else fname ^ suffix
          in
          let filename = find 1 in
          current_ch_name := filename;
          if for_append then open_out_gen [ Open_creat; Open_append ] 0o640 filename
          else open_out filename

    let current_ch = ref @@ find_ch ()

    let refresh_ch () =
      match split_files_after with
      | None -> false
      | Some split_after ->
          Stdlib.flush !current_ch;
          Int64.to_int (Stdlib.LargeFile.out_channel_length !current_ch) > split_after

    let current_snapshot = ref 0

    let debug_ch () =
      if refresh_ch () then (
        current_ch := find_ch ();
        current_snapshot := 0);
      !current_ch

    let debug_ch_name () = !current_ch_name

    let snapshot_ch () =
      flush !current_ch;
      current_snapshot := pos_out !current_ch

    let reset_to_snapshot () = seek_out !current_ch !current_snapshot

    let table_of_contents_ch =
      if with_table_of_contents then
        let suffix = Filename.extension filename in
        let filename = Filename.remove_extension filename ^ "-toc" ^ suffix in
        let ch =
          if for_append then open_out_gen [ Open_creat; Open_append ] 0o640 filename
          else open_out filename
        in
        Some ch
      else None

    let time_tagged = time_tagged
    let elapsed_times = elapsed_times
    let location_format = location_format
    let print_entry_ids = print_entry_ids
    let verbose_entry_ids = verbose_entry_ids
    let global_prefix = if global_prefix = "" then "" else global_prefix ^ " "
    let split_files_after = split_files_after
    let toc_entry = toc_entry
  end in
  (module Result)

module type Debug_runtime = sig
  val close_log : fname:string -> start_lnum:int -> entry_id:int -> unit

  val open_log :
    fname:string ->
    start_lnum:int ->
    start_colnum:int ->
    end_lnum:int ->
    end_colnum:int ->
    message:string ->
    entry_id:int ->
    unit

  val open_log_no_source : message:string -> entry_id:int -> unit

  val log_value_sexp :
    ?descr:string -> entry_id:int -> is_result:bool -> Sexplib0.Sexp.t -> unit

  val log_value_pp :
    ?descr:string ->
    entry_id:int ->
    pp:(Format.formatter -> 'a -> unit) ->
    is_result:bool ->
    'a ->
    unit

  val log_value_show : ?descr:string -> entry_id:int -> is_result:bool -> string -> unit
  val log_value_printbox : entry_id:int -> PrintBox.t -> unit
  val exceeds_max_nesting : unit -> bool
  val exceeds_max_children : unit -> bool
  val get_entry_id : unit -> int
  val max_nesting_depth : int option ref
  val max_num_children : int option ref
  val global_prefix : string
end

let exceeds ~value ~limit = match limit with None -> false | Some limit -> limit < value

let time_span ~none ~some ~elapsed ~elapsed_on_close elapsed_times =
  let span = Mtime.Span.to_float_ns (Mtime.Span.abs_diff elapsed_on_close elapsed) in
  match elapsed_times with
  | Not_reported -> none ()
  | Seconds ->
      let span_s = span /. 1e9 in
      if span_s >= 0.01 then some @@ Printf.sprintf "<%.2fs>" span_s else none ()
  | Milliseconds ->
      let span_ms = span /. 1e6 in
      if span_ms >= 0.01 then some @@ Printf.sprintf "<%.2fms>" span_ms else none ()
  | Microseconds ->
      let span_us = span /. 1e3 in
      if span_us >= 0.01 then some @@ Printf.sprintf "<%.2fμs>" span_us else none ()
  | Nanoseconds ->
      let span_ns = span in
      if span_ns >= 0.01 then some @@ Printf.sprintf "<%.2fns>" span_ns else none ()

let opt_entry_id ~print_entry_ids ~entry_id =
  if print_entry_ids && entry_id >= 0 then "{#" ^ Int.to_string entry_id ^ "} " else ""

let opt_verbose_entry_id ~verbose_entry_ids ~entry_id =
  if verbose_entry_ids && entry_id >= 0 then "{#" ^ Int.to_string entry_id ^ "} " else ""

module Flushing (Log_to : Shared_config) : Debug_runtime = struct
  open Log_to

  let max_nesting_depth = ref None
  let max_num_children = ref None
  let debug_ch = ref @@ debug_ch ()
  let debug_ch_name = ref @@ debug_ch_name ()

  type entry = {
    message : string;
    num_children : int;
    elapsed : Mtime.span;
    time_tag : string;
    entry_id : int;
  }

  let stack = ref []
  let depth_stack = ref []
  let indent () = String.make (List.length !stack) ' '

  let () =
    match Log_to.time_tagged with
    | Not_tagged -> Printf.fprintf !debug_ch "\nBEGIN DEBUG SESSION %s\n%!" global_prefix
    | Clock ->
        Printf.fprintf !debug_ch "\nBEGIN DEBUG SESSION %sat time %s\n%!" global_prefix
          (timestamp_to_string ())
    | Elapsed ->
        Printf.fprintf !debug_ch
          "\nBEGIN DEBUG SESSION %sat elapsed %s, corresponding to time %s\n%!"
          global_prefix
          (Format.asprintf "%a" pp_elapsed ())
          (timestamp_to_string ())

  let close_log ~fname ~start_lnum ~entry_id =
    match !stack with
    | [] ->
        let log_loc =
          Printf.sprintf "%s\"%s\":%d: entry_id=%d" global_prefix fname start_lnum
            entry_id
        in
        failwith @@ "ppx_minidebug: close_log must follow an earlier open_log; " ^ log_loc
    | { message; elapsed; time_tag; entry_id = open_entry_id; _ } :: tl -> (
        let elapsed_on_close = time_elapsed () in
        stack := tl;
        (if open_entry_id <> entry_id then
           let log_loc =
             Printf.sprintf "%s\"%s\":%d: open entry_id=%d, close entry_id=%d"
               global_prefix fname start_lnum open_entry_id entry_id
           in
           failwith
           @@ "ppx_minidebug: lexical scope of close_log not matching its dynamic scope; "
           ^ log_loc);
        Printf.fprintf !debug_ch "%s%!" (indent ());
        (match Log_to.time_tagged with
        | Not_tagged -> ()
        | Clock -> Printf.fprintf !debug_ch "%s - %!" (timestamp_to_string ())
        | Elapsed ->
            Printf.fprintf !debug_ch "%s - %!" (Format.asprintf "%a" pp_elapsed ()));
        time_span
          ~none:(fun () -> ())
          ~some:(Printf.fprintf !debug_ch "%s %!")
          ~elapsed ~elapsed_on_close elapsed_times;
        Printf.fprintf !debug_ch "%s%s end\n%!" global_prefix message;
        flush !debug_ch;
        if !stack = [] then (
          debug_ch := Log_to.debug_ch ();
          debug_ch_name := Log_to.debug_ch_name ());
        (match (table_of_contents_ch, !depth_stack) with
        | None, _ | _, [] -> ()
        | Some toc_ch, (depth, size) :: _ ->
            let span = Mtime.Span.abs_diff elapsed_on_close elapsed in
            if toc_entry_passes ~depth ~size ~span toc_entry then
              Printf.fprintf toc_ch "%s{#%d} %s%s\n%!" (indent ()) entry_id message
                time_tag);
        match !depth_stack with
        | [] -> ()
        | [ _ ] -> depth_stack := []
        | (cur_depth, cur_size) :: (depth, size) :: tl ->
            depth_stack := (max depth (cur_depth + 1), cur_size + size) :: tl)

  let open_log ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message ~entry_id =
    Printf.fprintf !debug_ch "%s%s%s%s begin %!" (indent ()) global_prefix
      (opt_entry_id ~print_entry_ids ~entry_id)
      message;
    let message = opt_verbose_entry_id ~verbose_entry_ids ~entry_id ^ message in
    (match Log_to.location_format with
    | No_location -> ()
    | File_only -> Printf.fprintf !debug_ch "\"%s\":%!" fname
    | Beg_line -> Printf.fprintf !debug_ch "\"%s\":%d:%!" fname start_lnum
    | Beg_pos -> Printf.fprintf !debug_ch "\"%s\":%d:%d:%!" fname start_lnum start_colnum
    | Range_line -> Printf.fprintf !debug_ch "\"%s\":%d-%d:%!" fname start_lnum end_lnum
    | Range_pos ->
        Printf.fprintf !debug_ch "\"%s\":%d:%d-%d:%d:%!" fname start_lnum start_colnum
          end_lnum end_colnum);
    let time_tag =
      match Log_to.time_tagged with
      | Not_tagged -> ""
      | Clock -> " " ^ timestamp_to_string ()
      | Elapsed -> Format.asprintf " %a" pp_elapsed ()
    in
    Printf.fprintf !debug_ch "%s\n%!" time_tag;
    stack :=
      { message; elapsed = time_elapsed (); time_tag; num_children = 0; entry_id }
      :: !stack

  let open_log_no_source ~message ~entry_id =
    Printf.fprintf !debug_ch "%s%s%s%s begin %!" (indent ()) global_prefix
      (opt_entry_id ~print_entry_ids ~entry_id)
      message;
    let message = opt_verbose_entry_id ~verbose_entry_ids ~entry_id ^ message in
    let time_tag =
      match Log_to.time_tagged with
      | Not_tagged -> ""
      | Clock -> " " ^ timestamp_to_string ()
      | Elapsed -> Format.asprintf " %a" pp_elapsed ()
    in
    Printf.fprintf !debug_ch "%s\n%!" time_tag;
    stack :=
      { message; elapsed = time_elapsed (); time_tag; num_children = 0; entry_id }
      :: !stack

  let bump_stack_entry entry_id =
    match !stack with
    | ({ num_children; _ } as entry) :: tl ->
        stack := { entry with num_children = num_children + 1 } :: tl;
        ""
    | [] -> "{orphaned from #" ^ Int.to_string entry_id ^ "} "

  let log_value_sexp ?descr ~entry_id ~is_result:_ sexp =
    let orphaned = bump_stack_entry entry_id in
    let descr = match descr with None -> "" | Some d -> d ^ " = " in
    Printf.fprintf !debug_ch "%s%s%s%s\n%!" (indent ()) orphaned descr
      (Sexplib0.Sexp.to_string_hum sexp)

  let log_value_pp ?descr ~entry_id ~pp ~is_result:_ v =
    let orphaned = bump_stack_entry entry_id in
    let descr = match descr with None -> "" | Some d -> d ^ " = " in
    let _ = CFormat.flush_str_formatter () in
    pp CFormat.str_formatter v;
    let v_str = CFormat.flush_str_formatter () in
    Printf.fprintf !debug_ch "%s%s%s%s\n%!" (indent ()) orphaned descr v_str

  let log_value_show ?descr ~entry_id ~is_result:_ v =
    let orphaned = bump_stack_entry entry_id in
    let descr = match descr with None -> "" | Some d -> d ^ " = " in
    Printf.fprintf !debug_ch "%s%s%s%s\n%!" (indent ()) orphaned descr v

  let log_value_printbox ~entry_id v =
    let orphaned = bump_stack_entry entry_id in
    let orphaned = if orphaned = "" then "" else " " ^ orphaned in
    let indent = indent () in
    Printf.fprintf !debug_ch "%a%s\n%!"
      (PrintBox_text.output ?style:None ~indent:(String.length indent))
      v orphaned

  let exceeds_max_nesting () =
    exceeds ~value:(List.length !stack) ~limit:!max_nesting_depth

  let exceeds_max_children () =
    match !stack with
    | [] -> false
    | { num_children; _ } :: _ -> exceeds ~value:num_children ~limit:!max_num_children

  let get_entry_id =
    let global_id = ref 0 in
    fun () ->
      incr global_id;
      !global_id

  let global_prefix = global_prefix
end

let default_html_config = PrintBox_html.Config.(tree_summary true default)
let default_md_config = PrintBox_md.Config.(foldable_trees default)

module type PrintBox_runtime = sig
  include Debug_runtime

  val no_debug_if : bool -> unit

  type config = {
    mutable hyperlink : [ `Prefix of string | `No_hyperlinks ];
    mutable toc_specific_hyperlink : string option;
    mutable backend :
      [ `Text | `Html of PrintBox_html.Config.t | `Markdown of PrintBox_md.Config.t ];
    mutable boxify_sexp_from_size : int;
    mutable highlight_terms : Re.re option;
    mutable exclude_on_path : Re.re option;
    mutable prune_upto : int;
    mutable truncate_children : int;
    mutable values_first_mode : bool;
    mutable max_inline_sexp_size : int;
    mutable max_inline_sexp_length : int;
    mutable log_level : log_level;
    mutable snapshot_every_sec : float option;
    mutable sexp_unescape_strings : bool;
    mutable with_toc_listing : bool;
    mutable toc_flame_graph : bool;
    mutable flame_graph_separation : int;
  }

  val config : config
  val snapshot : unit -> unit
end

let anchor_entry_id ~is_pure_text ~entry_id =
  if entry_id = -1 || is_pure_text then B.empty
  else
    let id = Int.to_string entry_id in
    (* TODO(#40): Not outputting a self-link, since we want the anchor in summaries,
       mostly to avoid generating tables in HTML. *)
    (* let uri = "{#" ^ id ^ "}" in
       let inner = if print_entry_ids then B.line uri else B.empty in *)
    let anchor = B.anchor ~id B.empty in
    if is_pure_text then B.hlist ~bars:false [ anchor; B.line " " ] else anchor

module PrintBox (Log_to : Shared_config) = struct
  open Log_to

  let max_nesting_depth = ref None
  let max_num_children = ref None

  type config = {
    mutable hyperlink : [ `Prefix of string | `No_hyperlinks ];
    mutable toc_specific_hyperlink : string option;
    mutable backend :
      [ `Text | `Html of PrintBox_html.Config.t | `Markdown of PrintBox_md.Config.t ];
    mutable boxify_sexp_from_size : int;
    mutable highlight_terms : Re.re option;
    mutable exclude_on_path : Re.re option;
    mutable prune_upto : int;
    mutable truncate_children : int;
    mutable values_first_mode : bool;
    mutable max_inline_sexp_size : int;
    mutable max_inline_sexp_length : int;
    mutable log_level : log_level;
    mutable snapshot_every_sec : float option;
    mutable sexp_unescape_strings : bool;
    mutable with_toc_listing : bool;
    mutable toc_flame_graph : bool;
    mutable flame_graph_separation : int;
  }

  let config =
    {
      hyperlink = `No_hyperlinks;
      toc_specific_hyperlink = None;
      backend = `Text;
      boxify_sexp_from_size = -1;
      highlight_terms = None;
      prune_upto = 0;
      truncate_children = 0;
      exclude_on_path = None;
      values_first_mode = false;
      max_inline_sexp_size = 20;
      max_inline_sexp_length = 80;
      log_level = Everything;
      snapshot_every_sec = None;
      sexp_unescape_strings = true;
      toc_flame_graph = false;
      with_toc_listing = false;
      flame_graph_separation = 40;
    }

  type subentry = {
    result_id : int;
    is_result : bool;
    elapsed_start : Mtime.span;
    elapsed_end : Mtime.span;
    subtree : B.t;
    toc_subtree : B.t;
    flame_subtree : string;
  }

  type entry = {
    cond : bool;
    highlight : bool;
    exclude : bool;
    elapsed : Mtime.span;
    time_tag : string;
    uri : string;
    path : string;
    entry_message : string;
    entry_id : int;
    body : subentry list;
    depth : int;
    toc_depth : int;
    size : int;
  }

  let stack : entry list ref = ref []

  let hyperlink_path ~uri ~inner =
    match config.hyperlink with
    | `Prefix prefix -> B.link ~uri:(prefix ^ uri) inner
    | `No_hyperlinks -> inner

  let () =
    let log_header =
      match time_tagged with
      | Not_tagged -> CFormat.asprintf "@.BEGIN DEBUG SESSION %s@." global_prefix
      | Clock ->
          CFormat.asprintf "@.BEGIN DEBUG SESSION %sat time %a@." global_prefix
            pp_timestamp ()
      | Elapsed ->
          CFormat.asprintf
            "@.BEGIN DEBUG SESSION %sat elapsed %a, corresponding to time %a@."
            global_prefix pp_elapsed () pp_timestamp ()
    in
    output_string (debug_ch ()) log_header

  let apply_highlight hl b =
    let rec loop b =
      match B.view b with
      | B.Empty | B.Frame _ -> b
      | B.Anchor { inner; _ } -> (
          match B.view inner with B.Empty | B.Frame _ -> b | _ -> B.frame b)
      | B.Pad ({ x; y }, b) -> B.pad' ~col:x ~lines:y @@ loop b
      | B.Align { h; v; inner } -> B.align ~h ~v @@ loop inner
      | B.Grid (bars, [| hl |]) -> B.grid ~bars:(bars = `Bars) [| Array.map loop hl |]
      | B.Tree (indent, h, ch) ->
          B.tree ~indent (loop h) @@ List.map loop @@ Array.to_list ch
      | B.Grid _ | B.Link _ | B.Text _ -> B.frame b
    in
    if hl then loop b else b

  let unpack ~f l =
    let f sub acc =
      let b = f sub in
      match B.view b with B.Empty -> acc | _ -> b :: acc
    in
    let rec unpack truncate acc = function
      | [] -> acc
      | [ sub ] -> f sub acc
      | sub :: tl ->
          if truncate = 0 then B.line "<earlier entries truncated>" :: f sub acc
          else unpack (truncate - 1) (f sub acc) tl
    in
    unpack (config.truncate_children - 1) [] l

  let stack_to_tree ~elapsed_on_close
      {
        cond = _;
        highlight;
        exclude = _;
        elapsed;
        time_tag = _;
        uri;
        path;
        entry_message;
        entry_id;
        body;
        depth = _;
        toc_depth = _;
        size = _;
      } =
    let non_id_message =
      (* Being defensive: checking for '=' not required so far. *)
      String.contains entry_message '<'
      || String.contains entry_message ':'
      || String.contains entry_message '='
    in
    let span =
      time_span
        ~none:(fun () -> "")
        ~some:(fun span -> " " ^ span)
        ~elapsed ~elapsed_on_close elapsed_times
    in
    let colon a b = if a = "" || b = "" then a ^ b else a ^ ": " ^ b in
    let b_path =
      if uri = "" then
        if config.values_first_mode then
          if entry_id = -1 then B.line entry_message else B.empty
        else B.line @@ entry_message ^ span
      else
        let inner =
          B.line
          @@
          if config.values_first_mode then
            if entry_id = -1 then colon path entry_message else path
          else colon path entry_message ^ span
        in
        hyperlink_path ~uri ~inner
    in
    let is_pure_text = config.backend = `Text in
    let anchor_id = anchor_entry_id ~is_pure_text ~entry_id in
    let b_path =
      if print_entry_ids && entry_id <> -1 then
        let uri = "#" ^ Int.to_string entry_id in
        let inner = B.line @@ "{" ^ uri ^ "}" in
        if is_pure_text then B.hlist ~bars:false [ b_path; B.line " "; inner ]
        else B.hlist ~bars:false [ b_path; B.link ~uri inner ]
      else b_path
    in
    let span_line = if elapsed_times = Not_reported then [] else [ B.line span ] in
    if config.values_first_mode then
      let header = B.hlist ~bars:false [ anchor_id; B.line @@ entry_message ^ span ] in
      let hl_header =
        if entry_id = -1 then B.empty else apply_highlight highlight header
      in
      let results, body =
        if entry_id = -1 then (body, [])
        else
          List.partition
            (fun { result_id; is_result; _ } -> is_result && result_id = entry_id)
            body
      in
      let results = unpack ~f:(fun { subtree; _ } -> subtree) results
      and body = unpack ~f:(fun { subtree; _ } -> subtree) body in
      match results with
      | [ subtree ] -> (
          let opt_message = if non_id_message then [ hl_header ] else [] in
          match B.view subtree with
          | B.Tree (_ident, result_header, result_body) ->
              let value_header =
                B.hlist ~bars:false (anchor_id :: result_header :: span_line)
              in
              ( value_header,
                B.tree
                  (apply_highlight highlight value_header)
                  (b_path
                   :: B.tree
                        (B.line @@ if body = [] then "<values>" else "<returns>")
                        (Array.to_list result_body)
                   :: opt_message
                  @ body) )
          | _ ->
              let value_header =
                B.hlist ~bars:false (anchor_id :: subtree :: span_line)
              in
              ( value_header,
                B.tree
                  (apply_highlight highlight value_header)
                  ((b_path :: opt_message) @ body) ))
      | [] -> (header, B.tree hl_header (b_path :: body))
      | _ ->
          ( header,
            B.tree hl_header
            @@ b_path
               :: B.tree (B.line @@ if body = [] then "<values>" else "<returns>") results
               :: body )
    else
      let hl_header =
        apply_highlight highlight @@ B.hlist ~bars:false [ anchor_id; b_path ]
      in
      (b_path, B.tree hl_header (unpack ~f:(fun { subtree; _ } -> subtree) body))

  let stack_to_toc ~toc_depth ~elapsed_on_close header
      { entry_id; depth; toc_depth = result_toc_depth; size; elapsed; body; time_tag; _ }
      =
    let span = Mtime.Span.abs_diff elapsed_on_close elapsed in
    match table_of_contents_ch with
    | None -> (toc_depth, B.empty, B.empty)
    | _ when not @@ toc_entry_passes ~depth ~size ~span toc_entry ->
        (toc_depth, B.empty, B.empty)
    | Some _toc_ch ->
        let prefix =
          match (config.toc_specific_hyperlink, config.hyperlink) with
          | Some prefix, _ | None, `Prefix prefix -> prefix ^ debug_ch_name ()
          | None, `No_hyperlinks -> debug_ch_name ()
        in
        let uri = prefix ^ "#" ^ Int.to_string entry_id in
        let rec replace_link b =
          match B.view b with
          | B.Frame b -> B.frame @@ replace_link b
          | B.Pad ({ x; y }, b) -> B.pad' ~col:x ~lines:y @@ replace_link b
          | B.Align { h; v; inner } -> B.align ~h ~v @@ replace_link inner
          | B.Grid (bars, m) -> B.grid ~bars:(bars = `Bars) @@ B.map_matrix replace_link m
          | B.Tree (indent, h, b) -> B.tree ~indent (replace_link h) @@ Array.to_list b
          | B.Link { inner; _ } -> replace_link inner
          | B.Anchor { inner; _ } -> replace_link inner
          | _ -> B.link ~uri b
        in
        let header = replace_link header in
        let header =
          if time_tag = "" then header
          else B.hlist ~bars:false [ header; B.line time_tag ]
        in
        ( max (result_toc_depth + 1) toc_depth,
          header,
          if config.with_toc_listing then
            B.tree header @@ unpack ~f:(fun { toc_subtree; _ } -> toc_subtree) body
          else B.empty )

  let pseudo_random_color =
    let rand = ref (1l : int32) in
    fun () ->
      (rand := Int32.(logxor !rand (shift_left !rand 13)));
      let r = 128 + 64 + (Int32.to_int !rand mod 50) in
      (rand := Int32.(logxor !rand (shift_right_logical !rand 17)));
      let g = 128 + 64 + (Int32.to_int !rand mod 50) in
      (rand := Int32.(logxor !rand (shift_left !rand 5)));
      let b = 128 + 64 + (Int32.to_int !rand mod 50) in
      Printf.sprintf "%x%x%x" r g b

  let stack_to_flame ~elapsed_on_close header { body; elapsed; _ } =
    let e2f = Mtime.Span.to_float_ns in
    let total = e2f @@ Mtime.Span.abs_diff elapsed_on_close elapsed in
    let left_pc ~elapsed_start =
      let left = Mtime.Span.abs_diff elapsed_start elapsed in
      e2f left *. 100. /. total
    in
    let width_pc ~elapsed_start ~elapsed_end =
      let width = Mtime.Span.abs_diff elapsed_end elapsed_start in
      e2f width *. 100. /. total
    in
    let result = Buffer.create 256 in
    let out = Buffer.add_string result in
    let subentry ~flame_subtree ~elapsed_start ~elapsed_end =
      if flame_subtree <> "" then
        let apply = function
          | "left" -> Float.to_string @@ left_pc ~elapsed_start
          | "width" -> Float.to_string @@ width_pc ~elapsed_start ~elapsed_end
          | "flame_subtree" -> flame_subtree
          | _ -> assert false
        in
        Buffer.add_substitute result apply
          {|<div style="position: relative; top:10%; height: 90%; left:$(left)%; width:$(width)%;">
       $(flame_subtree)</div>
       |}
    in
    let header =
      match config.backend with
      | `Text -> PrintBox_text.to_string header
      | `Html config ->
          let config = PrintBox_html.Config.tree_summary false config in
          PrintBox_html.(to_string ~config header)
      | `Markdown config ->
          let config = PrintBox_md.Config.unfolded_trees config in
          PrintBox_md.(to_string Config.(foldable_trees config) header)
    in
    let no_children =
      List.for_all (fun { flame_subtree; _ } -> flame_subtree = "") body
    in
    let out_header () =
      out
        {|<div style="position: relative; top: 0px; left: 0px; width: 100%; background: #|};
      out @@ pseudo_random_color ();
      out {|;">|};
      out header;
      out {|</div>|}
    in
    if header = "" && no_children then ()
    else if no_children then out_header ()
    else (
      out {|<div style="position: relative; top: 0%; width: 100%; height: 100%;">|};
      out_header ();
      List.iter (fun { flame_subtree; elapsed_start; elapsed_end; _ } ->
          subentry ~flame_subtree ~elapsed_start ~elapsed_end)
      @@ List.rev body;
      out "</div>");
    result

  let needs_snapshot_reset = ref false

  let pop_snapshot () =
    if !needs_snapshot_reset then (
      reset_to_snapshot ();
      needs_snapshot_reset := false)

  let output_box ~for_toc ch box =
    match B.view box with
    | Empty -> ()
    | _ ->
        (match config.backend with
        | `Text -> PrintBox_text.output ~style:false ch box
        | `Html config ->
            let config =
              if for_toc then PrintBox_html.Config.tree_summary false config else config
            in
            let log_str = PrintBox_html.(to_string ~config box) in
            output_string ch log_str
        | `Markdown config ->
            let config =
              if for_toc then PrintBox_md.Config.unfolded_trees config else config
            in
            output_string ch @@ PrintBox_md.(to_string Config.(foldable_trees config) box));
        output_string ch "\n";
        Stdlib.flush ch

  let rec is_empty b =
    match B.view b with
    | B.Empty -> true
    | B.Frame b | B.Pad (_, b) | B.Align { inner = b; _ } -> is_empty b
    | B.Grid (_, [| [||] |]) -> true
    | _ -> false

  let close_log_impl ~from_snapshot ~elapsed_on_close ~fname ~start_lnum ~entry_id =
    (match !stack with
    | { entry_id = open_entry_id; _ } :: _ when open_entry_id <> entry_id ->
        let log_loc =
          Printf.sprintf "%s\"%s\":%d: open entry_id=%d, close entry_id=%d" global_prefix
            fname start_lnum open_entry_id entry_id
        in
        failwith
        @@ "ppx_minidebug: lexical scope of close_log not matching its dynamic scope; "
        ^ log_loc
    | [] ->
        let log_loc =
          Printf.sprintf "%s\"%s\":%d: entry_id=%d" global_prefix fname start_lnum
            entry_id
        in
        failwith @@ "ppx_minidebug: close_log must follow an earlier open_log; " ^ log_loc
    | _ -> ());
    (* Note: we treat a tree under a box as part of that box. *)
    stack :=
      (* Design choice: exclude does not apply to its own entry -- it's about propagating children. *)
      match !stack with
      | { highlight = false; _ } :: bs when config.prune_upto >= List.length !stack -> bs
      | { body = []; _ } :: bs when config.log_level <> Everything -> bs
      | { body; _ } :: bs
        when is_prefixed_or_result config.log_level
             && List.for_all (fun e -> e.is_result) body ->
          bs
      | ({
           cond = true;
           highlight = hl;
           exclude = _;
           entry_id = result_id;
           depth = result_depth;
           size = result_size;
           elapsed = elapsed_start;
           _;
         } as entry)
        :: {
             cond;
             highlight;
             exclude;
             uri;
             path;
             elapsed;
             time_tag;
             entry_message;
             entry_id;
             body;
             depth;
             toc_depth;
             size;
           }
        :: bs3 ->
          let header, subtree = stack_to_tree ~elapsed_on_close entry in
          let toc_depth, toc_header, toc_subtree =
            stack_to_toc ~toc_depth ~elapsed_on_close header entry
          in
          let flame_subtree =
            if config.toc_flame_graph && not (is_empty toc_header) then
              Buffer.contents @@ stack_to_flame ~elapsed_on_close toc_header entry
            else ""
          in
          {
            cond;
            highlight = highlight || ((not exclude) && hl);
            exclude;
            uri;
            path;
            elapsed;
            time_tag;
            entry_message;
            entry_id;
            body =
              {
                result_id;
                is_result = false;
                elapsed_start;
                elapsed_end = elapsed_on_close;
                subtree;
                toc_subtree;
                flame_subtree;
              }
              :: body;
            depth = max (result_depth + 1) depth;
            toc_depth;
            size = result_size + size;
          }
          :: bs3
      | { cond = false; _ } :: bs -> bs
      | [ ({ cond = true; toc_depth; _ } as entry) ] ->
          let header, box = stack_to_tree ~elapsed_on_close entry in
          let ch = debug_ch () in
          pop_snapshot ();
          output_box ~for_toc:false ch box;
          if not from_snapshot then snapshot_ch ();
          (match table_of_contents_ch with
          | None -> ()
          | Some toc_ch ->
              let toc_depth, toc_header, toc_box =
                stack_to_toc ~toc_depth ~elapsed_on_close header entry
              in
              if config.with_toc_listing then output_box ~for_toc:true toc_ch toc_box;
              if config.toc_flame_graph && not (is_empty toc_header) then (
                output_string toc_ch
                  {|
                    <div style="position: relative; height: 0px;">|};
                Buffer.output_buffer toc_ch
                @@ stack_to_flame ~elapsed_on_close toc_header entry;
                output_string toc_ch @@ {|</div><div style="height: |}
                ^ Int.to_string (toc_depth * config.flame_graph_separation)
                ^ {|px;"></div>|};
                flush toc_ch));
          []
      | [] -> assert false

  let close_log ~fname ~start_lnum ~entry_id =
    let elapsed_on_close = time_elapsed () in
    close_log_impl ~from_snapshot:false ~elapsed_on_close ~fname ~start_lnum ~entry_id

  let snapshot () =
    let current_stack = !stack in
    let elapsed_on_close = time_elapsed () in
    try
      while !stack <> [] do
        match !stack with
        | { entry_id; _ } :: _ ->
            close_log_impl ~from_snapshot:true ~elapsed_on_close ~fname:"snapshotting"
              ~start_lnum:(List.length !stack) ~entry_id
        | _ -> assert false
      done;
      needs_snapshot_reset := true;
      stack := current_stack
    with e ->
      stack := current_stack;
      raise e

  let opt_auto_snapshot =
    let last_snapshot = ref @@ time_elapsed () in
    fun () ->
      match config.snapshot_every_sec with
      | None -> ()
      | Some threshold ->
          let threshold = Float.to_int @@ (threshold *. 1000.) in
          let now = time_elapsed () in
          if Mtime.Span.(compare (abs_diff now !last_snapshot) (threshold * ms)) > 0 then (
            last_snapshot := now;
            snapshot ())

  let stack_next ~entry_id ~is_result ~prefixed ~result_depth ~result_size (hl, b) =
    let opt_eid = opt_verbose_entry_id ~verbose_entry_ids ~entry_id in
    let rec eid b =
      match B.view b with
      | B.Empty -> B.line opt_eid
      | B.Text { l = []; style } -> B.line_with_style style opt_eid
      | B.Text { l = s :: more; style } -> B.lines_with_style style ((opt_eid ^ s) :: more)
      | B.Frame b -> B.frame @@ eid b
      | B.Pad ({ x; y }, b) -> B.pad' ~col:x ~lines:y @@ eid b
      | B.Align { h; v; inner } -> B.align ~h ~v @@ eid inner
      | B.Grid _ -> B.hlist ~bars:false [ B.line opt_eid; b ]
      | B.Tree (indent, h, b) -> B.tree ~indent (eid h) @@ Array.to_list b
      | B.Link { uri; inner } -> B.link ~uri @@ eid inner
      | B.Anchor { id; inner } -> B.anchor ~id @@ eid inner
    in
    let b = if opt_eid = "" then b else eid b in
    match config.log_level with
    | Nothing -> ()
    | Prefixed _ when not prefixed -> ()
    | Prefixed_or_result _ when not (is_result || prefixed) -> ()
    | _ -> (
        match !stack with
        | ({ highlight; exclude; body; depth; size; elapsed; _ } as entry) :: bs2 ->
            stack :=
              {
                entry with
                highlight = highlight || ((not exclude) && hl);
                body =
                  {
                    result_id = entry_id;
                    is_result;
                    elapsed_start = elapsed;
                    elapsed_end = elapsed;
                    subtree = b;
                    toc_subtree = B.empty;
                    flame_subtree = "";
                  }
                  :: body;
                depth = max (result_depth + 1) depth;
                size = size + result_size;
              }
              :: bs2
        | [] ->
            let elapsed = time_elapsed () in
            let subentry =
              {
                result_id = entry_id;
                is_result;
                elapsed_start = elapsed;
                elapsed_end = elapsed;
                subtree = b;
                toc_subtree = B.empty;
                flame_subtree = "";
              }
            in
            let entry_message = "{orphaned from #" ^ Int.to_string entry_id ^ "}" in
            stack :=
              [
                {
                  cond = true;
                  highlight = hl;
                  exclude = false;
                  elapsed;
                  time_tag = "";
                  uri = "";
                  path = "";
                  entry_message;
                  entry_id = -1;
                  body = [ subentry ];
                  depth = 1;
                  toc_depth = 0;
                  size = 1;
                };
              ];
            close_log ~fname:"orphaned" ~start_lnum:entry_id ~entry_id:(-1))

  let open_log ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message ~entry_id =
    let elapsed = time_elapsed () in
    let uri =
      match config.hyperlink with
      | `Prefix prefix
        when String.length prefix = 0
             || Char.equal prefix.[0] '.'
             || String.length prefix > 6
                && (String.equal (String.sub prefix 0 5) "http:"
                   || String.equal (String.sub prefix 0 6) "https:") ->
          Printf.sprintf "%s#L%d" fname start_lnum
      | _ -> Printf.sprintf "%s:%d:%d" fname start_lnum (start_colnum + 1)
    in
    let location =
      match Log_to.location_format with
      | No_location -> ""
      | File_only -> Printf.sprintf "\"%s\":" fname
      | Beg_line -> Printf.sprintf "\"%s\":%d" fname start_lnum
      | Beg_pos -> Printf.sprintf "\"%s\":%d:%d" fname start_lnum start_colnum
      | Range_line -> Format.asprintf "\"%s\":%d-%d" fname start_lnum end_lnum
      | Range_pos ->
          Format.asprintf "\"%s\":%d:%d-%d:%d" fname start_lnum start_colnum end_lnum
            end_colnum
    in
    let time_tag =
      match time_tagged with
      | Not_tagged -> ""
      | Clock -> Format.asprintf " at time %a" pp_timestamp ()
      | Elapsed -> Format.asprintf " at elapsed %a" pp_elapsed ()
    in
    let path = location ^ time_tag in
    let exclude =
      match config.exclude_on_path with Some r -> Re.execp r message | None -> false
    in
    let highlight =
      match config.highlight_terms with Some r -> Re.execp r message | None -> false
    in
    let entry_message = global_prefix ^ message in
    stack :=
      {
        cond = true;
        highlight;
        exclude;
        uri;
        path;
        elapsed;
        time_tag;
        entry_message;
        entry_id;
        body = [];
        depth = 0;
        toc_depth = 0;
        size = 1;
      }
      :: !stack

  let open_log_no_source ~message ~entry_id =
    let time_tag =
      match time_tagged with
      | Not_tagged -> ""
      | Clock -> Format.asprintf " at time %a" pp_timestamp ()
      | Elapsed -> Format.asprintf " at elapsed %a" pp_elapsed ()
    in
    let exclude =
      match config.exclude_on_path with Some r -> Re.execp r message | None -> false
    in
    let highlight =
      match config.highlight_terms with Some r -> Re.execp r message | None -> false
    in
    let entry_message = global_prefix ^ message in
    stack :=
      {
        cond = true;
        highlight;
        exclude;
        uri = "";
        path = "";
        elapsed = time_elapsed ();
        time_tag;
        entry_message;
        entry_id;
        body = [];
        depth = 0;
        toc_depth = 0;
        size = 1;
      }
      :: !stack

  let sexp_size sexp =
    let open Sexplib0.Sexp in
    let rec loop = function
      | Atom _ -> 1
      | List l -> List.fold_left ( + ) 0 (List.map loop l)
    in
    loop sexp

  let highlight_box ?(hl_body = false) b =
    (* Recall the design choice: [exclude] does not apply to its own entry.
       Therefore, an entry "propagates its highlight". *)
    let hl =
      match (config.exclude_on_path, config.highlight_terms, hl_body) with
      | None, None, _ | Some _, None, false -> false
      | Some e, hl_terms, true -> (
          let message = PrintBox_text.to_string_with ~style:false b in
          let excl = Re.execp e message in
          (not excl) || match hl_terms with None -> false | Some r -> Re.execp r message)
      | None, Some _, true -> true
      | _, Some r, false ->
          let message = PrintBox_text.to_string_with ~style:false b in
          Re.execp r message
    in
    (hl, apply_highlight hl b)

  let pp_sexp ppf = function
    | Sexplib0.Sexp.Atom s when config.sexp_unescape_strings ->
        Format.pp_print_string ppf s
    | e -> Sexplib0.Sexp.pp_hum ppf e

  let boxify ?descr sexp =
    let open Sexplib0.Sexp in
    let rec loop ?(as_tree = false) sexp =
      if (not as_tree) && sexp_size sexp < config.boxify_sexp_from_size then
        highlight_box @@ B.asprintf_with_style B.Style.preformatted "%a" pp_sexp sexp
      else
        match sexp with
        | Atom s -> highlight_box @@ B.text_with_style B.Style.preformatted s
        | List [] -> (false, B.empty)
        | List [ s ] -> loop s
        | List (Atom s :: l) ->
            let hl_body, bs = List.split @@ List.map loop l in
            let hl_body = List.exists (fun x -> x) hl_body in
            let hl, b =
              (* Design choice: Don't render headers of multiline values as monospace, to emphasize them. *)
              highlight_box ~hl_body
              @@ if as_tree then B.text s else B.text_with_style B.Style.preformatted s
            in
            (hl, B.tree b bs)
        | List l ->
            let hls, bs = List.split @@ List.map loop l in
            (List.exists (fun x -> x) hls, B.vlist ~bars:false bs)
    in
    match (sexp, descr) with
    | (Atom s | List [ Atom s ]), Some d ->
        highlight_box @@ B.text_with_style B.Style.preformatted (d ^ " = " ^ s)
    | (Atom s | List [ Atom s ]), None ->
        highlight_box @@ B.text_with_style B.Style.preformatted s
    | List [], Some d -> highlight_box @@ B.line d
    | List [], None -> (false, B.empty)
    | List l, _ ->
        let str =
          if sexp_size sexp < min config.boxify_sexp_from_size config.max_inline_sexp_size
          then Sexplib0.Sexp.to_string_hum sexp
          else ""
        in
        if String.length str > 0 && String.length str < config.max_inline_sexp_length then
          (* TODO: Desing choice: consider not using monospace, at least for descr.  *)
          highlight_box
          @@ B.text_with_style B.Style.preformatted
          @@ match descr with None -> str | Some d -> d ^ " = " ^ str
        else
          loop ~as_tree:true
          @@ List ((match descr with None -> [] | Some d -> [ Atom (d ^ " =") ]) @ l)

  let num_children () = match !stack with [] -> 0 | { body; _ } :: _ -> List.length body

  let log_value_sexp ?descr ~entry_id ~is_result sexp =
    let prefixed =
      match config.log_level with
      | Prefixed_or_result [||] -> true
      | Prefixed [||] ->
          failwith "ppx_minidebug: runtime log levels do not support explicit-logs-only"
      | Prefixed prefixes | Prefixed_or_result prefixes ->
          let rec loop = function
            | Sexplib0.Sexp.Atom s ->
                Array.exists (fun prefix -> String.starts_with ~prefix s) prefixes
            | List [] -> false
            | List (e :: _) -> loop e
          in
          loop sexp
      | _ -> true
    in
    (if config.boxify_sexp_from_size >= 0 then
       stack_next ~entry_id ~is_result ~prefixed ~result_depth:0 ~result_size:1
       @@ boxify ?descr sexp
     else
       stack_next ~entry_id ~is_result ~prefixed ~result_depth:0 ~result_size:1
       @@ highlight_box
       @@
       match descr with
       | None -> B.asprintf_with_style B.Style.preformatted "%a" pp_sexp sexp
       | Some d -> B.asprintf_with_style B.Style.preformatted "%s = %a" d pp_sexp sexp);
    opt_auto_snapshot ()

  let skip_parens s =
    let len = String.length s in
    let pos = ref 0 in
    while !pos < len && (s.[!pos] = '(' || s.[!pos] = '{' || s.[!pos] = '[') do
      incr pos
    done;
    let s = String.(sub s !pos @@ (length s - !pos)) in
    s

  let log_value_pp ?descr ~entry_id ~pp ~is_result v =
    let prefixed =
      match config.log_level with
      | Prefixed_or_result [||] -> true
      | Prefixed [||] ->
          failwith "ppx_minidebug: runtime log levels do not support explicit-logs-only"
      | Prefixed prefixes | Prefixed_or_result prefixes ->
          (* TODO: perf-hint: cache this conversion and maybe don't re-convert. *)
          let s = skip_parens @@ Format.asprintf "%a" pp v in
          Array.exists (fun prefix -> String.starts_with ~prefix s) prefixes
      | _ -> true
    in
    (stack_next ~entry_id ~is_result ~prefixed ~result_depth:0 ~result_size:1
    @@ highlight_box
    @@
    match descr with
    | None -> B.asprintf_with_style B.Style.preformatted "%a" pp v
    | Some d -> B.asprintf_with_style B.Style.preformatted "%s = %a" d pp v);
    opt_auto_snapshot ()

  let log_value_show ?descr ~entry_id ~is_result v =
    let prefixed =
      match config.log_level with
      | Prefixed_or_result [||] -> true
      | Prefixed [||] ->
          failwith "ppx_minidebug: runtime log levels do not support explicit-logs-only"
      | Prefixed prefixes | Prefixed_or_result prefixes ->
          let s = skip_parens v in
          Array.exists (fun prefix -> String.starts_with ~prefix s) prefixes
      | _ -> true
    in
    (stack_next ~entry_id ~is_result ~prefixed ~result_depth:0 ~result_size:1
    @@ highlight_box
    @@
    match descr with
    | None -> B.sprintf_with_style B.Style.preformatted "%s" v
    | Some d -> B.sprintf_with_style B.Style.preformatted "%s = %s" d v);
    opt_auto_snapshot ()

  let log_value_printbox ~entry_id v =
    let prefixed =
      match config.log_level with
      | Prefixed_or_result [||] -> true
      | Prefixed [||] -> true
      | Prefixed _ | Prefixed_or_result _ -> false
      | _ -> true
    in
    stack_next ~entry_id ~is_result:false ~prefixed ~result_depth:0 ~result_size:1
    @@ highlight_box v;
    opt_auto_snapshot ()

  let no_debug_if cond =
    match !stack with
    | ({ cond = true; _ } as entry) :: bs when cond ->
        stack := { entry with cond = false } :: bs
    | _ -> ()

  let exceeds_max_nesting () =
    exceeds ~value:(List.length !stack) ~limit:!max_nesting_depth

  let exceeds_max_children () = exceeds ~value:(num_children ()) ~limit:!max_num_children

  let get_entry_id =
    let global_id = ref 0 in
    fun () ->
      incr global_id;
      !global_id

  let global_prefix = global_prefix
end

let debug_file ?(time_tagged = Not_tagged) ?(elapsed_times = elapsed_default)
    ?(location_format = Beg_pos) ?(print_entry_ids = false) ?(verbose_entry_ids = false)
    ?(global_prefix = "") ?split_files_after ?(with_toc_listing = false)
    ?(toc_entry = And []) ?(toc_flame_graph = false) ?(flame_graph_separation = 40)
    ?highlight_terms ?exclude_on_path ?(prune_upto = 0) ?(truncate_children = 0)
    ?(for_append = false) ?(boxify_sexp_from_size = 50) ?(max_inline_sexp_length = 80)
    ?backend ?hyperlink ?toc_specific_hyperlink ?(values_first_mode = false)
    ?(log_level = Everything) ?snapshot_every_sec filename : (module PrintBox_runtime) =
  let filename =
    match backend with
    | None | Some (`Markdown _) -> filename ^ ".md"
    | Some (`Html _) -> filename ^ ".html"
    | Some `Text -> filename ^ ".log"
  in
  let with_table_of_contents = toc_flame_graph || with_toc_listing in
  let module Debug =
    PrintBox
      ((val shared_config ~time_tagged ~elapsed_times ~location_format ~print_entry_ids
              ~verbose_entry_ids ~global_prefix ~for_append ?split_files_after
              ~with_table_of_contents ~toc_entry filename)) in
  Debug.config.backend <- Option.value backend ~default:(`Markdown default_md_config);
  Debug.config.boxify_sexp_from_size <- boxify_sexp_from_size;
  Debug.config.max_inline_sexp_length <- max_inline_sexp_length;
  Debug.config.highlight_terms <- Option.map Re.compile highlight_terms;
  Debug.config.prune_upto <- prune_upto;
  Debug.config.truncate_children <- truncate_children;
  Debug.config.exclude_on_path <- Option.map Re.compile exclude_on_path;
  Debug.config.values_first_mode <- values_first_mode;
  Debug.config.hyperlink <-
    (match hyperlink with None -> `No_hyperlinks | Some prefix -> `Prefix prefix);
  Debug.config.toc_specific_hyperlink <- toc_specific_hyperlink;
  Debug.config.log_level <- log_level;
  Debug.config.snapshot_every_sec <- snapshot_every_sec;
  Debug.config.with_toc_listing <- with_toc_listing;
  if toc_flame_graph && backend = Some `Text then
    invalid_arg
      "Minidebug_runtime.debug_file: flame graphs are not supported in the Text backend";
  Debug.config.toc_flame_graph <- toc_flame_graph;
  Debug.config.flame_graph_separation <- flame_graph_separation;
  (module Debug)

let debug ?debug_ch ?(time_tagged = Not_tagged) ?(elapsed_times = elapsed_default)
    ?(location_format = Beg_pos) ?(print_entry_ids = false) ?(verbose_entry_ids = false)
    ?(global_prefix = "") ?table_of_contents_ch ?(toc_entry = And []) ?highlight_terms
    ?exclude_on_path ?(prune_upto = 0) ?(truncate_children = 0) ?toc_specific_hyperlink
    ?(values_first_mode = false) ?(log_level = Everything) ?snapshot_every_sec () :
    (module PrintBox_runtime) =
  let module Debug = PrintBox (struct
    let refresh_ch () = false
    let ch = match debug_ch with None -> stdout | Some ch -> ch
    let current_snapshot = ref 0

    let snapshot_ch () =
      match debug_ch with
      | None -> ()
      | Some _ ->
          flush ch;
          current_snapshot := pos_out ch

    let reset_to_snapshot () =
      match debug_ch with
      | None -> Printf.fprintf ch "\027[2J\027[1;1H%!"
      | Some _ -> seek_out ch !current_snapshot

    let debug_ch () = ch
    let debug_ch_name () = global_prefix
    let table_of_contents_ch = table_of_contents_ch
    let time_tagged = time_tagged
    let elapsed_times = elapsed_times
    let location_format = location_format
    let print_entry_ids = print_entry_ids
    let verbose_entry_ids = verbose_entry_ids
    let global_prefix = if global_prefix = "" then "" else global_prefix ^ " "
    let split_files_after = None
    let toc_entry = toc_entry
  end) in
  Debug.config.highlight_terms <- Option.map Re.compile highlight_terms;
  Debug.config.prune_upto <- prune_upto;
  Debug.config.truncate_children <- truncate_children;
  Debug.config.exclude_on_path <- Option.map Re.compile exclude_on_path;
  Debug.config.values_first_mode <- values_first_mode;
  Debug.config.log_level <- log_level;
  Debug.config.snapshot_every_sec <- snapshot_every_sec;
  Debug.config.toc_specific_hyperlink <- toc_specific_hyperlink;
  (module Debug)

let debug_flushing ?debug_ch:d_ch ?table_of_contents_ch ?filename
    ?(time_tagged = Not_tagged) ?(elapsed_times = elapsed_default)
    ?(location_format = Beg_pos) ?(print_entry_ids = false) ?(verbose_entry_ids = false)
    ?(global_prefix = "") ?split_files_after ?(with_table_of_contents = false)
    ?(toc_entry = And []) ?(for_append = false) () : (module Debug_runtime) =
  let log_to =
    match (filename, d_ch) with
    | None, _ ->
        (module struct
          let refresh_ch () = false
          let ch = match d_ch with None -> stdout | Some ch -> ch
          let current_snapshot = ref 0

          let snapshot_ch () =
            match d_ch with
            | None -> ()
            | Some _ ->
                flush ch;
                current_snapshot := pos_out ch

          let reset_to_snapshot () =
            match d_ch with
            | None -> Printf.fprintf ch "\027[2J\027[1;1H%!"
            | Some _ -> seek_out ch !current_snapshot

          let debug_ch () = ch
          let debug_ch_name () = global_prefix

          let table_of_contents_ch =
            match (table_of_contents_ch, with_table_of_contents) with
            | Some toc_ch, _ -> Some toc_ch
            | None, true -> Some ch
            | _ -> None

          let time_tagged = time_tagged
          let elapsed_times = elapsed_times
          let location_format = location_format
          let print_entry_ids = print_entry_ids
          let verbose_entry_ids = verbose_entry_ids
          let global_prefix = if global_prefix = "" then "" else global_prefix ^ " "
          let split_files_after = split_files_after
          let toc_entry = toc_entry
        end : Shared_config)
    | Some filename, None ->
        let filename = filename ^ ".log" in
        shared_config ~time_tagged ~elapsed_times ~location_format ~print_entry_ids
          ~global_prefix ?split_files_after ~with_table_of_contents ~toc_entry ~for_append
          filename
    | Some _, Some _ ->
        invalid_arg
          "Minidebug_runtime.debug_flushing: only one of debug_ch, filename should be \
           provided"
  in
  (module Flushing ((val log_to)))

let forget_printbox (module Runtime : PrintBox_runtime) = (module Runtime : Debug_runtime)

let sexp_of_lazy_t sexp_of_a l =
  if Lazy.is_val l then Sexplib0.Sexp.List [ Atom "lazy"; sexp_of_a @@ Lazy.force l ]
  else Sexplib0.Sexp.List [ Atom "lazy"; Atom "<thunk>" ]
