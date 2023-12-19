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
  val debug_ch : out_channel
  val time_tagged : bool
  val max_nesting_depth : int option
  val max_num_children : int option
end

let debug_ch ?(time_tagged = false) ?max_nesting_depth ?max_num_children
    ?(for_append = true) filename : (module Debug_ch) =
  let module Result = struct
    let debug_ch =
      if for_append then open_out_gen [ Open_creat; Open_append ] 0o640 filename
      else open_out filename

    let time_tagged = time_tagged
    let max_nesting_depth = max_nesting_depth
    let max_num_children = max_num_children
  end in
  (module Result)

module type Debug_runtime = sig
  val close_log : unit -> unit

  val open_log_preamble_brief :
    fname:string -> pos_lnum:int -> pos_colnum:int -> message:string -> unit

  val open_log_preamble_full :
    fname:string ->
    start_lnum:int ->
    start_colnum:int ->
    end_lnum:int ->
    end_colnum:int ->
    message:string ->
    unit

  val log_value_sexp : descr:string -> sexp:Sexplib0.Sexp.t -> unit
  val log_value_pp : descr:string -> pp:(Format.formatter -> 'a -> unit) -> v:'a -> unit
  val log_value_show : descr:string -> v:string -> unit
  val exceeds_max_nesting : unit -> bool
  val exceeds_max_children : unit -> bool
end

module type Debug_runtime_cond = sig
  include Debug_runtime

  val no_debug_if : bool -> unit
  (** When passed true within the scope of a log subtree, disables the logging of this subtree and its
      subtrees. Does not do anything when passed false ([no_debug_if false] does {e not} re-enable
      the log). *)
end

let exceeds ~value ~limit = match limit with None -> false | Some limit -> limit < value

module Pp_format (Log_to : Debug_ch) : Debug_runtime = struct
  open Log_to

  let ppf =
    let ppf = CFormat.formatter_of_out_channel debug_ch in
    CFormat.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf

  let stack = ref []

  let () =
    if Log_to.time_tagged then
      CFormat.fprintf ppf "@.BEGIN DEBUG SESSION at time %a@." pp_timestamp ()
    else CFormat.fprintf ppf "@.BEGIN DEBUG SESSION@."

  let close_log () =
    (match !stack with
    | [] -> failwith "ppx_minidebug: close_log must follow an earlier open_log_preamble"
    | _ :: tl -> stack := tl);
    CFormat.pp_close_box ppf ()

  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    stack := 0 :: !stack;
    CFormat.fprintf ppf "\"%s\":%d:%d:%s@ @[<hov 2>" fname pos_lnum pos_colnum message

  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum
      ~message =
    stack := 0 :: !stack;
    CFormat.fprintf ppf "@[\"%s\":%d:%d-%d:%d" fname start_lnum start_colnum end_lnum
      end_colnum;
    if Log_to.time_tagged then CFormat.fprintf ppf "@ at time@ %a" pp_timestamp ();
    CFormat.fprintf ppf ": %s@]@ @[<hov 2>" message

  let log_value_sexp ~descr ~sexp =
    (match !stack with
    | num_children :: tl -> stack := (num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    CFormat.fprintf ppf "%s = %a@ @ " descr Sexplib0.Sexp.pp_hum sexp

  let log_value_pp ~descr ~pp ~v =
    (match !stack with
    | num_children :: tl -> stack := (num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    CFormat.fprintf ppf "%s = %a@ @ " descr pp v

  let log_value_show ~descr ~v =
    (match !stack with
    | num_children :: tl -> stack := (num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    CFormat.fprintf ppf "%s = %s@ @ " descr v

  let exceeds_max_nesting () =
    exceeds ~value:(List.length !stack) ~limit:max_nesting_depth

  let exceeds_max_children () =
    match !stack with
    | [] -> false
    | num_children :: _ -> exceeds ~value:num_children ~limit:max_num_children
end

module Flushing (Log_to : Debug_ch) : Debug_runtime = struct
  open Log_to

  let stack = ref []
  let indent () = String.make (List.length !stack) ' '

  let () =
    if Log_to.time_tagged then
      Printf.fprintf debug_ch "\nBEGIN DEBUG SESSION at time %s\n%!"
        (timestamp_to_string ())
    else Printf.fprintf debug_ch "\nBEGIN DEBUG SESSION\n%!"

  let close_log () =
    match !stack with
    | [] -> failwith "ppx_minidebug: close_log must follow an earlier open_log_preamble"
    | (None, _) :: tl -> stack := tl
    | (Some message, _) :: tl ->
        stack := tl;
        Printf.fprintf debug_ch "%s%!" (indent ());
        if Log_to.time_tagged then
          Printf.fprintf debug_ch "%s - %!" (timestamp_to_string ());
        Printf.fprintf debug_ch "%s end\n%!" message;
        flush debug_ch

  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    stack := (None, 0) :: !stack;
    Printf.fprintf debug_ch "%s\"%s\":%d:%d:%s\n%!" (indent ()) fname pos_lnum pos_colnum
      message

  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum
      ~message =
    Printf.fprintf debug_ch "%s%!" (indent ());
    if Log_to.time_tagged then Printf.fprintf debug_ch "%s - %!" (timestamp_to_string ());
    Printf.fprintf debug_ch "%s begin \"%s\":%d:%d-%d:%d\n%!" message fname start_lnum
      start_colnum end_lnum end_colnum;
    stack := (Some message, 0) :: !stack

  let log_value_sexp ~descr ~sexp =
    (match !stack with
    | (hd, num_children) :: tl -> stack := (hd, num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    Printf.fprintf debug_ch "%s%s = %s\n%!" (indent ()) descr
      (Sexplib0.Sexp.to_string_hum sexp)

  let log_value_pp ~descr ~pp ~v =
    (match !stack with
    | (hd, num_children) :: tl -> stack := (hd, num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    let _ = CFormat.flush_str_formatter () in
    pp CFormat.str_formatter v;
    let v_str = CFormat.flush_str_formatter () in
    Printf.fprintf debug_ch "%s%s = %s\n%!" (indent ()) descr v_str

  let log_value_show ~descr ~v =
    (match !stack with
    | (hd, num_children) :: tl -> stack := (hd, num_children + 1) :: tl
    | [] -> failwith "ppx_minidebug: log_value must follow an earlier open_log_preamble");
    Printf.fprintf debug_ch "%s%s = %s\n%!" (indent ()) descr v

  let exceeds_max_nesting () =
    exceeds ~value:(List.length !stack) ~limit:max_nesting_depth

  let exceeds_max_children () =
    match !stack with
    | [] -> false
    | (_, num_children) :: _ -> exceeds ~value:num_children ~limit:max_num_children
end

module PrintBox (Log_to : Debug_ch) = struct
  open Log_to

  let to_html = ref false
  let boxify_sexp_from_size = ref (-1)

  module B = PrintBox

  let ppf =
    let ppf = CFormat.formatter_of_out_channel debug_ch in
    CFormat.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf

  let stack : (bool * (B.t * B.t list)) list ref = ref []

  let stack_next b =
    stack :=
      match !stack with
      | (cond, (b1, bs1)) :: bs2 -> (cond, (b1, b :: bs1)) :: bs2
      | _ ->
          failwith
            "minidebug_runtime: a log_value must be preceded by an open_log_preamble"

  let () =
    if Log_to.time_tagged then
      CFormat.fprintf ppf "@.BEGIN DEBUG SESSION at time %a@." pp_timestamp ()
    else CFormat.fprintf ppf "@.BEGIN DEBUG SESSION@."

  let stack_to_tree (b, bs) = B.tree b (List.rev bs)

  let close_log () =
    (* Note: we treat a tree under a box as part of that box. *)
    stack :=
      match !stack with
      | (true, b) :: (cond, (b2, bs2)) :: bs3 ->
          (cond, (b2, stack_to_tree b :: bs2)) :: bs3
      | (false, _) :: bs -> bs
      | [ (true, b) ] ->
          let box = stack_to_tree b in
          if !to_html then
            Out_channel.output_string debug_ch
            @@ PrintBox_html.(to_string ~config:Config.(tree_summary true default) box)
          else PrintBox_text.output debug_ch box;
          Out_channel.output_string debug_ch "\n";
          []
          (* CFormat.fprintf ppf "@\n%!"; [] *)
      | _ -> failwith "ppx_minidebug: close_log must follow an earlier open_log_preamble"

  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    let preamble = B.sprintf "\"%s\":%d:%d:%s" fname pos_lnum pos_colnum message in
    stack := (true, (preamble, [])) :: !stack

  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum
      ~message =
    let preamble =
      if Log_to.time_tagged then
        B.asprintf "@[\"%s\":%d:%d-%d:%d@ at time@ %a: %s@]" fname start_lnum start_colnum
          end_lnum end_colnum pp_timestamp () message
      else
        B.asprintf "@[\"%s\":%d:%d-%d:%d: %s@]" fname start_lnum start_colnum end_lnum
          end_colnum message
    in
    stack := (true, (preamble, [])) :: !stack

  let sexp_size sexp =
    let open Sexplib0.Sexp in
    let rec loop = function
      | Atom _ -> 1
      | List l -> List.fold_left ( + ) 0 (List.map loop l)
    in
    loop sexp

  let boxify descr sexp =
    let open Sexplib0.Sexp in
    let rec loop_atom sexp =
      if sexp_size sexp < !boxify_sexp_from_size then
        B.asprintf_with_style B.Style.preformatted "%a" Sexplib0.Sexp.pp_hum sexp
      else
        match sexp with
        | Atom s -> B.text_with_style B.Style.preformatted s
        | List [] -> B.empty
        | List [ s ] -> loop_atom s
        | List (Atom s :: l) ->
            B.tree (B.text_with_style B.Style.preformatted s) (List.map loop_atom l)
        | List l -> B.vlist (List.map loop_atom l)
    in
    match sexp with
    | Atom s | List [ Atom s ] ->
        B.text_with_style B.Style.preformatted (descr ^ " = " ^ s)
    | List [] -> B.empty
    | List l ->
        B.tree
          (B.text_with_style B.Style.preformatted (descr ^ " ="))
          (List.map loop_atom l)

  let num_children () =
    match !stack with [] -> 0 | (_, (_, children)) :: _ -> List.length children

  let log_value_sexp ~descr ~sexp =
    if !boxify_sexp_from_size >= 0 then stack_next @@ boxify descr sexp
    else
      stack_next
      @@ B.asprintf_with_style B.Style.preformatted "%s = %a" descr Sexplib0.Sexp.pp_hum
           sexp

  let log_value_pp ~descr ~pp ~v =
    stack_next @@ B.asprintf_with_style B.Style.preformatted "%s = %a" descr pp v

  let log_value_show ~descr ~v =
    stack_next
    @@ B.sprintf_with_style B.Style.preformatted "%s = %s" descr v

  let no_debug_if cond =
    match !stack with (true, b) :: bs when cond -> stack := (false, b) :: bs | _ -> ()

  let exceeds_max_nesting () =
    exceeds ~value:(List.length !stack) ~limit:max_nesting_depth

  let exceeds_max_children () = exceeds ~value:(num_children ()) ~limit:max_num_children
end

let debug_html ?(time_tagged = false) ?max_nesting_depth ?max_num_children
    ?(for_append = false) ?(boxify_sexp_from_size = 50) filename :
    (module Debug_runtime_cond) =
  let module Debug =
    PrintBox
      ((val debug_ch ~time_tagged ~for_append ?max_nesting_depth ?max_num_children
              filename)) in
  Debug.to_html := true;
  Debug.boxify_sexp_from_size := boxify_sexp_from_size;
  (module Debug)

let debug ?(debug_ch = stdout) ?(time_tagged = false) ?max_nesting_depth ?max_num_children
    () : (module Debug_runtime_cond) =
  (module PrintBox (struct
    let debug_ch = debug_ch
    let time_tagged = time_tagged
    let max_nesting_depth = max_nesting_depth
    let max_num_children = max_num_children
  end))

let debug_flushing ?(debug_ch = stdout) ?(time_tagged = false) ?max_nesting_depth
    ?max_num_children () : (module Debug_runtime) =
  (module Flushing (struct
    let debug_ch = debug_ch
    let time_tagged = time_tagged
    let max_nesting_depth = max_nesting_depth
    let max_num_children = max_num_children
  end))
