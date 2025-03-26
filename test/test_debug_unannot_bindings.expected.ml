let _get_local_debug_runtime =
  Minidebug_runtime.local_runtime_flushing "debugger_unannot_bindings"
let _result =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
    let a = 1 in let b = 2 in let point = (a, b) in ignore point
