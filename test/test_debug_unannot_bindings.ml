module Debug_runtime =
  Minidebug_runtime.Flushing
    ((val Minidebug_runtime.debug_ch "debugger_unannot_bindings.log"))

let%debug_show _result =
  let a = 1 in
  let b = 2 in
  let%ppx_minidebug_noop_for_testing point =
    (a, b)
  in
  ignore point
