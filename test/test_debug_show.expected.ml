let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_show" in fun () -> rt
let foo (x : int) =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:5
        ~start_colnum:19 ~end_lnum:7 ~end_colnum:17 ~message:"foo"
        ~scope_id:__scope_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~scope_id:__scope_id
        ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
     ();
     (match let y : int =
              let __scope_id = Debug_runtime.get_scope_id () in
              Debug_runtime.open_log ~fname:"test_debug_show.ml"
                ~start_lnum:6 ~start_colnum:6 ~end_lnum:6 ~end_colnum:7
                ~message:"y" ~scope_id:__scope_id ~log_level:1 `Debug;
              ();
              (match x + 1 with
               | y as __res ->
                   ((();
                     Debug_runtime.log_value_show ?descr:(Some "y")
                       ~scope_id:__scope_id ~log_level:1 ~is_result:true
                       (lazy (([%show : int]) y)));
                    Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:6 ~scope_id:__scope_id;
                    __res)
               | exception e ->
                   (Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:6 ~scope_id:__scope_id;
                    raise e)) in
            [x; y; 2 * y]
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "foo")
             ~scope_id:__scope_id ~log_level:1 ~is_result:true
             (lazy (([%show : int list]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:5
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:5
             ~scope_id:__scope_id;
           raise e)) : int list)
let () = ignore @@ (List.hd @@ (foo 7))
type t = {
  first: int ;
  second: int }[@@deriving show]
let bar (x : t) =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:13
        ~start_colnum:19 ~end_lnum:15 ~end_colnum:14 ~message:"bar"
        ~scope_id:__scope_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~scope_id:__scope_id
        ~log_level:1 ~is_result:false (lazy (([%show : t]) x)));
     ();
     (match let y : int =
              let __scope_id = Debug_runtime.get_scope_id () in
              Debug_runtime.open_log ~fname:"test_debug_show.ml"
                ~start_lnum:14 ~start_colnum:6 ~end_lnum:14 ~end_colnum:7
                ~message:"y" ~scope_id:__scope_id ~log_level:1 `Debug;
              ();
              (match x.first + 1 with
               | y as __res ->
                   ((();
                     Debug_runtime.log_value_show ?descr:(Some "y")
                       ~scope_id:__scope_id ~log_level:1 ~is_result:true
                       (lazy (([%show : int]) y)));
                    Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:14 ~scope_id:__scope_id;
                    __res)
               | exception e ->
                   (Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:14 ~scope_id:__scope_id;
                    raise e)) in
            x.second * y
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "bar")
             ~scope_id:__scope_id ~log_level:1 ~is_result:true
             (lazy (([%show : int]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:13
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:13
             ~scope_id:__scope_id;
           raise e)) : int)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:19
        ~start_colnum:19 ~end_lnum:21 ~end_colnum:20 ~message:"baz"
        ~scope_id:__scope_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~scope_id:__scope_id
        ~log_level:1 ~is_result:false (lazy (([%show : t]) x)));
     ();
     (match let ((y, z) as _yz) : (int * int) =
              let __scope_id = Debug_runtime.get_scope_id () in
              Debug_runtime.open_log ~fname:"test_debug_show.ml"
                ~start_lnum:20 ~start_colnum:17 ~end_lnum:20 ~end_colnum:20
                ~message:"_yz" ~scope_id:__scope_id ~log_level:1 `Debug;
              ();
              (match ((x.first + 1), 3) with
               | _yz as __res ->
                   ((();
                     Debug_runtime.log_value_show ?descr:(Some "_yz")
                       ~scope_id:__scope_id ~log_level:1 ~is_result:true
                       (lazy (([%show : (int * int)]) _yz)));
                    Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:20 ~scope_id:__scope_id;
                    __res)
               | exception e ->
                   (Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:20 ~scope_id:__scope_id;
                    raise e)) in
            (x.second * y) + z
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "baz")
             ~scope_id:__scope_id ~log_level:1 ~is_result:true
             (lazy (([%show : int]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:19
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:19
             ~scope_id:__scope_id;
           raise e)) : int)
let () = ignore @@ (baz { first = 7; second = 42 })
let rec loop (depth : int) (x : t) =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     ((Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:25
         ~start_colnum:24 ~end_lnum:31 ~end_colnum:9 ~message:"loop"
         ~scope_id:__scope_id ~log_level:1 `Debug;
       Debug_runtime.log_value_show ?descr:(Some "depth")
         ~scope_id:__scope_id ~log_level:1 ~is_result:false
         (lazy (([%show : int]) depth)));
      Debug_runtime.log_value_show ?descr:(Some "x") ~scope_id:__scope_id
        ~log_level:1 ~is_result:false (lazy (([%show : t]) x)));
     ();
     (match if depth > 6
            then x.first + x.second
            else
              if depth > 3
              then
                loop (depth + 1)
                  { first = (x.second + 1); second = (x.first / 2) }
              else
                (let y : int =
                   let __scope_id = Debug_runtime.get_scope_id () in
                   Debug_runtime.open_log ~fname:"test_debug_show.ml"
                     ~start_lnum:29 ~start_colnum:8 ~end_lnum:29
                     ~end_colnum:9 ~message:"y" ~scope_id:__scope_id
                     ~log_level:1 `Debug;
                   ();
                   (match loop (depth + 1)
                            { first = (x.second - 1); second = (x.first + 2)
                            }
                    with
                    | y as __res ->
                        ((();
                          Debug_runtime.log_value_show ?descr:(Some "y")
                            ~scope_id:__scope_id ~log_level:1 ~is_result:true
                            (lazy (([%show : int]) y)));
                         Debug_runtime.close_log ~fname:"test_debug_show.ml"
                           ~start_lnum:29 ~scope_id:__scope_id;
                         __res)
                    | exception e ->
                        (Debug_runtime.close_log ~fname:"test_debug_show.ml"
                           ~start_lnum:29 ~scope_id:__scope_id;
                         raise e)) in
                 let z : int =
                   let __scope_id = Debug_runtime.get_scope_id () in
                   Debug_runtime.open_log ~fname:"test_debug_show.ml"
                     ~start_lnum:30 ~start_colnum:8 ~end_lnum:30
                     ~end_colnum:9 ~message:"z" ~scope_id:__scope_id
                     ~log_level:1 `Debug;
                   ();
                   (match loop (depth + 1)
                            { first = (x.second + 1); second = y }
                    with
                    | z as __res ->
                        ((();
                          Debug_runtime.log_value_show ?descr:(Some "z")
                            ~scope_id:__scope_id ~log_level:1 ~is_result:true
                            (lazy (([%show : int]) z)));
                         Debug_runtime.close_log ~fname:"test_debug_show.ml"
                           ~start_lnum:30 ~scope_id:__scope_id;
                         __res)
                    | exception e ->
                        (Debug_runtime.close_log ~fname:"test_debug_show.ml"
                           ~start_lnum:30 ~scope_id:__scope_id;
                         raise e)) in
                 z + 7)
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "loop")
             ~scope_id:__scope_id ~log_level:1 ~is_result:true
             (lazy (([%show : int]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:25
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:25
             ~scope_id:__scope_id;
           raise e)) : int)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
let simple_thunk (x : string) () =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:38
        ~start_colnum:28 ~end_lnum:38 ~end_colnum:83 ~message:"simple_thunk"
        ~scope_id:__scope_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~scope_id:__scope_id
        ~log_level:1 ~is_result:false (lazy (([%show : string]) x)));
     ();
     (match print_endline x with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "simple_thunk")
             ~scope_id:__scope_id ~log_level:1 ~is_result:true
             (lazy (([%show : unit]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:38
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:38
             ~scope_id:__scope_id;
           raise e)) : unit)
let () = simple_thunk "hello" ()
let nested_fun (x : int) y =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:42
        ~start_colnum:26 ~end_lnum:42 ~end_colnum:75 ~message:"nested_fun"
        ~scope_id:__scope_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~scope_id:__scope_id
        ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
     ();
     (match ignore (x + y) with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "nested_fun")
             ~scope_id:__scope_id ~log_level:1 ~is_result:true
             (lazy (([%show : unit]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:42
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:42
             ~scope_id:__scope_id;
           raise e)) : unit)
let () = nested_fun 5 10
let cascade (x : int) y z =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:46
        ~start_colnum:23 ~end_lnum:46 ~end_colnum:82 ~message:"cascade"
        ~scope_id:__scope_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~scope_id:__scope_id
        ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
     ();
     (match (x + y) + z with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "cascade")
             ~scope_id:__scope_id ~log_level:1 ~is_result:true
             (lazy (([%show : int]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:46
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:46
             ~scope_id:__scope_id;
           raise e)) : int)
let () = ignore @@ (cascade 1 2 3)
let parallel_update (x : int) (y : int) =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     ((Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:50
         ~start_colnum:31 ~end_lnum:52 ~end_colnum:28
         ~message:"parallel_update" ~scope_id:__scope_id ~log_level:1 `Debug;
       Debug_runtime.log_value_show ?descr:(Some "x") ~scope_id:__scope_id
         ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
      Debug_runtime.log_value_show ?descr:(Some "y") ~scope_id:__scope_id
        ~log_level:1 ~is_result:false (lazy (([%show : int]) y)));
     ();
     (match let result = x + y in fun () -> print_int result with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "parallel_update")
             ~scope_id:__scope_id ~log_level:1 ~is_result:true
             (lazy (([%show : unit -> unit]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:50
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:50
             ~scope_id:__scope_id;
           raise e)) : unit -> unit)
let () = parallel_update 10 20 ()
let complex_case (type buffer_ptr) (x : int) (y : buffer_ptr -> int) =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     ((Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:57
         ~start_colnum:28 ~end_lnum:60 ~end_colnum:29 ~message:"complex_case"
         ~scope_id:__scope_id ~log_level:1 `Debug;
       Debug_runtime.log_value_show ?descr:(Some "x") ~scope_id:__scope_id
         ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
      Debug_runtime.log_value_show ?descr:(Some "y") ~scope_id:__scope_id
        ~log_level:1 ~is_result:false
        (lazy (([%show : buffer_ptr -> int]) y)));
     ();
     (match let compute = x + (y (Obj.magic 0)) in
            fun () -> print_int compute
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "complex_case")
             ~scope_id:__scope_id ~log_level:1 ~is_result:true
             (lazy (([%show : unit -> unit]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:57
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:57
             ~scope_id:__scope_id;
           raise e)) : unit -> unit)
let () = complex_case 5 (fun _ -> 10) ()
