open Base

let pp_timestamp ppf () =
  let tz_offset_s = Ptime_clock.current_tz_offset_s () in
  Ptime.(pp_human ~frac_s:6 ?tz_offset_s ()) ppf (Ptime_clock.now ())

let timestamp_to_string () =
  let _ = Caml.Format.flush_str_formatter () in
  let tz_offset_s = Ptime_clock.current_tz_offset_s () in
  Ptime.(pp_human ~frac_s:6 ?tz_offset_s ())
    Caml.Format.str_formatter
   (Ptime_clock.now ());
  Caml.Format.flush_str_formatter ()

module Format(File_name: sig val v : string end) = struct  
  let debug_ch =
    Caml.open_out_gen [Open_creat; Open_text; Open_append] 0o640 File_name.v
  (* Stdio.Out_channel.create ~binary:false ~append:true File_name.v *)

  let ppf =
    let ppf = Caml.Format.formatter_of_out_channel debug_ch in
    Caml.Format.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf
    
  let () =
    Caml.Format.fprintf ppf "@.BEGIN DEBUG SESSION at time %a@." pp_timestamp ()
  
  let close_log () =
    Caml.Format.pp_close_box ppf ()
      
  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    Caml.Format.fprintf ppf
        "\"%s\":%d:%d:%s@ @[<hov 2>" fname pos_lnum pos_colnum message
        
  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message =
    Caml.Format.fprintf ppf
        "@[\"%s\":%d:%d-%d:%d@ at time@ %a: %s@]@ @[<hov 2>"
        fname start_lnum start_colnum  end_lnum end_colnum
        pp_timestamp () message
        
  let log_value_sexp ~descr ~sexp =
    Caml.Format.fprintf ppf "%s = %a@ @ " descr Sexp.pp_hum sexp
    
  let log_value_pp ~descr ~pp ~v =
    Caml.Format.fprintf ppf "%s = %a@ @ " descr pp v
    
  let log_value_show ~descr ~v =
    Caml.Format.fprintf ppf "%s = %s@ @ " descr v
end

module Flushing(File_name: sig val v : string end) = struct  
  let debug_ch =
    Caml.open_out_gen [Open_creat; Open_text; Open_append] 0o640 File_name.v
  (* Stdio.Out_channel.create ~binary:false ~append:true File_name.v *)
    
  let callstack = ref []

  let indent() = String.make (List.length !callstack) ' '
  
  let () =
    Caml.Printf.fprintf debug_ch "\nBEGIN DEBUG SESSION at time %s\n%!" (timestamp_to_string())
  
  let close_log () =
    match !callstack with
    | [] -> failwith "ppx_minidebug: close_log must follow an earlier open_log_preamble"
    | None::tl ->
      callstack := tl
    | Some message::tl ->
      callstack := tl;
      Caml.Printf.fprintf debug_ch "%s%s - %s end\n%!" (indent()) (timestamp_to_string()) message

  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    callstack := None :: !callstack;
    Caml.Printf.fprintf debug_ch "%s\"%s\":%d:%d:%s\n%!" (indent()) fname pos_lnum pos_colnum message
        
  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message =
    Caml.Printf.fprintf debug_ch
        "%s%s - %s begin \"%s\":%d:%d-%d:%d\n%!"
        (indent()) (timestamp_to_string()) message fname start_lnum start_colnum  end_lnum end_colnum;
    callstack := Some message :: !callstack

  let log_value_sexp ~descr ~sexp =
    Caml.Printf.fprintf debug_ch "%s%s = %s\n%!"  (indent()) descr (Sexp.to_string_hum sexp)
    
  let log_value_pp ~descr ~pp ~v =
    let _ = Caml.Format.flush_str_formatter () in
    pp Caml.Format.str_formatter v;
    let v_str = Caml.Format.flush_str_formatter () in
    Caml.Printf.fprintf debug_ch "%s%s = %s\n%!" (indent()) descr v_str
    
  let log_value_show ~descr ~v =
    Caml.Printf.fprintf debug_ch "%s%s = %s\n%!" (indent()) descr v
end

let rec revert_order: PrintBox.Simple.t -> PrintBox.Simple.t = function
| `Empty -> `Empty
| `Pad b -> `Pad (revert_order b)
| (`Text _ | `Table _) as b -> b
| `Vlist bs -> `Vlist (List.rev_map bs ~f:revert_order)
| `Hlist bs -> `Hlist (List.rev_map bs ~f:revert_order)
| `Tree (b, bs) -> `Tree (b, List.rev_map bs ~f:revert_order)

module PrintBox(File_name: sig val v : string end) = struct
  module B = PrintBox
  
  let debug_ch =
    Caml.open_out_gen [Open_creat; Open_text; Open_append] 0o640 File_name.v
  (* Stdio.Out_channel.create ~binary:false ~append:true File_name.v *)
  
  let ppf =
    let ppf = Caml.Format.formatter_of_out_channel debug_ch in
    Caml.Format.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf
    
  let stack: B.Simple.t list ref = ref []
  let stack_next b = stack := (match !stack with
  | `Tree (b1, bs1)::bs2 -> `Tree (b1, (b::bs1))::bs2
  | _ -> failwith "minidebug_runtime: a log_value must be preceded by an open_log_preamble")
    
  let () =
    Caml.Format.fprintf ppf "@.BEGIN DEBUG SESSION at time %a@." pp_timestamp ()

  let close_log () =
    (* Note: we treat a `Tree under a box as part of that box. *)
    stack := (match !stack with
    | b::`Tree (b1, bs1)::bs2 -> `Tree (b1, (b::bs1))::bs2
    | [b] ->
      PrintBox_text.output debug_ch @@ B.Simple.to_box @@ revert_order @@ b;
      Caml.Format.fprintf ppf "@\n%!"; []
    | _ -> failwith "ppx_minidebug: close_log must follow an earlier open_log_preamble")
  
  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    let preamble = B.Simple.sprintf "\"%s\":%d:%d:%s" fname pos_lnum pos_colnum message in
    stack := `Tree (preamble, []) :: !stack
    
  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message =
    let preamble = B.Simple.asprintf
        "@[\"%s\":%d:%d-%d:%d@ at time@ %a: %s@]"
        fname start_lnum start_colnum  end_lnum end_colnum
        pp_timestamp () message in
    stack := `Tree (preamble, []) :: !stack
    
  let log_value_sexp ~descr ~sexp =
    stack_next @@ B.Simple.asprintf "%s = %a" descr Sexp.pp_hum sexp
    
  let log_value_pp ~descr ~pp ~v =
    stack_next @@ B.Simple.asprintf "%s = %a" descr pp v

  let log_value_show ~descr ~v =
    stack_next @@ B.Simple.sprintf "%s = %s" descr v
end
