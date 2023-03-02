module Printf(File_name: sig val v : string end) = struct  
  let debug_ch =
      open_out_gen [Open_creat; Open_text; Open_append] 0o640 File_name.v
  let ppf =
    let ppf = Format.formatter_of_out_channel debug_ch in
    Format.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf
  let pp_timestamp ppf now =
    let tz_offset_s = Ptime_clock.current_tz_offset_s () in
    Ptime.(pp_human ?tz_offset_s ()) ppf now
  let () =
    Format.fprintf ppf "\nBEGIN DEBUG SESSION at time %a\n%!"
    pp_timestamp (Ptime_clock.now ())
  let close_log () =
    Format.pp_close_box ppf ();
    (if then Format.pp_print_newline ppf ())
  let open_log_preamble_brief ~fname ~pos_lnum ~pos_colnum ~message =
    Format.fprintf ppf
        "\"%s\":%d:%d:%s" fname pos_lnum pos_colnum message
  let open_log_preamble_full ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message =
    Format.fprintf ppf
        "@[\"%s\":%d:%d-%d:%d@ at time@ %a: %s@]@ "
        fname start_lnum start_colnum  end_lnum end_colnum
        pp_timestamp (Ptime_clock.now ()) message
end
