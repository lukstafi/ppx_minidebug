module Debug_runtime =
  struct
    let debug_ch =
      let debug_ch =
        Stdio.Out_channel.create ~binary:false ~append:true
          "../../../debugger_pp.log" in
      Stdio.Out_channel.fprintf debug_ch
        "\nBEGIN DEBUG SESSION at time UTC %s\n%!"
        (Core.Time_ns.to_string_utc @@ (Core.Time_ns.now ()));
      debug_ch
    let ppf =
      let ppf = Caml.Format.formatter_of_out_channel debug_ch in
      Caml.Format.pp_set_geometry ppf ~max_indent:50 ~margin:100; ppf
    let pp_printf () (type a) =
      (Caml.Format.fprintf ppf : (a, Caml.Format.formatter, unit) format -> a)
    let open_box () = Caml.Format.pp_open_hovbox ppf 2
    let close_box ~toplevel  () =
      Caml.Format.pp_close_box ppf ();
      if toplevel then Caml.Format.pp_print_newline ppf ()
  end
type t = {
  first: int ;
  second: int }[@@deriving show]
type num = int[@@deriving show]
let bar (x : t) =
  (Debug_runtime.open_box ();
   (Debug_runtime.pp_printf ()
      "@[\"%s\":%d:%d-%d:%d@ at time UTC@ %s: %s@]@ " "test_debug_pp.ml" 22
      17 22 71 (Core.Time_ns.to_string_utc @@ (Core.Time_ns.now ())) "bar";
    Debug_runtime.pp_printf () "%s = %a@ @ " "x" pp x);
   (let bar__res =
      let y : num =
        Debug_runtime.open_box ();
        Debug_runtime.pp_printf () "\"%s\":%d:%d:%s" "test_debug_pp.ml" 22 35
          " ";
        (let y__res = (x.first + 1 : num) in
         Debug_runtime.pp_printf () "%s = %a@ @ " "y" pp_num y__res;
         Debug_runtime.close_box ~toplevel:false ();
         y__res) in
      x.second * y in
    Debug_runtime.pp_printf () "%s = %a@ @ " "bar" pp_num bar__res;
    Debug_runtime.close_box ~toplevel:true ();
    bar__res) : num)
let () = print_endline @@ (Int.to_string @@ (bar { first = 7; second = 42 }))
