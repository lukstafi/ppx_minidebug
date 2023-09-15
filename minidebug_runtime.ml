module CFormat = Format

let pp_timestamp ppf () =
  let tz_offset_s = Ptime_clock.current_tz_offset_s () in
  Ptime.(pp_human ~frac_s:6 ?tz_offset_s ()) ppf (Ptime_clock.now ())

let timestamp_to_string () =
  let _ = CFormat.flush_str_formatter () in
  let tz_offset_s = Ptime_clock.current_tz_offset_s () in
  Ptime.(pp_human ~frac_s:6 ?tz_offset_s ())
    CFormat.str_formatter
   (Ptime_clock.now ());
  CFormat.flush_str_formatter ()

module type Debug_ch = sig val debug_ch : out_channel val time_tagged : bool end

module Debug_ch(File_name: sig val filename : string end): Debug_ch = struct
    let debug_ch = open_out_gen [Open_creat; Open_text; Open_append] 0o640 File_name.filename
    (* or: Stdio.Out_channel.create ~binary:false ~append:true File_name.v *)
    let time_tagged = true
end

module Debug_ch_no_time_tags(File_name: sig val filename : string end): Debug_ch = struct
  let debug_ch = open_out_gen [Open_creat; Open_text; Open_append] 0o640 File_name.filename
  let time_tagged = false
end
  
module type Debug_runtime =
sig
  val close_log : unit -> unit
  val open_log_preamble_brief :
    fname:string ->
    pos_lnum:int -> pos_colnum:int -> message:string -> unit
  val open_log_preamble_full :
    fname:string ->
    start_lnum:int ->
    start_colnum:int ->
    end_lnum:int -> end_colnum:int -> message:string -> unit
  val log_value_sexp : descr:string -> sexp:Sexplib0.Sexp.t -> unit
  val log_value_pp :
    descr:string -> pp:(Format.formatter -> 'a -> unit) -> v:'a -> unit
  val log_value_show : descr:string -> v:string -> unit
end

module Pp_format(Log_to: Debug_ch): Debug_runtime = struct  
  open Log_to

  let ppf =
    let ppf = CFormat.formatter_of_out_channel debug_ch in
    CFormat.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf
    
  let () =
    if Log_to.time_tagged then
      CFormat.fprintf ppf "@.BEGIN DEBUG SESSION at time %a@." pp_timestamp ()
    else CFormat.fprintf ppf "@.BEGIN DEBUG SESSION@."
  
  let close_log () =
    CFormat.pp_close_box ppf ()

  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    CFormat.fprintf ppf
        "\"%s\":%d:%d:%s@ @[<hov 2>" fname pos_lnum pos_colnum message

  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message =
    CFormat.fprintf ppf "@[\"%s\":%d:%d-%d:%d" fname start_lnum start_colnum  end_lnum end_colnum;
    if Log_to.time_tagged then CFormat.fprintf ppf "@ at time@ %a" pp_timestamp ();
    CFormat.fprintf ppf ": %s@]@ @[<hov 2>" message
        
  let log_value_sexp ~descr ~sexp =
    CFormat.fprintf ppf "%s = %a@ @ " descr Sexplib0.Sexp.pp_hum sexp
    
  let log_value_pp ~descr ~pp ~v =
    CFormat.fprintf ppf "%s = %a@ @ " descr pp v
    
  let log_value_show ~descr ~v =
    CFormat.fprintf ppf "%s = %s@ @ " descr v
end

module Flushing(Log_to: Debug_ch): Debug_runtime = struct  
  open Log_to
    
  let callstack = ref []

  let indent() = String.make (List.length !callstack) ' '
  
  let () =
    if Log_to.time_tagged then
      Printf.fprintf debug_ch "\nBEGIN DEBUG SESSION at time %s\n%!" (timestamp_to_string())
    else Printf.fprintf debug_ch "\nBEGIN DEBUG SESSION\n%!"
  
  let close_log () =
    match !callstack with
    | [] -> failwith "ppx_minidebug: close_log must follow an earlier open_log_preamble"
    | None::tl ->
      callstack := tl
    | Some message::tl ->
      callstack := tl;
      Printf.fprintf debug_ch "%s%!" (indent());
      if Log_to.time_tagged then Printf.fprintf debug_ch "%s - %!" (timestamp_to_string());
      Printf.fprintf debug_ch "%s end\n%!" message;
      flush debug_ch

  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    callstack := None :: !callstack;
    Printf.fprintf debug_ch "%s\"%s\":%d:%d:%s\n%!" (indent()) fname pos_lnum pos_colnum message
        
  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message =
    Printf.fprintf debug_ch "%s%!" (indent());
    if Log_to.time_tagged then Printf.fprintf debug_ch "%s - %!" (timestamp_to_string());
    Printf.fprintf debug_ch "%s begin \"%s\":%d:%d-%d:%d\n%!"
      message fname start_lnum start_colnum end_lnum end_colnum;
    callstack := Some message :: !callstack

  let log_value_sexp ~descr ~sexp =
    Printf.fprintf debug_ch "%s%s = %s\n%!"  (indent()) descr (Sexplib0.Sexp.to_string_hum sexp)
    
  let log_value_pp ~descr ~pp ~v =
    let _ = CFormat.flush_str_formatter () in
    pp CFormat.str_formatter v;
    let v_str = CFormat.flush_str_formatter () in
    Printf.fprintf debug_ch "%s%s = %s\n%!" (indent()) descr v_str
    
  let log_value_show ~descr ~v =
    Printf.fprintf debug_ch "%s%s = %s\n%!" (indent()) descr v
end

let rec revert_order: PrintBox.Simple.t -> PrintBox.Simple.t = function
| `Empty -> `Empty
| `Pad b -> `Pad (revert_order b)
| (`Text _ | `Table _) as b -> b
| `Vlist bs -> `Vlist (List.rev_map revert_order bs)
| `Hlist bs -> `Hlist (List.rev_map revert_order bs)
| `Tree (b, bs) -> `Tree (b, List.rev_map revert_order bs)

module PrintBox(Log_to: Debug_ch): Debug_runtime = struct
  open Log_to
  module B = PrintBox
  
  let ppf =
    let ppf = CFormat.formatter_of_out_channel debug_ch in
    CFormat.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf
    
  let stack: B.Simple.t list ref = ref []
  let stack_next b = stack := (match !stack with
  | `Tree (b1, bs1)::bs2 -> `Tree (b1, (b::bs1))::bs2
  | _ -> failwith "minidebug_runtime: a log_value must be preceded by an open_log_preamble")
    
  let () =
    if Log_to.time_tagged then
      CFormat.fprintf ppf "@.BEGIN DEBUG SESSION at time %a@." pp_timestamp ()
    else CFormat.fprintf ppf "@.BEGIN DEBUG SESSION@."

  let close_log () =
    (* Note: we treat a `Tree under a box as part of that box. *)
    stack := (match !stack with
    | b::`Tree (b1, bs1)::bs2 -> `Tree (b1, (b::bs1))::bs2
    | [b] ->
      PrintBox_text.output debug_ch @@ B.Simple.to_box @@ revert_order @@ b;
      CFormat.fprintf ppf "@\n%!"; []
    | _ -> failwith "ppx_minidebug: close_log must follow an earlier open_log_preamble")
  
  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    let preamble = B.Simple.sprintf "\"%s\":%d:%d:%s" fname pos_lnum pos_colnum message in
    stack := `Tree (preamble, []) :: !stack
    
  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message =
    let preamble =
      if Log_to.time_tagged then
        B.Simple.asprintf "@[\"%s\":%d:%d-%d:%d@ at time@ %a: %s@]"
          fname start_lnum start_colnum end_lnum end_colnum pp_timestamp () message
      else
        B.Simple.asprintf "@[\"%s\":%d:%d-%d:%d: %s@]"
          fname start_lnum start_colnum end_lnum end_colnum message in
    stack := `Tree (preamble, []) :: !stack

  let log_value_sexp ~descr ~sexp =
    stack_next @@ B.Simple.asprintf "%s = %a" descr Sexplib0.Sexp.pp_hum sexp
    
  let log_value_pp ~descr ~pp ~v =
    stack_next @@ B.Simple.asprintf "%s = %a" descr pp v

  let log_value_show ~descr ~v =
    stack_next @@ B.Simple.sprintf "%s = %s" descr v
end
