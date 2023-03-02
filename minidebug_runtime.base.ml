open Base

module Format(File_name: sig val v : string end) = struct  
  let debug_ch =
    Caml.open_out_gen [Open_creat; Open_text; Open_append] 0o640 File_name.v
  (* Stdio.Out_channel.create ~binary:false ~append:true File_name.v *)

  let ppf =
    let ppf = Caml.Format.formatter_of_out_channel debug_ch in
    Caml.Format.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf
    
  let pp_timestamp ppf now =
    let tz_offset_s = Ptime_clock.current_tz_offset_s () in
    Ptime.(pp_human ?tz_offset_s ()) ppf now
    
  let () =
    Caml.Format.fprintf ppf "@.BEGIN DEBUG SESSION at time %a@." pp_timestamp (Ptime_clock.now ())

  let open_box() = Caml.Format.pp_open_hovbox ppf 2
  
  let close_box ~toplevel () =
    Caml.Format.pp_close_box ppf ();
    (if toplevel then Caml.Format.pp_print_newline ppf ())
      
  let log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    Caml.Format.fprintf ppf
        "\"%s\":%d:%d:%s" fname pos_lnum pos_colnum message
        
  let log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message =
    Caml.Format.fprintf ppf
        "@[\"%s\":%d:%d-%d:%d@ at time@ %a: %s@]@ "
        fname start_lnum start_colnum  end_lnum end_colnum
        pp_timestamp (Ptime_clock.now ()) message
        
  let log_value_sexp ~descr ~sexp =
    Caml.Format.fprintf ppf "%s = %a@ @ " descr Sexp.pp_hum sexp
    
  let log_value_pp ~descr ~pp ~v =
    Caml.Format.fprintf ppf "%s = %a@ @ " descr pp v
    
  let log_value_show ~descr ~v =
    Caml.Format.fprintf ppf "%s = %s@ @ " descr v
end

module Flat(File_name: sig val v : string end) = struct  
  let debug_ch =
    Caml.open_out_gen [Open_creat; Open_text; Open_append] 0o640 File_name.v
  (* Stdio.Out_channel.create ~binary:false ~append:true File_name.v *)
  
  let ppf =
    let ppf = Caml.Format.formatter_of_out_channel debug_ch in
    Caml.Format.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf
    
  let pp_timestamp ppf now =
    let tz_offset_s = Ptime_clock.current_tz_offset_s () in
    Ptime.(pp_human ?tz_offset_s ()) ppf now
    
  let () =
    Caml.Format.fprintf ppf "\nBEGIN DEBUG SESSION at time %a@." pp_timestamp (Ptime_clock.now ())
    
  let open_box() = Caml.Format.pp_open_hovbox ppf 2
  
  let close_box ~toplevel () =
    Caml.Format.pp_close_box ppf ();
    (if toplevel then Caml.Format.pp_print_newline ppf ())
      
  let log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    Caml.Format.fprintf ppf
        "\"%s\":%d:%d:%s" fname pos_lnum pos_colnum message
        
  let log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message =
    Caml.Format.fprintf ppf
        "\"%s\":%d:%d-%d:%d@ at time@ %a: %s@."
        fname start_lnum start_colnum  end_lnum end_colnum
        pp_timestamp (Ptime_clock.now ()) message
        
  let log_value_sexp ~descr ~sexp =
    Caml.Format.fprintf ppf "%s = %a@." descr Sexp.pp_hum sexp
    
  let log_value_pp ~descr ~pp ~v =
    Caml.Format.fprintf ppf "%s = %a@." descr pp v
    
  let log_value_show ~descr ~v =
    Caml.Format.fprintf ppf "%s = %s@." descr v
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
    
  let stack: B.Simple.t list ref = ref [`Empty]
  let stack_by b = stack := (match !stack with
  | [] -> [b]
  | `Vlist bs1::bs2 -> `Vlist (b::bs1)::bs2
  | `Hlist bs1::bs2 -> `Hlist (b::bs1)::bs2
  | `Tree (b1, bs1)::bs2 -> `Tree (b1, (b::bs1))::bs2
  | b1::bs -> `Vlist [b; b1]::bs)
  
  let pp_timestamp ppf now =
    let tz_offset_s = Ptime_clock.current_tz_offset_s () in
    Ptime.(pp_human ?tz_offset_s ()) ppf now
    
  let () =
    Caml.Format.fprintf ppf "@.BEGIN DEBUG SESSION at time %a@." pp_timestamp (Ptime_clock.now ())
    
  let open_box() = stack := `Vlist [] :: !stack

  let close_box ~toplevel () =
    stack := (match !stack with
        | b::`Empty::bs -> b::bs
        | b::`Vlist bs1::bs2 -> `Vlist (b::bs1)::bs2
        | b::`Hlist bs1::bs2 -> `Hlist (b::bs1)::bs2
        | (`Vlist bs)::`Tree (b1, bs1)::bs2 -> `Tree (b1, (bs @ bs1))::bs2
        | b::`Tree (b1, bs1)::bs2 -> `Tree (b1, (b::bs1))::bs2
        | b::b1::bs -> `Vlist [b; b1]::bs
        | [b] -> [b]
        | [] -> []);
    if toplevel then stack := (match !stack with
        | [] -> []
        | b::bs ->
          PrintBox_text.output debug_ch @@ B.Simple.to_box @@ revert_order @@ b; bs)
          
  let log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    let preamble = B.Simple.sprintf "\"%s\":%d:%d:%s" fname pos_lnum pos_colnum message in
    stack := `Tree (preamble, []) :: !stack
    
  let log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message =
    let preamble = B.Simple.asprintf
        "@[\"%s\":%d:%d-%d:%d@ at time@ %a: %s@]"
        fname start_lnum start_colnum  end_lnum end_colnum
        pp_timestamp (Ptime_clock.now ()) message in
    stack := `Tree (preamble, []) :: !stack
    
  let log_value_sexp ~descr ~sexp =
    stack_by @@ B.Simple.asprintf "%s = %a" descr Sexp.pp_hum sexp
    
  let log_value_pp ~descr ~pp ~v =
    stack_by @@ B.Simple.asprintf "%s = %a" descr pp v

  let log_value_show ~descr ~v =
    stack_by @@ B.Simple.asprintf "%s = %s" descr v
end
