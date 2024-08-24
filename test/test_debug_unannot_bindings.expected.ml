module Debug_runtime = (val
  Minidebug_runtime.debug_flushing ~filename:"debugger_unannot_bindings" ())
let _result =
  let __entry_id = Debug_runtime.get_entry_id () in
  ();
  Debug_runtime.open_log ~fname:"test_debug_unannot_bindings.ml"
    ~start_lnum:4 ~start_colnum:15 ~end_lnum:4 ~end_colnum:22
    ~message:"_result" ~entry_id:__entry_id ~log_level:1;
  (match let a = 1 in let b = 2 in let point = (a, b) in ignore point with
   | _ as __res ->
       (();
        Debug_runtime.close_log ~fname:"test_debug_unannot_bindings.ml"
          ~start_lnum:4 ~entry_id:__entry_id;
        __res)
   | exception e ->
       (Debug_runtime.close_log ~fname:"test_debug_unannot_bindings.ml"
          ~start_lnum:4 ~entry_id:__entry_id;
        raise e))
