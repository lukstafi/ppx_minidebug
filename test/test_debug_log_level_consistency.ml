let _get_local_debug_runtime =
  Minidebug_runtime.local_runtime_flushing "debugger_show_flushing"

[%%global_debug_log_level_from_env_var "PPX_MINIDEBUG_TEST_LOG_LEVEL_CONSISTENCY"]

let%debug_show foo (x : int) : int list =
  let y : int = x + 1 in
  [ x; y; 2 * y ]

let () = ignore @@ List.hd @@ foo 7
