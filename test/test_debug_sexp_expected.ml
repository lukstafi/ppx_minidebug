open Base
module Debug_runtime =
  (Debug_runtime_jane.Printf)(struct let v = "../../../debugger_sexp.log" end)
let foo (x : int) =
  (Debug_runtime.open_box ();
   (Debug_runtime.pp_printf () "@[\"%s\":%d:%d-%d:%d@ at time@ %s: %s@]@ "
      "test_debug_sexp.ml" 4 19 6 15 (Debug_runtime.timestamp_now ()) "foo";
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
   (Debug_runtime.pp_printf () "@[\"%s\":%d:%d-%d:%d@ at time@ %s: %s@]@ "
      "test_debug_sexp.ml" 11 19 11 73 (Debug_runtime.timestamp_now ()) "bar";
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
let baz (x : t) =
  (Debug_runtime.open_box ();
   (Debug_runtime.pp_printf () "@[\"%s\":%d:%d-%d:%d@ at time@ %s: %s@]@ "
      "test_debug_sexp.ml" 14 19 15 67 (Debug_runtime.timestamp_now ()) "baz";
    Debug_runtime.pp_printf () "%s = %a@ @ " "x" Sexp.pp_hum
      (([%sexp_of : t]) x));
   (let baz__res =
      let (((y, z) as _yz) : (int * int)) =
        Debug_runtime.open_box ();
        Debug_runtime.pp_printf () "\"%s\":%d:%d:%s" "test_debug_sexp.ml" 15
          15 " ";
        (let _yz__res = ((x.first + 1), 3) in
         Debug_runtime.pp_printf () "%s = %a@ @ " "_yz" Sexp.pp_hum
           (([%sexp_of : (int * int)]) _yz__res);
         Debug_runtime.close_box ~toplevel:false ();
         _yz__res) in
      (x.second * y) + z in
    Debug_runtime.pp_printf () "%s = %a@ @ " "baz" Sexp.pp_hum
      (([%sexp_of : int]) baz__res);
    Debug_runtime.close_box ~toplevel:true ();
    baz__res) : int)
let () =
  Stdio.Out_channel.print_endline @@
    (Int.to_string @@ (baz { first = 7; second = 42 }))
