open Base
module Debug_runtime =
  (Minidebug_runtime.Flat)(struct
                             let v = "../../../debugger_sexp_flat.log"
                           end)
let foo (x : int) =
  (Debug_runtime.log_preamble_full ~fname:"test_debug_sexp.ml" ~start_lnum:4
     ~start_colnum:19 ~end_lnum:6 ~end_colnum:15 ~message:"foo";
   Debug_runtime.open_box ();
   Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : int]) x);
   (let foo__res =
      let y : int =
        Debug_runtime.open_box ();
        Debug_runtime.log_preamble_brief ~fname:"test_debug_sexp.ml"
          ~pos_lnum:5 ~pos_colnum:6 ~message:" ";
        (let y__res = (x + 1 : int) in
         Debug_runtime.log_value_sexp ~descr:"y"
           ~sexp:(([%sexp_of : int]) y__res);
         Debug_runtime.close_box ~toplevel:false ();
         y__res) in
      [x; y; 2 * y] in
    Debug_runtime.log_value_sexp ~descr:"foo"
      ~sexp:(([%sexp_of : int list]) foo__res);
    Debug_runtime.close_box ~toplevel:true ();
    foo__res) : int list)
let () =
  Stdio.Out_channel.print_endline @@
    (Int.to_string @@ (List.hd_exn @@ (foo 7)))
type t = {
  first: int ;
  second: int }[@@deriving sexp]
let bar (x : t) =
  (Debug_runtime.log_preamble_full ~fname:"test_debug_sexp.ml" ~start_lnum:11
     ~start_colnum:19 ~end_lnum:11 ~end_colnum:73 ~message:"bar";
   Debug_runtime.open_box ();
   Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : t]) x);
   (let bar__res =
      let y : int =
        Debug_runtime.open_box ();
        Debug_runtime.log_preamble_brief ~fname:"test_debug_sexp.ml"
          ~pos_lnum:11 ~pos_colnum:37 ~message:" ";
        (let y__res = (x.first + 1 : int) in
         Debug_runtime.log_value_sexp ~descr:"y"
           ~sexp:(([%sexp_of : int]) y__res);
         Debug_runtime.close_box ~toplevel:false ();
         y__res) in
      x.second * y in
    Debug_runtime.log_value_sexp ~descr:"bar"
      ~sexp:(([%sexp_of : int]) bar__res);
    Debug_runtime.close_box ~toplevel:true ();
    bar__res) : int)
let () =
  Stdio.Out_channel.print_endline @@
    (Int.to_string @@ (bar { first = 7; second = 42 }))
let baz (x : t) =
  (Debug_runtime.log_preamble_full ~fname:"test_debug_sexp.ml" ~start_lnum:14
     ~start_colnum:19 ~end_lnum:15 ~end_colnum:67 ~message:"baz";
   Debug_runtime.open_box ();
   Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : t]) x);
   (let baz__res =
      let (((y, z) as _yz) : (int * int)) =
        Debug_runtime.open_box ();
        Debug_runtime.log_preamble_brief ~fname:"test_debug_sexp.ml"
          ~pos_lnum:15 ~pos_colnum:15 ~message:" ";
        (let _yz__res = ((x.first + 1), 3) in
         Debug_runtime.log_value_sexp ~descr:"_yz"
           ~sexp:(([%sexp_of : (int * int)]) _yz__res);
         Debug_runtime.close_box ~toplevel:false ();
         _yz__res) in
      (x.second * y) + z in
    Debug_runtime.log_value_sexp ~descr:"baz"
      ~sexp:(([%sexp_of : int]) baz__res);
    Debug_runtime.close_box ~toplevel:true ();
    baz__res) : int)
let () =
  Stdio.Out_channel.print_endline @@
    (Int.to_string @@ (baz { first = 7; second = 42 }))
let rec loop (depth : int) (x : t) =
  (Debug_runtime.log_preamble_full ~fname:"test_debug_sexp.ml" ~start_lnum:18
     ~start_colnum:24 ~end_lnum:24 ~end_colnum:9 ~message:"loop";
   Debug_runtime.open_box ();
   (Debug_runtime.log_value_sexp ~descr:"depth"
      ~sexp:(([%sexp_of : int]) depth);
    Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : t]) x));
   (let loop__res =
      if depth > 6
      then x.first + x.second
      else
        if depth > 3
        then
          loop (depth + 1) { first = (x.second + 1); second = (x.first / 2) }
        else
          (let y : int =
             Debug_runtime.open_box ();
             Debug_runtime.log_preamble_brief ~fname:"test_debug_sexp.ml"
               ~pos_lnum:22 ~pos_colnum:8 ~message:" ";
             (let y__res =
                (loop (depth + 1)
                   { first = (x.second - 1); second = (x.first + 2) } : 
                int) in
              Debug_runtime.log_value_sexp ~descr:"y"
                ~sexp:(([%sexp_of : int]) y__res);
              Debug_runtime.close_box ~toplevel:false ();
              y__res) in
           let z : int =
             Debug_runtime.open_box ();
             Debug_runtime.log_preamble_brief ~fname:"test_debug_sexp.ml"
               ~pos_lnum:23 ~pos_colnum:8 ~message:" ";
             (let z__res =
                (loop (depth + 1) { first = (x.second + 1); second = y } : 
                int) in
              Debug_runtime.log_value_sexp ~descr:"z"
                ~sexp:(([%sexp_of : int]) z__res);
              Debug_runtime.close_box ~toplevel:false ();
              z__res) in
           z + 7) in
    Debug_runtime.log_value_sexp ~descr:"loop"
      ~sexp:(([%sexp_of : int]) loop__res);
    Debug_runtime.close_box ~toplevel:true ();
    loop__res) : int)
let () =
  Stdio.Out_channel.print_endline @@
    (Int.to_string @@ (loop 0 { first = 7; second = 42 }))
