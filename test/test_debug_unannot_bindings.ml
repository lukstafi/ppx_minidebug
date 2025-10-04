let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_unannot_bindings" in
  fun () -> rt

let%debug_show _result =
  let a = 1 in
  let b = 2 in
  let%ppx_minidebug_noop_for_testing point = (a, b) in
  ignore point
