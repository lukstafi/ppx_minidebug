module Debug_runtime =
  (Minidebug_runtime.Flushing)((Minidebug_runtime.Debug_ch)(struct
                                                              let filename =
                                                                "debugger_show_flushing.log"
                                                            end))
let foo (x : int) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
      ~start_lnum:5 ~start_colnum:19 ~end_lnum:7 ~end_colnum:15
      ~message:"foo";
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : int]) x));
   (let foo__res =
      let y : int =
        Debug_runtime.open_log_preamble_brief ~fname:"test_debug_show.ml"
          ~pos_lnum:6 ~pos_colnum:6 ~message:" ";
        (let y__res = (x + 1 : int) in
         Debug_runtime.log_value_show ~descr:"y" ~v:(([%show : int]) y__res);
         Debug_runtime.close_log ();
         y__res) in
      [x; y; 2 * y] in
    Debug_runtime.log_value_show ~descr:"foo"
      ~v:(([%show : int list]) foo__res);
    Debug_runtime.close_log ();
    foo__res) : int list)
let () = ignore @@ (List.hd @@ (foo 7))
type t = {
  first: int ;
  second: int }[@@deriving show]
let bar (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
      ~start_lnum:12 ~start_colnum:19 ~end_lnum:12 ~end_colnum:73
      ~message:"bar";
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : t]) x));
   (let bar__res =
      let y : int =
        Debug_runtime.open_log_preamble_brief ~fname:"test_debug_show.ml"
          ~pos_lnum:12 ~pos_colnum:37 ~message:" ";
        (let y__res = (x.first + 1 : int) in
         Debug_runtime.log_value_show ~descr:"y" ~v:(([%show : int]) y__res);
         Debug_runtime.close_log ();
         y__res) in
      x.second * y in
    Debug_runtime.log_value_show ~descr:"bar" ~v:(([%show : int]) bar__res);
    Debug_runtime.close_log ();
    bar__res) : int)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
      ~start_lnum:15 ~start_colnum:19 ~end_lnum:16 ~end_colnum:67
      ~message:"baz";
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : t]) x));
   (let baz__res =
      let (((y, z) as _yz) : (int * int)) =
        Debug_runtime.open_log_preamble_brief ~fname:"test_debug_show.ml"
          ~pos_lnum:16 ~pos_colnum:15 ~message:" ";
        (let _yz__res = ((x.first + 1), 3) in
         Debug_runtime.log_value_show ~descr:"_yz"
           ~v:(([%show : (int * int)]) _yz__res);
         Debug_runtime.close_log ();
         _yz__res) in
      (x.second * y) + z in
    Debug_runtime.log_value_show ~descr:"baz" ~v:(([%show : int]) baz__res);
    Debug_runtime.close_log ();
    baz__res) : int)
let () = ignore @@ (baz { first = 7; second = 42 })
let rec loop (depth : int) (x : t) =
  (((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
       ~start_lnum:19 ~start_colnum:24 ~end_lnum:25 ~end_colnum:9
       ~message:"loop";
     Debug_runtime.log_value_show ~descr:"depth" ~v:(([%show : int]) depth));
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : t]) x));
   (let loop__res =
      if depth > 6
      then x.first + x.second
      else
        if depth > 3
        then
          loop (depth + 1) { first = (x.second + 1); second = (x.first / 2) }
        else
          (let y : int =
             Debug_runtime.open_log_preamble_brief
               ~fname:"test_debug_show.ml" ~pos_lnum:23 ~pos_colnum:8
               ~message:" ";
             (let y__res =
                (loop (depth + 1)
                   { first = (x.second - 1); second = (x.first + 2) } : 
                int) in
              Debug_runtime.log_value_show ~descr:"y"
                ~v:(([%show : int]) y__res);
              Debug_runtime.close_log ();
              y__res) in
           let z : int =
             Debug_runtime.open_log_preamble_brief
               ~fname:"test_debug_show.ml" ~pos_lnum:24 ~pos_colnum:8
               ~message:" ";
             (let z__res =
                (loop (depth + 1) { first = (x.second + 1); second = y } : 
                int) in
              Debug_runtime.log_value_show ~descr:"z"
                ~v:(([%show : int]) z__res);
              Debug_runtime.close_log ();
              z__res) in
           z + 7) in
    Debug_runtime.log_value_show ~descr:"loop" ~v:(([%show : int]) loop__res);
    Debug_runtime.close_log ();
    loop__res) : int)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
