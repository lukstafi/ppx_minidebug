open Sexplib0.Sexp_conv

type tree = Leaf of string | Node of string * tree list [@@deriving sexp]

let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_dag_highlight_propagation" in
  fun () -> rt

let%debug_sexp build_dag_value () : tree =
  let shared =
    Node
      ( "shared",
        [
          Leaf "needle";
          Leaf "context_a";
          Leaf "context_b";
          Leaf "context_c";
          Leaf "context_d";
          Leaf "context_e";
        ] )
  in
  Node ("root", [ Node ("left", [ shared ]); Node ("right", [ shared ]) ])

let failf fmt = Printf.ksprintf failwith fmt

let assert_headers_highlighted ~label ~results_table ~headers =
  List.iter
    (fun key ->
      if not (Hashtbl.mem results_table key) then
        failf "%s: missing highlighted header (%d, %d)" label (fst key) (snd key))
    headers

let () =
  let (_ : tree) = build_dag_value () in

  let db_path =
    Test_db_fixture_utils.latest_run_db_file
      ~base_name:"debugger_dag_highlight_propagation"
  in
  let module Query =
    Minidebug_client.Query.Make (struct
      let db_path = db_path
    end)
  in

  let header_keys_of_entries (entries : Minidebug_client.Query.entry list) =
    List.map
      (fun entry ->
        ( entry.Minidebug_client.Query.scope_id,
          entry.Minidebug_client.Query.seq_id ))
      entries
  in

  let find_first_duplicated_ancestor_scope ~start_scope_id =
    let visited = Hashtbl.create 32 in
    let rec bfs = function
      | [] -> None
      | scope_id :: rest ->
          if Hashtbl.mem visited scope_id then bfs rest
          else (
            Hashtbl.add visited scope_id ();
            let headers = Query.find_scope_headers ~scope_id in
            if List.length headers >= 2 then Some scope_id
            else bfs (rest @ Query.get_parent_ids ~scope_id))
    in
    bfs [ start_scope_id ]
  in

  let needle_matches = Query.search_entries ~pattern:"needle" in
  let needle_scope_id =
    match needle_matches with
    | entry :: _ -> entry.Minidebug_client.Query.scope_id
    | [] -> failwith "Test setup failed: no value entry matched 'needle'"
  in

  let duplicated_scope_id =
    match find_first_duplicated_ancestor_scope ~start_scope_id:needle_scope_id with
    | Some found -> found
    | None ->
        failf
          "Test setup failed: no duplicated ancestor scope found for match scope_id=%d"
          needle_scope_id
  in
  let shared_headers =
    Query.find_scope_headers ~scope_id:duplicated_scope_id |> header_keys_of_entries
  in
  if List.length shared_headers < 2 then
    failf
      "Test setup failed: expected duplicated scope %d to have at least 2 headers, got %d"
      duplicated_scope_id (List.length shared_headers);

  let run_search label search_order =
    let completed_ref = ref false in
    let results_table = Hashtbl.create 128 in
    Query.populate_search_results ~search_term:"needle" ~quiet_path:None ~search_order
      ~completed_ref ~results_table;
    if not !completed_ref then failf "%s: search did not complete" label;
    assert_headers_highlighted ~label ~results_table ~headers:shared_headers
  in

  run_search "ascending" Minidebug_client.Query.AscendingIds;
  run_search "descending" Minidebug_client.Query.DescendingIds;

  let completed_ref = ref false in
  let extract_results = Hashtbl.create 128 in
  Query.populate_extract_search_results ~search_path:[ "needle" ]
    ~extraction_path:[ "needle" ] ~quiet_path:None ~completed_ref
    ~results_table:extract_results;
  if not !completed_ref then failwith "extract-search did not complete";
  assert_headers_highlighted ~label:"extract" ~results_table:extract_results
    ~headers:shared_headers
