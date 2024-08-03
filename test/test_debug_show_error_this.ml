(* module Debug_runtime =
   (val Minidebug_runtime.debug_flushing ~filename:"debugger_show_flushing" ()) *)

let () =
  [%debug_this_show
    [%log_entry
      "The end";
      [%log (42 : int)]]];
  ()
