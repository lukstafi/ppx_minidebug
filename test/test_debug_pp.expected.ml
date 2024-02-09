module Debug_runtime = (Minidebug_runtime.Pp_format)((val
  Minidebug_runtime.debug_ch "debugger_pp_format.log"))
type t = {
  first: int ;
  second: int }[@@deriving show]
type num = int[@@deriving show]
let bar (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log_preamble_full ~fname:"test_debug_pp.ml"
      ~start_lnum:7 ~start_colnum:17 ~end_lnum:9 ~end_colnum:14
      ~message:"bar" ~entry_id:__entry_id;
    Debug_runtime.log_value_pp ?descr:(Some "x") ~entry_id:__entry_id ~pp
      ~is_result:false x);
   (match let y : num =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log_preamble_brief ~fname:"test_debug_pp.ml"
              ~pos_lnum:8 ~pos_colnum:6 ~message:"y" ~entry_id:__entry_id;
            (match x.first + 1 with
             | y as __res ->
                 ((();
                   Debug_runtime.log_value_pp ?descr:(Some "y")
                     ~entry_id:__entry_id ~pp:pp_num ~is_result:true y);
                  Debug_runtime.close_log ();
                  __res)
             | exception e -> (Debug_runtime.close_log (); raise e)) in
          x.second * y
    with
    | __res ->
        (Debug_runtime.log_value_pp ?descr:(Some "bar") ~entry_id:__entry_id
           ~pp:pp_num ~is_result:true __res;
         Debug_runtime.close_log ();
         __res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : num)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log_preamble_full ~fname:"test_debug_pp.ml"
      ~start_lnum:13 ~start_colnum:17 ~end_lnum:15 ~end_colnum:20
      ~message:"baz" ~entry_id:__entry_id;
    Debug_runtime.log_value_pp ?descr:(Some "x") ~entry_id:__entry_id ~pp
      ~is_result:false x);
   (match let (({ first = y; second = z } as _yz) : t) =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log_preamble_brief ~fname:"test_debug_pp.ml"
              ~pos_lnum:14 ~pos_colnum:36 ~message:"_yz" ~entry_id:__entry_id;
            (match { first = (x.first + 1); second = 3 } with
             | _yz as __res ->
                 ((();
                   Debug_runtime.log_value_pp ?descr:(Some "_yz")
                     ~entry_id:__entry_id ~pp ~is_result:true _yz);
                  Debug_runtime.close_log ();
                  __res)
             | exception e -> (Debug_runtime.close_log (); raise e)) in
          (x.second * y) + z
    with
    | __res ->
        (Debug_runtime.log_value_pp ?descr:(Some "baz") ~entry_id:__entry_id
           ~pp:pp_num ~is_result:true __res;
         Debug_runtime.close_log ();
         __res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : num)
let () = ignore @@ (baz { first = 7; second = 42 })
let rec loop (depth : num) (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   ((Debug_runtime.open_log_preamble_full ~fname:"test_debug_pp.ml"
       ~start_lnum:19 ~start_colnum:22 ~end_lnum:25 ~end_colnum:9
       ~message:"loop" ~entry_id:__entry_id;
     Debug_runtime.log_value_pp ?descr:(Some "depth") ~entry_id:__entry_id
       ~pp:pp_num ~is_result:false depth);
    Debug_runtime.log_value_pp ?descr:(Some "x") ~entry_id:__entry_id ~pp
      ~is_result:false x);
   (match if depth > 6
          then x.first + x.second
          else
            if depth > 3
            then
              loop (depth + 1)
                { first = (x.second + 1); second = (x.first / 2) }
            else
              (let y : num =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 Debug_runtime.open_log_preamble_brief
                   ~fname:"test_debug_pp.ml" ~pos_lnum:23 ~pos_colnum:8
                   ~message:"y" ~entry_id:__entry_id;
                 (match loop (depth + 1)
                          { first = (x.second - 1); second = (x.first + 2) }
                  with
                  | y as __res ->
                      ((();
                        Debug_runtime.log_value_pp ?descr:(Some "y")
                          ~entry_id:__entry_id ~pp:pp_num ~is_result:true y);
                       Debug_runtime.close_log ();
                       __res)
                  | exception e -> (Debug_runtime.close_log (); raise e)) in
               let z : num =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 Debug_runtime.open_log_preamble_brief
                   ~fname:"test_debug_pp.ml" ~pos_lnum:24 ~pos_colnum:8
                   ~message:"z" ~entry_id:__entry_id;
                 (match loop (depth + 1)
                          { first = (x.second + 1); second = y }
                  with
                  | z as __res ->
                      ((();
                        Debug_runtime.log_value_pp ?descr:(Some "z")
                          ~entry_id:__entry_id ~pp:pp_num ~is_result:true z);
                       Debug_runtime.close_log ();
                       __res)
                  | exception e -> (Debug_runtime.close_log (); raise e)) in
               z + 7)
    with
    | __res ->
        (Debug_runtime.log_value_pp ?descr:(Some "loop") ~entry_id:__entry_id
           ~pp:pp_num ~is_result:true __res;
         Debug_runtime.close_log ();
         __res)
    | exception e -> (Debug_runtime.close_log (); raise e)) : num)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
