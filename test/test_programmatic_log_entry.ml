let db_file = "test_programmatic_log_entry.db"

let () =
  let _get_local_debug_runtime =
    let rt = Minidebug_db.debug_db_file db_file in
    fun () -> rt
  in
  let%diagn_show _logging_logic : unit =
    let rec loop logs =
      match logs with
      | "start" :: header :: tl ->
          let more =
            [%log_entry
              header;
              loop tl]
          in
          loop more
      | "end" :: tl -> tl
      | msg :: tl ->
          [%log msg];
          loop tl
      | [] -> []
    in
    ignore
    @@ loop
         [
           "preamble";
           "start";
           "header 1";
           "log 1";
           "start";
           "nested header";
           "log 2";
           "end";
           "log 3";
           "end";
           "start";
           "header 2";
           "log 4";
           "end";
           "postscript";
         ]
  in
  let db = Minidebug_client.Client.open_db db_file in
  let latest_run = Minidebug_client.Client.get_latest_run db |> Option.get in
  Minidebug_client.Client.show_trace db latest_run.run_id
