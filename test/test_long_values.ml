(* Test for long value expansion in TUI *)
open Minidebug_db

let sexp_of_string = Sexplib0.Sexp_conv.sexp_of_string
let sexp_of_int = Sexplib0.Sexp_conv.sexp_of_int

let _get_local_debug_runtime =
  let rt = debug_db_file ~log_level:9 "debugger_long_values" in
  fun () -> rt

(* Generate a long string that will exceed the long_value_threshold (80 chars) *)
let long_string () =
  "This is a very long string that should definitely exceed the threshold for " ^
  "long values in the TUI. When expanded, it should wrap across multiple lines " ^
  "to show the full content without truncation. This allows users to see the " ^
  "complete value instead of just seeing '...' at the end."

(* A function that produces a short value *)
let%debug_sexp short_value (x : int) : string =
  "Short: " ^ string_of_int x

(* A function that produces a long value *)
let%debug_sexp long_value (x : int) : string =
  long_string () ^ " (input=" ^ string_of_int x ^ ")"

(* A function with multiple long values *)
let%debug_sexp process_data (input : string) (factor : int) : string =
  let step1 : string = "Processing: " ^ input ^ " with detailed context information " ^
    "that spans well beyond the normal display width of the terminal" in
  let step2 : string = step1 ^ " and then we add even more text to make this " ^
    "value extremely long so it definitely needs expansion" in
  let result : string = step2 ^ " (factor=" ^ string_of_int factor ^ ")" in
  result

let () =
  let (_ : string) = short_value 42 in
  let (_ : string) = long_value 123 in
  let (_ : string) = short_value 99 in
  let (_ : string) = process_data "test input" 7 in
  let (_ : string) = long_value 456 in
  print_endline "Test complete. Database written to debugger_long_values.db"
