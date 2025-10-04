(* Test for path filtering functionality - demonstrates runtime path filtering *)

let () =
  (* $MDX part-begin=whitelist-fname *)
  (* Test 1: Whitelist by file - only logs from files matching "test_path_filter.ml" *)
  let _get_local_debug_runtime =
    let rt =
      Minidebug_db.debug_db_file ~path_filter:(`Whitelist (Re.compile (Re.str "test_path_filter.ml")))
        "test_path_filter_1"
    in
    fun () -> rt
  in
  let%debug_show compute_value (x : int) : int =
    let y = x + 10 in
    y * 2
  in
  Printf.printf "=== Test 1: Whitelist by file (logs from test_path_filter.ml) ===\n%!";
  let result = compute_value 5 in
  Printf.printf "Result: %d\n%!" result;

  (* $MDX part-end *)

  (* $MDX part-begin=whitelist-function *)
  (* Test 2: Whitelist by function - only logs functions starting with "compute_" *)
  Printf.printf "\n=== Test 2: Whitelist by function (only compute_* functions) ===\n%!";
  let _get_local_debug_runtime =
    let rt =
      Minidebug_db.debug_db_file ~path_filter:(`Whitelist (Re.compile (Re.str "/compute_")))
        "test_path_filter_2"
    in
    fun () -> rt
  in
  let%debug_show compute_sum (x : int) : int =
    let y = x + 10 in
    y * 2
  in
  let%debug_show helper_function (x : int) : int = x + 1 in
  let result1 = compute_sum 5 in
  let result2 = helper_function 5 in
  Printf.printf "Results: %d, %d\n%!" result1 result2;

  (* $MDX part-end *)

  (* Test 3: Blacklist - filter out logs from files matching "test_path_filter.ml" *)
  Printf.printf "\n=== Test 3: Blacklist (blocks test_path_filter.ml) ===\n%!";
  let _get_local_debug_runtime =
    let rt =
      Minidebug_db.debug_db_file ~path_filter:(`Blacklist (Re.compile (Re.str "test_path_filter.ml")))
        "test_path_filter_3"
    in
    fun () -> rt
  in
  let%debug_show compute_blacklist (x : int) : int =
    let y = x + 10 in
    y * 2
  in
  let result = compute_blacklist 5 in
  Printf.printf "Result: %d\n%!" result;

  (* Test 4: No filter - all logs are output *)
  Printf.printf "\n=== Test 4: No filter (shows all logs) ===\n%!";
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file "test_path_filter_4" in
    fun () -> rt
  in
  let%debug_show compute_nofilter (x : int) : int =
    let y = x + 10 in
    y * 2
  in
  let result = compute_nofilter 5 in
  Printf.printf "Result: %d\n%!" result
