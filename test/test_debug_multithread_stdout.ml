let _get_local_debug_runtime = Minidebug_runtime.prefixed_runtime_flushing ()

let%debug_show thread_work (thread_id : int) (iterations : int) : unit =
  for i = 0 to iterations do
    let result : int = i + (100 * thread_id) in
    let _ : int = result mod 2 in
    ()
  done

let%debug_show spawn_threads (num_threads : int) (iterations : int) : unit =
  (* This is the simplest way to ensure the test is deterministic. *)
  ignore
  @@ List.init num_threads (fun i ->
         Thread.join @@ Thread.create (fun () -> thread_work i iterations) ())

let () =
  try
    print_endline "Starting multi-threaded test...";
    spawn_threads 3 10;
    print_endline "Multi-threaded test completed successfully."
  with e -> Printf.printf "Error in multi-threaded test: %s\n" (Printexc.to_string e)
