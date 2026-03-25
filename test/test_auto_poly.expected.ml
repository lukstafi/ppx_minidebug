module Debug_runtime = (val
  Minidebug_db.debug_db_file "debugger_test_auto_poly")
let identity : 'a . 'a -> 'a =
  fun x ->
    let __scope_id = Debug_runtime.get_scope_id () in
    Debug_runtime.open_log ~fname:"test_auto_poly.ml" ~start_lnum:3
      ~start_colnum:30 ~end_lnum:3 ~end_colnum:40 ~message:"identity"
      ~scope_id:__scope_id ~log_level:1 `Track;
    ();
    (match x with
     | __res ->
         (();
          Debug_runtime.close_log ~fname:"test_auto_poly.ml" ~start_lnum:3
            ~scope_id:__scope_id;
          __res)
     | exception e ->
         (Debug_runtime.log_exception ~scope_id:__scope_id ~log_level:1 e;
          Debug_runtime.close_log ~fname:"test_auto_poly.ml" ~start_lnum:3
            ~scope_id:__scope_id;
          raise e))
let const : 'a 'b . 'a -> 'b -> 'a =
  fun x _y ->
    let __scope_id = Debug_runtime.get_scope_id () in
    Debug_runtime.open_log ~fname:"test_auto_poly.ml" ~start_lnum:5
      ~start_colnum:36 ~end_lnum:5 ~end_colnum:49 ~message:"const"
      ~scope_id:__scope_id ~log_level:1 `Track;
    ();
    (match x with
     | __res ->
         (();
          Debug_runtime.close_log ~fname:"test_auto_poly.ml" ~start_lnum:5
            ~scope_id:__scope_id;
          __res)
     | exception e ->
         (Debug_runtime.log_exception ~scope_id:__scope_id ~log_level:1 e;
          Debug_runtime.close_log ~fname:"test_auto_poly.ml" ~start_lnum:5
            ~scope_id:__scope_id;
          raise e))
