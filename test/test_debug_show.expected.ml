module Debug_runtime =
  (Minidebug_runtime.Flushing)((Minidebug_runtime.Debug_ch_no_time_tags)(
  struct
    let filename = "debugger_show_flushing.log"
  end))
let foo (x : int) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
      ~start_lnum:5 ~start_colnum:19 ~end_lnum:7 ~end_colnum:15
      ~message:"foo";
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : int]) x));
   (match let y : int =
            Debug_runtime.open_log_preamble_brief ~fname:"test_debug_show.ml"
              ~pos_lnum:6 ~pos_colnum:6 ~message:" ";
            (match (x + 1 : int) with
             | y__res ->
                 (Debug_runtime.log_value_show ~descr:"y"
                    ~v:(([%show : int]) y__res);
                  Debug_runtime.close_log ();
                  y__res)
             | exception e -> (Debug_runtime.close_log (); raise e)) in
          [x; y; 2 * y]
    with
    | foo__res ->
        (Debug_runtime.log_value_show ~descr:"foo"
           ~v:(([%show : int list]) foo__res);
         Debug_runtime.close_log ();
         foo__res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : int list)
let () = ignore @@ (List.hd @@ (foo 7))
type t = {
  first: int ;
  second: int }[@@deriving show]
let bar (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
      ~start_lnum:12 ~start_colnum:19 ~end_lnum:12 ~end_colnum:73
      ~message:"bar";
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : t]) x));
   (match let y : int =
            Debug_runtime.open_log_preamble_brief ~fname:"test_debug_show.ml"
              ~pos_lnum:12 ~pos_colnum:37 ~message:" ";
            (match (x.first + 1 : int) with
             | y__res ->
                 (Debug_runtime.log_value_show ~descr:"y"
                    ~v:(([%show : int]) y__res);
                  Debug_runtime.close_log ();
                  y__res)
             | exception e -> (Debug_runtime.close_log (); raise e)) in
          x.second * y
    with
    | bar__res ->
        (Debug_runtime.log_value_show ~descr:"bar"
           ~v:(([%show : int]) bar__res);
         Debug_runtime.close_log ();
         bar__res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : int)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
      ~start_lnum:15 ~start_colnum:19 ~end_lnum:16 ~end_colnum:67
      ~message:"baz";
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : t]) x));
   (match let (((y, z) as _yz) : (int * int)) =
            Debug_runtime.open_log_preamble_brief ~fname:"test_debug_show.ml"
              ~pos_lnum:16 ~pos_colnum:15 ~message:" ";
            (match ((x.first + 1), 3) with
             | _yz__res ->
                 (Debug_runtime.log_value_show ~descr:"_yz"
                    ~v:(([%show : (int * int)]) _yz__res);
                  Debug_runtime.close_log ();
                  _yz__res)
             | exception e -> (Debug_runtime.close_log (); raise e)) in
          (x.second * y) + z
    with
    | baz__res ->
        (Debug_runtime.log_value_show ~descr:"baz"
           ~v:(([%show : int]) baz__res);
         Debug_runtime.close_log ();
         baz__res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : int)
let () = ignore @@ (baz { first = 7; second = 42 })
let rec loop (depth : int) (x : t) =
  (((Debug_runtime.open_log_preamble_full ~fname:"test_debug_show.ml"
       ~start_lnum:19 ~start_colnum:24 ~end_lnum:25 ~end_colnum:9
       ~message:"loop";
     Debug_runtime.log_value_show ~descr:"depth" ~v:(([%show : int]) depth));
    Debug_runtime.log_value_show ~descr:"x" ~v:(([%show : t]) x));
   (match if depth > 6
          then x.first + x.second
          else
            if depth > 3
            then
              loop (depth + 1)
                { first = (x.second + 1); second = (x.first / 2) }
            else
              (let y : int =
                 Debug_runtime.open_log_preamble_brief
                   ~fname:"test_debug_show.ml" ~pos_lnum:23 ~pos_colnum:8
                   ~message:" ";
                 (match (loop (depth + 1)
                           { first = (x.second - 1); second = (x.first + 2) } : 
                    int)
                  with
                  | y__res ->
                      (Debug_runtime.log_value_show ~descr:"y"
                         ~v:(([%show : int]) y__res);
                       Debug_runtime.close_log ();
                       y__res)
                  | exception e -> (Debug_runtime.close_log (); raise e)) in
               let z : int =
                 Debug_runtime.open_log_preamble_brief
                   ~fname:"test_debug_show.ml" ~pos_lnum:24 ~pos_colnum:8
                   ~message:" ";
                 (match (loop (depth + 1)
                           { first = (x.second + 1); second = y } : int)
                  with
                  | z__res ->
                      (Debug_runtime.log_value_show ~descr:"z"
                         ~v:(([%show : int]) z__res);
                       Debug_runtime.close_log ();
                       z__res)
                  | exception e -> (Debug_runtime.close_log (); raise e)) in
               z + 7)
    with
    | loop__res ->
        (Debug_runtime.log_value_show ~descr:"loop"
           ~v:(([%show : int]) loop__res);
         Debug_runtime.close_log ();
         loop__res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : int)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
