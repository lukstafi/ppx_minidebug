open Sexplib0.Sexp_conv

(* This test creates multiple chunks with various patterns to test the diffing
   functionality *)

(* Helper function to create a deterministic timestamp string *)
let%debug_rt_sexp fixed_timestamp run_id position =
  Printf.sprintf "[2024-%02d-%02d %02d:%02d:%02d]" (run_id + 1) (position + 1)
    (position mod 24) (position mod 60)
    (position * 2 mod 60)

(* Helper function to create a deterministic string with a timestamp *)
let%debug_rt_sexp string_with_timestamp run_id position =
  let timestamp : string = fixed_timestamp (module Debug_runtime) run_id position in
  let fixed_string : string =
    match position mod 5 with
    | 0 -> "abcdefghij"
    | 1 -> "klmnopqrst"
    | 2 -> "uvwxyzabcd"
    | 3 -> "efghijklmn"
    | _ -> "opqrstuvwx"
  in
  timestamp ^ " " ^ fixed_string

(* Helper to create a data structure with deterministic elements *)
let create_data_structure size run_id =
  let rec build_list n acc =
    if n <= 0 then acc else build_list (n - 1) ((n * (run_id + 1) mod 100) :: acc)
  in
  build_list size []

(* Run 1: Create baseline data *)
let debug_run1 () =
  Printf.printf "Running debug_run1...\n%!";

  let _get_local_debug_runtime =
    Minidebug_runtime.local_runtime ~values_first_mode:true ~backend:`Text
      ~diff_ignore_pattern:(Re.Pcre.re {|\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]|})
      "debugger_large_diffs_run1"
  in
  (* Chunk 1: Simple function with timestamps *)
  let%debug_sexp process_message (msg : string) : string =
    let timestamp = string_with_timestamp (module Debug_runtime) 0 1 in
    timestamp ^ " Processing: " ^ msg
  in
  ignore @@ process_message "hello";
  ignore @@ process_message "world";

  (* Chunk 2: Function with data structures *)
  let%debug_sexp process_data (size : int) : int list =
    let data = create_data_structure size 0 in
    let timestamp = string_with_timestamp (module Debug_runtime) 0 2 in
    [%log timestamp, "Processing data of size", (size : int)];
    data
  in
  ignore @@ process_data 5;
  ignore @@ process_data 10;

  (* Chunk 3: Nested function calls with timestamps *)
  let%debug_sexp helper (x : int) : int =
    let timestamp = string_with_timestamp (module Debug_runtime) 0 3 in
    [%log timestamp, "Helper called with", (x : int)];
    x * 2
  in

  let%debug_sexp process_number (n : int) : int =
    let timestamp = string_with_timestamp (module Debug_runtime) 0 4 in
    [%log timestamp, "Processing number", (n : int)];
    let result = helper (n + 1) in
    result + 3
  in

  ignore @@ process_number 5;
  ignore @@ process_number 10;

  (* Chunk 4: Complex data with some changes between runs *)
  let%debug_sexp complex_operation (input : string) : (string * int) list =
    let timestamp = string_with_timestamp (module Debug_runtime) 0 5 in
    let words = String.split_on_char ' ' input in
    let result = List.mapi (fun i word -> (word, String.length word + i)) words in
    [%log timestamp, "Complex operation on:", input];
    result
  in

  ignore @@ complex_operation "this is a test string";
  ignore @@ complex_operation "another example with more words to process";
  let module D = (val _get_local_debug_runtime ()) in
  D.finish_and_cleanup ()

(* Run 2: Similar to run 1 but with some intentional changes *)
let debug_run2 () =
  Printf.printf "Running debug_run2...\n%!";

  let _get_local_debug_runtime =
    Minidebug_runtime.local_runtime ~values_first_mode:true ~backend:`Text
      ~prev_run_file:"debugger_large_diffs_run1.raw"
      ~diff_ignore_pattern:(Re.Pcre.re {|\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]|})
      "debugger_large_diffs_run2"
  in
  (* Chunk 1: Same as run1 but with different timestamps *)
  let%debug_sexp process_message (msg : string) : string =
    let timestamp = string_with_timestamp (module Debug_runtime) 1 1 in
    timestamp ^ " Processing: " ^ msg
  in
  ignore @@ process_message "hello";
  ignore @@ process_message "world";

  (* Chunk 2: Same function but with slightly different data *)
  let%debug_sexp process_data (size : int) : int list =
    let data = create_data_structure size 1 in
    let timestamp = string_with_timestamp (module Debug_runtime) 1 2 in
    [%log timestamp, "Processing data of size", (size : int)];
    data
  in
  ignore @@ process_data 5;
  ignore @@ process_data 11;

  (* Changed from 10 to 11 *)

  (* Chunk 3: Same nested functions but with a small change *)
  let%debug_sexp helper (x : int) : int =
    let timestamp = string_with_timestamp (module Debug_runtime) 1 3 in
    [%log timestamp, "Helper called with", (x : int)];
    x * 2
  in

  let%debug_sexp process_number (n : int) : int =
    let timestamp = string_with_timestamp (module Debug_runtime) 1 4 in
    [%log timestamp, "Processing number", (n : int)];
    let result = helper (n + 2) in
    (* Changed from n+1 to n+2 *)
    result + 3
  in

  ignore @@ process_number 5;
  ignore @@ process_number 10;

  (* Chunk 4: Same complex data with one different input *)
  let%debug_sexp complex_operation (input : string) : (string * int) list =
    let timestamp = string_with_timestamp (module Debug_runtime) 1 5 in
    let words = String.split_on_char ' ' input in
    let result = List.mapi (fun i word -> (word, String.length word + i)) words in
    [%log timestamp, "Complex operation on:", input];
    result
  in

  ignore @@ complex_operation "this is a test string";
  ignore @@ complex_operation "a completely different string with new words";
  (* Changed input *)
  let module D = (val _get_local_debug_runtime ()) in
  D.finish_and_cleanup ()

(* Run 3: Test with additional chunks and more complex changes *)
let debug_run3 () =
  Printf.printf "Running debug_run3...\n%!";

  let _get_local_debug_runtime =
    Minidebug_runtime.local_runtime ~values_first_mode:true ~backend:`Text
      ~prev_run_file:"debugger_large_diffs_run2.raw"
      ~diff_ignore_pattern:(Re.Pcre.re {|\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]|})
      "debugger_large_diffs_run3"
  in
  (* Chunk 1: Same as before *)
  let%debug_sexp process_message (msg : string) : string =
    let timestamp = string_with_timestamp (module Debug_runtime) 2 1 in
    timestamp ^ " Processing: " ^ msg
  in
  ignore @@ process_message "hello";
  ignore @@ process_message "world";

  (* Chunk 2: Now with an additional call *)
  let%debug_sexp process_data (size : int) : int list =
    let data = create_data_structure size 2 in
    let timestamp = string_with_timestamp (module Debug_runtime) 2 2 in
    [%log timestamp, "Processing data of size", (size : int)];
    data
  in
  ignore @@ process_data 5;
  ignore @@ process_data 11;
  ignore @@ process_data 15;

  (* Added a new call *)

  (* Chunk 3: Modified implementation *)
  let%debug_sexp helper (x : int) : int =
    let timestamp = string_with_timestamp (module Debug_runtime) 2 3 in
    [%log timestamp, "Helper called with", (x : int)];
    x * 3 (* Changed multiplier from 2 to 3 *)
  in

  let%debug_sexp process_number (n : int) : int =
    let timestamp = string_with_timestamp (module Debug_runtime) 2 4 in
    [%log timestamp, "Processing number", (n : int)];
    let result = helper (n + 2) in
    result + 5 (* Changed from +3 to +5 *)
  in

  ignore @@ process_number 5;
  ignore @@ process_number 10;

  (* Chunk 4: Same as run2 *)
  let%debug_sexp complex_operation (input : string) : (string * int) list =
    let timestamp = string_with_timestamp (module Debug_runtime) 2 5 in
    let words = String.split_on_char ' ' input in
    let result = List.mapi (fun i word -> (word, String.length word + i)) words in
    [%log timestamp, "Complex operation on:", input];
    result
  in

  ignore @@ complex_operation "this is a test string";
  ignore @@ complex_operation "a completely different string with new words";

  (* Chunk 5: New chunk not present in previous runs *)
  let%debug_sexp new_operation (a : int) (b : int) : int * int * int =
    let timestamp = string_with_timestamp (module Debug_runtime) 2 6 in
    [%log timestamp, "New operation with", (a : int), "and", (b : int)];
    (a + b, a * b, a - b)
  in

  ignore @@ new_operation 10 20;
  ignore @@ new_operation 5 7;
  let module D = (val _get_local_debug_runtime ()) in
  D.finish_and_cleanup ()

(* Main function to run all tests sequentially *)
let () =
  Printf.printf "Starting test_debug_large_diffs...\n%!";

  (* Run all three debug runs sequentially *)
  Printf.printf "About to run debug_run1...\n%!";
  debug_run1 ();
  Printf.printf "debug_run1 completed.\n%!";

  Printf.printf "About to run debug_run2...\n%!";
  debug_run2 ();
  Printf.printf "debug_run2 completed.\n%!";

  Printf.printf "About to run debug_run3...\n%!";
  debug_run3 ();
  Printf.printf "debug_run3 completed.\n%!";

  Printf.printf "All debug runs completed successfully.\n%!"
