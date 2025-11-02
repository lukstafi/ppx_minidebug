let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_pp" in fun () -> rt
type t = {
  first: int ;
  second: int }[@@deriving show]
type num = int[@@deriving show]
let bar (x : t) =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     (Debug_runtime.open_log ~fname:"test_debug_pp.ml" ~start_lnum:8
        ~start_colnum:17 ~end_lnum:10 ~end_colnum:14 ~message:"bar"
        ~scope_id:__scope_id ~log_level:1 `Debug;
      Debug_runtime.log_value_pp ?descr:(Some "x") ~scope_id:__scope_id
        ~log_level:1 ~pp ~is_result:false (lazy x));
     ();
     (match let y : num =
              let __scope_id = Debug_runtime.get_scope_id () in
              Debug_runtime.open_log ~fname:"test_debug_pp.ml" ~start_lnum:9
                ~start_colnum:6 ~end_lnum:9 ~end_colnum:7 ~message:"y"
                ~scope_id:__scope_id ~log_level:1 `Debug;
              ();
              (match x.first + 1 with
               | y as __res ->
                   ((();
                     Debug_runtime.log_value_pp ?descr:(Some "y")
                       ~scope_id:__scope_id ~log_level:1 ~pp:pp_num
                       ~is_result:true (lazy y));
                    Debug_runtime.close_log ~fname:"test_debug_pp.ml"
                      ~start_lnum:9 ~scope_id:__scope_id;
                    __res)
               | exception e ->
                   (Debug_runtime.log_exception ~scope_id:__scope_id
                      ~log_level:1 e;
                    Debug_runtime.close_log ~fname:"test_debug_pp.ml"
                      ~start_lnum:9 ~scope_id:__scope_id;
                    raise e)) in
            x.second * y
      with
      | __res ->
          (Debug_runtime.log_value_pp ?descr:(Some "bar")
             ~scope_id:__scope_id ~log_level:1 ~pp:pp_num ~is_result:true
             (lazy __res);
           Debug_runtime.close_log ~fname:"test_debug_pp.ml" ~start_lnum:8
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.log_exception ~scope_id:__scope_id ~log_level:1 e;
           Debug_runtime.close_log ~fname:"test_debug_pp.ml" ~start_lnum:8
             ~scope_id:__scope_id;
           raise e)) : num)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     (Debug_runtime.open_log ~fname:"test_debug_pp.ml" ~start_lnum:14
        ~start_colnum:17 ~end_lnum:16 ~end_colnum:20 ~message:"baz"
        ~scope_id:__scope_id ~log_level:1 `Debug;
      Debug_runtime.log_value_pp ?descr:(Some "x") ~scope_id:__scope_id
        ~log_level:1 ~pp ~is_result:false (lazy x));
     ();
     (match let ({ first = y; second = z } as _yz) : t =
              let __scope_id = Debug_runtime.get_scope_id () in
              Debug_runtime.open_log ~fname:"test_debug_pp.ml" ~start_lnum:15
                ~start_colnum:36 ~end_lnum:15 ~end_colnum:39 ~message:"_yz"
                ~scope_id:__scope_id ~log_level:1 `Debug;
              ();
              (match { first = (x.first + 1); second = 3 } with
               | _yz as __res ->
                   ((();
                     Debug_runtime.log_value_pp ?descr:(Some "_yz")
                       ~scope_id:__scope_id ~log_level:1 ~pp ~is_result:true
                       (lazy _yz));
                    Debug_runtime.close_log ~fname:"test_debug_pp.ml"
                      ~start_lnum:15 ~scope_id:__scope_id;
                    __res)
               | exception e ->
                   (Debug_runtime.log_exception ~scope_id:__scope_id
                      ~log_level:1 e;
                    Debug_runtime.close_log ~fname:"test_debug_pp.ml"
                      ~start_lnum:15 ~scope_id:__scope_id;
                    raise e)) in
            (x.second * y) + z
      with
      | __res ->
          (Debug_runtime.log_value_pp ?descr:(Some "baz")
             ~scope_id:__scope_id ~log_level:1 ~pp:pp_num ~is_result:true
             (lazy __res);
           Debug_runtime.close_log ~fname:"test_debug_pp.ml" ~start_lnum:14
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.log_exception ~scope_id:__scope_id ~log_level:1 e;
           Debug_runtime.close_log ~fname:"test_debug_pp.ml" ~start_lnum:14
             ~scope_id:__scope_id;
           raise e)) : num)
let () = ignore @@ (baz { first = 7; second = 42 })
let rec loop (depth : num) (x : t) =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     ((Debug_runtime.open_log ~fname:"test_debug_pp.ml" ~start_lnum:20
         ~start_colnum:22 ~end_lnum:26 ~end_colnum:9 ~message:"loop"
         ~scope_id:__scope_id ~log_level:1 `Debug;
       Debug_runtime.log_value_pp ?descr:(Some "depth") ~scope_id:__scope_id
         ~log_level:1 ~pp:pp_num ~is_result:false (lazy depth));
      Debug_runtime.log_value_pp ?descr:(Some "x") ~scope_id:__scope_id
        ~log_level:1 ~pp ~is_result:false (lazy x));
     ();
     (match if depth > 6
            then x.first + x.second
            else
              if depth > 3
              then
                loop (depth + 1)
                  { first = (x.second + 1); second = (x.first / 2) }
              else
                (let y : num =
                   let __scope_id = Debug_runtime.get_scope_id () in
                   Debug_runtime.open_log ~fname:"test_debug_pp.ml"
                     ~start_lnum:24 ~start_colnum:8 ~end_lnum:24
                     ~end_colnum:9 ~message:"y" ~scope_id:__scope_id
                     ~log_level:1 `Debug;
                   ();
                   (match loop (depth + 1)
                            { first = (x.second - 1); second = (x.first + 2)
                            }
                    with
                    | y as __res ->
                        ((();
                          Debug_runtime.log_value_pp ?descr:(Some "y")
                            ~scope_id:__scope_id ~log_level:1 ~pp:pp_num
                            ~is_result:true (lazy y));
                         Debug_runtime.close_log ~fname:"test_debug_pp.ml"
                           ~start_lnum:24 ~scope_id:__scope_id;
                         __res)
                    | exception e ->
                        (Debug_runtime.log_exception ~scope_id:__scope_id
                           ~log_level:1 e;
                         Debug_runtime.close_log ~fname:"test_debug_pp.ml"
                           ~start_lnum:24 ~scope_id:__scope_id;
                         raise e)) in
                 let z : num =
                   let __scope_id = Debug_runtime.get_scope_id () in
                   Debug_runtime.open_log ~fname:"test_debug_pp.ml"
                     ~start_lnum:25 ~start_colnum:8 ~end_lnum:25
                     ~end_colnum:9 ~message:"z" ~scope_id:__scope_id
                     ~log_level:1 `Debug;
                   ();
                   (match loop (depth + 1)
                            { first = (x.second + 1); second = y }
                    with
                    | z as __res ->
                        ((();
                          Debug_runtime.log_value_pp ?descr:(Some "z")
                            ~scope_id:__scope_id ~log_level:1 ~pp:pp_num
                            ~is_result:true (lazy z));
                         Debug_runtime.close_log ~fname:"test_debug_pp.ml"
                           ~start_lnum:25 ~scope_id:__scope_id;
                         __res)
                    | exception e ->
                        (Debug_runtime.log_exception ~scope_id:__scope_id
                           ~log_level:1 e;
                         Debug_runtime.close_log ~fname:"test_debug_pp.ml"
                           ~start_lnum:25 ~scope_id:__scope_id;
                         raise e)) in
                 z + 7)
      with
      | __res ->
          (Debug_runtime.log_value_pp ?descr:(Some "loop")
             ~scope_id:__scope_id ~log_level:1 ~pp:pp_num ~is_result:true
             (lazy __res);
           Debug_runtime.close_log ~fname:"test_debug_pp.ml" ~start_lnum:20
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.log_exception ~scope_id:__scope_id ~log_level:1 e;
           Debug_runtime.close_log ~fname:"test_debug_pp.ml" ~start_lnum:20
             ~scope_id:__scope_id;
           raise e)) : num)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
