(* Test for boxify_sexp functionality - demonstrates splitting large s-expressions *)

open! Sexplib0.Sexp_conv

let () =
  Printf.printf "=== Test boxify with small threshold (boxify_sexp_from_size=2) ===\n%!";
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file ~boxify_sexp_from_size:2 "test_boxify_sexp" in
    fun () -> rt
  in
  let%debug_sexp test_boxify () : unit =
    [%log "This is the first log line"];
    [%log [ "This is the"; "2"; "log line" ]];
    [%log "This is the", 3, "or", 3.14, "log line"]
  in
  test_boxify ();
  let db = Minidebug_client.Client.open_db "test_boxify_sexp.db" in
  Minidebug_client.Client.show_trace db
    (Option.get @@ Minidebug_client.Client.get_latest_run db).run_id;
  Printf.printf "Test complete.\n%!"
