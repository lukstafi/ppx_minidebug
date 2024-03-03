module Debug_runtime = (val
  Minidebug_runtime.debug_flushing ~filename:"debugger_show_flushing" ())
let foo (x : int) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:4
      ~start_colnum:19 ~end_lnum:6 ~end_colnum:17 ~message:"foo"
      ~entry_id:__entry_id;
    Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
      ~is_result:false (([%show : int]) x));
   (match let y : int =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:5
              ~start_colnum:6 ~end_lnum:5 ~end_colnum:7 ~message:"y"
              ~entry_id:__entry_id;
            (match x + 1 with
             | y as __res ->
                 ((();
                   Debug_runtime.log_value_show ?descr:(Some "y")
                     ~entry_id:__entry_id ~is_result:true (([%show : int]) y));
                  Debug_runtime.close_log ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~entry_id:__entry_id; raise e)) in
          [x; y; 2 * y]
    with
    | __res ->
        (Debug_runtime.log_value_show ?descr:(Some "foo")
           ~entry_id:__entry_id ~is_result:true (([%show : int list]) __res);
         Debug_runtime.close_log ~entry_id:__entry_id;
         __res)
    | exception e -> (Debug_runtime.close_log ~entry_id:__entry_id; raise e)) : 
  int list)
let () = ignore @@ (List.hd @@ (foo 7))
type t = {
  first: int ;
  second: int }[@@deriving show]
let bar (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:12
      ~start_colnum:19 ~end_lnum:14 ~end_colnum:14 ~message:"bar"
      ~entry_id:__entry_id;
    Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
      ~is_result:false (([%show : t]) x));
   (match let y : int =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:13
              ~start_colnum:6 ~end_lnum:13 ~end_colnum:7 ~message:"y"
              ~entry_id:__entry_id;
            (match x.first + 1 with
             | y as __res ->
                 ((();
                   Debug_runtime.log_value_show ?descr:(Some "y")
                     ~entry_id:__entry_id ~is_result:true (([%show : int]) y));
                  Debug_runtime.close_log ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~entry_id:__entry_id; raise e)) in
          x.second * y
    with
    | __res ->
        (Debug_runtime.log_value_show ?descr:(Some "bar")
           ~entry_id:__entry_id ~is_result:true (([%show : int]) __res);
         Debug_runtime.close_log ~entry_id:__entry_id;
         __res)
    | exception e -> (Debug_runtime.close_log ~entry_id:__entry_id; raise e)) : 
  int)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:18
      ~start_colnum:19 ~end_lnum:20 ~end_colnum:20 ~message:"baz"
      ~entry_id:__entry_id;
    Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
      ~is_result:false (([%show : t]) x));
   (match let (((y, z) as _yz) : (int * int)) =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:19
              ~start_colnum:17 ~end_lnum:19 ~end_colnum:20 ~message:"_yz"
              ~entry_id:__entry_id;
            (match ((x.first + 1), 3) with
             | _yz as __res ->
                 ((();
                   Debug_runtime.log_value_show ?descr:(Some "_yz")
                     ~entry_id:__entry_id ~is_result:true
                     (([%show : (int * int)]) _yz));
                  Debug_runtime.close_log ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~entry_id:__entry_id; raise e)) in
          (x.second * y) + z
    with
    | __res ->
        (Debug_runtime.log_value_show ?descr:(Some "baz")
           ~entry_id:__entry_id ~is_result:true (([%show : int]) __res);
         Debug_runtime.close_log ~entry_id:__entry_id;
         __res)
    | exception e -> (Debug_runtime.close_log ~entry_id:__entry_id; raise e)) : 
  int)
let () = ignore @@ (baz { first = 7; second = 42 })
let rec loop (depth : int) (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   ((Debug_runtime.open_log ~fname:"test_debug_show.ml" ~start_lnum:24
       ~start_colnum:24 ~end_lnum:30 ~end_colnum:9 ~message:"loop"
       ~entry_id:__entry_id;
     Debug_runtime.log_value_show ?descr:(Some "depth") ~entry_id:__entry_id
       ~is_result:false (([%show : int]) depth));
    Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
      ~is_result:false (([%show : t]) x));
   (match if depth > 6
          then x.first + x.second
          else
            if depth > 3
            then
              loop (depth + 1)
                { first = (x.second + 1); second = (x.first / 2) }
            else
              (let y : int =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 Debug_runtime.open_log ~fname:"test_debug_show.ml"
                   ~start_lnum:28 ~start_colnum:8 ~end_lnum:28 ~end_colnum:9
                   ~message:"y" ~entry_id:__entry_id;
                 (match loop (depth + 1)
                          { first = (x.second - 1); second = (x.first + 2) }
                  with
                  | y as __res ->
                      ((();
                        Debug_runtime.log_value_show ?descr:(Some "y")
                          ~entry_id:__entry_id ~is_result:true
                          (([%show : int]) y));
                       Debug_runtime.close_log ~entry_id:__entry_id;
                       __res)
                  | exception e ->
                      (Debug_runtime.close_log ~entry_id:__entry_id; raise e)) in
               let z : int =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 Debug_runtime.open_log ~fname:"test_debug_show.ml"
                   ~start_lnum:29 ~start_colnum:8 ~end_lnum:29 ~end_colnum:9
                   ~message:"z" ~entry_id:__entry_id;
                 (match loop (depth + 1)
                          { first = (x.second + 1); second = y }
                  with
                  | z as __res ->
                      ((();
                        Debug_runtime.log_value_show ?descr:(Some "z")
                          ~entry_id:__entry_id ~is_result:true
                          (([%show : int]) z));
                       Debug_runtime.close_log ~entry_id:__entry_id;
                       __res)
                  | exception e ->
                      (Debug_runtime.close_log ~entry_id:__entry_id; raise e)) in
               z + 7)
    with
    | __res ->
        (Debug_runtime.log_value_show ?descr:(Some "loop")
           ~entry_id:__entry_id ~is_result:true (([%show : int]) __res);
         Debug_runtime.close_log ~entry_id:__entry_id;
         __res)
    | exception e -> (Debug_runtime.close_log ~entry_id:__entry_id; raise e)) : 
  int)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
