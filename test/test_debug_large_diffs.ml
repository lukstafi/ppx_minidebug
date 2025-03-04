open Sexplib0.Sexp_conv

(* This test creates multiple chunks with various patterns to test the diffing
   functionality *)

(* Helper function to create a random string with a timestamp *)
let%debug_rt_sexp random_string_with_timestamp () =
  let timestamp : string =
    Printf.sprintf "[%04d-%02d-%02d %02d:%02d:%02d]" 2024
      (Random.int 12 + 1)
      (Random.int 28 + 1)
      (Random.int 24) (Random.int 60) (Random.int 60)
  in
  let random_chars : string =
    String.init (Random.int 20 + 5) (fun _ -> Char.chr (Random.int 26 + 97))
  in
  timestamp ^ " " ^ random_chars

(* Helper to create a data structure with some random elements *)
let create_data_structure size =
  let rec build_list n acc =
    if n <= 0 then acc else build_list (n - 1) (Random.int 100 :: acc)
  in
  build_list size []

(* Run 1: Create baseline data *)
let debug_run1 () =
  Random.init 42;

  (* Fixed seed for reproducibility *)
  let module Debug_runtime =
    (val Minidebug_runtime.debug_file ~values_first_mode:true ~backend:`Text
           ~diff_ignore_pattern:(Re.Pcre.re {|\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]|})
           "debugger_large_diffs_run1")
  in
  (* Chunk 1: Simple function with timestamps *)
  let%debug_sexp process_message (msg : string) : string =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    timestamp ^ " Processing: " ^ msg
  in
  ignore @@ process_message "hello";
  ignore @@ process_message "world";

  (* Chunk 2: Function with data structures *)
  let%debug_sexp process_data (size : int) : int list =
    let data = create_data_structure size in
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    [%log timestamp, "Processing data of size", (size : int)];
    data
  in
  ignore @@ process_data 5;
  ignore @@ process_data 10;

  (* Chunk 3: Nested function calls with timestamps *)
  let%debug_sexp helper (x : int) : int =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    [%log timestamp, "Helper called with", (x : int)];
    x * 2
  in

  let%debug_sexp process_number (n : int) : int =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    [%log timestamp, "Processing number", (n : int)];
    let result = helper (n + 1) in
    result + 3
  in

  ignore @@ process_number 5;
  ignore @@ process_number 10;

  (* Chunk 4: Complex data with some changes between runs *)
  let%debug_sexp complex_operation (input : string) : (string * int) list =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    let words = String.split_on_char ' ' input in
    let result = List.mapi (fun i word -> (word, String.length word + i)) words in
    [%log timestamp, "Complex operation on:", input];
    result
  in

  ignore @@ complex_operation "this is a test string";
  ignore @@ complex_operation "another example with more words to process";
  Debug_runtime.finish_and_cleanup ()

(* Run 2: Similar to run 1 but with some intentional changes *)
let debug_run2 () =
  Random.init 43;

  (* Different seed to generate different timestamps *)
  let module Debug_runtime =
    (val Minidebug_runtime.debug_file ~values_first_mode:true ~backend:`Text
           ~prev_run_file:"debugger_large_diffs_run1.raw"
           ~diff_ignore_pattern:(Re.Pcre.re {|\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]|})
           "debugger_large_diffs_run2")
  in
  (* Chunk 1: Same as run1 but with different timestamps *)
  let%debug_sexp process_message (msg : string) : string =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    timestamp ^ " Processing: " ^ msg
  in
  ignore @@ process_message "hello";
  ignore @@ process_message "world";

  (* Chunk 2: Same function but with slightly different data *)
  let%debug_sexp process_data (size : int) : int list =
    let data = create_data_structure size in
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    [%log timestamp, "Processing data of size", (size : int)];
    data
  in
  ignore @@ process_data 5;
  ignore @@ process_data 11;

  (* Changed from 10 to 11 *)

  (* Chunk 3: Same nested functions but with a small change *)
  let%debug_sexp helper (x : int) : int =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    [%log timestamp, "Helper called with", (x : int)];
    x * 2
  in

  let%debug_sexp process_number (n : int) : int =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    [%log timestamp, "Processing number", (n : int)];
    let result = helper (n + 2) in
    (* Changed from n+1 to n+2 *)
    result + 3
  in

  ignore @@ process_number 5;
  ignore @@ process_number 10;

  (* Chunk 4: Same complex data with one different input *)
  let%debug_sexp complex_operation (input : string) : (string * int) list =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    let words = String.split_on_char ' ' input in
    let result = List.mapi (fun i word -> (word, String.length word + i)) words in
    [%log timestamp, "Complex operation on:", input];
    result
  in

  ignore @@ complex_operation "this is a test string";
  ignore
  @@ complex_operation "a completely different string with new words" (* Changed input *);
  Debug_runtime.finish_and_cleanup ()

(* Run 3: Test with additional chunks and more complex changes *)
let debug_run3 () =
  Random.init 44;

  (* Different seed again *)
  let module Debug_runtime =
    (val Minidebug_runtime.debug_file ~values_first_mode:true ~backend:`Text
           ~prev_run_file:"debugger_large_diffs_run2.raw"
           ~diff_ignore_pattern:(Re.Pcre.re {|\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\]|})
           "debugger_large_diffs_run3")
  in
  (* Chunk 1: Same as before *)
  let%debug_sexp process_message (msg : string) : string =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    timestamp ^ " Processing: " ^ msg
  in
  ignore @@ process_message "hello";
  ignore @@ process_message "world";

  (* Chunk 2: Now with an additional call *)
  let%debug_sexp process_data (size : int) : int list =
    let data = create_data_structure size in
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    [%log timestamp, "Processing data of size", (size : int)];
    data
  in
  ignore @@ process_data 5;
  ignore @@ process_data 11;
  ignore @@ process_data 15;

  (* Added a new call *)

  (* Chunk 3: Modified implementation *)
  let%debug_sexp helper (x : int) : int =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    [%log timestamp, "Helper called with", (x : int)];
    x * 3 (* Changed multiplier from 2 to 3 *)
  in

  let%debug_sexp process_number (n : int) : int =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    [%log timestamp, "Processing number", (n : int)];
    let result = helper (n + 2) in
    result + 5 (* Changed from +3 to +5 *)
  in

  ignore @@ process_number 5;
  ignore @@ process_number 10;

  (* Chunk 4: Same as run2 *)
  let%debug_sexp complex_operation (input : string) : (string * int) list =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    let words = String.split_on_char ' ' input in
    let result = List.mapi (fun i word -> (word, String.length word + i)) words in
    [%log timestamp, "Complex operation on:", input];
    result
  in

  ignore @@ complex_operation "this is a test string";
  ignore @@ complex_operation "a completely different string with new words";

  (* Chunk 5: New chunk not present in previous runs *)
  let%debug_sexp new_operation (a : int) (b : int) : int * int * int =
    let timestamp = random_string_with_timestamp (module Debug_runtime) () in
    [%log timestamp, "New operation with", (a : int), "and", (b : int)];
    (a + b, a * b, a - b)
  in

  ignore @@ new_operation 10 20;
  ignore @@ new_operation 5 7;
  Debug_runtime.finish_and_cleanup ()

(* Main function to run the appropriate test *)
let () =
  if Array.length Sys.argv > 1 then
    match Sys.argv.(1) with
    | "run1" -> debug_run1 ()
    | "run2" -> debug_run2 ()
    | "run3" -> debug_run3 ()
    | _ -> failwith "Usage: test_debug_large_diffs run1|run2|run3"
  else failwith "Usage: test_debug_large_diffs run1|run2|run3"
