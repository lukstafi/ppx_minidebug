(** Filter to remove non-deterministic lines from test output.
    Reads from stdin, writes to stdout. *)

let () =
  try
    while true do
      let line = input_line stdin in
      (* Skip lines that start with "Timestamp:" or "Elapsed:" *)
      let is_timestamp = String.length line >= 11 && String.sub line 0 11 = "Timestamp: " in
      let is_elapsed = String.length line >= 9 && String.sub line 0 9 = "Elapsed: " in
      if not is_timestamp && not is_elapsed then
        print_endline line
    done
  with End_of_file -> ()
