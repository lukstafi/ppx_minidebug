open Base
module Debug_runtime =
  (Minidebug_runtime.PrintBox)((Minidebug_runtime.Debug_ch)(struct
                                                              let filename =
                                                                "debugger_sexp_printbox.log"
                                                            end))
let foo (x : int) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_sexp.ml"
      ~start_lnum:6 ~start_colnum:19 ~end_lnum:8 ~end_colnum:15
      ~message:"foo";
    Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : int]) x));
   (let foo__res = let y : int = x + 1 in [x; y; 2 * y] in
    Debug_runtime.log_value_sexp ~descr:"foo"
      ~sexp:(([%sexp_of : int list]) foo__res);
    Debug_runtime.close_log ();
    foo__res) : int list)
let () = ignore @@ (List.hd_exn @@ (foo 7))
type t = {
  first: int ;
  second: int }[@@deriving sexp]
let bar (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_sexp.ml"
      ~start_lnum:13 ~start_colnum:19 ~end_lnum:13 ~end_colnum:73
      ~message:"bar";
    Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : t]) x));
   (let bar__res = let y : int = x.first + 1 in x.second * y in
    Debug_runtime.log_value_sexp ~descr:"bar"
      ~sexp:(([%sexp_of : int]) bar__res);
    Debug_runtime.close_log ();
    bar__res) : int)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_sexp.ml"
      ~start_lnum:16 ~start_colnum:19 ~end_lnum:17 ~end_colnum:67
      ~message:"baz";
    Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : t]) x));
   (let baz__res =
      let (((y, z) as _yz) : (int * int)) = ((x.first + 1), 3) in
      (x.second * y) + z in
    Debug_runtime.log_value_sexp ~descr:"baz"
      ~sexp:(([%sexp_of : int]) baz__res);
    Debug_runtime.close_log ();
    baz__res) : int)
let () = ignore @@ (baz { first = 7; second = 42 })
let lab ~x:(x : int)  =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_sexp.ml"
      ~start_lnum:20 ~start_colnum:19 ~end_lnum:22 ~end_colnum:15
      ~message:"lab";
    Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : int]) x));
   (let lab__res = let y : int = x + 1 in [x; y; 2 * y] in
    Debug_runtime.log_value_sexp ~descr:"lab"
      ~sexp:(([%sexp_of : int list]) lab__res);
    Debug_runtime.close_log ();
    lab__res) : int list)
let () = ignore @@ (List.hd_exn @@ (lab ~x:7))
let rec loop (depth : int) (x : t) =
  (((Debug_runtime.open_log_preamble_full ~fname:"test_debug_sexp.ml"
       ~start_lnum:26 ~start_colnum:24 ~end_lnum:32 ~end_colnum:9
       ~message:"loop";
     Debug_runtime.log_value_sexp ~descr:"depth"
       ~sexp:(([%sexp_of : int]) depth));
    Debug_runtime.log_value_sexp ~descr:"x" ~sexp:(([%sexp_of : t]) x));
   (let loop__res =
      if depth > 4
      then x.first + x.second
      else
        if depth > 1
        then
          loop (depth + 1) { first = (x.second + 1); second = (x.first / 2) }
        else
          (let y : int =
             Debug_runtime.open_log_preamble_brief
               ~fname:"test_debug_sexp.ml" ~pos_lnum:30 ~pos_colnum:8
               ~message:" ";
             (let y__res =
                (loop (depth + 1)
                   { first = (x.second - 1); second = (x.first + 2) } : 
                int) in
              Debug_runtime.log_value_sexp ~descr:"y"
                ~sexp:(([%sexp_of : int]) y__res);
              Debug_runtime.close_log ();
              y__res) in
           let z : int =
             Debug_runtime.open_log_preamble_brief
               ~fname:"test_debug_sexp.ml" ~pos_lnum:31 ~pos_colnum:8
               ~message:" ";
             (let z__res =
                (loop (depth + 1) { first = (x.second + 1); second = y } : 
                int) in
              Debug_runtime.log_value_sexp ~descr:"z"
                ~sexp:(([%sexp_of : int]) z__res);
              Debug_runtime.close_log ();
              z__res) in
           z + 7) in
    Debug_runtime.log_value_sexp ~descr:"loop"
      ~sexp:(([%sexp_of : int]) loop__res);
    Debug_runtime.close_log ();
    loop__res) : int)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
