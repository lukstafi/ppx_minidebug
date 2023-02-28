module Printf(File_name: sig val v : string end) = struct
  let debug_ch =
    let debug_ch =
      open_out_gen [Open_creat; Open_text; Open_append] 0o640 File_name.v in
    let tm = Unix.localtime (Unix.time ()) in
    Printf.fprintf debug_ch "\nBEGIN DEBUG SESSION at local time %dh:%dm:%ds -- %f\n%!"
      tm.tm_hour tm.tm_min tm.tm_sec (Unix.gettimeofday());
    debug_ch
  let ppf =
    let ppf = Format.formatter_of_out_channel debug_ch in
    Format.pp_set_geometry ppf ~max_indent:50 ~margin:100;
    ppf
  let pp_printf () (type a): (a, Format.formatter, unit) format -> a =
    Format.fprintf ppf
  let open_box() = Format.pp_open_hovbox ppf 2
  let close_box ~toplevel () =
    Format.pp_close_box ppf ();
    (if toplevel then Format.pp_print_newline ppf ())
  let timestamp_now() = Float.to_string @@ Unix.gettimeofday()
end
