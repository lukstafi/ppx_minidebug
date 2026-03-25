module Debug_runtime = (val
  Minidebug_db.debug_db_file "debugger_test_auto_instrument")
let foo x =
  let __scope_id = Debug_runtime.get_scope_id () in
  Debug_runtime.open_log ~fname:"test_auto_instrument.ml" ~start_lnum:3
    ~start_colnum:8 ~end_lnum:3 ~end_colnum:25 ~message:"foo"
    ~scope_id:__scope_id ~log_level:1 `Track;
  ();
  (match x + 1 with
   | __res ->
       (();
        Debug_runtime.close_log ~fname:"test_auto_instrument.ml"
          ~start_lnum:3 ~scope_id:__scope_id;
        __res)
   | exception e ->
       (Debug_runtime.log_exception ~scope_id:__scope_id ~log_level:1 e;
        Debug_runtime.close_log ~fname:"test_auto_instrument.ml"
          ~start_lnum:3 ~scope_id:__scope_id;
        raise e))
let bar x y =
  let __scope_id = Debug_runtime.get_scope_id () in
  Debug_runtime.open_log ~fname:"test_auto_instrument.ml" ~start_lnum:5
    ~start_colnum:8 ~end_lnum:7 ~end_colnum:7 ~message:"bar"
    ~scope_id:__scope_id ~log_level:1 `Track;
  ();
  (match let z = x + y in z * 2 with
   | __res ->
       (();
        Debug_runtime.close_log ~fname:"test_auto_instrument.ml"
          ~start_lnum:5 ~scope_id:__scope_id;
        __res)
   | exception e ->
       (Debug_runtime.log_exception ~scope_id:__scope_id ~log_level:1 e;
        Debug_runtime.close_log ~fname:"test_auto_instrument.ml"
          ~start_lnum:5 ~scope_id:__scope_id;
        raise e))
let value = 42
let () = print_endline "hello"
