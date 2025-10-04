open Sexplib0.Sexp_conv

(* Setup database runtime *)
let _get_local_debug_runtime =
  let rt =
    Minidebug_db.debug_db_file ~print_entry_ids:true ~verbose_entry_ids:true "test_db"
  in
  fun () -> rt

(* Test functions *)
let%debug_sexp rec fib (n : int) : int =
  if n <= 1 then n
  else
    let a : int = fib (n - 1) in
    let b : int = fib (n - 2) in
    a + b

let%debug_sexp calculate (x : int) (y : int) : int * int =
  let sum : int = x + y in
  let product : int = x * y in
  (sum, product)

let%debug_sexp process_list (items : int list) : int list =
  List.map (fun x -> x * 2) items

(* Run tests *)
let () =
  Printf.printf "Running database backend test...\n";
  let result = fib 5 in
  Printf.printf "fib(5) = %d\n" result;

  let sum, prod = calculate 10 20 in
  Printf.printf "calculate(10, 20) = (%d, %d)\n" sum prod;

  let doubled = process_list [ 1; 2; 3; 4; 5 ] in
  Printf.printf "process_list([1;2;3;4;5]) = %s\n"
    (String.concat ";" (List.map string_of_int doubled));

  let module Debug_runtime = (val _get_local_debug_runtime ()) in
  Debug_runtime.finish_and_cleanup ();
  Printf.printf "Test complete. Database written to test_db.db\n"
