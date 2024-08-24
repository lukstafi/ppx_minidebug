open Sexplib0.Sexp_conv
module Debug_runtime = (Minidebug_runtime.PrintBox)((val
  Minidebug_runtime.shared_config "debugger_sexp_printbox.log"))
let foo (x : int) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:7
      ~start_colnum:19 ~end_lnum:9 ~end_colnum:17 ~message:"foo"
      ~entry_id:__entry_id ~log_level:1 `Debug;
    Debug_runtime.log_value_sexp ?descr:(Some "x") ~entry_id:__entry_id
      ~log_level:1 ~is_result:false (([%sexp_of : int]) x));
   (match let y : int =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:8
              ~start_colnum:6 ~end_lnum:8 ~end_colnum:7 ~message:"y"
              ~entry_id:__entry_id ~log_level:1 `Debug;
            (match x + 1 with
             | y as __res ->
                 ((();
                   Debug_runtime.log_value_sexp ?descr:(Some "y")
                     ~entry_id:__entry_id ~log_level:1 ~is_result:true
                     (([%sexp_of : int]) y));
                  Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:8 ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:8 ~entry_id:__entry_id;
                  raise e)) in
          [x; y; 2 * y]
    with
    | __res ->
        (Debug_runtime.log_value_sexp ?descr:(Some "foo")
           ~entry_id:__entry_id ~log_level:1 ~is_result:true
           (([%sexp_of : int list]) __res);
         Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:7
           ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:7
           ~entry_id:__entry_id;
         raise e)) : int list)
let () = ignore @@ (List.hd @@ (foo 7))
type t = {
  first: int ;
  second: int }[@@deriving sexp]
let bar (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:15
      ~start_colnum:19 ~end_lnum:17 ~end_colnum:14 ~message:"bar"
      ~entry_id:__entry_id ~log_level:1 `Debug;
    Debug_runtime.log_value_sexp ?descr:(Some "x") ~entry_id:__entry_id
      ~log_level:1 ~is_result:false (([%sexp_of : t]) x));
   (match let y : int =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:16
              ~start_colnum:6 ~end_lnum:16 ~end_colnum:7 ~message:"y"
              ~entry_id:__entry_id ~log_level:1 `Debug;
            (match x.first + 1 with
             | y as __res ->
                 ((();
                   Debug_runtime.log_value_sexp ?descr:(Some "y")
                     ~entry_id:__entry_id ~log_level:1 ~is_result:true
                     (([%sexp_of : int]) y));
                  Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:16 ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:16 ~entry_id:__entry_id;
                  raise e)) in
          x.second * y
    with
    | __res ->
        (Debug_runtime.log_value_sexp ?descr:(Some "bar")
           ~entry_id:__entry_id ~log_level:1 ~is_result:true
           (([%sexp_of : int]) __res);
         Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:15
           ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:15
           ~entry_id:__entry_id;
         raise e)) : int)
let () = ignore @@ (bar { first = 7; second = 42 })
let baz (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:21
      ~start_colnum:19 ~end_lnum:24 ~end_colnum:28 ~message:"baz"
      ~entry_id:__entry_id ~log_level:1 `Debug;
    Debug_runtime.log_value_sexp ?descr:(Some "x") ~entry_id:__entry_id
      ~log_level:1 ~is_result:false (([%sexp_of : t]) x));
   (match let (((y, z) as _yz) : (int * int)) =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:22
              ~start_colnum:17 ~end_lnum:22 ~end_colnum:20 ~message:"_yz"
              ~entry_id:__entry_id ~log_level:1 `Debug;
            (match ((x.first + 1), 3) with
             | _yz as __res ->
                 ((();
                   Debug_runtime.log_value_sexp ?descr:(Some "_yz")
                     ~entry_id:__entry_id ~log_level:1 ~is_result:true
                     (([%sexp_of : (int * int)]) _yz));
                  Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:22 ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:22 ~entry_id:__entry_id;
                  raise e)) in
          let (((u, w) as _uw) : (int * int)) =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:23
              ~start_colnum:17 ~end_lnum:23 ~end_colnum:20 ~message:"_uw"
              ~entry_id:__entry_id ~log_level:1 `Debug;
            (match (7, 13) with
             | _uw as __res ->
                 ((();
                   Debug_runtime.log_value_sexp ?descr:(Some "_uw")
                     ~entry_id:__entry_id ~log_level:1 ~is_result:true
                     (([%sexp_of : (int * int)]) _uw));
                  Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:23 ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:23 ~entry_id:__entry_id;
                  raise e)) in
          (((x.second * y) + z) + u) + w
    with
    | __res ->
        (Debug_runtime.log_value_sexp ?descr:(Some "baz")
           ~entry_id:__entry_id ~log_level:1 ~is_result:true
           (([%sexp_of : int]) __res);
         Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:21
           ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:21
           ~entry_id:__entry_id;
         raise e)) : int)
let () = ignore @@ (baz { first = 7; second = 42 })
let lab ~x:(x : int)  =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   (Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:28
      ~start_colnum:19 ~end_lnum:30 ~end_colnum:17 ~message:"lab"
      ~entry_id:__entry_id ~log_level:1 `Debug;
    Debug_runtime.log_value_sexp ?descr:(Some "x") ~entry_id:__entry_id
      ~log_level:1 ~is_result:false (([%sexp_of : int]) x));
   (match let y : int =
            let __entry_id = Debug_runtime.get_entry_id () in
            ();
            Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:29
              ~start_colnum:6 ~end_lnum:29 ~end_colnum:7 ~message:"y"
              ~entry_id:__entry_id ~log_level:1 `Debug;
            (match x + 1 with
             | y as __res ->
                 ((();
                   Debug_runtime.log_value_sexp ?descr:(Some "y")
                     ~entry_id:__entry_id ~log_level:1 ~is_result:true
                     (([%sexp_of : int]) y));
                  Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:29 ~entry_id:__entry_id;
                  __res)
             | exception e ->
                 (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                    ~start_lnum:29 ~entry_id:__entry_id;
                  raise e)) in
          [x; y; 2 * y]
    with
    | __res ->
        (Debug_runtime.log_value_sexp ?descr:(Some "lab")
           ~entry_id:__entry_id ~log_level:1 ~is_result:true
           (([%sexp_of : int list]) __res);
         Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:28
           ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:28
           ~entry_id:__entry_id;
         raise e)) : int list)
let () = ignore @@ (List.hd @@ (lab ~x:7))
let rec loop (depth : int) (x : t) =
  (let __entry_id = Debug_runtime.get_entry_id () in
   ();
   ((Debug_runtime.open_log ~fname:"test_debug_sexp.ml" ~start_lnum:34
       ~start_colnum:24 ~end_lnum:40 ~end_colnum:9 ~message:"loop"
       ~entry_id:__entry_id ~log_level:1 `Debug;
     Debug_runtime.log_value_sexp ?descr:(Some "depth") ~entry_id:__entry_id
       ~log_level:1 ~is_result:false (([%sexp_of : int]) depth));
    Debug_runtime.log_value_sexp ?descr:(Some "x") ~entry_id:__entry_id
      ~log_level:1 ~is_result:false (([%sexp_of : t]) x));
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
                   ~start_lnum:38 ~start_colnum:8 ~end_lnum:38 ~end_colnum:9
                   ~message:"y" ~entry_id:__entry_id ~log_level:1 `Debug;
                 (match loop (depth + 1)
                          { first = (x.second - 1); second = (x.first + 2) }
                  with
                  | y as __res ->
                      ((();
                        Debug_runtime.log_value_sexp ?descr:(Some "y")
                          ~entry_id:__entry_id ~log_level:1 ~is_result:true
                          (([%sexp_of : int]) y));
                       Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                         ~start_lnum:38 ~entry_id:__entry_id;
                       __res)
                  | exception e ->
                      (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                         ~start_lnum:38 ~entry_id:__entry_id;
                       raise e)) in
               let z : int =
                 let __entry_id = Debug_runtime.get_entry_id () in
                 ();
                 Debug_runtime.open_log ~fname:"test_debug_sexp.ml"
                   ~start_lnum:39 ~start_colnum:8 ~end_lnum:39 ~end_colnum:9
                   ~message:"z" ~entry_id:__entry_id ~log_level:1 `Debug;
                 (match loop (depth + 1)
                          { first = (x.second + 1); second = y }
                  with
                  | z as __res ->
                      ((();
                        Debug_runtime.log_value_sexp ?descr:(Some "z")
                          ~entry_id:__entry_id ~log_level:1 ~is_result:true
                          (([%sexp_of : int]) z));
                       Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                         ~start_lnum:39 ~entry_id:__entry_id;
                       __res)
                  | exception e ->
                      (Debug_runtime.close_log ~fname:"test_debug_sexp.ml"
                         ~start_lnum:39 ~entry_id:__entry_id;
                       raise e)) in
               z + 7)
    with
    | __res ->
        (Debug_runtime.log_value_sexp ?descr:(Some "loop")
           ~entry_id:__entry_id ~log_level:1 ~is_result:true
           (([%sexp_of : int]) __res);
         Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:34
           ~entry_id:__entry_id;
         __res)
    | exception e ->
        (Debug_runtime.close_log ~fname:"test_debug_sexp.ml" ~start_lnum:34
           ~entry_id:__entry_id;
         raise e)) : int)
let () = ignore @@ (loop 0 { first = 7; second = 42 })
