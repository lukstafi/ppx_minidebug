open Base
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
type nonrec int = int[@@deriving sexp]
let foo (x : int) =
  (Debug_runtime.open_box ();
   (Debug_runtime.pp_printf ()
      "@[\"%s\":%d:%d-%d:%d@ at time UTC@ %s: %s@]@ " "test_debug_sexp.ml" 21
      19 21 62 (Core.Time_ns.to_string_utc @@ (Core.Time_ns.now ())) "foo";
    Debug_runtime.pp_printf () "%s = %a@ @ " "x" Sexp.pp_hum (sexp_of_int x));
   (let foo__res = let y : int = x + 1 in 2 * y in
    Debug_runtime.pp_printf () "%s = %a@ @ " "foo" Sexp.pp_hum
      (sexp_of_int foo__res);
    Debug_runtime.close_box ();
    foo__res) : int)
let () = ignore foo
