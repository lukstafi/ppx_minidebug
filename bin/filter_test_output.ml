(** Filter to remove non-deterministic lines from test output. Reads from stdin, writes to
    stdout. *)

(** Replace time spans like <123.45μs> or <1.23ms> with <TIME> *)
let filter_time_spans line =
  let re = Str.regexp "<[0-9.]+\\(μs\\|ms\\|s\\)>" in
  Str.global_replace re "<TIME>" line

(** Replace standalone time spans like 123.45μs or 1.23ms or 123ns with TIME
    (used in profile command output where times are not angle-bracketed).
    Matches μs, ms, ns suffixes and also fractional seconds like 1.23s. *)
let filter_bare_time_spans line =
  (* First handle μs, ms, ns (safe - no false positives) *)
  let re1 = Str.regexp "[0-9.]+\\(μs\\|ms\\|ns\\)" in
  let line = Str.global_replace re1 "TIME" line in
  (* Then handle fractional seconds like 1.23s (requires decimal point) *)
  let re2 = Str.regexp "[0-9]+\\.[0-9]+s" in
  Str.global_replace re2 "TIME" line

let () =
  try
    while true do
      let line = input_line stdin in
      (* Skip lines that start with "Timestamp:" or "Elapsed:" *)
      let is_timestamp =
        String.length line >= 11 && String.sub line 0 11 = "Timestamp: "
      in
      let is_elapsed = String.length line >= 9 && String.sub line 0 9 = "Elapsed: " in
      if (not is_timestamp) && not is_elapsed then
        print_endline (filter_bare_time_spans (filter_time_spans line))
    done
  with End_of_file -> ()
