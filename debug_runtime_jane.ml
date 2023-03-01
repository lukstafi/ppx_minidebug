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
  let timestamp_now() = "UTC "^Core.Time_ns.to_string_utc @@ Core.Time_ns.now()
end
