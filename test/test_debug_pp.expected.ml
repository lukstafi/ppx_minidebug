module Debug_runtime = (Minidebug_runtime.Pp_format)((val
  Minidebug_runtime.debug_ch "debugger_pp_format.log"))
type t = {
  first: int ;
  second: int }[@@deriving show]
type num = int[@@deriving show]
let bar (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_pp.ml"
      ~start_lnum:7 ~start_colnum:17 ~end_lnum:9 ~end_colnum:14
      ~message:"bar";
    Debug_runtime.log_value_pp ~descr:"x" ~pp ~v:x);
   (match let y : num =
            Debug_runtime.open_log_preamble_brief ~fname:"test_debug_pp.ml"
              ~pos_lnum:8 ~pos_colnum:6 ~message:" ";
            (match (x.first + 1 : num) with
             | y__res ->
                 (Debug_runtime.log_value_pp ~descr:"y" ~pp:pp_num ~v:y__res;
                  Debug_runtime.close_log ();
                  y__res)
             | exception e -> (Debug_runtime.close_log (); raise e)) in
          x.second * y
    with
    | bar__res ->
        (Debug_runtime.log_value_pp ~descr:"bar" ~pp:pp_num ~v:bar__res;
         Debug_runtime.close_log ();
         bar__res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : num)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_pp.ml"
      ~start_lnum:13 ~start_colnum:17 ~end_lnum:15 ~end_colnum:20
      ~message:"baz";
    Debug_runtime.log_value_pp ~descr:"x" ~pp ~v:x);
   (match let (({ first = y; second = z } as _yz) : t) =
            Debug_runtime.open_log_preamble_brief ~fname:"test_debug_pp.ml"
              ~pos_lnum:14 ~pos_colnum:36 ~message:" ";
            (match { first = (x.first + 1); second = 3 } with
             | _yz__res ->
                 (Debug_runtime.log_value_pp ~descr:"_yz" ~pp ~v:_yz__res;
                  Debug_runtime.close_log ();
                  _yz__res)
             | exception e -> (Debug_runtime.close_log (); raise e)) in
          (x.second * y) + z
    with
    | baz__res ->
        (Debug_runtime.log_value_pp ~descr:"baz" ~pp:pp_num ~v:baz__res;
         Debug_runtime.close_log ();
         baz__res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : num)
let () = ignore @@ (baz { first = 7; second = 42 })
let rec loop (depth : num) (x : t) =
  (((Debug_runtime.open_log_preamble_full ~fname:"test_debug_pp.ml"
       ~start_lnum:19 ~start_colnum:22 ~end_lnum:25 ~end_colnum:9
       ~message:"loop";
     Debug_runtime.log_value_pp ~descr:"depth" ~pp:pp_num ~v:depth);
    Debug_runtime.log_value_pp ~descr:"x" ~pp ~v:x);
   (match if depth > 6
          then x.first + x.second
          else
            if depth > 3
            then
              loop (depth + 1)
                { first = (x.second + 1); second = (x.first / 2) }
            else
              (let y : num =
                 Debug_runtime.open_log_preamble_brief
                   ~fname:"test_debug_pp.ml" ~pos_lnum:23 ~pos_colnum:8
                   ~message:" ";
                 (match (loop (depth + 1)
                           { first = (x.second - 1); second = (x.first + 2) } : 
                    num)
                  with
                  | y__res ->
                      (Debug_runtime.log_value_pp ~descr:"y" ~pp:pp_num
                         ~v:y__res;
                       Debug_runtime.close_log ();
                       y__res)
                  | exception e -> (Debug_runtime.close_log (); raise e)) in
               let z : num =
                 Debug_runtime.open_log_preamble_brief
                   ~fname:"test_debug_pp.ml" ~pos_lnum:24 ~pos_colnum:8
                   ~message:" ";
                 (match (loop (depth + 1)
                           { first = (x.second + 1); second = y } : num)
                  with
                  | z__res ->
                      (Debug_runtime.log_value_pp ~descr:"z" ~pp:pp_num
                         ~v:z__res;
                       Debug_runtime.close_log ();
                       z__res)
                  | exception e -> (Debug_runtime.close_log (); raise e)) in
               z + 7)
    with
    | loop__res ->
        (Debug_runtime.log_value_pp ~descr:"loop" ~pp:pp_num ~v:loop__res;
         Debug_runtime.close_log ();
         loop__res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : num)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
