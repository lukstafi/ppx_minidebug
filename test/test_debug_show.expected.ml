let _get_local_debug_runtime =
  Minidebug_runtime.local_runtime_flushing "debugger_show_flushing"
let foo (x : int) =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    (let __entry_id = Debug_runtime.get_entry_id () in
     ();
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:4
        ~start_colnum:19 ~end_lnum:6 ~end_colnum:17 ~message:"foo"
        ~entry_id:__entry_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
        ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
     (match let y =
              let __entry_id = Debug_runtime.get_entry_id () in
              ();
              Debug_runtime.open_log ~fname:"test_debug_show.ml"
                ~start_lnum:5 ~start_colnum:6 ~end_lnum:5 ~end_colnum:7
                ~message:"y" ~entry_id:__entry_id ~log_level:1 `Debug;
              (match x + 1 with
               | y as __res ->
                   ((();
                     Debug_runtime.log_value_show ?descr:(Some "y")
                       ~entry_id:__entry_id ~log_level:1 ~is_result:true
                       (lazy (([%show : int]) y)));
                    Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:5 ~entry_id:__entry_id;
                    __res)
               | exception e ->
                   (Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:5 ~entry_id:__entry_id;
                    raise e)) in
            [x; y; 2 * y]
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "foo")
             ~entry_id:__entry_id ~log_level:1 ~is_result:true
             (lazy (([%show : int list]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:4
             ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:4
             ~entry_id:__entry_id;
           raise e)) : int list)
let () = ignore @@ (List.hd @@ (foo 7))
type t = {
  first: int ;
  second: int }[@@deriving show]
let bar (x : t) =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    (let __entry_id = Debug_runtime.get_entry_id () in
     ();
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:12
        ~start_colnum:19 ~end_lnum:14 ~end_colnum:14 ~message:"bar"
        ~entry_id:__entry_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
        ~log_level:1 ~is_result:false (lazy (([%show : t]) x)));
     (match let y =
              let __entry_id = Debug_runtime.get_entry_id () in
              ();
              Debug_runtime.open_log ~fname:"test_debug_show.ml"
                ~start_lnum:13 ~start_colnum:6 ~end_lnum:13 ~end_colnum:7
                ~message:"y" ~entry_id:__entry_id ~log_level:1 `Debug;
              (match x.first + 1 with
               | y as __res ->
                   ((();
                     Debug_runtime.log_value_show ?descr:(Some "y")
                       ~entry_id:__entry_id ~log_level:1 ~is_result:true
                       (lazy (([%show : int]) y)));
                    Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:13 ~entry_id:__entry_id;
                    __res)
               | exception e ->
                   (Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:13 ~entry_id:__entry_id;
                    raise e)) in
            x.second * y
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "bar")
             ~entry_id:__entry_id ~log_level:1 ~is_result:true
             (lazy (([%show : int]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:12
             ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:12
             ~entry_id:__entry_id;
           raise e)) : int)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    (let __entry_id = Debug_runtime.get_entry_id () in
     ();
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:18
        ~start_colnum:19 ~end_lnum:20 ~end_colnum:20 ~message:"baz"
        ~entry_id:__entry_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
        ~log_level:1 ~is_result:false (lazy (([%show : t]) x)));
     (match let (y, z) as _yz =
              let __entry_id = Debug_runtime.get_entry_id () in
              ();
              Debug_runtime.open_log ~fname:"test_debug_show.ml"
                ~start_lnum:19 ~start_colnum:17 ~end_lnum:19 ~end_colnum:20
                ~message:"_yz" ~entry_id:__entry_id ~log_level:1 `Debug;
              (match ((x.first + 1), 3) with
               | _yz as __res ->
                   ((();
                     Debug_runtime.log_value_show ?descr:(Some "_yz")
                       ~entry_id:__entry_id ~log_level:1 ~is_result:true
                       (lazy (([%show : (int * int)]) _yz)));
                    Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:19 ~entry_id:__entry_id;
                    __res)
               | exception e ->
                   (Debug_runtime.close_log ~fname:"test_debug_show.ml"
                      ~start_lnum:19 ~entry_id:__entry_id;
                    raise e)) in
            (x.second * y) + z
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "baz")
             ~entry_id:__entry_id ~log_level:1 ~is_result:true
             (lazy (([%show : int]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:18
             ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:18
             ~entry_id:__entry_id;
           raise e)) : int)
let () = ignore @@ (baz { first = 7; second = 42 })
let rec loop (depth : int) (x : t) =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    (let __entry_id = Debug_runtime.get_entry_id () in
     ();
     ((Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:24
         ~start_colnum:24 ~end_lnum:30 ~end_colnum:9 ~message:"loop"
         ~entry_id:__entry_id ~log_level:1 `Debug;
       Debug_runtime.log_value_show ?descr:(Some "depth")
         ~entry_id:__entry_id ~log_level:1 ~is_result:false
         (lazy (([%show : int]) depth)));
      Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
        ~log_level:1 ~is_result:false (lazy (([%show : t]) x)));
     (match if depth > 6
            then x.first + x.second
            else
              if depth > 3
              then
                loop (depth + 1)
                  { first = (x.second + 1); second = (x.first / 2) }
              else
                (let y =
                   let __entry_id = Debug_runtime.get_entry_id () in
                   ();
                   Debug_runtime.open_log ~fname:"test_debug_show.ml"
                     ~start_lnum:28 ~start_colnum:8 ~end_lnum:28
                     ~end_colnum:9 ~message:"y" ~entry_id:__entry_id
                     ~log_level:1 `Debug;
                   (match loop (depth + 1)
                            { first = (x.second - 1); second = (x.first + 2)
                            }
                    with
                    | y as __res ->
                        ((();
                          Debug_runtime.log_value_show ?descr:(Some "y")
                            ~entry_id:__entry_id ~log_level:1 ~is_result:true
                            (lazy (([%show : int]) y)));
                         Debug_runtime.close_log ~fname:"test_debug_show.ml"
                           ~start_lnum:28 ~entry_id:__entry_id;
                         __res)
                    | exception e ->
                        (Debug_runtime.close_log ~fname:"test_debug_show.ml"
                           ~start_lnum:28 ~entry_id:__entry_id;
                         raise e)) in
                 let z =
                   let __entry_id = Debug_runtime.get_entry_id () in
                   ();
                   Debug_runtime.open_log ~fname:"test_debug_show.ml"
                     ~start_lnum:29 ~start_colnum:8 ~end_lnum:29
                     ~end_colnum:9 ~message:"z" ~entry_id:__entry_id
                     ~log_level:1 `Debug;
                   (match loop (depth + 1)
                            { first = (x.second + 1); second = y }
                    with
                    | z as __res ->
                        ((();
                          Debug_runtime.log_value_show ?descr:(Some "z")
                            ~entry_id:__entry_id ~log_level:1 ~is_result:true
                            (lazy (([%show : int]) z)));
                         Debug_runtime.close_log ~fname:"test_debug_show.ml"
                           ~start_lnum:29 ~entry_id:__entry_id;
                         __res)
                    | exception e ->
                        (Debug_runtime.close_log ~fname:"test_debug_show.ml"
                           ~start_lnum:29 ~entry_id:__entry_id;
                         raise e)) in
                 z + 7)
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "loop")
             ~entry_id:__entry_id ~log_level:1 ~is_result:true
             (lazy (([%show : int]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:24
             ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:24
             ~entry_id:__entry_id;
           raise e)) : int)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
let simple_thunk (x : string) () =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    (let __entry_id = Debug_runtime.get_entry_id () in
     ();
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:37
        ~start_colnum:28 ~end_lnum:37 ~end_colnum:83 ~message:"simple_thunk"
        ~entry_id:__entry_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
        ~log_level:1 ~is_result:false (lazy (([%show : string]) x)));
     (match print_endline x with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "simple_thunk")
             ~entry_id:__entry_id ~log_level:1 ~is_result:true
             (lazy (([%show : unit]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:37
             ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:37
             ~entry_id:__entry_id;
           raise e)) : unit)
let () = simple_thunk "hello" ()
let nested_fun (x : int) y =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    (let __entry_id = Debug_runtime.get_entry_id () in
     ();
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:42
        ~start_colnum:26 ~end_lnum:42 ~end_colnum:75 ~message:"nested_fun"
        ~entry_id:__entry_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
        ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
     (match ignore (x + y) with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "nested_fun")
             ~entry_id:__entry_id ~log_level:1 ~is_result:true
             (lazy (([%show : unit]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:42
             ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:42
             ~entry_id:__entry_id;
           raise e)) : unit)
let () = nested_fun 5 10
let cascade (x : int) y z =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    (let __entry_id = Debug_runtime.get_entry_id () in
     ();
     (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:47
        ~start_colnum:23 ~end_lnum:47 ~end_colnum:82 ~message:"cascade"
        ~entry_id:__entry_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
        ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
     (match (x + y) + z with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "cascade")
             ~entry_id:__entry_id ~log_level:1 ~is_result:true
             (lazy (([%show : int]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:47
             ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:47
             ~entry_id:__entry_id;
           raise e)) : int)
let () = ignore @@ (cascade 1 2 3)
let parallel_update (x : int) (y : int) =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    (let __entry_id = Debug_runtime.get_entry_id () in
     ();
     ((Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:52
         ~start_colnum:31 ~end_lnum:54 ~end_colnum:28
         ~message:"parallel_update" ~entry_id:__entry_id ~log_level:1 `Debug;
       Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
         ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
      Debug_runtime.log_value_show ?descr:(Some "y") ~entry_id:__entry_id
        ~log_level:1 ~is_result:false (lazy (([%show : int]) y)));
     (match let result = x + y in fun () -> print_int result with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "parallel_update")
             ~entry_id:__entry_id ~log_level:1 ~is_result:true
             (lazy (([%show : unit -> unit]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:52
             ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:52
             ~entry_id:__entry_id;
           raise e)) : unit -> unit)
let () = parallel_update 10 20 ()
let complex_case (type buffer_ptr) (x : int) (y : buffer_ptr -> int) =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    (let __entry_id = Debug_runtime.get_entry_id () in
     ();
     ((Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:59
         ~start_colnum:28 ~end_lnum:61 ~end_colnum:29 ~message:"complex_case"
         ~entry_id:__entry_id ~log_level:1 `Debug;
       Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
         ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
      Debug_runtime.log_value_show ?descr:(Some "y") ~entry_id:__entry_id
        ~log_level:1 ~is_result:false
        (lazy (([%show : buffer_ptr -> int]) y)));
     (match let compute = x + (y (Obj.magic 0)) in
            fun () -> print_int compute
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "complex_case")
             ~entry_id:__entry_id ~log_level:1 ~is_result:true
             (lazy (([%show : unit -> unit]) __res));
           Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:59
             ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log ~fname:"test_debug_show.ml" ~start_lnum:59
             ~entry_id:__entry_id;
           raise e)) : unit -> unit)
let () = complex_case 5 (fun _ -> 10) ()
