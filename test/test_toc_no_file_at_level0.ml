let () =
  let stem = "debugger_toc_no_file_at_level0" in
  let log_file = stem ^ ".log" in
  let toc_file = stem ^ "-toc.log" in
  (* Clean up any leftover files from previous runs *)
  (try Sys.remove log_file with Sys_error _ -> ());
  (try Sys.remove toc_file with Sys_error _ -> ());
  (* Create a runtime with log_level=0 and with_toc_listing=true *)
  let module Debug_runtime =
    (val Minidebug_runtime.debug_file ~log_level:0 ~with_toc_listing:true
           stem)
  in
  ignore (module Debug_runtime : Minidebug_runtime.PrintBox_runtime);
  (* Verify neither file was created *)
  if Sys.file_exists log_file then (
    Printf.eprintf "FAIL: %s should not exist at log_level 0\n" log_file;
    exit 1);
  if Sys.file_exists toc_file then (
    Printf.eprintf "FAIL: %s should not exist at log_level 0\n" toc_file;
    exit 1);
  print_endline "PASS: no log or toc file created at log_level 0"
