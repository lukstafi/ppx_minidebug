let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_unannot_bindings" in
  fun () -> rt
let _result =
  let module Debug_runtime = (val
    (_get_local_debug_runtime () : (module Minidebug_runtime.Debug_runtime)))
    in let a = 1 in let b = 2 in let point = (a, b) in ignore point
