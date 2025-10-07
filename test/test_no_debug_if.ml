open Sexplib0.Sexp_conv

(* Setup database runtime *)
let _get_local_debug_runtime =
  let rt =
    Minidebug_db.debug_db_file ~print_entry_ids:true ~verbose_entry_ids:true
      "debugger_no_debug_if"
  in
  fun () -> rt

(* Test function that conditionally discards logs *)
let%debug_sexp compute (x : int) (y : int) : int =
  let module Debug_runtime = (val _get_local_debug_runtime ()) in
  let intermediate1 : int = x + 1 in
  let intermediate2 : int = y + 2 in
  (* If x is negative, discard this computation's logs *)
  Debug_runtime.no_debug_if (x < 0);
  let sum : int = intermediate1 + intermediate2 in
  sum

(* Test function without no_debug_if for comparison *)
let%debug_sexp compute_normal (x : int) (y : int) : int =
  let intermediate1 : int = x + 1 in
  let intermediate2 : int = y + 2 in
  let sum : int = intermediate1 + intermediate2 in
  sum

(* Run tests *)
let () =
  Printf.printf "Running no_debug_if test...\n";

  (* This should have full logs *)
  let result1 = compute 5 10 in
  Printf.printf "compute(5, 10) = %d\n" result1;

  (* This should discard all logs for this call (header + values removed from DB) *)
  let result2 = compute (-3) 7 in
  Printf.printf "compute(-3, 7) = %d\n" result2;

  (* This should have full logs for comparison *)
  let result3 = compute_normal 5 10 in
  Printf.printf "compute_normal(5, 10) = %d\n" result3;

  let module Debug_runtime = (val _get_local_debug_runtime ()) in
  Debug_runtime.finish_and_cleanup ();
  Printf.printf "Test complete. Database written to debugger_no_debug_if.db\n"
