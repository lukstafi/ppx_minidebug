module Debug_runtime = (Minidebug_runtime.Flushing)((val
  Minidebug_runtime.debug_ch "debugger_unannot_bindings.log"))
let result =
  let __entry_id = Debug_runtime.get_entry_id () in
  ();
  Debug_runtime.open_log_preamble_brief
    ~fname:"test_debug_unannot_bindings.ml" ~pos_lnum:5 ~pos_colnum:15
    ~message:"result" ~entry_id:__entry_id;
  (match let a = 1 in let b = 2 in let point = (a, b) in ignore point with
   | _ as __res -> ((); Debug_runtime.close_log (); __res)
   | exception e -> (Debug_runtime.close_log (); raise e))
