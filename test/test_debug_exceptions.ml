let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_exceptions" in
  fun () -> rt

exception Custom_error of string

let%debug_show failing_function (x : int) : int =
  if x < 0 then raise (Custom_error "negative input")
  else if x = 0 then raise Division_by_zero
  else 100 / x

let%debug_show nested_exception (y : int) : int =
  let z : int = failing_function y in
  z * 2

let%debug_show reraise_test (n : int) : int =
  try failing_function n with
  | Division_by_zero -> raise (Custom_error "caught division by zero")
  | e -> raise e

let () =
  (* Test 1: Simple exception *)
  print_endline "Test 1: Division by zero";
  (try
     let _ = failing_function 0 in
     ()
   with _ -> print_endline "Caught exception");

  (* Test 2: Nested exception *)
  print_endline "\nTest 2: Nested exception";
  (try
     let _ = nested_exception (-1) in
     ()
   with _ -> print_endline "Caught exception");

  (* Test 3: Re-raised exception (should only log once) *)
  print_endline "\nTest 3: Re-raised exception";
  (try
     let _ = reraise_test 0 in
     ()
   with _ -> print_endline "Caught exception");

  (* Test 4: Multiple calls with same exception type (should log each) *)
  print_endline "\nTest 4: Multiple exceptions";
  (try
     let _ = failing_function 0 in
     ()
   with _ -> print_endline "Caught first exception");
  (try
     let _ = failing_function (-1) in
     ()
   with _ -> print_endline "Caught second exception")
