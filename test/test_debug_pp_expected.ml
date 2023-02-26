module Debug_runtime =
  struct
    let debug_ch =
      let debug_ch =
        Stdio.Out_channel.create ~binary:false ~append:true
          "../../../debugger.log" in
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
    let close_box () = Caml.Format.pp_close_box ppf ()
  end
type t = {
  first: int ;
  second: int }[@@deriving show]
type num = int[@@deriving show]
let foo (x : t) =
  (Debug_runtime.open_box ();
   (Debug_runtime.pp_printf ()
      "@[\"%s\":%d:%d-%d:%d@ at time UTC@ %s: %s@]@ " "test_debug_pp.ml" 22
      17 22 71 (Core.Time_ns.to_string_utc @@ (Core.Time_ns.now ())) "foo";
    Debug_runtime.pp_printf () "%s = %a@ @ " "x" pp x);
   (let foo__res = let y : num = x.first + 1 in x.second * y in
    Debug_runtime.pp_printf () "%s = %a@ @ " "foo" pp_num foo__res;
    Debug_runtime.close_box ();
    foo__res) : num)
let () = ignore foo
