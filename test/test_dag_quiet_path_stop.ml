open Sexplib0.Sexp_conv

type tree = Leaf of string | Node of string * tree list [@@deriving sexp]

let quiet_marker = "Node"

let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "debugger_dag_quiet_path_stop" in
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

let assert_headers_not_highlighted ~label ~results_table ~headers =
  List.iter
    (fun key ->
      if Hashtbl.mem results_table key then
        failf "%s: header should not be highlighted (%d, %d)" label (fst key) (snd key))
    headers

let () =
  let (_ : tree) = build_dag_value () in

  let db_path =
    Test_db_fixture_utils.latest_run_db_file ~base_name:"debugger_dag_quiet_path_stop"
  in
  let module Query =
    Minidebug_client.Query.Make (struct
      let db_path = db_path
    end)
  in

  let header_keys (entries : Minidebug_client.Query.entry list) =
    List.map
      (fun entry ->
        ( entry.Minidebug_client.Query.scope_id,
          entry.Minidebug_client.Query.seq_id ))
      entries
  in

  let find_first_quiet_duplicated_ancestor_scope ~start_scope_id =
    let visited = Hashtbl.create 32 in
    let quiet_regex = Re.Str.regexp_string quiet_marker in
    let rec bfs = function
      | [] -> None
      | scope_id :: rest ->
          if Hashtbl.mem visited scope_id then bfs rest
          else (
            Hashtbl.add visited scope_id ();
            let headers : Minidebug_client.Query.entry list =
              Query.find_scope_headers ~scope_id
            in
            let quiet_match =
              List.exists
                (fun entry ->
                  try
                    let _ =
                      Re.Str.search_forward quiet_regex
                        entry.Minidebug_client.Query.message 0
                    in
                    true
                  with Not_found -> (
                    match entry.Minidebug_client.Query.data with
                    | None -> false
                    | Some data -> (
                        try
                          let _ = Re.Str.search_forward quiet_regex data 0 in
                          true
                        with Not_found -> false)))
                headers
            in
            if quiet_match && List.length headers >= 2 then Some scope_id
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

  let target_headers = Query.find_scope_headers ~scope_id:needle_scope_id |> header_keys in
  if target_headers = [] then
    failf
      "Test setup failed: expected at least one header for target scope %d"
      needle_scope_id;

  let quiet_scope_id =
    match find_first_quiet_duplicated_ancestor_scope ~start_scope_id:needle_scope_id with
    | Some found -> found
    | None ->
        failf
          "Test setup failed: no duplicated quiet ancestor found for scope_id=%d"
          needle_scope_id
  in
  let quiet_headers = Query.find_scope_headers ~scope_id:quiet_scope_id |> header_keys in
  if List.length quiet_headers < 2 then
    failf
      "Test setup failed: expected quiet scope %d to have at least 2 headers, got %d"
      quiet_scope_id (List.length quiet_headers);

  let run_search_mode () =
    let completed_ref = ref false in
    let results_table = Hashtbl.create 128 in
    Query.populate_search_results ~search_term:"needle"
      ~quiet_path:(Some quiet_marker)
      ~search_order:Minidebug_client.Query.AscendingIds ~completed_ref ~results_table;
    if not !completed_ref then failwith "search did not complete";
    assert_headers_highlighted ~label:"search target" ~results_table ~headers:target_headers;
    assert_headers_not_highlighted ~label:"search quiet" ~results_table
      ~headers:quiet_headers
  in

  let run_extract_mode () =
    let completed_ref = ref false in
    let results_table = Hashtbl.create 128 in
    Query.populate_extract_search_results ~search_path:[ "needle" ]
      ~extraction_path:[ "needle" ] ~quiet_path:(Some quiet_marker) ~completed_ref
      ~results_table;
    if not !completed_ref then failwith "extract-search did not complete";
    assert_headers_highlighted ~label:"extract target" ~results_table ~headers:target_headers;
    assert_headers_not_highlighted ~label:"extract quiet" ~results_table
      ~headers:quiet_headers
  in

  run_search_mode ();
  run_extract_mode ()
