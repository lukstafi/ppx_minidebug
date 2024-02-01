module CFormat = Format

let pp_timestamp ppf () =
  let tz_offset_s = Ptime_clock.current_tz_offset_s () in
  Ptime.(pp_human ~frac_s:6 ?tz_offset_s ()) ppf (Ptime_clock.now ())

let timestamp_to_string () =
  let _ = CFormat.flush_str_formatter () in
  let tz_offset_s = Ptime_clock.current_tz_offset_s () in
  Ptime.(pp_human ~frac_s:6 ?tz_offset_s ()) CFormat.str_formatter (Ptime_clock.now ());
  CFormat.flush_str_formatter ()

module type Debug_ch = sig
  val refresh_ch : unit -> bool
  val debug_ch : unit -> out_channel
  val time_tagged : bool
  val split_files_after : int option
end

let debug_ch ?(time_tagged = false)
    ?split_files_after ?(for_append = true) filename : (module Debug_ch) =
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

    let debug_ch () =
      if refresh_ch () then current_ch := find_ch ();
      !current_ch

    let time_tagged = time_tagged
    let split_files_after = split_files_after
  end in
  (module Result)

module type Debug_runtime = sig
  val close_log : unit -> unit

  val open_log_preamble_brief :
    fname:string ->
    pos_lnum:int ->
    pos_colnum:int ->
    message:string ->
    entry_id:int ->
    unit

  val open_log_preamble_full :
    fname:string ->
    start_lnum:int ->
    start_colnum:int ->
    end_lnum:int ->
    end_colnum:int ->
    message:string ->
    entry_id:int ->
    unit

  val log_value_sexp : descr:string -> entry_id:int -> sexp:Sexplib0.Sexp.t -> unit

  val log_value_pp :
    descr:string -> entry_id:int -> pp:(Format.formatter -> 'a -> unit) -> v:'a -> unit

  val log_value_show : descr:string -> entry_id:int -> v:string -> unit
  val exceeds_max_nesting : unit -> bool
  val exceeds_max_children : unit -> bool
  val get_entry_id : unit -> int
  val max_nesting_depth : int option ref
  val max_num_children : int option ref
end

let exceeds ~value ~limit = match limit with None -> false | Some limit -> limit < value

module Pp_format (Log_to : Debug_ch) : Debug_runtime = struct
  open Log_to

  let max_nesting_depth = ref None
  let max_num_children = ref None

  let get_ppf () =
    let ppf = CFormat.formatter_of_out_channel @@ debug_ch () in
    CFormat.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf

  let ppf = ref @@ get_ppf ()
  let stack = ref []

  let () =
    if Log_to.time_tagged then
      CFormat.fprintf !ppf "@.BEGIN DEBUG SESSION at time %a@." pp_timestamp ()
    else CFormat.fprintf !ppf "@.BEGIN DEBUG SESSION@."

  let close_log () =
    (match !stack with
    | [] -> failwith "ppx_minidebug: close_log must follow an earlier open_log_preamble"
    | _ :: tl -> stack := tl);
    CFormat.pp_close_box !ppf ();
    if !stack = [] then (
      (* Importantly, pp_print_newline invokes pp_print_flush, flushes the out channel. *)
      CFormat.pp_print_newline !ppf ();
      if refresh_ch () then ppf := get_ppf ())

  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message ~entry_id:_ =
    stack := 0 :: !stack;
    CFormat.fprintf !ppf "\"%s\":%d:%d: %s@ @[<hov 2>" fname pos_lnum pos_colnum message

  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum
      ~message ~entry_id:_ =
    stack := 0 :: !stack;
    CFormat.fprintf !ppf "@[\"%s\":%d:%d-%d:%d" fname start_lnum start_colnum end_lnum
      end_colnum;
    if Log_to.time_tagged then CFormat.fprintf !ppf "@ at time@ %a" pp_timestamp ();
    CFormat.fprintf !ppf ": %s@]@ @[<hov 2>" message

  let log_value_sexp ~descr ~entry_id:_ ~sexp =
    (match !stack with
    | num_children :: tl -> stack := (num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    CFormat.fprintf !ppf "%s = %a@ @ " descr Sexplib0.Sexp.pp_hum sexp

  let log_value_pp ~descr ~entry_id:_ ~pp ~v =
    (match !stack with
    | num_children :: tl -> stack := (num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    CFormat.fprintf !ppf "%s = %a@ @ " descr pp v

  let log_value_show ~descr ~entry_id:_ ~v =
    (match !stack with
    | num_children :: tl -> stack := (num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    CFormat.fprintf !ppf "%s = %s@ @ " descr v

  let exceeds_max_nesting () =
    exceeds ~value:(List.length !stack) ~limit:!max_nesting_depth

  let exceeds_max_children () =
    match !stack with
    | [] -> false
    | num_children :: _ -> exceeds ~value:num_children ~limit:!max_num_children

  let get_entry_id =
    let global_id = ref 0 in
    fun () ->
      incr global_id;
      !global_id
end

module Flushing (Log_to : Debug_ch) : Debug_runtime = struct
  open Log_to

  let max_nesting_depth = ref None
  let max_num_children = ref None
  let debug_ch = ref @@ debug_ch ()
  let stack = ref []
  let indent () = String.make (List.length !stack) ' '

  let () =
    if Log_to.time_tagged then
      Printf.fprintf !debug_ch "\nBEGIN DEBUG SESSION at time %s\n%!"
        (timestamp_to_string ())
    else Printf.fprintf !debug_ch "\nBEGIN DEBUG SESSION\n%!"

  let close_log () =
    match !stack with
    | [] -> failwith "ppx_minidebug: close_log must follow an earlier open_log_preamble"
    | (None, _) :: tl -> stack := tl
    | (Some message, _) :: tl ->
        stack := tl;
        Printf.fprintf !debug_ch "%s%!" (indent ());
        if Log_to.time_tagged then
          Printf.fprintf !debug_ch "%s - %!" (timestamp_to_string ());
        Printf.fprintf !debug_ch "%s end\n%!" message;
        flush !debug_ch;
        if !stack = [] then debug_ch := Log_to.debug_ch ()

  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message ~entry_id:_ =
    stack := (None, 0) :: !stack;
    Printf.fprintf !debug_ch "%s\"%s\":%d:%d: %s\n%!" (indent ()) fname pos_lnum
      pos_colnum message

  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum
      ~message ~entry_id:_ =
    Printf.fprintf !debug_ch "%s%!" (indent ());
    if Log_to.time_tagged then Printf.fprintf !debug_ch "%s - %!" (timestamp_to_string ());
    Printf.fprintf !debug_ch "%s begin \"%s\":%d:%d-%d:%d\n%!" message fname start_lnum
      start_colnum end_lnum end_colnum;
    stack := (Some message, 0) :: !stack

  let log_value_sexp ~descr ~entry_id:_ ~sexp =
    (match !stack with
    | (hd, num_children) :: tl -> stack := (hd, num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    Printf.fprintf !debug_ch "%s%s = %s\n%!" (indent ()) descr
      (Sexplib0.Sexp.to_string_hum sexp)

  let log_value_pp ~descr ~entry_id:_ ~pp ~v =
    (match !stack with
    | (hd, num_children) :: tl -> stack := (hd, num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    let _ = CFormat.flush_str_formatter () in
    pp CFormat.str_formatter v;
    let v_str = CFormat.flush_str_formatter () in
    Printf.fprintf !debug_ch "%s%s = %s\n%!" (indent ()) descr v_str

  let log_value_show ~descr ~entry_id:_ ~v =
    (match !stack with
    | (hd, num_children) :: tl -> stack := (hd, num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    Printf.fprintf !debug_ch "%s%s = %s\n%!" (indent ()) descr v

  let exceeds_max_nesting () =
    exceeds ~value:(List.length !stack) ~limit:!max_nesting_depth

  let exceeds_max_children () =
    match !stack with
    | [] -> false
    | (_, num_children) :: _ -> exceeds ~value:num_children ~limit:!max_num_children

  let get_entry_id =
    let global_id = ref 0 in
    fun () ->
      incr global_id;
      !global_id
end

module type PrintBox_runtime = sig
  include Debug_runtime

  val no_debug_if : bool -> unit
  val default_html_config : PrintBox_html.Config.t
  val default_md_config : PrintBox_md.Config.t

  type config = {
    mutable hyperlink : [ `Prefix of string | `No_hyperlinks ];
    mutable backend :
      [ `Text | `Html of PrintBox_html.Config.t | `Markdown of PrintBox_md.Config.t ];
    mutable boxify_sexp_from_size : int;
    mutable highlight_terms : Re.re option;
    mutable exclude_on_path : Re.re option;
    mutable prune_upto : int;
    mutable values_first_mode : bool;
    mutable max_inline_sexp_size : int;
    mutable max_inline_sexp_length : int;
  }

  val config : config
end

module PrintBox (Log_to : Debug_ch) = struct
  open Log_to

  let max_nesting_depth = ref None
  let max_num_children = ref None
  let default_html_config = PrintBox_html.Config.(tree_summary true default)

  (* let default_md_config = PrintBox_html.Config.(foldable_trees true default) *)
  let default_md_config = PrintBox_md.Config.uniform

  type config = {
    mutable hyperlink : [ `Prefix of string | `No_hyperlinks ];
    mutable backend :
      [ `Text | `Html of PrintBox_html.Config.t | `Markdown of PrintBox_md.Config.t ];
    mutable boxify_sexp_from_size : int;
    mutable highlight_terms : Re.re option;
    mutable exclude_on_path : Re.re option;
    mutable prune_upto : int;
    mutable values_first_mode : bool;
    mutable max_inline_sexp_size : int;
    mutable max_inline_sexp_length : int;
  }

  let config =
    {
      hyperlink = `No_hyperlinks;
      backend = `Text;
      boxify_sexp_from_size = -1;
      highlight_terms = None;
      prune_upto = 0;
      exclude_on_path = None;
      values_first_mode = false;
      max_inline_sexp_size = 20;
      max_inline_sexp_length = 50;
    }

  module B = PrintBox

  type subentry = { result_id : int; subtree : B.t }

  type entry = {
    cond : bool;
    highlight : bool;
    exclude : bool;
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

  let stack_next ~entry_id (hl, b) =
    stack :=
      match !stack with
      | ({ highlight; exclude; body; _ } as entry) :: bs2 ->
          {
            entry with
            highlight = highlight || ((not exclude) && hl);
            body = { result_id = entry_id; subtree = b } :: body;
          }
          :: bs2
      | _ ->
          failwith
            "minidebug_runtime: a log_value must be preceded by an open_log_preamble"

  let () =
    let log_header =
      if Log_to.time_tagged then
        CFormat.asprintf "@.BEGIN DEBUG SESSION at time %a@." pp_timestamp ()
      else CFormat.asprintf "@.BEGIN DEBUG SESSION@."
    in
    output_string (debug_ch ()) log_header

  let apply_highlight hl b =
    match B.view b with B.Frame _ -> b | _ -> if hl then B.frame b else b

  let partition_at pos l =
    let rec loop pos acc l =
      if pos <= 0 then (List.rev acc, l)
      else
        match l with
        | [] -> (List.rev acc, [])
        | hd :: tl -> loop (pos - 1) (hd :: acc) tl
    in
    loop pos [] l

  let stack_to_tree
      { cond = _; highlight; exclude = _; uri; path; entry_message; entry_id; body } =
    let is_struct, n_struct =
      if String.contains entry_message ',' || String.contains entry_message ';' then
        let tuple_elems = String.split_on_char ',' entry_message in
        let record_elems = String.split_on_char ';' entry_message in
        let n_tuple = List.length tuple_elems in
        let n_record = List.length record_elems in
        (n_tuple > 1 || n_record > 1, max n_tuple n_record)
      else (false, 0)
    in
    let b_path =
      B.line @@ if config.values_first_mode then path else path ^ ": " ^ entry_message
    in
    let b_path = hyperlink_path ~uri ~inner:b_path in
    let b_body = List.map (fun { subtree; _ } -> subtree) body in
    if config.values_first_mode then
      let hl_header = apply_highlight highlight @@ B.line entry_message in
      match body with
      | [] -> B.tree hl_header [ b_path ]
      | { result_id; _ } :: _ as body when is_struct && result_id = entry_id ->
          let body = List.map (fun { subtree; _ } -> subtree) body in
          let result, body = partition_at n_struct body in
          B.tree
            (apply_highlight highlight hl_header)
            (b_path :: B.tree (B.line "<values>") (List.rev result) :: List.rev body)
      | { result_id; subtree } :: body when result_id = entry_id -> (
          let body = List.map (fun { subtree; _ } -> subtree) body in
          match B.view subtree with
          | B.Tree (_ident, result_header, result_body) ->
              B.tree
                (apply_highlight highlight result_header)
                (b_path
                :: B.tree (B.line "<returns>") (Array.to_list result_body)
                :: List.rev body)
          | _ -> B.tree (apply_highlight highlight subtree) (b_path :: List.rev body))
      | _ -> B.tree hl_header (b_path :: List.rev b_body)
    else
      let hl_header = apply_highlight highlight b_path in
      B.tree hl_header (List.rev b_body)

  let close_log () =
    (* Note: we treat a tree under a box as part of that box. *)
    stack :=
      (* Design choice: exclude does not apply to its own entry -- its about propagating children. *)
      match !stack with
      | { highlight = false; _ } :: bs when config.prune_upto >= List.length !stack -> bs
      | ({ cond = true; highlight = hl; exclude = _; entry_id = result_id; _ } as entry)
        :: { cond; highlight; exclude; uri; path; entry_message; entry_id; body }
        :: bs3 ->
          {
            cond;
            highlight = highlight || ((not exclude) && hl);
            exclude;
            uri;
            path;
            entry_message;
            entry_id;
            body = { result_id; subtree = stack_to_tree entry } :: body;
          }
          :: bs3
      | { cond = false; _ } :: bs -> bs
      | [ ({ cond = true; _ } as entry) ] ->
          let box = stack_to_tree entry in
          let ch = debug_ch () in
          (match config.backend with
          | `Text -> PrintBox_text.output ch box
          | `Html config -> output_string ch @@ PrintBox_html.(to_string ~config box)
          | `Markdown config ->
              output_string ch
              @@ PrintBox_md.(to_string Config.(foldable_trees config) box));
          output_string ch "\n";
          Stdlib.flush ch;
          []
      | _ -> failwith "ppx_minidebug: close_log must follow an earlier open_log_preamble"

  let open_log_preamble ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message
      ~entry_id ~brief =
    let uri =
      match config.hyperlink with
      | `Prefix prefix
        when String.length prefix = 0
             || Char.equal prefix.[0] '.'
             || String.equal (String.sub prefix 0 5) "http:"
             || String.equal (String.sub prefix 0 6) "https:" ->
          Printf.sprintf "%s#L%d" fname start_lnum
      | _ -> Printf.sprintf "%s:%d:%d" fname start_lnum (start_colnum + 1)
    in

    let path =
      if brief then Printf.sprintf "\"%s\":%d:%d" fname start_lnum start_colnum
      else if Log_to.time_tagged then
        Format.asprintf "@[\"%s\":%d:%d-%d:%d@ at time@ %a@]" fname start_lnum
          start_colnum end_lnum end_colnum pp_timestamp ()
      else
        Format.asprintf "@[\"%s\":%d:%d-%d:%d@]" fname start_lnum start_colnum end_lnum
          end_colnum
    in
    let exclude =
      match config.exclude_on_path with Some r -> Re.execp r message | None -> false
    in
    let highlight =
      match config.highlight_terms with Some r -> Re.execp r message | None -> false
    in
    stack :=
      {
        cond = true;
        highlight;
        exclude;
        uri;
        path;
        entry_message = message;
        entry_id;
        body = [];
      }
      :: !stack

  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum =
    open_log_preamble ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~brief:false

  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum =
    open_log_preamble ~fname ~start_lnum:pos_lnum ~start_colnum:pos_colnum
      ~end_lnum:pos_lnum ~end_colnum:pos_colnum ~brief:true

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

  let boxify descr sexp =
    let open Sexplib0.Sexp in
    let rec loop ?(as_tree = false) sexp =
      if (not as_tree) && sexp_size sexp < config.boxify_sexp_from_size then
        highlight_box
        @@ B.asprintf_with_style B.Style.preformatted "%a" Sexplib0.Sexp.pp_hum sexp
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
    match sexp with
    | Atom s | List [ Atom s ] ->
        highlight_box @@ B.text_with_style B.Style.preformatted (descr ^ " = " ^ s)
    | List [] -> highlight_box @@ B.line descr
    | List l ->
        let str =
          if sexp_size sexp < min config.boxify_sexp_from_size config.max_inline_sexp_size
          then Sexplib0.Sexp.to_string_hum sexp
          else ""
        in
        if String.length str > 0 && String.length str < config.max_inline_sexp_length then
          (* TODO: Desing choice: consider not using monospace, at least for descr.  *)
          highlight_box @@ B.text_with_style B.Style.preformatted (descr ^ " = " ^ str)
        else loop ~as_tree:true @@ List (Atom (descr ^ " =") :: l)

  let num_children () = match !stack with [] -> 0 | { body; _ } :: _ -> List.length body

  let log_value_sexp ~descr ~entry_id ~sexp =
    if config.boxify_sexp_from_size >= 0 then stack_next ~entry_id @@ boxify descr sexp
    else
      stack_next ~entry_id @@ highlight_box
      @@ B.asprintf_with_style B.Style.preformatted "%s = %a" descr Sexplib0.Sexp.pp_hum
           sexp

  let log_value_pp ~descr ~entry_id ~pp ~v =
    stack_next ~entry_id @@ highlight_box
    @@ B.asprintf_with_style B.Style.preformatted "%s = %a" descr pp v

  let log_value_show ~descr ~entry_id ~v =
    stack_next ~entry_id @@ highlight_box
    @@ B.sprintf_with_style B.Style.preformatted "%s = %s" descr v

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
end

let debug_file ?(time_tagged = false) ?split_files_after ?highlight_terms ?exclude_on_path
    ?(prune_upto = 0) ?(for_append = false) ?(boxify_sexp_from_size = 50) ?backend
    ?hyperlink ?(values_first_mode = false) filename : (module PrintBox_runtime) =
  let filename =
    match backend with
    | None | Some (`Markdown _) -> filename ^ ".md"
    | Some (`Html _) -> filename ^ ".html"
    | Some `Text -> filename ^ ".log"
  in
  let module Debug =
    PrintBox ((val debug_ch ~time_tagged ~for_append ?split_files_after filename)) in
  Debug.config.backend <-
    Option.value backend ~default:(`Markdown Debug.default_md_config);
  Debug.config.boxify_sexp_from_size <- boxify_sexp_from_size;
  Debug.config.highlight_terms <- Option.map Re.compile highlight_terms;
  Debug.config.prune_upto <- prune_upto;
  Debug.config.exclude_on_path <- Option.map Re.compile exclude_on_path;
  Debug.config.values_first_mode <- values_first_mode;
  Debug.config.hyperlink <-
    (match hyperlink with None -> `No_hyperlinks | Some prefix -> `Prefix prefix);
  (module Debug)

let debug ?(debug_ch = stdout) ?(time_tagged = false)
    ?highlight_terms ?exclude_on_path ?(prune_upto = 0) ?(values_first_mode = false) () :
    (module PrintBox_runtime) =
  let module Debug = PrintBox (struct
    let refresh_ch () = false
    let debug_ch () = debug_ch
    let time_tagged = time_tagged
    let split_files_after = None
  end) in
  Debug.config.highlight_terms <- Option.map Re.compile highlight_terms;
  Debug.config.prune_upto <- prune_upto;
  Debug.config.exclude_on_path <- Option.map Re.compile exclude_on_path;
  Debug.config.values_first_mode <- values_first_mode;
  (module Debug)

let debug_flushing ?(debug_ch = stdout) ?(time_tagged = false) () : (module Debug_runtime) =
  (module Flushing (struct
    let refresh_ch () = false
    let debug_ch () = debug_ch
    let time_tagged = time_tagged
    let split_files_after = None
  end))
