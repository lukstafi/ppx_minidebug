module Debug_runtime =
  (Minidebug_runtime.Format)(struct
                               let v = "../../../debugger_pp_format.log"
                             end)
type t = {
  first: int ;
  second: int }[@@deriving show]
type num = int[@@deriving show]
let bar (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_pp.ml"
      ~start_lnum:4 ~start_colnum:17 ~end_lnum:4 ~end_colnum:71
      ~message:"bar";
    Debug_runtime.log_value_pp ~descr:"x" ~pp ~v:x);
   (let bar__res = let y : num = x.first + 1 in x.second * y in
    Debug_runtime.log_value_pp ~descr:"bar" ~pp:pp_num ~v:bar__res;
    Debug_runtime.close_log ();
    bar__res) : num)
let () = print_endline @@ (Int.to_string @@ (bar { first = 7; second = 42 }))
let baz (x : t) =
  ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_pp.ml"
      ~start_lnum:8 ~start_colnum:17 ~end_lnum:9 ~end_colnum:89
      ~message:"baz";
    Debug_runtime.log_value_pp ~descr:"x" ~pp ~v:x);
   (let baz__res =
      let (({ first = y; second = z } as _yz) : t) =
        { first = (x.first + 1); second = 3 } in
      (x.second * y) + z in
    Debug_runtime.log_value_pp ~descr:"baz" ~pp:pp_num ~v:baz__res;
    Debug_runtime.close_log ();
    baz__res) : num)
let () = print_endline @@ (Int.to_string @@ (baz { first = 7; second = 42 }))
let rec loop (depth : num) (x : t) =
  (((Debug_runtime.open_log_preamble_full ~fname:"test_debug_pp.ml"
       ~start_lnum:12 ~start_colnum:22 ~end_lnum:18 ~end_colnum:9
       ~message:"loop";
     Debug_runtime.log_value_pp ~descr:"depth" ~pp:pp_num ~v:depth);
    Debug_runtime.log_value_pp ~descr:"x" ~pp ~v:x);
   (let loop__res =
      if depth > 6
      then x.first + x.second
      else
        if depth > 3
        then
          loop (depth + 1) { first = (x.second + 1); second = (x.first / 2) }
        else
          (let y : num =
             Debug_runtime.open_log_preamble_brief ~fname:"test_debug_pp.ml"
               ~pos_lnum:16 ~pos_colnum:8 ~message:" ";
             (let y__res =
                (loop (depth + 1)
                   { first = (x.second - 1); second = (x.first + 2) } : 
                num) in
              Debug_runtime.log_value_pp ~descr:"y" ~pp:pp_num ~v:y__res;
              Debug_runtime.close_log ();
              y__res) in
           let z : num =
             Debug_runtime.open_log_preamble_brief ~fname:"test_debug_pp.ml"
               ~pos_lnum:17 ~pos_colnum:8 ~message:" ";
             (let z__res =
                (loop (depth + 1) { first = (x.second + 1); second = y } : 
                num) in
              Debug_runtime.log_value_pp ~descr:"z" ~pp:pp_num ~v:z__res;
              Debug_runtime.close_log ();
              z__res) in
           z + 7) in
    Debug_runtime.log_value_pp ~descr:"loop" ~pp:pp_num ~v:loop__res;
    Debug_runtime.close_log ();
    loop__res) : num)
let () =
  print_endline @@ (Int.to_string @@ (loop 0 { first = 7; second = 42 }))
