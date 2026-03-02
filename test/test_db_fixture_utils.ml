let failf fmt = Printf.ksprintf failwith fmt

let latest_run_db_file ~base_name =
  let meta_db_path = base_name ^ "_meta.db" in
  if not (Sys.file_exists meta_db_path) then
    failf "Test setup failed: metadata DB %s not found" meta_db_path;
  let db = Sqlite3.db_open ~mode:`READONLY meta_db_path in
  let stmt =
    Sqlite3.prepare db "SELECT db_file FROM runs ORDER BY run_id DESC LIMIT 1"
  in
  let db_file =
    match Sqlite3.step stmt with
    | Sqlite3.Rc.ROW -> (
        match Sqlite3.column stmt 0 with
        | Sqlite3.Data.TEXT s -> s
        | _ -> failwith "Test setup failed: latest run has no db_file")
    | _ -> failwith "Test setup failed: no runs found in metadata DB"
  in
  Sqlite3.finalize stmt |> ignore;
  Sqlite3.db_close db |> ignore;
  db_file
