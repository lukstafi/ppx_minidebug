(* Test for ellipsis functionality in TUI *)
open Minidebug_db

let sexp_of_int = Sexplib0.Sexp_conv.sexp_of_int

let _get_local_debug_runtime =
  let rt = debug_db_file ~log_level:9 "debugger_ellipsis" in
  fun () -> rt

(* Create many functions to generate many entries *)
let%debug_sexp entry_1 (x : int) : int = x + 1
let%debug_sexp entry_2 (x : int) : int = x + 2
let%debug_sexp entry_3 (x : int) : int = x + 3
let%debug_sexp entry_4 (x : int) : int = x + 4
let%debug_sexp entry_5 (x : int) : int = x + 5
let%debug_sexp entry_6 (x : int) : int = x + 6
let%debug_sexp entry_7 (x : int) : int = x + 7
let%debug_sexp entry_8 (x : int) : int = x + 8
let%debug_sexp entry_9 (x : int) : int = x + 9
let%debug_sexp entry_10 (x : int) : int = x + 10

(* A highlighted target in the middle *)
let%debug_sexp target_entry (x : int) : int = x * 100

let%debug_sexp entry_11 (x : int) : int = x + 11
let%debug_sexp entry_12 (x : int) : int = x + 12
let%debug_sexp entry_13 (x : int) : int = x + 13
let%debug_sexp entry_14 (x : int) : int = x + 14
let%debug_sexp entry_15 (x : int) : int = x + 15
let%debug_sexp entry_16 (x : int) : int = x + 16
let%debug_sexp entry_17 (x : int) : int = x + 17
let%debug_sexp entry_18 (x : int) : int = x + 18
let%debug_sexp entry_19 (x : int) : int = x + 19
let%debug_sexp entry_20 (x : int) : int = x + 20

let () =
  let (_ : int) = entry_1 1 in
  let (_ : int) = entry_2 2 in
  let (_ : int) = entry_3 3 in
  let (_ : int) = entry_4 4 in
  let (_ : int) = entry_5 5 in
  let (_ : int) = entry_6 6 in
  let (_ : int) = entry_7 7 in
  let (_ : int) = entry_8 8 in
  let (_ : int) = entry_9 9 in
  let (_ : int) = entry_10 10 in
  let (_ : int) = target_entry 5 in  (* This will be our search target *)
  let (_ : int) = entry_11 11 in
  let (_ : int) = entry_12 12 in
  let (_ : int) = entry_13 13 in
  let (_ : int) = entry_14 14 in
  let (_ : int) = entry_15 15 in
  let (_ : int) = entry_16 16 in
  let (_ : int) = entry_17 17 in
  let (_ : int) = entry_18 18 in
  let (_ : int) = entry_19 19 in
  let (_ : int) = entry_20 20 in
  print_endline "Test complete. Database written to debugger_ellipsis.db"
