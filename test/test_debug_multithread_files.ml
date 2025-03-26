let _get_local_debug_runtime =
  Minidebug_runtime.local_runtime_flushing "debugger_multithread_files"

let%debug_show thread_work (thread_id : int) (iterations : int) : unit =
  for i = 0 to iterations do
    let result : int = i + (100 * thread_id) in
    let _ : int = result mod 2 in
    ()
  done

let%debug_show spawn_threads (num_threads : int) (iterations : int) : unit =
  let threads =
    List.init num_threads (fun i -> Thread.create (fun () -> thread_work i iterations) ())
  in
  List.iter Thread.join threads

let () =
  try
    print_endline "Starting multi-threaded test...";
    spawn_threads 3 100;
    print_endline "Multi-threaded test completed successfully."
  with e -> Printf.printf "Error in multi-threaded test: %s\n" (Printexc.to_string e)
