let debug_run1 () =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_file ~values_first_mode:false ~backend:`Text
           ~normalize_pattern:
             (Re.compile (Re.Pcre.re {|\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]|}))
           "debugger_timestamps_run1")
  in
  let%debug_show process_message (msg : string) : int =
    let timestamp : string = "[2024-03-21 10:00:00] " in
    let processed : string = timestamp ^ "Processing: " ^ msg in
    String.length processed
  in
  ignore @@ process_message "hello"

let debug_run2 () =
  let module Debug_runtime =
    (val Minidebug_runtime.debug_file ~values_first_mode:false ~backend:`Text
           ~prev_run_file:"debugger_timestamps_run1.raw"
           ~normalize_pattern:
             (Re.compile (Re.Pcre.re {|\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]|}))
           "debugger_timestamps_run2")
  in
  let%debug_show process_message (msg : string) : int =
    let timestamp : string = "[2024-03-22 15:30:45] " in
    let processed : string = timestamp ^ "Processing: " ^ msg in
    String.length processed
  in
  ignore @@ process_message "hello"

let () =
  if Array.length Sys.argv > 1 && Sys.argv.(1) = "run2" then debug_run2 ()
  else if Array.length Sys.argv > 1 && Sys.argv.(1) = "run1" then debug_run1 ()
  else failwith "Usage: test_debug_timestamps run1|run2" 