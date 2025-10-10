module CFormat = Format
module B = PrintBox

let time_elapsed () = Mtime_clock.elapsed ()

let pp_timestamp ppf () =
  let tz_offset_s = Ptime_clock.current_tz_offset_s () in
  Ptime.(pp_human ~frac_s:6 ?tz_offset_s ()) ppf (Ptime_clock.now ())

let timestamp_to_string () =
  let buf = Buffer.create 512 in
  let formatter = CFormat.formatter_of_buffer buf in
  let tz_offset_s = Ptime_clock.current_tz_offset_s () in
  Ptime.(pp_human ~frac_s:6 ?tz_offset_s ()) formatter (Ptime_clock.now ());
  CFormat.pp_print_flush formatter ();
  Buffer.contents buf

let pp_elapsed ppf () =
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
  val prefix_all_logs : bool
  val split_files_after : int option
  val toc_entry : toc_entry_criteria
  val init_log_level : int
  val path_filter : [ `Whitelist of Re.re | `Blacklist of Re.re ] option
end

let elapsed_default = Not_reported

let shared_config ?(time_tagged = Not_tagged) ?(elapsed_times = elapsed_default)
    ?(location_format = Beg_pos) ?(print_entry_ids = false) ?(verbose_entry_ids = false)
    ?(global_prefix = "") ?(prefix_all_logs = false) ?split_files_after
    ?(with_table_of_contents = false) ?(toc_entry = And []) ?(for_append = true)
    ?(log_level = 9) ?path_filter filename : (module Shared_config) =
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
          let ch =
            if for_append then open_out_gen [ Open_creat; Open_append ] 0o640 filename
            else open_out filename
          in
          Gc.finalise (fun _ -> close_out ch) ch;
          ch
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
          let ch =
            if for_append then open_out_gen [ Open_creat; Open_append ] 0o640 filename
            else open_out filename
          in
          Gc.finalise (fun _ -> close_out ch) ch;
          ch

    let current_ch = lazy (ref @@ find_ch ())
    let ( !! ) ch = !(Lazy.force_val ch)

    let refresh_ch () =
      match split_files_after with
      | None -> false
      | Some split_after ->
          Stdlib.flush !!current_ch;
          Int64.to_int (Stdlib.LargeFile.out_channel_length !!current_ch) > split_after

    let current_snapshot = ref 0

    let debug_ch () =
      if refresh_ch () then (
        close_out !!current_ch;
        Lazy.force_val current_ch := find_ch ();
        current_snapshot := 0);
      !!current_ch

    let debug_ch_name () = !current_ch_name

    let snapshot_ch () =
      flush !!current_ch;
      current_snapshot := pos_out !!current_ch

    let reset_to_snapshot () = seek_out !!current_ch !current_snapshot

    let table_of_contents_ch =
      if with_table_of_contents then (
        let suffix = Filename.extension filename in
        let filename = Filename.remove_extension filename ^ "-toc" ^ suffix in
        let ch =
          if for_append then open_out_gen [ Open_creat; Open_append ] 0o640 filename
          else open_out filename
        in
        Gc.finalise (fun _ -> close_out ch) ch;
        Some ch)
      else None

    let time_tagged = time_tagged
    let elapsed_times = elapsed_times
    let location_format = location_format
    let print_entry_ids = print_entry_ids
    let verbose_entry_ids = verbose_entry_ids
    let global_prefix = if global_prefix = "" then "" else global_prefix ^ " "
    let prefix_all_logs = prefix_all_logs
    let split_files_after = split_files_after
    let toc_entry = toc_entry
    let init_log_level = log_level
    let path_filter = path_filter
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
    log_level:int ->
    [ `Diagn | `Debug | `Track ] ->
    unit

  val open_log_no_source :
    message:string ->
    entry_id:int ->
    log_level:int ->
    [ `Diagn | `Debug | `Track ] ->
    unit

  val log_value_sexp :
    ?descr:string ->
    entry_id:int ->
    log_level:int ->
    is_result:bool ->
    Sexplib0.Sexp.t Lazy.t ->
    unit

  val log_value_pp :
    ?descr:string ->
    entry_id:int ->
    log_level:int ->
    pp:(Format.formatter -> 'a -> unit) ->
    is_result:bool ->
    'a Lazy.t ->
    unit

  val log_value_show :
    ?descr:string ->
    entry_id:int ->
    log_level:int ->
    is_result:bool ->
    string Lazy.t ->
    unit

  val log_value_printbox : entry_id:int -> log_level:int -> PrintBox.t -> unit
  val exceeds_max_nesting : unit -> bool
  val exceeds_max_children : unit -> bool
  val get_entry_id : unit -> int
  val max_nesting_depth : int option ref
  val max_num_children : int option ref
  val global_prefix : string

  (* val prefix_all_logs : bool *)
  val snapshot : unit -> unit
  val finish_and_cleanup : unit -> unit
  val no_debug_if : bool -> unit
  val log_level : int ref
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

  let log_level = ref init_log_level
  let max_nesting_depth = ref None
  let max_num_children = ref None

  type entry = {
    message : string;
    num_children : int;
    elapsed : Mtime.span;
    time_tag : string;
    entry_id : int;
  }

  let check_log_level level = level <= !log_level

  let should_log_path fname message =
    match Log_to.path_filter with
    | None -> true
    | Some (`Whitelist re) -> Re.execp re (fname ^ "/" ^ message)
    | Some (`Blacklist re) -> not (Re.execp re (fname ^ "/" ^ message))

  let should_log ~log_level ~fname ~message =
    check_log_level log_level && should_log_path fname message

  let stack = ref []
  let hidden_entries = ref []
  let filtered_entries_tbl = Hashtbl.create 10
  let depth_stack = ref []
  let indent () = String.make (List.length !stack) ' '

  let () =
    if !log_level > 0 then
      let ch = debug_ch () in
      match Log_to.time_tagged with
      | Not_tagged -> Printf.fprintf ch "\nBEGIN DEBUG SESSION %s\n%!" global_prefix
      | Clock ->
          Printf.fprintf ch "\nBEGIN DEBUG SESSION %sat time %s\n%!" global_prefix
            (timestamp_to_string ())
      | Elapsed ->
          Printf.fprintf ch
            "\nBEGIN DEBUG SESSION %sat elapsed %s, corresponding to time %s\n%!"
            global_prefix
            (Format.asprintf "%a" pp_elapsed ())
            (timestamp_to_string ())

  let close_log ~fname ~start_lnum ~entry_id =
    match (!hidden_entries, !stack) with
    | hidden_id :: tl, _ when hidden_id = entry_id -> hidden_entries := tl
    | _, [] ->
        let log_loc =
          Printf.sprintf "%s\"%s\":%d: entry_id=%d" global_prefix fname start_lnum
            entry_id
        in
        failwith @@ "ppx_minidebug: close_log must follow an earlier open_log; " ^ log_loc
    | _, { message; elapsed; time_tag; entry_id = open_entry_id; _ } :: tl -> (
        let ch = debug_ch () in
        let elapsed_on_close = time_elapsed () in
        stack := tl;
        (if open_entry_id <> entry_id then
           let log_loc =
             Printf.sprintf
               "%s\"%s\":%d: open entry_id=%d, close entry_id=%d, stack entries %s"
               global_prefix fname start_lnum open_entry_id entry_id
               (String.concat ", "
               @@ List.map (fun { entry_id; _ } -> Int.to_string entry_id) tl)
           in
           failwith
           @@ "ppx_minidebug: lexical scope of close_log not matching its dynamic scope; "
           ^ log_loc);
        Printf.fprintf ch "%s%!" (indent ());
        (match Log_to.time_tagged with
        | Not_tagged -> ()
        | Clock -> Printf.fprintf ch "%s - %!" (timestamp_to_string ())
        | Elapsed -> Printf.fprintf ch "%s - %!" (Format.asprintf "%a" pp_elapsed ()));
        time_span
          ~none:(fun () -> ())
          ~some:(Printf.fprintf ch "%s %!") ~elapsed ~elapsed_on_close elapsed_times;
        Printf.fprintf ch "%s%s end\n%!" global_prefix message;
        flush ch;
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

  let open_log ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message ~entry_id
      ~log_level _track_or_explicit =
    if should_log ~log_level ~fname ~message then (
      let ch = debug_ch () in
      let message = opt_verbose_entry_id ~verbose_entry_ids ~entry_id ^ message in
      let time_tag =
        match Log_to.time_tagged with
        | Not_tagged -> ""
        | Clock -> " " ^ timestamp_to_string ()
        | Elapsed -> Format.asprintf " %a" pp_elapsed ()
      in
      Printf.fprintf ch "%s%s%s%s begin %!" (indent ()) global_prefix
        (opt_entry_id ~print_entry_ids ~entry_id)
        message;
      stack :=
        { message; elapsed = time_elapsed (); time_tag; num_children = 0; entry_id }
        :: !stack;
      (match Log_to.location_format with
      | No_location -> ()
      | File_only -> Printf.fprintf ch "\"%s\":%!" fname
      | Beg_line -> Printf.fprintf ch "\"%s\":%d:%!" fname start_lnum
      | Beg_pos -> Printf.fprintf ch "\"%s\":%d:%d:%!" fname start_lnum start_colnum
      | Range_line -> Printf.fprintf ch "\"%s\":%d-%d:%!" fname start_lnum end_lnum
      | Range_pos ->
          Printf.fprintf ch "\"%s\":%d:%d-%d:%d:%!" fname start_lnum start_colnum end_lnum
            end_colnum);
      Printf.fprintf ch "%s\n%!" time_tag)
    else (
      hidden_entries := entry_id :: !hidden_entries;
      Hashtbl.add filtered_entries_tbl entry_id ())

  let open_log_no_source ~message ~entry_id ~log_level _track_or_explicit =
    if check_log_level log_level then (
      let ch = debug_ch () in
      let message = opt_verbose_entry_id ~verbose_entry_ids ~entry_id ^ message in
      let time_tag =
        match Log_to.time_tagged with
        | Not_tagged -> ""
        | Clock -> " " ^ timestamp_to_string ()
        | Elapsed -> Format.asprintf " %a" pp_elapsed ()
      in
      Printf.fprintf ch "%s%s%s%s begin %!" (indent ()) global_prefix
        (opt_entry_id ~print_entry_ids ~entry_id)
        message;
      stack :=
        { message; elapsed = time_elapsed (); time_tag; num_children = 0; entry_id }
        :: !stack;
      Printf.fprintf ch "%s\n%!" time_tag)
    else hidden_entries := entry_id :: !hidden_entries

  let opt_global_prefix = if prefix_all_logs then global_prefix else ""

  let bump_stack_entry entry_id =
    match !stack with
    | ({ num_children; _ } as entry) :: tl ->
        stack := { entry with num_children = num_children + 1 } :: tl;
        ""
    | [] -> "{orphaned from #" ^ Int.to_string entry_id ^ "} "

  let log_value_sexp ?descr ~entry_id ~log_level:_ ~is_result:_ lazy_sexp =
    if not (Hashtbl.mem filtered_entries_tbl entry_id) then
      let orphaned = bump_stack_entry entry_id in
      let descr = match descr with None -> "" | Some d -> d ^ " = " in
      let sexp = Lazy.force lazy_sexp in
      Printf.fprintf (debug_ch ()) "%s%s%s%s%s\n%!" (indent ()) opt_global_prefix orphaned
        descr
        (Sexplib0.Sexp.to_string_hum sexp)

  let log_value_pp ?descr ~entry_id ~log_level:_ ~pp ~is_result:_ lazy_v =
    if not (Hashtbl.mem filtered_entries_tbl entry_id) then (
      let orphaned = bump_stack_entry entry_id in
      let descr = match descr with None -> "" | Some d -> d ^ " = " in
      let v = Lazy.force lazy_v in
      let buf = Buffer.create 512 in
      let formatter = CFormat.formatter_of_buffer buf in
      pp formatter v;
      CFormat.pp_print_flush formatter ();
      let v_str = Buffer.contents buf in
      Printf.fprintf (debug_ch ()) "%s%s%s%s%s\n%!" (indent ()) opt_global_prefix orphaned
        descr v_str)

  let log_value_show ?descr ~entry_id ~log_level:_ ~is_result:_ lazy_v =
    if not (Hashtbl.mem filtered_entries_tbl entry_id) then
      let orphaned = bump_stack_entry entry_id in
      let descr = match descr with None -> "" | Some d -> d ^ " = " in
      let v = Lazy.force lazy_v in
      Printf.fprintf (debug_ch ()) "%s%s%s%s%s\n%!" (indent ()) opt_global_prefix orphaned
        descr v

  let log_value_printbox ~entry_id ~log_level:_ v =
    if not (Hashtbl.mem filtered_entries_tbl entry_id) then
      let orphaned = bump_stack_entry entry_id in
      let orphaned = if orphaned = "" then "" else " " ^ orphaned in
      let indent = indent () in
      Printf.fprintf (debug_ch ()) "%s%a%s\n%!" opt_global_prefix
        (PrintBox_text.output ?style:None
           ~indent:(String.length indent + String.length opt_global_prefix))
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
  let snapshot () = ()
  let no_debug_if _condition = ()

  let finish_and_cleanup () =
    if !log_level > 0 then
      let ch = debug_ch () in
      let () =
        match Log_to.time_tagged with
        | Not_tagged -> Printf.fprintf ch "\nEND DEBUG SESSION %s\n%!" global_prefix
        | Clock ->
            Printf.fprintf ch "\nEND DEBUG SESSION %sat time %s\n%!" global_prefix
              (timestamp_to_string ())
        | Elapsed ->
            Printf.fprintf ch
              "\nEND DEBUG SESSION %sat elapsed %s, corresponding to time %s\n%!"
              global_prefix
              (Format.asprintf "%a" pp_elapsed ())
              (timestamp_to_string ())
      in
      close_out ch
end

let default_html_config = PrintBox_html.Config.(tree_summary true default)
let default_md_config = PrintBox_md.Config.(foldable_trees default)

let anchor_entry_id ~is_pure_text ~entry_id =
  if entry_id = -1 || is_pure_text then B.empty
  else
    let id = Int.to_string entry_id in
    (* TODO(#40): Not outputting a self-link, since we want the anchor in summaries,
       mostly to avoid generating tables in HTML. *)
    (* let uri = "{#" ^ id ^ "}" in let inner = if print_entry_ids then B.line uri else
       B.empty in *)
    let anchor = B.anchor ~id B.empty in
    if is_pure_text then B.hlist ~bars:false [ anchor; B.line " " ] else anchor

type B.ext += Susp_box of B.t Lazy.t

let lbox f = B.extension ~key:"susp" (Susp_box f)

(** [eval_susp_boxes box] traverses a PrintBox.t structure and replaces any Susp_box
    extensions with their actual content by executing the suspension.
    @return the box with all suspensions evaluated *)
let rec eval_susp_boxes (box : B.t) : B.t =
  match B.view box with
  | B.Empty -> box
  | B.Text _ -> box
  | B.Frame { sub; stretch } -> B.frame ~stretch (eval_susp_boxes sub)
  | B.Pad (pos, inner) -> B.pad' ~col:pos.x ~lines:pos.y (eval_susp_boxes inner)
  | B.Align { h; v; inner } -> B.align ~h ~v (eval_susp_boxes inner)
  | B.Grid (style, arr) ->
      let arr' = Array.map (Array.map eval_susp_boxes) arr in
      B.grid ~bars:(style = `Bars) arr'
  | B.Tree (indent, label, children) ->
      let label' = eval_susp_boxes label in
      let children' = Array.map eval_susp_boxes children in
      B.tree ~indent label' (Array.to_list children')
  | B.Link { uri; inner } -> B.link ~uri (eval_susp_boxes inner)
  | B.Anchor { id; inner } -> B.anchor ~id (eval_susp_boxes inner)
  | B.Ext { key = _; ext } -> (
      match ext with
      | Susp_box f ->
          eval_susp_boxes (Lazy.force f) (* execute suspension and evaluate its result *)
      | _ -> box)
(* keep other extensions as is *)

(** [transform_tree_labels box] transforms every tree label in the box by converting any
    Tree structure within the label into a vlist.
    @return the box with transformed tree labels *)
let rec transform_tree_labels (box : B.t) : B.t =
  match B.view box with
  | B.Empty -> box
  | B.Text _ -> box
  | B.Frame { sub; stretch } -> B.frame ~stretch (transform_tree_labels sub)
  | B.Pad (pos, inner) -> B.pad' ~col:pos.x ~lines:pos.y (transform_tree_labels inner)
  | B.Align { h; v; inner } -> B.align ~h ~v (transform_tree_labels inner)
  | B.Grid (style, arr) ->
      let arr' = Array.map (Array.map transform_tree_labels) arr in
      B.grid ~bars:(style = `Bars) arr'
  | B.Tree (indent, label, children) ->
      (* Transform the label by recursively processing it *)
      let rec convert_trees_to_vlist box =
        match B.view box with
        | B.Tree (_inner_indent, inner_label, inner_children) ->
            (* Convert this tree to vlist *)
            let transformed_label = convert_trees_to_vlist inner_label in
            let transformed_children =
              Array.to_list inner_children
              |> List.map (fun child ->
                     convert_trees_to_vlist (transform_tree_labels child))
            in
            B.vlist ~bars:false (transformed_label :: transformed_children)
        | B.Frame { sub; stretch } -> B.frame ~stretch (convert_trees_to_vlist sub)
        | B.Pad (pos, inner) ->
            B.pad' ~col:pos.x ~lines:pos.y (convert_trees_to_vlist inner)
        | B.Align { h; v; inner } -> B.align ~h ~v (convert_trees_to_vlist inner)
        | B.Grid (style, arr) ->
            let arr' = Array.map (Array.map convert_trees_to_vlist) arr in
            B.grid ~bars:(style = `Bars) arr'
        | B.Link { uri; inner } -> B.link ~uri (convert_trees_to_vlist inner)
        | B.Anchor { id; inner } -> B.anchor ~id (convert_trees_to_vlist inner)
        | B.Ext { key; ext } -> B.extension ~key ext
        | _ -> box
      in
      let transformed_label = convert_trees_to_vlist label in
      let children' = Array.map transform_tree_labels children in
      B.tree ~indent transformed_label (Array.to_list children')
  | B.Link { uri; inner } -> B.link ~uri (transform_tree_labels inner)
  | B.Anchor { id; inner } -> B.anchor ~id (transform_tree_labels inner)
  | B.Ext { key; ext } -> B.extension ~key ext (* Extensions are kept as is *)

let eval_and_transform_tree_labels (box : B.t) : B.t =
  box |> eval_susp_boxes |> transform_tree_labels

module PrevRun = struct
  type edit_type = Match | Insert | Delete | Change of string

  type edit_info = {
    edit_type : edit_type;
    curr_index : int; (* Index in current run where edit occurred *)
  }

  type diffable = { message : string; depth : int; entry_id : int option; msg_idx : int }
  type chunk = { messages_with_depth : diffable array }

  (* The dynamic programming state *)
  type dp_state = {
    mutable prev_chunk : chunk option; (* Previous run's current chunk *)
    curr_chunk : diffable Dynarray.t; (* Current chunk being built *)
    dp_table : (int * int, int * int * int) Hashtbl.t;
        (* (i,j) -> (edit_dist, prev_i, prev_j) *)
    mutable num_rows : int; (* Number of rows in the prev_chunk *)
    mutable last_computed_col : int; (* Last computed column in dp table *)
    mutable optimal_edits : edit_info list; (* Optimal edit sequence so far *)
    prev_ic : in_channel option; (* Channel for reading previous chunks *)
    curr_oc : out_channel option; (* Channel for writing current chunks *)
    diff_ignore_pattern : Re.re option;
        (* Pattern to normalize messages before comparison *)
    normalized_msgs : (string, string) Hashtbl.t;
        (* Memoization table for normalized messages *)
    min_cost_rows : (int, int) Hashtbl.t; (* Column index -> row with minimum cost *)
    max_distance_factor : int;
        (* Maximum distance to consider as a factor of current position *)
    depth_threshold : int; (* New parameter for depth discrepancy threshold *)
    entry_id_pairs : (int * int) list;
        (* Maps previous entry_id to current entry_id for forced matches *)
    entry_id_to_pos : (int, int) Hashtbl.t;
        (* Maps entry_id to its position in the chunk for the previous run *)
    curr_entry_id_to_pos : (int, int) Hashtbl.t;
        (* Maps entry_id to its position in the chunk for the current run *)
    mutable reverse_forced_matches : (int * int) list;
        (* Remaining forced matches (entry_id for column, row of matching entry_id) sorted
           by column *)
  }

  (* Get depth from previous chunk by index *)
  let get_depth_prev state i =
    try if i < 0 then -1 else (Option.get state.prev_chunk).messages_with_depth.(i).depth
    with Invalid_argument _ ->
      Printf.eprintf "get_depth_prev: index %d out of bounds\n" i;
      assert false

  (* Get depth from current chunk by index *)
  let get_depth_curr state j =
    try if j < 0 then -1 else (Dynarray.get state.curr_chunk j).depth
    with Invalid_argument _ ->
      Printf.eprintf "get_depth_curr: index %d out of bounds\n" j;
      assert false

  let save_chunk oc messages =
    let chunk = { messages_with_depth = Array.of_seq (Dynarray.to_seq messages) } in
    Marshal.to_channel oc chunk [];
    flush oc

  let load_next_chunk ic =
    try
      let chunk = (Marshal.from_channel ic : chunk) in
      Some chunk
    with End_of_file -> None

  let base_del_cost = 2
  let base_ins_cost = 2
  let base_change_cost = 3
  let base_contiguous_change_cost = 2
  let base_depth_cost = 2

  let empty_state =
    {
      prev_chunk = None;
      curr_chunk = Dynarray.create ();
      dp_table = Hashtbl.create 0;
      num_rows = 0;
      last_computed_col = -1;
      optimal_edits = [];
      prev_ic = None;
      curr_oc = None;
      diff_ignore_pattern = None;
      normalized_msgs = Hashtbl.create 0;
      min_cost_rows = Hashtbl.create 0;
      max_distance_factor = 200;
      depth_threshold = 1;
      entry_id_pairs = [];
      entry_id_to_pos = Hashtbl.create 0;
      curr_entry_id_to_pos = Hashtbl.create 0;
      reverse_forced_matches = [];
    }

  let populate_entry_id_to_pos state chunk =
    Array.iteri
      (fun i md ->
        match md.entry_id with
        | Some entry_id -> Hashtbl.add state.entry_id_to_pos entry_id i
        | None -> ())
      chunk.messages_with_depth;
    state.reverse_forced_matches <-
      List.filter_map
        (fun (prev_id, curr_id) ->
          try Some (curr_id, Hashtbl.find state.entry_id_to_pos prev_id)
          with Not_found -> None)
        state.entry_id_pairs
      |> List.sort (fun (j0, _) (j1, _) -> Int.compare j0 j1)

  let init_run ?prev_file ?diff_ignore_pattern ?(max_distance_factor = 200)
      ?(depth_threshold = 1) ?(entry_id_pairs = []) curr_file =
    let prev_ic = Option.map open_in_bin prev_file in
    let prev_chunk = Option.bind prev_ic load_next_chunk in
    let curr_oc = open_out_bin (curr_file ^ ".raw") in
    Gc.finalise (fun _ -> close_out curr_oc) curr_oc;
    (* entry_id_to_pos and reverse_forced_matches are initialized in
       populate_entry_id_to_pos *)
    let state =
      {
        prev_chunk;
        curr_chunk = Dynarray.create ();
        dp_table = Hashtbl.create 10000;
        num_rows =
          (match prev_chunk with
          | None -> 0
          | Some chunk -> Array.length chunk.messages_with_depth - 1);
        last_computed_col = -1;
        optimal_edits = [];
        prev_ic;
        curr_oc = Some curr_oc;
        diff_ignore_pattern;
        normalized_msgs = Hashtbl.create 1000;
        min_cost_rows = Hashtbl.create 1000;
        max_distance_factor;
        depth_threshold;
        entry_id_pairs;
        entry_id_to_pos = Hashtbl.create 100;
        curr_entry_id_to_pos = Hashtbl.create 100;
        reverse_forced_matches = [];
      }
    in
    Option.iter (populate_entry_id_to_pos state) prev_chunk;
    state

  (* Get normalized message either from normalized chunk or by normalizing on demand *)
  let normalize_message state msg =
    match state.diff_ignore_pattern with
    | None -> msg
    | Some re -> (
        try Hashtbl.find state.normalized_msgs msg
        with Not_found ->
          let normalized = Re.replace_string re ~by:"..." msg in
          Hashtbl.add state.normalized_msgs msg normalized;
          normalized)

  (* Get normalized message from previous chunk by index *)
  let get_normalized_prev state i =
    try
      normalize_message state
        (Option.get state.prev_chunk).messages_with_depth.(i).message
    with Invalid_argument _ ->
      Printf.eprintf "get_normalized_prev: index %d out of bounds\n" i;
      assert false

  (* Get original message from previous chunk by index with its ID *)
  let get_prev_msg state i =
    let chunk = Option.get state.prev_chunk in
    try chunk.messages_with_depth.(i).message
    with Invalid_argument _ ->
      Printf.eprintf "get_prev_msg: index %d out of bounds\n" i;
      assert false

  (* Get normalized message from current chunk by index *)
  let get_normalized_curr state j =
    try
      let msg_with_depth = Dynarray.get state.curr_chunk j in
      let normalized = normalize_message state msg_with_depth.message in
      normalized
    with Invalid_argument _ ->
      Printf.eprintf "get_normalized_curr: index %d out of bounds\n" j;
      assert false

  (* Get a value from the dp_table, handling edge cases *)
  let get_dp_value state ~i ~j =
    if i < 0 && j < 0 then
      (* Base case with no elements *)
      (0, -1, -1)
    else if i < 0 then
      (* Cost of aligning empty previous sequence with current sequence up to j *)
      (j * base_ins_cost, -1, j - 1)
    else if j < 0 then
      (* Cost of aligning previous sequence up to i with empty current sequence *)
      (i * base_del_cost, i - 1, -1)
    else
      (* For valid indices, try to find the value in the table *)
      try Hashtbl.find state.dp_table (i, j) with Not_found -> (max_int, -1, -1)

  let set_dp_value state ~i ~j ((v, _prev_i, _prev_j) as prev) =
    assert (i >= 0 && j >= 0);
    assert (v >= 0);
    Hashtbl.replace state.dp_table (i, j) prev

  (* Being careful about overflow *)
  let safe_add a b =
    assert (a >= 0);
    assert (b >= 0);
    if a = max_int || b = max_int then max_int
    else if a > max_int - b then max_int
    else a + b

  let compute_dp_cell state i j =
    let normalized_prev = get_normalized_prev state i in
    let normalized_curr = get_normalized_curr state j in

    (* Get message IDs for logging *)
    let prev_depth = get_depth_prev state i in
    let curr_depth = get_depth_curr state j in
    let delta = prev_depth - curr_depth in

    let above =
      let c, _, _ = get_dp_value state ~i:(i - 1) ~j in
      safe_add c base_del_cost
    in
    let left =
      let c, _, _ = get_dp_value state ~i ~j:(j - 1) in
      safe_add c base_ins_cost
    in
    let diag =
      let c, prev_i, prev_j = get_dp_value state ~i:(i - 1) ~j:(j - 1) in
      let match_cost =
        if normalized_prev = normalized_curr then 0
        else
          let _, pi', pj' = get_dp_value state ~i:prev_i ~j:prev_j in
          if pi' = prev_i - 1 && pj' = prev_j - 1 then base_contiguous_change_cost
          else base_change_cost
      in
      safe_add c match_cost
    in

    (* Compute minimum cost operation *)
    let min_cost, prev_i, prev_j =
      let costs = [ (above, i - 1, j); (left, i, j - 1); (diag, i - 1, j - 1) ] in
      List.fold_left
        (fun (mc, pi, pj) (c, i', j') ->
          let delta' = get_depth_prev state i' - get_depth_curr state j' in
          let c' = safe_add c (if delta = delta' then 0 else base_depth_cost) in
          if c' <= mc then (c', i', j') else (mc, pi, pj))
        (max_int, -1, -1) costs
    in
    if min_cost < max_int then set_dp_value state ~i ~j (min_cost, prev_i, prev_j);
    min_cost

  (* Modified backtracking in update_optimal_edits to handle skipped cells *)
  let update_optimal_edits state col =
    (* Backtrack through dp table to find optimal edit sequence *)
    let rec backtrack i j acc =
      if j < 0 then
        (* No need to backtrack, since we're at the start of the current run *)
        acc
      else if i < 0 then
        let edit = { edit_type = Insert; curr_index = j } in
        backtrack i (j - 1) (edit :: acc)
      else
        let cost, prev_i, prev_j = get_dp_value state ~i ~j in
        if cost = max_int && prev_i = -1 && prev_j = -1 then
          (* Unpopulated cell, default to deletion as a fallback *)
          let edit = { edit_type = Delete; curr_index = j } in
          backtrack (i - 1) j (edit :: acc)
        else if prev_i = i - 1 && prev_j = j - 1 then
          (* Diagonal move: either match or change *)
          let normalized_prev = get_normalized_prev state i in
          let edit =
            if normalized_prev = get_normalized_curr state j then
              { edit_type = Match; curr_index = j }
            else
              let prev_msg = get_prev_msg state i in
              { edit_type = Change prev_msg; curr_index = j }
          in
          backtrack prev_i prev_j (edit :: acc)
        else if prev_i = i - 1 then
          (* Moving up: deletion *)
          let edit = { edit_type = Delete; curr_index = j } in
          backtrack prev_i prev_j (edit :: acc)
        else if prev_j = j - 1 then
          (* Moving left: insertion *)
          let edit = { edit_type = Insert; curr_index = j } in
          backtrack prev_i prev_j (edit :: acc)
        else assert false
    in

    (* We cannot start backtracking from the end of the column, because, especially early
       on, the rows that we want to be matched later on can skew the results. And we
       cannot always start from the best row, because that will prefer insertions over
       substitutions. *)
    let row =
      try max col (Hashtbl.find state.min_cost_rows col)
      with Not_found -> min state.num_rows (col + state.max_distance_factor)
    in

    let edits = backtrack row col [] in
    state.optimal_edits <- edits

  let compute_dp_upto state col =
    (* Compute new cells with adaptive pruning - transposed for column-first iteration *)
    for j = state.last_computed_col + 1 to col do
      let curr = Dynarray.get state.curr_chunk j in
      let forced_entry_id, forced_pos =
        match state.reverse_forced_matches with
        | (curr_id, forced_pos) :: _ -> (curr_id, forced_pos)
        | [] -> (-2, -2)
      in
      match curr.entry_id with
      | Some curr_id when curr_id = forced_entry_id ->
          let center_row = forced_pos in
          state.reverse_forced_matches <- List.tl state.reverse_forced_matches;
          set_dp_value state ~i:center_row ~j (0, center_row - 1, j - 1);
          Hashtbl.replace state.min_cost_rows j center_row
      | _ ->
          (* For each new column, determine the center row for exploration *)
          let curr_depth = get_depth_curr state j in

          (* Use the priority row if it exists, otherwise use regular heuristics *)
          let center_row =
            (* Regular heuristic-based center row calculation *)
            if Hashtbl.mem state.min_cost_rows (j - 1) then
              (* Center around the min cost row from the previous column *)
              let old_center_row = Hashtbl.find state.min_cost_rows (j - 1) in
              let old_center_depth = get_depth_prev state old_center_row in
              let new_center_row = old_center_row + 1 in
              (* Find the new center row with matching depth *)
              if new_center_row > state.num_rows then old_center_row
              else
                let new_center_depth = get_depth_prev state new_center_row in
                let old_depth = get_depth_curr state (j - 1) in
                let depth_delta = curr_depth - old_depth in
                let center_delta = new_center_depth - old_center_depth in
                if depth_delta = center_delta then new_center_row
                else if depth_delta < center_delta then
                  let rec find_center_row i =
                    if i > state.num_rows then old_center_row
                    else
                      let new_center_depth = get_depth_prev state i in
                      let center_delta = new_center_depth - old_center_depth in
                      if depth_delta >= center_delta then i else find_center_row (i + 1)
                  in
                  find_center_row (old_center_row + 2)
                else old_center_row
            else j
          in
          let center_depth = get_depth_prev state center_row in
          (* Define initial exploration range in a subtree-sensitive manner *)
          let boundary p =
            let depth = get_depth_prev state p in
            depth + state.depth_threshold <= center_depth
            || (depth <= center_depth && abs (p - center_row) >= state.max_distance_factor)
          in
          let min_i = ref (max 0 (center_row - state.max_distance_factor)) in
          while !min_i > 0 && not (boundary !min_i) do
            decr min_i
          done;
          let max_i = ref (min state.num_rows (center_row + state.max_distance_factor)) in
          while !max_i < state.num_rows && not (boundary !max_i) do
            incr max_i
          done;

          (* Due to assymetry in insertions and deletions -- deletions are the default
             fallback -- we incorporate forcing to push min_i up, but not max_i down *)
          if forced_entry_id <> -2 then
            min_i := max 0 (min !min_i (forced_pos - state.max_distance_factor));

          (* Track best result *)
          let min_cost_for_col = ref max_int in
          let min_cost_row = ref center_row in

          for i = !min_i to !max_i do
            (* Cell is valid for computation *)
            let cost = compute_dp_cell state i j in

            (* Update minimum cost if better *)
            if cost < !min_cost_for_col then (
              min_cost_for_col := cost;
              min_cost_row := i)
          done;

          (* Store the row with minimum cost for this column *)
          Hashtbl.replace state.min_cost_rows j !min_cost_row
    done;

    if state.last_computed_col < col then (
      update_optimal_edits state col;
      state.last_computed_col <- max state.last_computed_col col)

  (* OCaml < 5.3.0 has no List.take *)
  let list_take n l =
    let[@tail_mod_cons] rec aux n l =
      match (n, l) with 0, _ | _, [] -> [] | n, x :: l -> x :: aux (n - 1) l
    in
    if n < 0 then invalid_arg "List.take";
    aux n l

  (* Ensure the message is at the right position in the DP table regardless of when we
     need to compute the match. *)
  let get_diffable state ~depth ~entry_id message =
    let msg_idx = Dynarray.length state.curr_chunk in
    let res = { message; depth; entry_id; msg_idx } in
    try
      (* Track entry_id to position mapping for the current run *)
      (match entry_id with
      | Some eid -> Hashtbl.add state.curr_entry_id_to_pos eid msg_idx
      | None -> ());

      let _normalized_msg = normalize_message state message in
      Dynarray.add_last state.curr_chunk res;
      if Option.is_some state.prev_ic && Option.is_some state.prev_chunk then
        compute_dp_upto state msg_idx;
      res
    with exn ->
      Printf.eprintf "Error in get_diffable: %s\n%s\n%!" (Printexc.to_string exn)
        (Printexc.get_backtrace ());
      res

  let check_diff state diffable =
    try
      match (state.prev_ic, state.prev_chunk) with
      | None, None -> fun () -> None
      | Some _, None -> fun () -> Some "New chunk"
      | None, Some _ -> assert false
      | Some _, Some prev_chunk ->
          fun () ->
            (* Find the edit for current message in optimal edit sequence *)
            let is_match =
              List.exists
                (fun edit -> edit.curr_index = diffable.msg_idx && edit.edit_type = Match)
                state.optimal_edits
            in
            if is_match then None
            else
              let edit_type =
                (* First try to find a Change edit for this message index *)
                match
                  List.find_map
                    (fun edit ->
                      if edit.curr_index = diffable.msg_idx then
                        match edit.edit_type with
                        | Change prev_msg ->
                            Some (Printf.sprintf "Changed from: %s" prev_msg)
                        | _ -> None
                      else None)
                    state.optimal_edits
                with
                | Some change_msg -> change_msg
                | None when state.num_rows < 0 -> "No previous-run chunk"
                | None
                  when List.for_all
                         (fun edit -> edit.curr_index <> diffable.msg_idx)
                         state.optimal_edits ->
                    let edits_str =
                      List.fold_left
                        (fun acc edit ->
                          if String.length acc > 0 then acc ^ "; "
                          else
                            acc
                            ^
                            match edit.edit_type with
                            | Match -> Printf.sprintf "Match at %d" edit.curr_index
                            | Insert -> Printf.sprintf "Insert at %d" edit.curr_index
                            | Delete -> Printf.sprintf "Delete at %d" edit.curr_index
                            | Change msg ->
                                Printf.sprintf "Change at %d: msg=%s" edit.curr_index msg)
                        ""
                        (list_take 5 state.optimal_edits)
                    in

                    (* Get IDs for the first and current messages in prev_chunk *)
                    let first_msg = prev_chunk.messages_with_depth.(0).message in

                    let current_msg =
                      if diffable.msg_idx > 0 && diffable.msg_idx < state.num_rows then
                        Printf.sprintf " ... %s"
                          prev_chunk.messages_with_depth.(diffable.msg_idx).message
                      else ""
                    in

                    Printf.sprintf
                      "Bad chunk? current position %d, previous: size %d, num edits: %d, \
                       messages: %s%s. 5 edits: %s"
                      diffable.msg_idx state.num_rows
                      (List.length state.optimal_edits)
                      first_msg current_msg edits_str
                | None ->
                    (* Count deletions in the optimal edits *)
                    let deletion_count =
                      List.fold_left
                        (fun count e ->
                          if e.curr_index = diffable.msg_idx && e.edit_type = Delete then
                            count + 1
                          else count)
                        0 state.optimal_edits
                    in
                    if deletion_count > 0 then
                      Printf.sprintf "Covers %d deletions" deletion_count
                    else Printf.sprintf "Inserted in current run"
              in
              Some edit_type
    with exn ->
      Printf.eprintf "Error in check_diff: %s\n%s\n%!" (Printexc.to_string exn)
        (Printexc.get_backtrace ());
      fun () -> None

  let signal_chunk_end state =
    if Dynarray.length state.curr_chunk > 0 then (
      Option.iter (Fun.flip save_chunk state.curr_chunk) state.curr_oc;
      Dynarray.clear state.curr_chunk;
      state.prev_chunk <- Option.bind state.prev_ic load_next_chunk;
      (* Update num_rows based on the new prev_chunk *)
      state.num_rows <-
        (match state.prev_chunk with
        | None -> 0
        | Some chunk -> Array.length chunk.messages_with_depth - 1);
      Hashtbl.clear state.dp_table;
      Option.iter (populate_entry_id_to_pos state) state.prev_chunk;
      state.last_computed_col <- -1;
      state.optimal_edits <- [];
      Hashtbl.clear state.normalized_msgs;
      Hashtbl.clear state.min_cost_rows)
end

type printbox_config = {
  mutable hyperlink : [ `Prefix of string | `No_hyperlinks ];
  mutable toc_specific_hyperlink : string option;
  mutable backend :
    [ `Text | `Html of PrintBox_html.Config.t | `Markdown of PrintBox_md.Config.t ];
  mutable boxify_sexp_from_size : int;
  mutable highlight_terms : Re.re option;
  mutable highlight_diffs : bool;
  mutable exclude_on_path : Re.re option;
  mutable prune_upto : int;
  mutable truncate_children : int;
  mutable values_first_mode : bool;
  mutable max_inline_sexp_size : int;
  mutable max_inline_sexp_length : int;
  mutable snapshot_every_sec : float option;
  mutable sexp_unescape_strings : bool;
  mutable with_toc_listing : bool;
  mutable toc_flame_graph : bool;
  mutable flame_graph_separation : int;
  mutable prev_run_file : string option;
  mutable path_filter : [ `Whitelist of Re.re | `Blacklist of Re.re ] option;
}

module type PrintBox_runtime = sig
  include Debug_runtime

  val config : printbox_config
end

module PrintBox (Log_to : Shared_config) = struct
  open Log_to

  let log_level = ref init_log_level
  let max_nesting_depth = ref None
  let max_num_children = ref None
  let prev_run_state = ref PrevRun.empty_state
  let check_log_level level = level <= !log_level

  let config =
    {
      hyperlink = `No_hyperlinks;
      toc_specific_hyperlink = None;
      backend = `Text;
      boxify_sexp_from_size = -1;
      highlight_terms = None;
      highlight_diffs = false;
      prune_upto = 0;
      truncate_children = 0;
      exclude_on_path = None;
      values_first_mode = true;
      max_inline_sexp_size = 20;
      max_inline_sexp_length = 80;
      snapshot_every_sec = None;
      sexp_unescape_strings = true;
      toc_flame_graph = false;
      with_toc_listing = false;
      flame_graph_separation = 40;
      prev_run_file = None;
      path_filter = Log_to.path_filter;
    }

  let should_log_path fname message =
    match config.path_filter with
    | None -> true
    | Some (`Whitelist re) -> Re.execp re (fname ^ "/" ^ message)
    | Some (`Blacklist re) -> not (Re.execp re (fname ^ "/" ^ message))

  let should_log ~log_level ~fname ~message =
    check_log_level log_level && should_log_path fname message

  let filtered_entries_tbl = Hashtbl.create 10

  type highlight = { pattern_match : bool; diff_check : unit -> (bool * string) option }

  type subentry = {
    result_id : int;
    is_result : bool;
    highlighted : highlight;
    elapsed_start : Mtime.span;
    elapsed_end : Mtime.span;
    subtree : B.t;
    toc_subtree : B.t;
    flame_subtree : string;
  }

  type entry = {
    no_debug_if : bool;
    track_or_explicit : [ `Diagn | `Debug | `Track ];
    highlight : highlight;
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
  let hidden_entries = ref []

  let hyperlink_path ~uri ~inner =
    match config.hyperlink with
    | `Prefix prefix -> B.link ~uri:(prefix ^ uri) inner
    | `No_hyperlinks -> inner

  let () =
    if !log_level > 0 then
      let log_header =
        match time_tagged with
        | Not_tagged -> CFormat.asprintf "@.BEGIN DEBUG SESSION %s@." global_prefix
        | Clock ->
            CFormat.asprintf "@.BEGIN DEBUG SESSION %sat time %s\n%!" global_prefix
              (timestamp_to_string ())
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
      | B.Grid _ | B.Link _ | B.Text _ | B.Ext _ -> B.frame b
    in
    if hl.pattern_match then loop b
    else if not config.highlight_diffs then b
    else
      lbox
        (lazy
          (match hl.diff_check () with
          | None -> b
          | Some (full_reason, reason) when String.length reason > 40 ->
              B.hlist ~bars:false
                [
                  loop b;
                  (let skip = String.length "Changed from: " in
                   let summary =
                     String.map
                       (function '\n' | '\r' -> ' ' | c -> c)
                       (String.sub reason 0 35)
                     ^ "..."
                   in
                   if full_reason then
                     B.tree (B.text summary)
                       [
                         B.text_with_style B.Style.preformatted
                         @@ String.sub reason skip (String.length reason - skip);
                       ]
                   else B.text summary);
                ]
          | Some (_, reason) when String.length reason = 0 -> loop b
          | Some (_, reason) -> B.hlist ~bars:false [ loop b; B.text reason ]))

  let hl_or hl1 hl2 =
    {
      pattern_match = hl1.pattern_match || hl2.pattern_match;
      diff_check =
        (fun () ->
          (* Erase reason on inheriting nodes *)
          match hl1.diff_check () with
          | Some _ as reason -> reason
          | None -> Option.map (fun r -> (false, snd r)) @@ hl2.diff_check ());
    }

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

  let set_full_highlight full hl =
    {
      hl with
      diff_check = (fun () -> Option.map (fun r -> (full, snd r)) @@ hl.diff_check ());
    }

  let hl_oneof ~full_reason highlighted =
    let result =
      {
        pattern_match = List.exists (fun hl -> hl.pattern_match) highlighted;
        diff_check = (fun () -> List.find_map (fun hl -> hl.diff_check ()) highlighted);
      }
    in
    if full_reason then result else set_full_highlight false result

  let stack_to_tree ~elapsed_on_close
      {
        no_debug_if;
        track_or_explicit = _;
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
    assert (not no_debug_if);
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
      let results_hl =
        hl_oneof ~full_reason:true
        @@ List.map (fun { highlighted; _ } -> highlighted) results
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
                        (apply_highlight (set_full_highlight false results_hl)
                        @@ B.line
                        @@ if body = [] then "<values>" else "<returns>")
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
               :: B.tree
                    (apply_highlight (set_full_highlight false results_hl)
                    @@ B.line
                    @@ if body = [] then "<values>" else "<returns>")
                    results
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
          | B.Frame { sub; stretch } -> B.frame ~stretch @@ replace_link sub
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
    let open Int32 in
    let rand = ref (1l : int32) in
    fun () ->
      let ( + ) = Int32.add in
      let ( mod ) = Int32.rem in
      rand := logxor !rand (shift_left !rand 13);
      let r = to_int (128l + 64l + (!rand mod 50l)) in
      rand := logxor !rand (shift_right_logical !rand 17);
      let g = to_int (128l + 64l + (!rand mod 50l)) in
      rand := logxor !rand (shift_left !rand 5);
      let b = to_int (128l + 64l + (!rand mod 50l)) in
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
    let header = eval_and_transform_tree_labels header in
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
        let box = eval_and_transform_tree_labels box in
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
    | B.Frame { sub = b; stretch = _ } | B.Pad (_, b) | B.Align { inner = b; _ } ->
        is_empty b
    | B.Grid (_, [| [||] |]) -> true
    | _ -> false

  let rec snapshot () =
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

  and close_log_impl ~from_snapshot ~elapsed_on_close ~fname ~start_lnum ~entry_id =
    let close_tree ~entry ~toc_depth =
      let header, box = stack_to_tree ~elapsed_on_close entry in
      let ch = debug_ch () in
      pop_snapshot ();
      output_box ~for_toc:false ch box;
      if not from_snapshot then snapshot_ch ();
      PrevRun.signal_chunk_end !prev_run_state;
      match table_of_contents_ch with
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
            flush toc_ch)
    in
    (match !stack with
    | { entry_id = open_entry_id; _ } :: tl when open_entry_id <> entry_id ->
        let log_loc =
          Printf.sprintf
            "%s\"%s\":%d: open entry_id=%d, close entry_id=%d, stack entries %s"
            global_prefix fname start_lnum open_entry_id entry_id
            (String.concat ", "
            @@ List.map (fun { entry_id; _ } -> Int.to_string entry_id) tl)
        in
        snapshot ();
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
    (* TODO: factor out logic shared with stack_next. *)
    stack :=
      (* Design choice: exclude does not apply to its own entry -- it's about propagating
         children. *)
      match !stack with
      | { no_debug_if = true; _ } :: bs -> bs
      | { highlight; _ } :: bs
        when (not highlight.pattern_match) && config.prune_upto >= List.length !stack ->
          bs
      | { body = []; track_or_explicit = `Diagn; _ } :: bs -> bs
      | { body; track_or_explicit = `Diagn; _ } :: bs
        when List.for_all (fun e -> e.is_result) body ->
          bs
      | ({
           highlight = hl;
           exclude = _;
           entry_id = result_id;
           depth = result_depth;
           size = result_size;
           elapsed = elapsed_start;
           _;
         } as entry)
        :: {
             no_debug_if;
             track_or_explicit;
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
            no_debug_if;
            track_or_explicit;
            highlight = (if exclude then highlight else hl_or highlight hl);
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
                highlighted = hl;
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
      | [ ({ toc_depth; _ } as entry) ] ->
          close_tree ~entry ~toc_depth;
          []
      | [] -> assert false

  let close_log ~fname ~start_lnum ~entry_id =
    match !hidden_entries with
    | hidden_id :: tl when hidden_id = entry_id -> hidden_entries := tl
    | _ ->
        let elapsed_on_close = time_elapsed () in
        close_log_impl ~from_snapshot:false ~elapsed_on_close ~fname ~start_lnum ~entry_id

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

  let stack_next ~entry_id ~is_result ~result_depth ~result_size (hl, b) =
    let opt_eid = opt_verbose_entry_id ~verbose_entry_ids ~entry_id in
    let rec eid b =
      match B.view b with
      | B.Empty -> B.line opt_eid
      | B.Text { l = []; style } -> B.line_with_style style opt_eid
      | B.Text { l = s :: more; style } -> B.lines_with_style style ((opt_eid ^ s) :: more)
      | B.Frame { sub; stretch } -> B.frame ~stretch @@ eid sub
      | B.Pad ({ x; y }, b) -> B.pad' ~col:x ~lines:y @@ eid b
      | B.Align { h; v; inner } -> B.align ~h ~v @@ eid inner
      | B.Grid _ -> B.hlist ~bars:false [ B.line opt_eid; b ]
      | B.Tree (indent, h, b) -> B.tree ~indent (eid h) @@ Array.to_list b
      | B.Link { uri; inner } -> B.link ~uri @@ eid inner
      | B.Anchor { id; inner } -> B.anchor ~id @@ eid inner
      | B.Ext { key; ext } -> B.extension ~key ext
    in
    let b = if opt_eid = "" then b else eid b in
    match !stack with
    | ({ highlight; exclude; body; depth; size; elapsed; _ } as entry) :: bs2 ->
        stack :=
          {
            entry with
            highlight = (if exclude then highlight else hl_or highlight hl);
            body =
              {
                result_id = entry_id;
                is_result;
                highlighted = hl;
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
            highlighted = hl;
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
              no_debug_if = false;
              track_or_explicit = `Debug;
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
        close_log ~fname:"orphaned" ~start_lnum:entry_id ~entry_id:(-1)

  let get_highlight diffable =
    let diff_check =
      let diff_result = PrevRun.check_diff !prev_run_state diffable in
      fun () -> Option.map (fun r -> (true, r)) @@ diff_result ()
    in
    match config.highlight_terms with
    | None -> { pattern_match = false; diff_check }
    | Some r -> { pattern_match = Re.execp r diffable.message; diff_check }

  let open_log ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message ~entry_id
      ~log_level track_or_explicit =
    if should_log ~log_level ~fname ~message then
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
        match Log_to.time_tagged with
        | Not_tagged -> ""
        | Clock -> Format.asprintf " at time %a" pp_timestamp ()
        | Elapsed -> Format.asprintf " at elapsed %a" pp_elapsed ()
      in
      let path = location ^ time_tag in
      let exclude =
        match config.exclude_on_path with Some r -> Re.execp r message | None -> false
      in
      let highlight =
        get_highlight
        @@ PrevRun.get_diffable !prev_run_state message ~depth:(List.length !stack)
             ~entry_id:(Some entry_id)
      in
      let entry_message = global_prefix ^ message in
      stack :=
        {
          no_debug_if = false;
          track_or_explicit;
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
    else (
      hidden_entries := entry_id :: !hidden_entries;
      Hashtbl.add filtered_entries_tbl entry_id ())

  let open_log_no_source ~message ~entry_id ~log_level track_or_explicit =
    if check_log_level log_level then
      let time_tag =
        match Log_to.time_tagged with
        | Not_tagged -> ""
        | Clock -> Format.asprintf " at time %a" pp_timestamp ()
        | Elapsed -> Format.asprintf " at elapsed %a" pp_elapsed ()
      in
      let exclude =
        match config.exclude_on_path with Some r -> Re.execp r message | None -> false
      in
      let highlight =
        get_highlight
        @@ PrevRun.get_diffable !prev_run_state message ~depth:(List.length !stack)
             ~entry_id:(Some entry_id)
      in
      let entry_message = global_prefix ^ message in
      stack :=
        {
          no_debug_if = false;
          track_or_explicit;
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
    else hidden_entries := entry_id :: !hidden_entries

  let sexp_size sexp =
    let open Sexplib0.Sexp in
    let rec loop = function
      | Atom _ -> 1
      | List l -> List.fold_left ( + ) 0 (List.map loop l)
    in
    loop sexp

  let highlight_box ~depth ?body ?loop ~entry_id b =
    (* Design choice: Don't render headers of multiline values as monospace, to emphasize
       them. *)
    (* Recall the design choice: [exclude] does not apply to its own entry. Therefore, an
       entry "propagates its highlight". *)
    let message = PrintBox_text.to_string_with ~style:false b in
    let hl_header =
      get_highlight @@ PrevRun.get_diffable !prev_run_state message ~depth ~entry_id
    in
    let hl_body, b, bs =
      match (body, loop) with
      | None, None -> (None, b, [])
      | Some _, None | None, Some _ -> assert false
      | Some body, Some loop ->
          let hl_body, bs = List.split @@ List.map (loop ~depth:(depth + 1)) body in
          let hl_body = hl_oneof ~full_reason:false hl_body in
          let hl_body =
            match config.exclude_on_path with
            | None -> Some hl_body
            | Some r -> if Re.execp r message then None else Some hl_body
          in
          (hl_body, b, bs)
    in
    let hl = Option.value ~default:hl_header (Option.map (hl_or hl_header) hl_body) in
    let b = apply_highlight hl b in
    (hl, if bs = [] then b else B.tree b bs)

  let pp_sexp ppf = function
    | Sexplib0.Sexp.Atom s when config.sexp_unescape_strings ->
        Format.pp_print_string ppf s
    | e -> Sexplib0.Sexp.pp_hum ppf e

  let boxify ~descr ~depth ~entry_id sexp =
    let open Sexplib0.Sexp in
    let rec loop ?(as_tree = false) ~depth sexp =
      if (not as_tree) && sexp_size sexp < config.boxify_sexp_from_size then
        highlight_box ~depth ~entry_id
        @@ B.asprintf_with_style B.Style.preformatted "%a" pp_sexp sexp
      else
        match sexp with
        (* FIXME: Should we render [List [Atom s]] at [depth] also? *)
        | Atom s ->
            highlight_box ~depth ~entry_id @@ B.text_with_style B.Style.preformatted s
        | List [] -> ({ pattern_match = false; diff_check = (fun () -> None) }, B.empty)
        | List [ s ] -> loop ~depth:(depth + 1) s
        | List (Atom s :: body) ->
            highlight_box ~depth ~entry_id ~body ~loop:(loop ?as_tree:None)
            @@ if as_tree then B.text s else B.text_with_style B.Style.preformatted s
        | List l ->
            let hls, bs = List.split @@ List.map (loop ~depth:(depth + 1)) l in
            (hl_oneof ~full_reason:false hls, B.vlist ~bars:false bs)
    in
    match (sexp, descr) with
    | (Atom s | List [ Atom s ]), Some d ->
        highlight_box ~depth ~entry_id
        @@ B.text_with_style B.Style.preformatted (d ^ " = " ^ s)
    | (Atom s | List [ Atom s ]), None ->
        highlight_box ~depth ~entry_id @@ B.text_with_style B.Style.preformatted s
    | List [], Some d -> highlight_box ~depth ~entry_id @@ B.line d
    | List [], None -> ({ pattern_match = false; diff_check = (fun () -> None) }, B.empty)
    | List l, _ ->
        let str =
          if sexp_size sexp < min config.boxify_sexp_from_size config.max_inline_sexp_size
          then Sexplib0.Sexp.to_string_hum sexp
          else ""
        in
        if String.length str > 0 && String.length str < config.max_inline_sexp_length then
          (* TODO: Design choice: consider not using monospace, at least for descr. *)
          highlight_box ~depth ~entry_id
          @@ B.text_with_style B.Style.preformatted
          @@ match descr with None -> str | Some d -> d ^ " = " ^ str
        else
          loop ~depth:(depth + 1) ~as_tree:true
          @@ List ((match descr with None -> [] | Some d -> [ Atom (d ^ " =") ]) @ l)

  let num_children () = match !stack with [] -> 0 | { body; _ } :: _ -> List.length body

  let log_value_sexp ?descr ~entry_id ~log_level:_ ~is_result lazy_sexp =
    if not (Hashtbl.mem filtered_entries_tbl entry_id) then (
      let sexp = Lazy.force lazy_sexp in
      (if config.boxify_sexp_from_size >= 0 then
         stack_next ~entry_id ~is_result ~result_depth:0 ~result_size:1
         @@ boxify ~descr ~depth:(List.length !stack) ~entry_id:None sexp
       else
         stack_next ~entry_id ~is_result ~result_depth:0 ~result_size:1
         @@ highlight_box ~depth:(List.length !stack) ~entry_id:None
         @@
         match descr with
         | None -> B.asprintf_with_style B.Style.preformatted "%a" pp_sexp sexp
         | Some d -> B.asprintf_with_style B.Style.preformatted "%s = %a" d pp_sexp sexp);
      opt_auto_snapshot ())

  let log_value_pp ?descr ~entry_id ~log_level:_ ~pp ~is_result lazy_v =
    if not (Hashtbl.mem filtered_entries_tbl entry_id) then (
      let v = Lazy.force lazy_v in
      (stack_next ~entry_id ~is_result ~result_depth:0 ~result_size:1
      @@ highlight_box ~depth:(List.length !stack) ~entry_id:None
      @@
      match descr with
      | None -> B.asprintf_with_style B.Style.preformatted "%a" pp v
      | Some d -> B.asprintf_with_style B.Style.preformatted "%s = %a" d pp v);
      opt_auto_snapshot ())

  let log_value_show ?descr ~entry_id ~log_level:_ ~is_result lazy_v =
    if not (Hashtbl.mem filtered_entries_tbl entry_id) then (
      let v = Lazy.force lazy_v in
      (stack_next ~entry_id ~is_result ~result_depth:0 ~result_size:1
      @@ highlight_box ~depth:(List.length !stack) ~entry_id:None
      @@
      match descr with
      | None -> B.sprintf_with_style B.Style.preformatted "%s" v
      | Some d -> B.sprintf_with_style B.Style.preformatted "%s = %s" d v);
      opt_auto_snapshot ())

  let log_value_printbox ~entry_id ~log_level:_ v =
    if not (Hashtbl.mem filtered_entries_tbl entry_id) then (
      stack_next ~entry_id ~is_result:false ~result_depth:0 ~result_size:1
      @@ highlight_box ~depth:(List.length !stack) ~entry_id:None v;
      opt_auto_snapshot ())

  let no_debug_if cond =
    match !stack with
    | ({ no_debug_if = false; _ } as entry) :: bs when cond ->
        stack := { entry with no_debug_if = true } :: bs
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

  let finish_and_cleanup () =
    if !log_level > 0 then (
      let () = snapshot () in
      let ch = debug_ch () in
      let log_ps =
        match Log_to.time_tagged with
        | Not_tagged -> Printf.sprintf "\nEND DEBUG SESSION %s\n" global_prefix
        | Clock ->
            Printf.sprintf "\nEND DEBUG SESSION %sat time %s\n" global_prefix
              (timestamp_to_string ())
        | Elapsed ->
            Printf.sprintf
              "\nEND DEBUG SESSION %sat elapsed %s, corresponding to time %s\n"
              global_prefix
              (Format.asprintf "%a" pp_elapsed ())
              (timestamp_to_string ())
      in
      output_string ch log_ps;
      close_out ch)
end

let debug_file ?(time_tagged = Not_tagged) ?(elapsed_times = elapsed_default)
    ?(location_format = Beg_pos) ?(print_entry_ids = false) ?(verbose_entry_ids = false)
    ?(global_prefix = "") ?split_files_after ?(with_toc_listing = false)
    ?(toc_entry = And []) ?(toc_flame_graph = false) ?(flame_graph_separation = 40)
    ?highlight_terms ?exclude_on_path ?(prune_upto = 0) ?(truncate_children = 0)
    ?(for_append = false) ?(boxify_sexp_from_size = 50) ?(max_inline_sexp_length = 80)
    ?(backend = `Text) ?hyperlink ?toc_specific_hyperlink ?(values_first_mode = true)
    ?(log_level = 9) ?snapshot_every_sec ?prev_run_file ?diff_ignore_pattern
    ?max_distance_factor ?(entry_id_pairs = []) ?path_filter filename_stem :
    (module PrintBox_runtime) =
  let filename =
    match backend with
    | `Markdown _ -> filename_stem ^ ".md"
    | `Html _ -> filename_stem ^ ".html"
    | `Text -> filename_stem ^ ".log"
  in
  let with_table_of_contents = toc_flame_graph || with_toc_listing in
  let module Debug =
    PrintBox
      ((val shared_config ~time_tagged ~elapsed_times ~location_format ~print_entry_ids
              ~verbose_entry_ids ~global_prefix ~for_append ?split_files_after
              ~with_table_of_contents ~toc_entry ~log_level ?path_filter filename)) in
  Debug.config.backend <- backend;
  Debug.config.boxify_sexp_from_size <- boxify_sexp_from_size;
  Debug.config.max_inline_sexp_length <- max_inline_sexp_length;
  Debug.config.highlight_terms <- Option.map Re.compile highlight_terms;
  Debug.config.highlight_diffs <- Option.is_some prev_run_file;
  Debug.config.prune_upto <- prune_upto;
  Debug.config.truncate_children <- truncate_children;
  Debug.config.exclude_on_path <- Option.map Re.compile exclude_on_path;
  Debug.config.values_first_mode <- values_first_mode;
  Debug.config.hyperlink <-
    (match hyperlink with None -> `No_hyperlinks | Some prefix -> `Prefix prefix);
  Debug.config.toc_specific_hyperlink <- toc_specific_hyperlink;
  Debug.log_level := log_level;
  Debug.config.snapshot_every_sec <- snapshot_every_sec;
  Debug.config.with_toc_listing <- with_toc_listing;
  if toc_flame_graph && backend = `Text then
    invalid_arg
      "Minidebug_runtime.debug_file: flame graphs are not supported in the Text backend";
  Debug.config.toc_flame_graph <- toc_flame_graph;
  Debug.config.flame_graph_separation <- flame_graph_separation;
  Debug.config.prev_run_file <- prev_run_file;
  Debug.prev_run_state :=
    PrevRun.init_run ?prev_file:prev_run_file
      ?diff_ignore_pattern:(Option.map Re.compile diff_ignore_pattern)
      ?max_distance_factor ~entry_id_pairs filename_stem;
  (module Debug)

let debug ?debug_ch ?(time_tagged = Not_tagged) ?(elapsed_times = elapsed_default)
    ?(location_format = Beg_pos) ?(print_entry_ids = false) ?(verbose_entry_ids = false)
    ?(global_prefix = "") ?table_of_contents_ch ?(toc_entry = And [])
    ?(boxify_sexp_from_size = 50) ?(max_inline_sexp_length = 80) ?(backend = `Text)
    ?hyperlink ?toc_specific_hyperlink ?highlight_terms ?exclude_on_path ?(prune_upto = 0)
    ?(truncate_children = 0) ?(values_first_mode = true) ?(log_level = 9)
    ?snapshot_every_sec ?path_filter () : (module PrintBox_runtime) =
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
    let prefix_all_logs = false
    let split_files_after = None
    let toc_entry = toc_entry
    let init_log_level = log_level
    let path_filter = path_filter
  end) in
  Debug.config.backend <- backend;
  Debug.config.boxify_sexp_from_size <- boxify_sexp_from_size;
  Debug.config.max_inline_sexp_length <- max_inline_sexp_length;
  Debug.config.highlight_terms <- Option.map Re.compile highlight_terms;
  Debug.config.hyperlink <-
    (match hyperlink with None -> `No_hyperlinks | Some prefix -> `Prefix prefix);
  Debug.config.toc_specific_hyperlink <- toc_specific_hyperlink;
  Debug.config.prune_upto <- prune_upto;
  Debug.config.truncate_children <- truncate_children;
  Debug.config.exclude_on_path <- Option.map Re.compile exclude_on_path;
  Debug.config.values_first_mode <- values_first_mode;
  Debug.config.snapshot_every_sec <- snapshot_every_sec;
  (module Debug)

let debug_flushing ?debug_ch:d_ch ?table_of_contents_ch ?filename
    ?(time_tagged = Not_tagged) ?(elapsed_times = elapsed_default)
    ?(location_format = Beg_pos) ?(print_entry_ids = false) ?(verbose_entry_ids = false)
    ?(global_prefix = "") ?(prefix_all_logs = false) ?split_files_after
    ?(with_table_of_contents = false) ?(toc_entry = And []) ?(for_append = false)
    ?(log_level = 9) ?path_filter () : (module Debug_runtime) =
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
          let prefix_all_logs = prefix_all_logs
          let split_files_after = split_files_after
          let toc_entry = toc_entry
          let init_log_level = log_level
          let path_filter = path_filter
        end : Shared_config)
    | Some filename, None ->
        let filename = filename ^ ".log" in
        shared_config ~time_tagged ~elapsed_times ~location_format ~print_entry_ids
          ~global_prefix ?split_files_after ~with_table_of_contents ~toc_entry ~for_append
          ~log_level ?path_filter filename
    | Some _, Some _ ->
        invalid_arg
          "Minidebug_runtime.debug_flushing: only one of debug_ch, filename should be \
           provided"
  in
  let module Debug = Flushing ((val log_to)) in
  (module Debug)

let forget_printbox (module Runtime : PrintBox_runtime) = (module Runtime : Debug_runtime)

let sexp_of_lazy_t sexp_of_a l =
  if Lazy.is_val l then Sexplib0.Sexp.List [ Atom "lazy"; sexp_of_a @@ Lazy.force l ]
  else Sexplib0.Sexp.List [ Atom "lazy"; Atom "<thunk>" ]

let local_runtime ?time_tagged ?elapsed_times ?location_format ?print_entry_ids
    ?verbose_entry_ids ?global_prefix ?split_files_after ?with_toc_listing ?toc_entry
    ?toc_flame_graph ?flame_graph_separation ?highlight_terms ?exclude_on_path ?prune_upto
    ?truncate_children ?for_append ?boxify_sexp_from_size ?max_inline_sexp_length ?backend
    ?hyperlink ?toc_specific_hyperlink ?values_first_mode ?log_level ?snapshot_every_sec
    ?prev_run_file ?diff_ignore_pattern ?max_distance_factor ?entry_id_pairs
    ?update_config ?path_filter filename_stem =
  let get_thread_id () = Thread.id (Thread.self ()) in
  let get_debug () : (module PrintBox_runtime) =
    let filename =
      let id = get_thread_id () in
      if id = 0 then filename_stem else Printf.sprintf "%s-%d" filename_stem id
    in
    debug_file ?time_tagged ?elapsed_times ?location_format ?print_entry_ids
      ?verbose_entry_ids ?global_prefix ?split_files_after ?with_toc_listing ?toc_entry
      ?toc_flame_graph ?flame_graph_separation ?highlight_terms ?exclude_on_path
      ?prune_upto ?truncate_children ?for_append ?boxify_sexp_from_size
      ?max_inline_sexp_length ?backend ?hyperlink ?toc_specific_hyperlink
      ?values_first_mode ?log_level ?snapshot_every_sec ?prev_run_file
      ?diff_ignore_pattern ?max_distance_factor ?entry_id_pairs ?path_filter filename
  in
  let key = Thread_local_storage.create () in
  let get_local () = Thread_local_storage.get_default ~default:get_debug key in
  match update_config with
  | None -> fun () -> forget_printbox @@ get_local ()
  | Some update_config ->
      fun () ->
        let module Debug = (val get_local ()) in
        update_config Debug.config;
        (module Debug : Debug_runtime)

let local_runtime_flushing ?table_of_contents_ch ?time_tagged ?elapsed_times
    ?location_format ?print_entry_ids ?verbose_entry_ids ?global_prefix ?split_files_after
    ?with_table_of_contents ?toc_entry ?for_append ?log_level ?path_filter filename_stem =
  let get_thread_id () = Thread.id (Thread.self ()) in
  let get_debug () =
    let filename =
      let id = get_thread_id () in
      if id = 0 then filename_stem else Printf.sprintf "%s-%d" filename_stem id
    in
    debug_flushing ?table_of_contents_ch ?time_tagged ?elapsed_times ?location_format
      ?print_entry_ids ?verbose_entry_ids ?global_prefix ?split_files_after
      ?with_table_of_contents ?toc_entry ?for_append ?log_level ?path_filter ~filename ()
  in
  let key = Thread_local_storage.create () in
  fun () -> Thread_local_storage.get_default ~default:get_debug key

let prefixed_runtime ?debug_ch ?time_tagged ?elapsed_times ?location_format
    ?print_entry_ids ?verbose_entry_ids ?global_prefix ?table_of_contents_ch ?toc_entry
    ?highlight_terms ?exclude_on_path ?prune_upto ?truncate_children ?values_first_mode
    ?boxify_sexp_from_size ?max_inline_sexp_length ?backend ?hyperlink
    ?toc_specific_hyperlink ?log_level ?snapshot_every_sec ?update_config ?path_filter ()
    =
  let get_thread_id () = Thread.id (Thread.self ()) in
  let get_debug () : (module PrintBox_runtime) =
    let global_prefix =
      let id = get_thread_id () in
      if id = 0 then global_prefix
      else Some (Printf.sprintf "%s-%d" (Option.value ~default:"Thread" global_prefix) id)
    in
    debug ?debug_ch ?time_tagged ?elapsed_times ?location_format ?print_entry_ids
      ?verbose_entry_ids ?global_prefix ?table_of_contents_ch ?toc_entry ?highlight_terms
      ?exclude_on_path ?prune_upto ?truncate_children ?boxify_sexp_from_size
      ?max_inline_sexp_length ?backend ?hyperlink ?toc_specific_hyperlink
      ?values_first_mode ?log_level ?snapshot_every_sec ?path_filter ()
  in
  let key = Thread_local_storage.create () in
  let get_local () = Thread_local_storage.get_default ~default:get_debug key in
  match update_config with
  | None -> fun () -> forget_printbox @@ get_local ()
  | Some update_config ->
      fun () ->
        let module Debug = (val get_local ()) in
        update_config Debug.config;
        (module Debug : Debug_runtime)

let prefixed_runtime_flushing ?debug_ch ?table_of_contents_ch ?time_tagged ?elapsed_times
    ?location_format ?print_entry_ids ?verbose_entry_ids ?global_prefix ?split_files_after
    ?with_table_of_contents ?toc_entry ?for_append ?log_level ?path_filter () =
  let get_thread_id () = Thread.id (Thread.self ()) in
  let get_debug () =
    let global_prefix =
      let id = get_thread_id () in
      if id = 0 then global_prefix
      else Some (Printf.sprintf "%s-%d" (Option.value ~default:"Thread" global_prefix) id)
    in
    debug_flushing ?debug_ch ?table_of_contents_ch ?time_tagged ?elapsed_times
      ?location_format ?print_entry_ids ?verbose_entry_ids ?global_prefix
      ~prefix_all_logs:true ?split_files_after ?with_table_of_contents ?toc_entry
      ?for_append ?log_level ?path_filter ()
  in
  let key = Thread_local_storage.create () in
  fun () -> Thread_local_storage.get_default ~default:get_debug key
