let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_log_level_consistency" in
  fun () -> rt
;;try
    let runtime_log_level =
      Stdlib.String.lowercase_ascii @@
        (Stdlib.Sys.getenv "PPX_MINIDEBUG_TEST_LOG_LEVEL_CONSISTENCY") in
    if
      (not (Stdlib.String.equal "" runtime_log_level)) &&
        (not (Stdlib.String.equal "9" runtime_log_level))
    then
      failwith
        ("ppx_minidebug: compile-time vs. runtime log level mismatch, found '"
           ^
           ("9" ^
              ("' at compile time, '" ^ (runtime_log_level ^ "' at runtime"))))
  with | Stdlib.Not_found -> ()
let foo (x : int) =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __entry_id = Debug_runtime.get_entry_id () in
     (Debug_runtime.open_log ~fname:"test_debug_log_level_consistency.ml"
        ~start_lnum:7 ~start_colnum:19 ~end_lnum:9 ~end_colnum:17
        ~message:"foo" ~entry_id:__entry_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~entry_id:__entry_id
        ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
     ();
     (match let y =
              let __entry_id = Debug_runtime.get_entry_id () in
              Debug_runtime.open_log
                ~fname:"test_debug_log_level_consistency.ml" ~start_lnum:8
                ~start_colnum:6 ~end_lnum:8 ~end_colnum:7 ~message:"y"
                ~entry_id:__entry_id ~log_level:1 `Debug;
              ();
              (match x + 1 with
               | y as __res ->
                   ((();
                     Debug_runtime.log_value_show ?descr:(Some "y")
                       ~entry_id:__entry_id ~log_level:1 ~is_result:true
                       (lazy (([%show : int]) y)));
                    Debug_runtime.close_log
                      ~fname:"test_debug_log_level_consistency.ml"
                      ~start_lnum:8 ~entry_id:__entry_id;
                    __res)
               | exception e ->
                   (Debug_runtime.close_log
                      ~fname:"test_debug_log_level_consistency.ml"
                      ~start_lnum:8 ~entry_id:__entry_id;
                    raise e)) in
            [x; y; 2 * y]
      with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "foo")
             ~entry_id:__entry_id ~log_level:1 ~is_result:true
             (lazy (([%show : int list]) __res));
           Debug_runtime.close_log
             ~fname:"test_debug_log_level_consistency.ml" ~start_lnum:7
             ~entry_id:__entry_id;
           __res)
      | exception e ->
          (Debug_runtime.close_log
             ~fname:"test_debug_log_level_consistency.ml" ~start_lnum:7
             ~entry_id:__entry_id;
           raise e)) : int list)
let () = ignore @@ (List.hd @@ (foo 7))
