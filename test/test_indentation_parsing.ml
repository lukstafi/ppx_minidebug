(* Test for indentation-based parsing of pretty-printed sexps *)

open! Sexplib0.Sexp_conv

let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "test_indentation_parsing" in
  fun () -> rt

(* Create types with long field names that will force multi-line formatting *)
type record_with_long_fields = {
  very_long_field_name_one: string;
  very_long_field_name_two: string;
  very_long_field_name_three: string;
} [@@deriving sexp]

let%debug_sexp test_multiline_record () : unit =
  (* Simpler record that should trigger multi-line formatting *)
  let r = {
    very_long_field_name_one = "value_one";
    very_long_field_name_two = "value_two";
    very_long_field_name_three = "value_three"
  } in
  [%log (r : record_with_long_fields)]

let%debug_sexp test_nested_list () : unit =
  (* Create a nested structure with long strings to trigger multi-line *)
  let data = [
    ("key_number_one_with_long_name", "This is a value with substantial length");
    ("key_number_two_also_very_long", "Another value that contributes to line length");
    ("key_three_similarly_lengthy", "Final value to ensure proper formatting")
  ] in
  [%log (data : (string * string) list)]

let () =
  test_multiline_record ();
  test_nested_list ();
  let db = Minidebug_client.Client.open_db "test_indentation_parsing.db" in
  Minidebug_client.Client.show_trace db;
  ()
