module CFormat = Format

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

let is_prefixed_or_result = function Prefixed_or_result _ -> true | _ -> false

module type Shared_config = sig
  val refresh_ch : unit -> bool
  val debug_ch : unit -> out_channel
  val snapshot_ch : unit -> unit
  val reset_to_snapshot : unit -> unit
  val time_tagged : time_tagged
  val elapsed_times : elapsed_times
  val location_format : location_format
  val print_entry_ids : bool
  val verbose_entry_ids : bool
  val global_prefix : string
  val split_files_after : int option
end

let elapsed_default = Not_reported

let shared_config ?(time_tagged = Not_tagged) ?(elapsed_times = elapsed_default)
    ?(location_format = Beg_pos) ?(print_entry_ids = false) ?(verbose_entry_ids = false)
    ?(global_prefix = "") ?split_files_after ?(for_append = true) filename :
    (module Shared_config) =
  let module Result = struct
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

    let snapshot_ch () =
      flush !current_ch;
      current_snapshot := pos_out !current_ch

    let reset_to_snapshot () = seek_out !current_ch !current_snapshot
    let time_tagged = time_tagged
    let elapsed_times = elapsed_times
    let location_format = location_format
    let print_entry_ids = print_entry_ids
    let verbose_entry_ids = verbose_entry_ids
    let global_prefix = if global_prefix = "" then "" else global_prefix ^ " "
    let split_files_after = split_files_after
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

let time_span ~none ~some elapsed elapsed_times =
  let span = Mtime.Span.to_float_ns (Mtime.Span.abs_diff (time_elapsed ()) elapsed) in
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

  type entry = {
    message : string;
    num_children : int;
    elapsed : Mtime.span;
    entry_id : int;
  }

  let stack = ref []
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
        let log_loc = Printf.sprintf "\"%s\":%d: entry_id=%d" fname start_lnum entry_id in
        failwith @@ "ppx_minidebug: close_log must follow an earlier open_log; " ^ log_loc
    | { message; elapsed; entry_id = open_entry_id; _ } :: tl ->
        stack := tl;
        (if open_entry_id <> entry_id then
           let log_loc =
             Printf.sprintf "\"%s\":%d: open entry_id=%d, close entry_id=%d" fname
               start_lnum open_entry_id entry_id
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
          elapsed elapsed_times;
        Printf.fprintf !debug_ch "%s%s end\n%!" global_prefix message;
        flush !debug_ch;
        if !stack = [] then debug_ch := Log_to.debug_ch ()

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
    (match Log_to.time_tagged with
    | Not_tagged -> Printf.fprintf !debug_ch "\n%!"
    | Clock -> Printf.fprintf !debug_ch " %s\n%!" (timestamp_to_string ())
    | Elapsed -> Printf.fprintf !debug_ch " %s\n%!" (Format.asprintf "%a" pp_elapsed ()));
    stack := { message; elapsed = time_elapsed (); num_children = 0; entry_id } :: !stack

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
  }

  val config : config
  val snapshot : unit -> unit
end

module PrintBox (Log_to : Shared_config) = struct
  open Log_to

  let max_nesting_depth = ref None
  let max_num_children = ref None

  type config = {
    mutable hyperlink : [ `Prefix of string | `No_hyperlinks ];
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
  }

  let config =
    {
      hyperlink = `No_hyperlinks;
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
    }

  module B = PrintBox

  type subentry = { result_id : int; is_result : bool; subtree : B.t }

  type entry = {
    cond : bool;
    highlight : bool;
    exclude : bool;
    elapsed : Mtime.span;
    uri : string;
    path : string;
    entry_message : string;
    entry_id : int;
    body : subentry list;
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
    match B.view b with B.Frame _ -> b | _ -> if hl then B.frame b else b

  let stack_to_tree
      {
        cond = _;
        highlight;
        exclude = _;
        elapsed;
        uri;
        path;
        entry_message;
        entry_id;
        body;
      } =
    let non_id_message =
      (* Being defensive: checking for '=' not required so far. *)
      String.contains entry_message '<'
      || String.contains entry_message ':'
      || String.contains entry_message '='
    in
    let span =
      time_span ~none:(fun () -> "") ~some:(fun span -> " " ^ span) elapsed elapsed_times
    in
    let opt_id = opt_entry_id ~print_entry_ids ~entry_id in
    let colon a b = if a = "" || b = "" then a ^ b else a ^ ": " ^ b in
    let b_path =
      B.line
      @@
      if config.values_first_mode then
        if entry_id = -1 then colon path entry_message else colon path opt_id
      else colon path (opt_id ^ entry_message) ^ span
    in
    let b_path = hyperlink_path ~uri ~inner:b_path in
    let rec unpack truncate acc = function
      | [] -> acc
      | [ { subtree; _ } ] -> subtree :: acc
      | { subtree; _ } :: tl ->
          if truncate = 0 then B.line "<earlier entries truncated>" :: subtree :: acc
          else unpack (truncate - 1) (subtree :: acc) tl
    in
    let unpack l = unpack (config.truncate_children - 1) [] l in
    if config.values_first_mode then
      let hl_header =
        if entry_id = -1 then B.empty
        else apply_highlight highlight @@ B.line @@ opt_id ^ entry_message ^ span
      in
      let results, body =
        if entry_id = -1 then (body, [])
        else
          List.partition
            (fun { result_id; is_result; _ } -> is_result && result_id = entry_id)
            body
      in
      let results = unpack results and body = unpack body in
      match results with
      | [ subtree ] -> (
          let opt_message = if non_id_message then [ hl_header ] else [] in
          match B.view subtree with
          | B.Tree (_ident, result_header, result_body) ->
              let value_header =
                if elapsed_times = Not_reported then result_header
                else B.hlist ~bars:false [ result_header; B.line span ]
              in
              B.tree
                (apply_highlight highlight value_header)
                (b_path
                 :: B.tree
                      (B.line @@ if body = [] then "<values>" else "<returns>")
                      (Array.to_list result_body)
                 :: opt_message
                @ body)
          | _ ->
              let value_header =
                if elapsed_times = Not_reported then subtree
                else B.hlist ~bars:false [ subtree; B.line span ]
              in
              B.tree
                (apply_highlight highlight value_header)
                ((b_path :: opt_message) @ body))
      | [] -> B.tree hl_header (b_path :: body)
      | _ ->
          B.tree hl_header
          @@ b_path
             :: B.tree (B.line @@ if body = [] then "<values>" else "<returns>") results
             :: body
    else
      let hl_header = apply_highlight highlight b_path in
      B.tree hl_header (unpack body)

  let needs_snapshot_reset = ref false

  let pop_snapshot () =
    if !needs_snapshot_reset then (
      reset_to_snapshot ();
      needs_snapshot_reset := false)

  let close_log_impl ~from_snapshot ~fname ~start_lnum ~entry_id =
    (match !stack with
    | { entry_id = open_entry_id; _ } :: _ when open_entry_id <> entry_id ->
        let log_loc =
          Printf.sprintf "\"%s\":%d: open entry_id=%d, close entry_id=%d" fname start_lnum
            open_entry_id entry_id
        in
        failwith
        @@ "ppx_minidebug: lexical scope of close_log not matching its dynamic scope; "
        ^ log_loc
    | [] ->
        let log_loc = Printf.sprintf "\"%s\":%d: entry_id=%d" fname start_lnum entry_id in
        failwith @@ "ppx_minidebug: close_log must follow an earlier open_log; " ^ log_loc
    | _ -> ());
    (* Note: we treat a tree under a box as part of that box. *)
    stack :=
      (* Design choice: exclude does not apply to its own entry -- its about propagating children. *)
      match !stack with
      | { highlight = false; _ } :: bs when config.prune_upto >= List.length !stack -> bs
      | { body = []; _ } :: bs when config.log_level <> Everything -> bs
      | { body; _ } :: bs
        when is_prefixed_or_result config.log_level
             && List.for_all (fun e -> e.is_result) body ->
          bs
      | ({ cond = true; highlight = hl; exclude = _; entry_id = result_id; _ } as entry)
        :: { cond; highlight; exclude; uri; path; elapsed; entry_message; entry_id; body }
        :: bs3 ->
          {
            cond;
            highlight = highlight || ((not exclude) && hl);
            exclude;
            uri;
            path;
            elapsed;
            entry_message;
            entry_id;
            body = { result_id; is_result = false; subtree = stack_to_tree entry } :: body;
          }
          :: bs3
      | { cond = false; _ } :: bs -> bs
      | [ ({ cond = true; _ } as entry) ] ->
          let box = stack_to_tree entry in
          let ch = debug_ch () in
          pop_snapshot ();
          (match config.backend with
          | `Text -> PrintBox_text.output ch box
          | `Html config -> output_string ch @@ PrintBox_html.(to_string ~config box)
          | `Markdown config ->
              output_string ch
              @@ PrintBox_md.(to_string Config.(foldable_trees config) box));
          output_string ch "\n";
          Stdlib.flush ch;
          if not from_snapshot then snapshot_ch ();
          []
      | [] -> assert false

  let close_log ~fname ~start_lnum ~entry_id =
    close_log_impl ~from_snapshot:false ~fname ~start_lnum ~entry_id

  let snapshot () =
    let current_stack = !stack in
    try
      while !stack <> [] do
        match !stack with
        | { entry_id; _ } :: _ ->
            close_log_impl ~from_snapshot:true ~fname:"snapshotting"
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

  let stack_next ~entry_id ~is_result ~prefixed (hl, b) =
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
    in
    let b = if opt_eid = "" then b else eid b in
    match config.log_level with
    | Nothing -> ()
    | Prefixed _ when not prefixed -> ()
    | Prefixed_or_result _ when not (is_result || prefixed) -> ()
    | _ -> (
        match !stack with
        | ({ highlight; exclude; body; _ } as entry) :: bs2 ->
            stack :=
              {
                entry with
                highlight = highlight || ((not exclude) && hl);
                body = { result_id = entry_id; is_result; subtree = b } :: body;
              }
              :: bs2
        | [] ->
            let subentry = { result_id = entry_id; is_result; subtree = b } in
            let entry_message = "{orphaned from #" ^ Int.to_string entry_id ^ "}" in
            stack :=
              [
                {
                  cond = true;
                  highlight = hl;
                  exclude = false;
                  elapsed = Mtime.Span.zero;
                  uri = "";
                  path = "";
                  entry_message;
                  entry_id = -1;
                  body = [ subentry ];
                };
              ];
            close_log ~fname:"orphaned" ~start_lnum:entry_id ~entry_id:(-1))

  let open_log ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message ~entry_id =
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
        elapsed = time_elapsed ();
        entry_message;
        entry_id;
        body = [];
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
       stack_next ~entry_id ~is_result ~prefixed @@ boxify ?descr sexp
     else
       stack_next ~entry_id ~is_result ~prefixed
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
    (stack_next ~entry_id ~is_result ~prefixed
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
    (stack_next ~entry_id ~is_result ~prefixed
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
    stack_next ~entry_id ~is_result:false ~prefixed @@ highlight_box v;
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
    ?(global_prefix = "") ?split_files_after ?highlight_terms ?exclude_on_path
    ?(prune_upto = 0) ?(truncate_children = 0) ?(for_append = false)
    ?(boxify_sexp_from_size = 50) ?(max_inline_sexp_length = 80) ?backend ?hyperlink
    ?(values_first_mode = false) ?(log_level = Everything) ?snapshot_every_sec filename :
    (module PrintBox_runtime) =
  let filename =
    match backend with
    | None | Some (`Markdown _) -> filename ^ ".md"
    | Some (`Html _) -> filename ^ ".html"
    | Some `Text -> filename ^ ".log"
  in
  let module Debug =
    PrintBox
      ((val shared_config ~time_tagged ~elapsed_times ~location_format ~print_entry_ids
              ~verbose_entry_ids ~global_prefix ~for_append ?split_files_after filename)) in
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
  Debug.config.log_level <- log_level;
  Debug.config.snapshot_every_sec <- snapshot_every_sec;
  (module Debug)

let debug ?debug_ch ?(time_tagged = Not_tagged) ?(elapsed_times = elapsed_default)
    ?(location_format = Beg_pos) ?(print_entry_ids = false) ?(verbose_entry_ids = false)
    ?(global_prefix = "") ?highlight_terms ?exclude_on_path ?(prune_upto = 0)
    ?(truncate_children = 0) ?(values_first_mode = false) ?(log_level = Everything)
    ?snapshot_every_sec () : (module PrintBox_runtime) =
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
    let time_tagged = time_tagged
    let elapsed_times = elapsed_times
    let location_format = location_format
    let print_entry_ids = print_entry_ids
    let verbose_entry_ids = verbose_entry_ids
    let global_prefix = if global_prefix = "" then "" else global_prefix ^ " "
    let split_files_after = None
  end) in
  Debug.config.highlight_terms <- Option.map Re.compile highlight_terms;
  Debug.config.prune_upto <- prune_upto;
  Debug.config.truncate_children <- truncate_children;
  Debug.config.exclude_on_path <- Option.map Re.compile exclude_on_path;
  Debug.config.values_first_mode <- values_first_mode;
  Debug.config.log_level <- log_level;
  Debug.config.snapshot_every_sec <- snapshot_every_sec;
  (module Debug)

let debug_flushing ?debug_ch:d_ch ?filename ?(time_tagged = Not_tagged)
    ?(elapsed_times = elapsed_default) ?(location_format = Beg_pos)
    ?(print_entry_ids = false) ?(verbose_entry_ids = false) ?(global_prefix = "")
    ?split_files_after ?(for_append = false) () : (module Debug_runtime) =
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
          let time_tagged = time_tagged
          let elapsed_times = elapsed_times
          let location_format = location_format
          let print_entry_ids = print_entry_ids
          let verbose_entry_ids = verbose_entry_ids
          let global_prefix = if global_prefix = "" then "" else global_prefix ^ " "
          let split_files_after = split_files_after
        end : Shared_config)
    | Some filename, None ->
        let filename = filename ^ ".log" in
        shared_config ~time_tagged ~elapsed_times ~location_format ~print_entry_ids
          ~global_prefix ?split_files_after ~for_append filename
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
