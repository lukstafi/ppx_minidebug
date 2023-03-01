open Base

module Printf(File_name: sig val v : string end) = struct  
  let debug_ch =
    Stdio.Out_channel.create ~binary:false ~append:true File_name.v
  let ppf =
    let ppf = Caml.Format.formatter_of_out_channel debug_ch in
    Caml.Format.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf
  let pp_timestamp ppf now =
    let tz_offset_s = Ptime_clock.current_tz_offset_s () in
    Ptime.(pp_human ?tz_offset_s ()) ppf now
  let () =
    Caml.Format.fprintf ppf "\nBEGIN DEBUG SESSION at time %a\n%!"
    pp_timestamp (Ptime_clock.now ())
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
end
