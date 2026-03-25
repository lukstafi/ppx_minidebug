module Debug_runtime = (val
  Minidebug_db.debug_db_file "debugger_test_auto_mixed")
let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_auto_mixed" in fun () -> rt
let annotated_fn (x : int) =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in
    (let __scope_id = Debug_runtime.get_scope_id () in
     (Debug_runtime.open_log ~fname:"test_auto_mixed.ml" ~start_lnum:8
        ~start_colnum:28 ~end_lnum:8 ~end_colnum:51 ~message:"annotated_fn"
        ~scope_id:__scope_id ~log_level:1 `Debug;
      Debug_runtime.log_value_show ?descr:(Some "x") ~scope_id:__scope_id
        ~log_level:1 ~is_result:false (lazy (([%show : int]) x)));
     ();
     (match x * 2 with
      | __res ->
          (Debug_runtime.log_value_show ?descr:(Some "annotated_fn")
             ~scope_id:__scope_id ~log_level:1 ~is_result:true
             (lazy (([%show : int]) __res));
           Debug_runtime.close_log ~fname:"test_auto_mixed.ml" ~start_lnum:8
             ~scope_id:__scope_id;
           __res)
      | exception e ->
          (Debug_runtime.log_exception ~scope_id:__scope_id ~log_level:1 e;
           Debug_runtime.close_log ~fname:"test_auto_mixed.ml" ~start_lnum:8
             ~scope_id:__scope_id;
           raise e)) : int)
let unannotated_fn x =
  let __scope_id = Debug_runtime.get_scope_id () in
  Debug_runtime.open_log ~fname:"test_auto_mixed.ml" ~start_lnum:11
    ~start_colnum:19 ~end_lnum:11 ~end_colnum:36 ~message:"unannotated_fn"
    ~scope_id:__scope_id ~log_level:1 `Track;
  ();
  (match x + 1 with
   | __res ->
       (();
        Debug_runtime.close_log ~fname:"test_auto_mixed.ml" ~start_lnum:11
          ~scope_id:__scope_id;
        __res)
   | exception e ->
       (Debug_runtime.log_exception ~scope_id:__scope_id ~log_level:1 e;
        Debug_runtime.close_log ~fname:"test_auto_mixed.ml" ~start_lnum:11
          ~scope_id:__scope_id;
        raise e))
