let () =
  let prev_run = "test_expect_test_entry_id_pairs_prev" in
  let curr_run = "test_expect_test_entry_id_pairs_curr" in

  (* First run - create baseline with several entries *)
  let _get_local_debug_runtime =
    Minidebug_runtime.local_runtime ~values_first_mode:false ~print_entry_ids:true
      ~backend:`Text prev_run
  in
  let%debug_show _run1 : unit =
    let logify logs =
      [%log_block
        "logs";
        let rec loop logs =
          match logs with
          | "start" :: header :: tl ->
              let more =
                [%log_entry
                  header;
                  loop tl]
              in
              loop more
          | "end" :: tl -> tl
          | msg :: tl ->
              [%log msg];
              loop tl
          | [] -> []
        in
        ignore (loop logs)]
    in

    (* First run with specific entries *)
    logify
      [
        "start";
        "Entry one";
        "This is the first entry";
        "end";
        "start";
        "Entry two";
        "This is the second entry";
        "end";
        "start";
        "Entry three";
        "This is the third entry";
        "Some more content";
        "end";
        "start";
        "Entry four";
        "This is the fourth entry";
        "end";
        "start";
        "Entry five";
        "This is the fifth entry";
        "end";
        "start";
        "Entry six";
        "This is the sixth entry";
        "end";
        "start";
        "Final content";
        "end";
      ]
  in
  (let module D = (val _get_local_debug_runtime ()) in
  D.finish_and_cleanup ());

  (* Second run with different structure *)
  (* $MDX part-begin=align_entry_ids *)
  let _get_local_debug_runtime =
    Minidebug_runtime.local_runtime ~values_first_mode:false ~print_entry_ids:true
      ~backend:`Text ~prev_run_file:(prev_run ^ ".raw")
      ~entry_id_pairs:[ (2, 4); (8, 6) ]
        (* Force mappings: - Entry 2 (early prev) to Entry 4 (middle curr) - Entry 8 (late
           prev) to Entry 6 (in the shorter curr) *)
      curr_run
  in
  (* $MDX part-end *)
  (* Second run with different structure to test diffing *)
  let%debug_show _run2 : unit =
    let logify logs =
      [%log_block
        "logs";
        let rec loop logs =
          match logs with
          | "start" :: header :: tl ->
              let more =
                [%log_entry
                  header;
                  loop tl]
              in
              loop more
          | "end" :: tl -> tl
          | msg :: tl ->
              [%log msg];
              loop tl
          | [] -> []
        in
        ignore (loop logs)]
    in
    logify
      [
        "start";
        "New first";
        "This is a new first entry";
        "end";
        "start";
        "New second";
        "This is a new second entry";
        "end";
        "start";
        "Entry one";
        "This is the first entry";
        "With some modifications";
        "end";
        "start";
        "New third";
        "Another new entry";
        "end";
        "start";
        "Entry four";
        "This is the fourth entry";
        "end";
        "start";
        "Final content";
        "end";
      ]
  in
  (let module D = (val _get_local_debug_runtime ()) in
  D.finish_and_cleanup ());

  (* Print the outputs to show the diff results *)
  let print_log filename =
    let log_file = open_in (filename ^ ".log") in
    try
      while true do
        print_endline (input_line log_file)
      done
    with End_of_file -> close_in log_file
  in

  print_endline "=== Previous Run ===";
  print_log prev_run;
  print_endline "\n=== Current Run with Diff ===";
  print_log curr_run
