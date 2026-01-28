(** Test expandable long values feature *)

(* Set up debug runtime to write to debugger_long_values.db *)
let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_long_values" in
  fun () -> rt

type long_record = {
  field1 : string;
  field2 : string;
  field3 : string;
  field4 : string;
}
[@@deriving show]

(* Test function that logs a long value *)
let%debug_pp test_long_value () : long_record =
  let result : long_record =
    {
      field1 = "This is a very long string that should exceed the terminal width when rendered";
      field2 = "Another lengthy string field that contributes to the overall length";
      field3 = "Yet more text to ensure the value is definitely truncated";
      field4 = "Final field with additional text content";
    }
  in
  result

(* Test function with a very long string *)
let%debug_show test_very_long_string () : string =
  let long_string : string =
    String.make 200 'x' ^ " middle part " ^ String.make 200 'y'
  in
  long_string

let () =
  let _ = test_long_value () in
  let _ = test_very_long_string () in
  Printf.printf "Test complete. Database written to debugger_long_values.db\n"
