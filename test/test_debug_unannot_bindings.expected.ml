module Debug_runtime = (val
  Minidebug_runtime.debug_flushing ~filename:"debugger_unannot_bindings" ())
let _result = let a = 1 in let b = 2 in let point = (a, b) in ignore point
