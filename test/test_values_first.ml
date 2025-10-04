(* Simple test to demonstrate values_first_mode *)

let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file ~elapsed_times:Microseconds "test_values_first" in
  fun () -> rt

let%debug_show rec factorial (n : int) : int =
  if n <= 1 then 1
  else n * factorial (n - 1)

let%debug_show add (x : int) (y : int) : int = x + y

let%debug_show compute (a : int) (b : int) : int =
  let sum = add a b in
  let result = factorial sum in
  result

let () =
  let _ = compute 3 2 in
  ()
