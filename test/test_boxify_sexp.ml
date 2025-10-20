(* Test for boxify_sexp functionality - demonstrates splitting large s-expressions *)

open! Sexplib0.Sexp_conv

let () =
  Printf.printf "=== Test structural splitting with threshold (size 10) ===\n%!";
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file "test_boxify_sexp" in
    fun () -> rt
  in
  let%debug_sexp test_small () : unit =
    (* Small sexp - will NOT be split (3 atoms < 10) *)
    [%log [ "This is the"; "2"; "log line" ]]
  in
  let%debug_sexp test_medium () : unit =
    (* Medium sexp - will be structurally split (11 atoms >= 10) *)
    [%log [ "item1"; "item2"; "item3"; "item4"; "item5"; "item6"; "item7"; "item8"; "item9"; "item10" ]]
  in
  let%debug_sexp test_large () : unit =
    (* Large sexp with nested structure - will be structurally split *)
    [%log [ ("a", 1); ("b", 2); ("c", 3); ("d", 4); ("e", 5); ("f", 6) ]]
  in
  test_small ();
  test_medium ();
  test_large ();
  let db = Minidebug_client.Client.open_db "test_boxify_sexp.db" in
  Minidebug_client.Client.show_trace db
    (Option.get @@ Minidebug_client.Client.get_latest_run db).run_id;
  Printf.printf "Test complete.\n%!"
