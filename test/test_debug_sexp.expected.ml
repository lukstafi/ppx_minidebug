open Sexplib0.Sexp_conv
module Debug_runtime = (Minidebug_runtime.PrintBox)((val
  Minidebug_runtime.shared_config "debugger_sexp_printbox.log"))
let () = Debug_runtime.config.values_first_mode <- false
let foo (x : int) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:9
      ~start_colnum:21 ~end_lnum:11 ~end_colnum:17 ~message:"foo"
      ~entry_id:__entry_id ~log_level:1 `Debug;
    Debug_runtime.log_value_sexp ?descr:(Some "x") ~entry_id:__entry_id
      ~log_level:1 ~is_result:false (lazy (([%sexp_of : int]) x)));
   (match let y : int =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:10
              ~start_colnum:6 ~end_lnum:10 ~end_colnum:7 ~message:"y"
              ~entry_id:__entry_id ~log_level:1 `Debug;
            (match x + 1 with
             | y as __res ->
                 ((();
                   Debug_runtime.log_value_sexp ?descr:(Some "y")
                     ~entry_id:__entry_id ~log_level:1 ~is_result:true
                     (lazy (([%sexp_of : int]) y)));
                  Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:10 ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:10 ~entry_id:__entry_id;
                  raise e)) in
          [x; y; 2 * y]
    with
    | __res ->
        (Debug_runtime.log_value_sexp ?descr:(Some "foo")
           ~entry_id:__entry_id ~log_level:1 ~is_result:true
           (lazy (([%sexp_of : int list]) __res));
         Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:9
           ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:9
           ~entry_id:__entry_id;
         raise e)) : int list)
let () = ignore @@ (List.hd @@ (foo 7))
type t = {
  first: int ;
  second: int }[@@deriving sexp]
let bar (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:17
      ~start_colnum:21 ~end_lnum:19 ~end_colnum:14 ~message:"bar"
      ~entry_id:__entry_id ~log_level:1 `Debug;
    Debug_runtime.log_value_sexp ?descr:(Some "x") ~entry_id:__entry_id
      ~log_level:1 ~is_result:false (lazy (([%sexp_of : t]) x)));
   (match let y : int =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:18
              ~start_colnum:6 ~end_lnum:18 ~end_colnum:7 ~message:"y"
              ~entry_id:__entry_id ~log_level:1 `Debug;
            (match x.first + 1 with
             | y as __res ->
                 ((();
                   Debug_runtime.log_value_sexp ?descr:(Some "y")
                     ~entry_id:__entry_id ~log_level:1 ~is_result:true
                     (lazy (([%sexp_of : int]) y)));
                  Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:18 ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:18 ~entry_id:__entry_id;
                  raise e)) in
          x.second * y
    with
    | __res ->
        (Debug_runtime.log_value_sexp ?descr:(Some "bar")
           ~entry_id:__entry_id ~log_level:1 ~is_result:true
           (lazy (([%sexp_of : int]) __res));
         Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:17
           ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:17
           ~entry_id:__entry_id;
         raise e)) : int)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:23
      ~start_colnum:21 ~end_lnum:26 ~end_colnum:28 ~message:"baz"
      ~entry_id:__entry_id ~log_level:1 `Debug;
    Debug_runtime.log_value_sexp ?descr:(Some "x") ~entry_id:__entry_id
      ~log_level:1 ~is_result:false (lazy (([%sexp_of : t]) x)));
   (match let ((y, z) as _yz) : (int * int) =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:24
              ~start_colnum:17 ~end_lnum:24 ~end_colnum:20 ~message:"_yz"
              ~entry_id:__entry_id ~log_level:1 `Debug;
            (match ((x.first + 1), 3) with
             | _yz as __res ->
                 ((();
                   Debug_runtime.log_value_sexp ?descr:(Some "_yz")
                     ~entry_id:__entry_id ~log_level:1 ~is_result:true
                     (lazy (([%sexp_of : (int * int)]) _yz)));
                  Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:24 ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:24 ~entry_id:__entry_id;
                  raise e)) in
          let ((u, w) as _uw) : (int * int) =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:25
              ~start_colnum:17 ~end_lnum:25 ~end_colnum:20 ~message:"_uw"
              ~entry_id:__entry_id ~log_level:1 `Debug;
            (match (7, 13) with
             | _uw as __res ->
                 ((();
                   Debug_runtime.log_value_sexp ?descr:(Some "_uw")
                     ~entry_id:__entry_id ~log_level:1 ~is_result:true
                     (lazy (([%sexp_of : (int * int)]) _uw)));
                  Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:25 ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:25 ~entry_id:__entry_id;
                  raise e)) in
          (((x.second * y) + z) + u) + w
    with
    | __res ->
        (Debug_runtime.log_value_sexp ?descr:(Some "baz")
           ~entry_id:__entry_id ~log_level:1 ~is_result:true
           (lazy (([%sexp_of : int]) __res));
         Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:23
           ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:23
           ~entry_id:__entry_id;
         raise e)) : int)
let () = ignore @@ (baz { first = 7; second = 42 })
let lab ~x:(x : int) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:30
      ~start_colnum:21 ~end_lnum:32 ~end_colnum:17 ~message:"lab"
      ~entry_id:__entry_id ~log_level:1 `Debug;
    Debug_runtime.log_value_sexp ?descr:(Some "x") ~entry_id:__entry_id
      ~log_level:1 ~is_result:false (lazy (([%sexp_of : int]) x)));
   (match let y : int =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:31
              ~start_colnum:6 ~end_lnum:31 ~end_colnum:7 ~message:"y"
              ~entry_id:__entry_id ~log_level:1 `Debug;
            (match x + 1 with
             | y as __res ->
                 ((();
                   Debug_runtime.log_value_sexp ?descr:(Some "y")
                     ~entry_id:__entry_id ~log_level:1 ~is_result:true
                     (lazy (([%sexp_of : int]) y)));
                  Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:31 ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:31 ~entry_id:__entry_id;
                  raise e)) in
          [x; y; 2 * y]
    with
    | __res ->
        (Debug_runtime.log_value_sexp ?descr:(Some "lab")
           ~entry_id:__entry_id ~log_level:1 ~is_result:true
           (lazy (([%sexp_of : int list]) __res));
         Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:30
           ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:30
           ~entry_id:__entry_id;
         raise e)) : int list)
let () = ignore @@ (List.hd @@ (lab ~x:7))
let rec loop (depth : int) (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   ((Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:36
       ~start_colnum:26 ~end_lnum:42 ~end_colnum:9 ~message:"loop"
       ~entry_id:__entry_id ~log_level:1 `Debug;
     Debug_runtime.log_value_sexp ?descr:(Some "depth") ~entry_id:__entry_id
       ~log_level:1 ~is_result:false (lazy (([%sexp_of : int]) depth)));
    Debug_runtime.log_value_sexp ?descr:(Some "x") ~entry_id:__entry_id
      ~log_level:1 ~is_result:false (lazy (([%sexp_of : t]) x)));
   (match if depth > 4
          then x.first + x.second
          else
            if depth > 1
            then
              loop (depth + 1)
                { first = (x.second + 1); second = (x.first / 2) }
            else
              (let y : int =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 Debug_runtime.open_log ~fname:"test_debug_sexp.ml"
                   ~start_lnum:40 ~start_colnum:8 ~end_lnum:40 ~end_colnum:9
                   ~message:"y" ~entry_id:__entry_id ~log_level:1 `Debug;
                 (match loop (depth + 1)
                          { first = (x.second - 1); second = (x.first + 2) }
                  with
                  | y as __res ->
                      ((();
                        Debug_runtime.log_value_sexp ?descr:(Some "y")
                          ~entry_id:__entry_id ~log_level:1 ~is_result:true
                          (lazy (([%sexp_of : int]) y)));
                       Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                         ~start_lnum:40 ~entry_id:__entry_id;
                       __res)
                  | exception e ->
                      (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                         ~start_lnum:40 ~entry_id:__entry_id;
                       raise e)) in
               let z : int =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 Debug_runtime.open_log ~fname:"test_debug_sexp.ml"
                   ~start_lnum:41 ~start_colnum:8 ~end_lnum:41 ~end_colnum:9
                   ~message:"z" ~entry_id:__entry_id ~log_level:1 `Debug;
                 (match loop (depth + 1)
                          { first = (x.second + 1); second = y }
                  with
                  | z as __res ->
                      ((();
                        Debug_runtime.log_value_sexp ?descr:(Some "z")
                          ~entry_id:__entry_id ~log_level:1 ~is_result:true
                          (lazy (([%sexp_of : int]) z)));
                       Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                         ~start_lnum:41 ~entry_id:__entry_id;
                       __res)
                  | exception e ->
                      (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                         ~start_lnum:41 ~entry_id:__entry_id;
                       raise e)) in
               z + 7)
    with
    | __res ->
        (Debug_runtime.log_value_sexp ?descr:(Some "loop")
           ~entry_id:__entry_id ~log_level:1 ~is_result:true
           (lazy (([%sexp_of : int]) __res));
         Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:36
           ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:36
           ~entry_id:__entry_id;
         raise e)) : int)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
