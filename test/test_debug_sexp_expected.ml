open Base
module Debug_runtime =
  (Debug_runtime_jane.Printf)(struct let v = "../../../debugger.log" end)
let foo (x : int) =
  (Debug_runtime.open_box ();
   (Debug_runtime.pp_printf ()
      "@[\"%s\":%d:%d-%d:%d@ at time UTC@ %s: %s@]@ " "test_debug_sexp.ml" 4
      19 6 15 (Core.Time_ns.to_string_utc @@ (Core.Time_ns.now ())) "foo";
    Debug_runtime.pp_printf () "%s = %a@ @ " "x" Sexp.pp_hum
      (([%sexp_of : int]) x));
   (let foo__res =
      let y : int =
        Debug_runtime.open_box ();
        Debug_runtime.pp_printf () "\"%s\":%d:%d:%s" "test_debug_sexp.ml" 5 6
          " ";
        (let y__res = (x + 1 : int) in
         Debug_runtime.pp_printf () "%s = %a@ @ " "y" Sexp.pp_hum
           (([%sexp_of : int]) y__res);
         Debug_runtime.close_box ~toplevel:false ();
         y__res) in
      [x; y; 2 * y] in
    Debug_runtime.pp_printf () "%s = %a@ @ " "foo" Sexp.pp_hum
      (([%sexp_of : int list]) foo__res);
    Debug_runtime.close_box ~toplevel:true ();
    foo__res) : int list)
let () =
  Stdio.Out_channel.print_endline @@
    (Int.to_string @@ (List.hd_exn @@ (foo 7)))
type t = {
  first: int ;
  second: int }[@@deriving sexp]
let bar (x : t) =
  (Debug_runtime.open_box ();
   (Debug_runtime.pp_printf ()
      "@[\"%s\":%d:%d-%d:%d@ at time UTC@ %s: %s@]@ " "test_debug_sexp.ml" 11
      19 11 73 (Core.Time_ns.to_string_utc @@ (Core.Time_ns.now ())) "bar";
    Debug_runtime.pp_printf () "%s = %a@ @ " "x" Sexp.pp_hum
      (([%sexp_of : t]) x));
   (let bar__res =
      let y : int =
        Debug_runtime.open_box ();
        Debug_runtime.pp_printf () "\"%s\":%d:%d:%s" "test_debug_sexp.ml" 11
          37 " ";
        (let y__res = (x.first + 1 : int) in
         Debug_runtime.pp_printf () "%s = %a@ @ " "y" Sexp.pp_hum
           (([%sexp_of : int]) y__res);
         Debug_runtime.close_box ~toplevel:false ();
         y__res) in
      x.second * y in
    Debug_runtime.pp_printf () "%s = %a@ @ " "bar" Sexp.pp_hum
      (([%sexp_of : int]) bar__res);
    Debug_runtime.close_box ~toplevel:true ();
    bar__res) : int)
let () =
  Stdio.Out_channel.print_endline @@
    (Int.to_string @@ (bar { first = 7; second = 42 }))
