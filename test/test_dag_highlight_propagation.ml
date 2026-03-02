open Sexplib0.Sexp_conv

type tree = Leaf of string | Node of string * tree list [@@deriving sexp]

let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_dag_highlight_propagation" in
  fun () -> rt

let%debug_sexp build_dag_value () : tree =
  let shared = Node ("shared", [ Leaf "needle"; Leaf "context" ]) in
  Node ("root", [ Node ("left", [ shared ]); Node ("right", [ shared ]) ])

let failf fmt = Printf.ksprintf failwith fmt

let headers_for_child_scope ~db_path ~child_scope_id =
  let db = Sqlite3.db_open ~mode:`READONLY db_path in
  let stmt =
    Sqlite3.prepare db
      {|
      SELECT scope_id, seq_id
      FROM entries
      WHERE child_scope_id = ?
      ORDER BY scope_id, seq_id
    |}
  in
  Sqlite3.bind_int stmt 1 child_scope_id |> ignore;
  let rows = ref [] in
  let rec loop () =
    match Sqlite3.step stmt with
    | Sqlite3.Rc.ROW ->
        let scope_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0) in
        let seq_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 1) in
        rows := (scope_id, seq_id) :: !rows;
        loop ()
    | _ -> ()
  in
  loop ();
  Sqlite3.finalize stmt |> ignore;
  Sqlite3.db_close db |> ignore;
  List.rev !rows

let assert_headers_highlighted ~label ~results_table ~headers =
  List.iter
    (fun key ->
      if not (Hashtbl.mem results_table key) then
        failf "%s: missing highlighted header (%d, %d)" label (fst key) (snd key))
    headers

let () =
  let (_ : tree) = build_dag_value () in

  let db_path = "debugger_dag_highlight_propagation_1.db" in
  let module Q =
    Minidebug_client.Query.Make (struct
      let db_path = db_path
    end)
  in

  let needle_matches = Q.search_entries ~pattern:"needle" in
  let needle_parent_scope_id =
    match needle_matches with
    | entry :: _ -> entry.scope_id
    | [] -> failwith "Test setup failed: no value entry matched 'needle'"
  in

  let shared_headers =
    headers_for_child_scope ~db_path ~child_scope_id:needle_parent_scope_id
  in
  if List.length shared_headers < 2 then
    failf
      "Test setup failed: expected shared scope %d to have at least 2 headers, got %d"
      needle_parent_scope_id (List.length shared_headers);

  let run_search label search_order =
    let completed_ref = ref false in
    let results_table = Hashtbl.create 128 in
    Q.populate_search_results ~search_term:"needle" ~quiet_path:None ~search_order
      ~completed_ref ~results_table;
    if not !completed_ref then failf "%s: search did not complete" label;
    assert_headers_highlighted ~label ~results_table ~headers:shared_headers
  in

  run_search "ascending" Minidebug_client.Query.AscendingIds;
  run_search "descending" Minidebug_client.Query.DescendingIds;

  let completed_ref = ref false in
  let extract_results = Hashtbl.create 128 in
  Q.populate_extract_search_results ~search_path:[ "needle" ]
    ~extraction_path:[ "needle" ] ~quiet_path:None ~completed_ref
    ~results_table:extract_results;
  if not !completed_ref then failwith "extract-search did not complete";
  assert_headers_highlighted ~label:"extract" ~results_table:extract_results
    ~headers:shared_headers
