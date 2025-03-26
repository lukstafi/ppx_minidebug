let _get_local_debug_runtime =
  Minidebug_runtime.local_runtime_flushing "debugger_unannot_bindings"

let%debug_show _result =
  let a = 1 in
  let b = 2 in
  let%ppx_minidebug_noop_for_testing point = (a, b) in
  ignore point
