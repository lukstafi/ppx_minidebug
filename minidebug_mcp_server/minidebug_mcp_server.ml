(** MCP Server for ppx_minidebug database traces *)

open Mcp_sdk

(* Helper for extracting string parameter from JSON *)
let get_string_param json name =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt name fields with
      | Some (`String value) -> value
      | _ -> failwith (Printf.sprintf "Missing or invalid parameter: %s" name))
  | _ -> failwith "Expected JSON object"

(* Helper for extracting optional string parameter *)
let get_optional_string_param json name =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt name fields with
      | Some (`String value) -> Some value
      | Some `Null | None -> None
      | _ -> failwith (Printf.sprintf "Invalid parameter type: %s" name))
  | _ -> failwith "Expected JSON object"

(* Helper for extracting optional int parameter *)
let get_optional_int_param json name =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt name fields with
      | Some (`Int value) -> Some value
      | Some `Null | None -> None
      | _ -> failwith (Printf.sprintf "Invalid parameter type: %s" name))
  | _ -> failwith "Expected JSON object"

(* Helper for extracting optional bool parameter *)
let get_optional_bool_param json name =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt name fields with
      | Some (`Bool value) -> Some value
      | Some `Null | None -> None
      | _ -> failwith (Printf.sprintf "Invalid parameter type: %s" name))
  | _ -> failwith "Expected JSON object"

(** Session state for MCP server *)
type session_state = {
  db_path : string;
  query : (module Minidebug_client.Query.S); (* First-class module with DB connection *)
  search_cache : (string, (int * int, bool) Hashtbl.t) Hashtbl.t;
      (* pattern -> results_table: (scope_id, seq_id) -> is_match *)
}

(** Current server session - None means no database loaded *)
let current_session : session_state option ref = ref None

(** Get current session or fail *)
let get_session () =
  match !current_session with
  | Some session -> session
  | None -> failwith "No database initialized. Use minidebug/init-db first."

(** Initialize or reinitialize session with a database *)
let init_session db_path =
  (* Create Query module for this database *)
  let module Q = Minidebug_client.Query.Make (struct
    let db_path = db_path
  end) in
  let query = (module Q : Minidebug_client.Query.S) in
  let search_cache = Hashtbl.create 16 in
  current_session := Some { db_path; query; search_cache };
  Logs.info (fun m -> m "Session initialized with database: %s" db_path)

(** Get or compute search results with caching.
    Cache key includes pattern and quiet_path to ensure correct results. *)
let get_search_results session ~pattern ~quiet_path =
  (* Create cache key from pattern + quiet_path *)
  let cache_key =
    match quiet_path with
    | None -> pattern
    | Some qp -> Printf.sprintf "%s|quiet:%s" pattern qp
  in

  (* Check cache first *)
  match Hashtbl.find_opt session.search_cache cache_key with
  | Some cached_results ->
      Logs.debug (fun m -> m "Using cached search results for pattern: %s" pattern);
      cached_results
  | None ->
      (* Cache miss - run search and cache results *)
      Logs.debug (fun m -> m "Cache miss, running search for pattern: %s" pattern);
      let module Q = (val session.query : Minidebug_client.Query.S) in
      let completed_ref = ref false in
      let results_table = Hashtbl.create 1024 in
      Q.populate_search_results ~search_term:pattern ~quiet_path
        ~search_order:Minidebug_client.Query.AscendingIds ~completed_ref ~results_table;
      (* Cache the results *)
      Hashtbl.add session.search_cache cache_key results_table;
      results_table

(* Create the MCP server *)
let create_server ?db_path () =
  (* Initialize session if db_path provided *)
  (match db_path with Some path -> init_session path | None -> ());

  let server = create_server ~name:"ppx_minidebug MCP Server" ~version:"0.1.0" () in
  let server = configure_server server ~with_tools:true ~with_resources:false () in

  (* Tool: init-db - Initialize or reinitialize database session *)
  let _ =
    add_tool server ~name:"minidebug/init-db"
      ~description:
        "Initialize or reinitialize the MCP server session with a database. This must be \
         called before any other operations if no database was specified at server startup. \
         Can also be used to switch to a different database."
      ~schema_properties:
        [ ("db_path", "string", "Path to the ppx_minidebug database file (.db)") ]
      ~schema_required:[ "db_path" ]
      (fun args ->
         try
           let db_path = get_string_param args "db_path" in

           (* Validate database exists and is readable *)
           if not (Sys.file_exists db_path) then
             failwith (Printf.sprintf "Database file not found: %s" db_path);

           (* Initialize session *)
           init_session db_path;

           Tool.create_tool_result
             [
               Mcp.make_text_content
                 (Printf.sprintf "Successfully initialized session with database: %s" db_path);
             ]
             ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in init-db: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: list-runs - List all trace runs in database *)
  let _ =
    add_tool server ~name:"minidebug/list-runs"
      ~description:"List all trace runs in the database with metadata"
      ~schema_properties:[] ~schema_required:[]
      (fun _args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in
           let runs = Q.get_runs () in

           (* Convert runs to JSON *)
           let runs_json =
             `List
               (List.map
                  (fun (run : Minidebug_client.Query.run_info) ->
                    `Assoc
                      [
                        ("run_id", `Int run.run_id);
                        ("timestamp", `String run.timestamp);
                        ("elapsed_ns", `Int run.elapsed_ns);
                        ("command_line", `String run.command_line);
                        ( "run_name",
                          match run.run_name with
                          | Some name -> `String name
                          | None -> `Null );
                      ])
                  runs)
           in

           Tool.create_tool_result
             [
               Mcp.make_text_content
                 (Yojson.Safe.pretty_to_string
                    (`Assoc [ ("runs", runs_json); ("count", `Int (List.length runs)) ]));
             ]
             ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in list-runs: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: stats - Show database statistics *)
  let _ =
    add_tool server ~name:"minidebug/stats"
      ~description:"Show database statistics including size and deduplication metrics"
      ~schema_properties:[] ~schema_required:[]
      (fun _args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in

           (* Capture stats output using buffer-backed formatter *)
           let buffer = Buffer.create 1024 in
           let fmt = Format.formatter_of_buffer buffer in

           (* Get stats and format them *)
           let stats = Q.get_stats () in
           Format.fprintf fmt "Database Statistics\n";
           Format.fprintf fmt "===================\n";
           Format.fprintf fmt "Total entries: %d\n" stats.total_entries;
           Format.fprintf fmt "Total value references: %d\n" stats.total_values;
           Format.fprintf fmt "Unique values: %d\n" stats.unique_values;
           Format.fprintf fmt "Deduplication: %.1f%%\n" stats.dedup_percentage;
           Format.fprintf fmt "Database size: %d KB\n" stats.database_size_kb;
           Format.pp_print_flush fmt ();

           let stats_text = Buffer.contents buffer in

           Tool.create_tool_result [ Mcp.make_text_content stats_text ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in stats: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: show-trace - Show full trace tree *)
  let _ =
    add_tool server ~name:"minidebug/show-trace"
      ~description:
        "Show full trace tree for a run. Returns formatted text output suitable for \
         viewing."
      ~schema_properties:
        [
          ("run_id", "integer", "Run ID to show (optional, defaults to latest)");
          ("show_scope_ids", "boolean", "Show scope IDs (optional, default false)");
          ("show_times", "boolean", "Show elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum depth to display (optional)");
          ( "values_first_mode",
            "boolean",
            "Show values first (optional, default false)" );
        ]
      ~schema_required:[]
      (fun args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in

           let _run_id = get_optional_int_param args "run_id" in
           let show_scope_ids =
             Option.value (get_optional_bool_param args "show_scope_ids") ~default:false
           in
           let show_times =
             Option.value (get_optional_bool_param args "show_times") ~default:false
           in
           let max_depth = get_optional_int_param args "max_depth" in
           let values_first_mode =
             Option.value (get_optional_bool_param args "values_first_mode")
               ~default:false
           in

           (* Get latest run for summary *)
           let runs = Q.get_runs () in
           let latest_run =
             (match Q.get_latest_run_id () with
             | Some run_id -> List.find_opt (fun r -> r.Minidebug_client.Query.run_id = run_id) runs
             | None -> None)
             |> Option.get (* Safe: would have errored if no runs *)
           in

           (* Capture trace output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           (* Generate run summary *)
           Format.fprintf fmt "Run #%d\n" latest_run.run_id;
           Format.fprintf fmt "Timestamp: %s\n" latest_run.timestamp;
           Format.fprintf fmt "Command: %s\n" latest_run.command_line;
           Format.fprintf fmt "Elapsed: %s\n\n"
             (Minidebug_client.Renderer.format_elapsed_ns latest_run.elapsed_ns);

           (* Generate trace *)
           let roots = Q.get_root_entries ~with_values:false in
           let trees = Minidebug_client.Renderer.build_tree (module Q) ?max_depth roots in
           let rendered =
             Minidebug_client.Renderer.render_tree ~show_scope_ids ~show_times ~max_depth ~values_first_mode trees
           in
           Format.fprintf fmt "%s" rendered;
           Format.pp_print_flush fmt ();

           let trace_text = Buffer.contents buffer in

           Tool.create_tool_result [ Mcp.make_text_content trace_text ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in show-trace: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: search-tree - Search with full tree context (best for LLM analysis) *)
  let _ =
    add_tool server ~name:"minidebug/search-tree"
      ~description:
        "Search entries with full ancestor tree context. Returns formatted text showing \
         each match with its complete path from root. This is the recommended search \
         tool for AI assistants to understand code execution flow."
      ~schema_properties:
        [
          ("pattern", "string", "Regex pattern to search for in entry messages");
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum tree depth (optional)");
          ( "quiet_path",
            "string",
            "Stop ancestor propagation at pattern (optional)" );
          ("limit", "integer", "Limit number of results (optional)");
          ("offset", "integer", "Skip first n results (optional)");
        ]
      ~schema_required:[ "pattern" ]
      (fun args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in

           let pattern = get_string_param args "pattern" in
           let show_times =
             Option.value (get_optional_bool_param args "show_times") ~default:false
           in
           let max_depth = get_optional_int_param args "max_depth" in
           let quiet_path = get_optional_string_param args "quiet_path" in
           let limit = get_optional_int_param args "limit" in
           let offset = get_optional_int_param args "offset" in

           (* Capture search output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           (* Get search results (cached or fresh) *)
           let results_table = get_search_results session ~pattern ~quiet_path in

           (* Extract matching entries from hash table *)
           let all_matching_scope_ids =
             Hashtbl.fold
               (fun (scope_id, _seq_id) is_match acc ->
                 if is_match then scope_id :: acc else acc)
               results_table []
             |> List.sort_uniq compare
           in

           (* Get all entries from DB and filter to only those in results_table *)
           let filtered_entries = Q.get_entries_from_results ~results_table in

           (* Build tree from filtered entries *)
           let all_trees = Minidebug_client.Renderer.build_tree_from_entries filtered_entries in

           (* Apply pagination at the tree level (root scopes only) *)
           let trees =
             let t = all_trees in
             let t = match offset with
               | None -> t
               | Some off ->
                   if off < List.length t then
                     List.filteri (fun i _ -> i >= off) t
                   else []
             in
             match limit with
             | None -> t
             | Some lim ->
                 if lim >= List.length t then t
                 else List.filteri (fun i _ -> i < lim) t
           in

           (* Output *)
           let total_scopes = List.length all_matching_scope_ids in
           let total_trees = List.length all_trees in
           let shown_trees = List.length trees in
           let start_idx = Option.value offset ~default:0 in
           (if limit <> None || offset <> None then
              Format.fprintf fmt
                "Found %d matching scopes for pattern '%s', %d root trees (showing trees \
                 %d-%d)\n\
                 \n"
                total_scopes pattern total_trees start_idx (start_idx + shown_trees)
            else
              Format.fprintf fmt "Found %d matching scopes for pattern '%s'\n\n" total_scopes
                pattern);
           let rendered =
             Minidebug_client.Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
               ~values_first_mode:true trees
           in
           Format.fprintf fmt "%s" rendered;
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in

           Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in search-tree: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: search-subtree - Search showing only matching subtrees *)
  let _ =
    add_tool server ~name:"minidebug/search-subtree"
      ~description:
        "Search entries and show only matching subtrees (pruned). Returns each match \
         with its descendants but prunes non-matching branches."
      ~schema_properties:
        [
          ("pattern", "string", "Regex pattern to search for");
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum depth from match (optional)");
          ("limit", "integer", "Limit number of results (optional)");
        ]
      ~schema_required:[ "pattern" ]
      (fun args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in

           let pattern = get_string_param args "pattern" in
           let show_times =
             Option.value (get_optional_bool_param args "show_times") ~default:false
           in
           let max_depth = get_optional_int_param args "max_depth" in
           let limit = get_optional_int_param args "limit" in

           (* Capture search output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           (* Get search results (cached or fresh) *)
           let results_table = get_search_results session ~pattern ~quiet_path:None in

           (* Get entries from results_table (includes matches and propagated ancestors) *)
           let filtered_entries = Q.get_entries_from_results ~results_table in
           let full_trees = Minidebug_client.Renderer.build_tree_from_entries filtered_entries in

           (* Prune tree: keep only nodes that have matches in their subtree *)
           let rec prune_tree node =
             let entry = node.Minidebug_client.Renderer.entry in
             (* Check if this entry is a match *)
             let is_match = Hashtbl.mem results_table (entry.scope_id, entry.seq_id) in
             (* Recursively prune children *)
             let pruned_children =
               List.filter_map prune_tree node.children in
             (* Keep this node if it's a match OR if any child survived pruning *)
             if is_match || pruned_children <> [] then
               Some { node with Minidebug_client.Renderer.children = pruned_children }
             else None
           in

           let all_pruned_trees = List.filter_map prune_tree full_trees in

           (* Apply pagination to pruned trees (at root level) *)
           let pruned_trees =
             let trees = all_pruned_trees in
             let trees = match limit with
               | None -> trees
               | Some lim ->
                   if lim >= List.length trees then trees
                   else List.filteri (fun i _ -> i < lim) trees
             in
             trees
           in

           (* Count actual matches (not propagated ancestors) *)
           let match_count =
             Hashtbl.fold
               (fun _key is_match acc -> if is_match then acc + 1 else acc)
               results_table 0
           in

           (* Output *)
           let total_trees = List.length all_pruned_trees in
           let shown_trees = List.length pruned_trees in
           if limit <> None then
             Format.fprintf fmt
               "Found %d matches for pattern '%s', %d root trees (showing trees 0-%d):\n\n"
               match_count pattern total_trees shown_trees
           else
             Format.fprintf fmt
               "Found %d matches for pattern '%s', showing %d pruned subtrees:\n\n" match_count
               pattern total_trees;
           let rendered =
             Minidebug_client.Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
               ~values_first_mode:true pruned_trees
           in
           Format.fprintf fmt "%s" rendered;
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in

           Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in search-subtree: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: show-scope - Show specific scope with descendants *)
  let _ =
    add_tool server ~name:"minidebug/show-scope"
      ~description:"Show a specific scope by ID with its descendants and optional ancestors"
      ~schema_properties:
        [
          ("scope_id", "integer", "Scope ID to show");
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum depth from scope (optional)");
          ("show_ancestors", "boolean", "Include ancestor path (optional, default true)");
        ]
      ~schema_required:[ "scope_id" ]
      (fun args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in

           let scope_id =
             match get_optional_int_param args "scope_id" with
             | Some id -> id
             | None -> failwith "scope_id is required"
           in
           let show_times =
             Option.value (get_optional_bool_param args "show_times") ~default:false
           in
           let max_depth = get_optional_int_param args "max_depth" in
           let show_ancestors =
             Option.value (get_optional_bool_param args "show_ancestors") ~default:true
           in

           (* Capture scope output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           if show_ancestors then (
             (* Show path from root to this scope *)
             let ancestors = Q.get_ancestors ~scope_id in
             let filtered_entries = Q.get_entries_for_scopes ~scope_ids:ancestors in
             let trees = Minidebug_client.Renderer.build_tree_from_entries filtered_entries in
             Format.fprintf fmt "Ancestor path to scope %d:\n\n" scope_id;
             let rendered =
               Minidebug_client.Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
                 ~values_first_mode:true trees
             in
             Format.fprintf fmt "%s" rendered
           ) else (
             (* Show just this scope and descendants *)
             let children = Q.get_scope_children ~parent_scope_id:scope_id in
             Format.fprintf fmt "Scope %d contents:\n\n" scope_id;
             let rendered = Minidebug_client.Renderer.render_entries_json children in
             Format.fprintf fmt "%s\n" rendered
           );
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in

           Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in show-scope: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: get-ancestors - Get ancestor chain for navigation *)
  let _ =
    add_tool server ~name:"minidebug/get-ancestors"
      ~description:"Get the chain of ancestor scope IDs from root to the target scope"
      ~schema_properties:[ ("scope_id", "integer", "Scope ID to get ancestors for") ]
      ~schema_required:[ "scope_id" ]
      (fun args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in

           let scope_id =
             match get_optional_int_param args "scope_id" with
             | Some id -> id
             | None -> failwith "scope_id is required"
           in

           (* Capture ancestors output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           (* Get all ancestor paths *)
           let all_paths = Q.get_all_ancestor_paths ~scope_id in

           (* Fetch header entries for ancestors *)
           let get_entry_for_scope ancestor_id = Q.find_scope_header ~scope_id:ancestor_id in

           if List.length all_paths = 1 then (
             Format.fprintf fmt "Ancestor path to scope %d:\n\n" scope_id;
             List.iter
               (fun ancestor_id ->
                 match get_entry_for_scope ancestor_id with
                 | Some entry ->
                     let loc_str = match entry.Minidebug_client.Query.location with
                       | Some loc -> Printf.sprintf " @ %s" loc
                       | None -> ""
                     in
                     Format.fprintf fmt "  #%d [%s] %s%s\n"
                       ancestor_id entry.Minidebug_client.Query.entry_type entry.Minidebug_client.Query.message loc_str
                 | None -> ())
               (List.hd all_paths)
           ) else (
             (* Multiple paths - simplified version showing just scope IDs *)
             Format.fprintf fmt "Found %d ancestor paths to scope %d:\n\n"
               (List.length all_paths) scope_id;
             List.iteri (fun i path ->
               Format.fprintf fmt "Path %d: %s\n" (i+1)
                 (String.concat " -> " (List.map string_of_int path))
             ) all_paths
           );
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in

           Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in get-ancestors: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: get-children - Get child scope IDs for navigation *)
  let _ =
    add_tool server ~name:"minidebug/get-children"
      ~description:"Get the list of child scope IDs for a given scope"
      ~schema_properties:[ ("scope_id", "integer", "Scope ID to get children for") ]
      ~schema_required:[ "scope_id" ]
      (fun args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in

           let scope_id =
             match get_optional_int_param args "scope_id" with
             | Some id -> id
             | None -> failwith "scope_id is required"
           in

           (* Capture children output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           (* Get children and extract child scope IDs *)
           let children = Q.get_scope_children ~parent_scope_id:scope_id in
           let child_scope_ids =
             List.filter_map
               (fun e ->
                 match e.Minidebug_client.Query.child_scope_id with Some id -> Some id | None -> None)
               children
             |> List.sort_uniq compare
           in
           Format.fprintf fmt "Child scopes of %d: [ %s ]\n" scope_id
             (String.concat ", " (List.map string_of_int child_scope_ids));
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in

           Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in get-children: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: show-subtree - Show subtree rooted at scope with ancestor path *)
  let _ =
    add_tool server ~name:"minidebug/show-subtree"
      ~description:
        "Show subtree rooted at a specific scope with optional ancestor path. Max depth is \
         INCREMENTAL from the target scope."
      ~schema_properties:
        [
          ("scope_id", "integer", "Scope ID to show subtree for");
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ( "max_depth",
            "integer",
            "Maximum INCREMENTAL depth from scope (optional, relative to target)" );
          ("show_ancestors", "boolean", "Include ancestor path (optional, default true)");
        ]
      ~schema_required:[ "scope_id" ]
      (fun args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in

           let scope_id =
             match get_optional_int_param args "scope_id" with
             | Some id -> id
             | None -> failwith "scope_id is required"
           in
           let show_times =
             Option.value (get_optional_bool_param args "show_times") ~default:false
           in
           let max_depth = get_optional_int_param args "max_depth" in
           let show_ancestors =
             Option.value (get_optional_bool_param args "show_ancestors") ~default:true
           in

           (* Capture subtree output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           if show_ancestors then (
             (* Get ancestor chain and build tree from filtered entries *)
             let ancestors = Q.get_ancestors ~scope_id in
             let filtered_entries = Q.get_entries_for_scopes ~scope_ids:ancestors in
             let trees = Minidebug_client.Renderer.build_tree_from_entries filtered_entries in

             Format.fprintf fmt "Subtree for scope %d (with ancestor path):\n\n" scope_id;
             let rendered =
               Minidebug_client.Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
                 ~values_first_mode:true trees
             in
             Format.fprintf fmt "%s" rendered
           ) else (
             (* Just show the subtree starting at scope_id *)
             (* Get all entries for this scope and its descendants *)
             let rec get_subtree_scope_ids sid =
               let children = Q.get_scope_children ~parent_scope_id:sid in
               let child_ids = List.filter_map
                 (fun e -> e.Minidebug_client.Query.child_scope_id)
                 children
               in
               sid :: List.concat_map get_subtree_scope_ids child_ids
             in
             let all_scope_ids = get_subtree_scope_ids scope_id in
             let filtered_entries = Q.get_entries_for_scopes ~scope_ids:all_scope_ids in
             let trees = Minidebug_client.Renderer.build_tree_from_entries filtered_entries in

             Format.fprintf fmt "Subtree for scope %d:\n\n" scope_id;
             let rendered =
               Minidebug_client.Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
                 ~values_first_mode:true trees
             in
             Format.fprintf fmt "%s" rendered
           );
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in

           Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in show-subtree: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: search-at-depth - Search summary at specific depth *)
  let _ =
    add_tool server ~name:"minidebug/search-at-depth"
      ~description:
        "Search and show summary at a specific depth (TUI-like view). Good for large \
         traces where you want to see matches organized by depth level."
      ~schema_properties:
        [
          ("pattern", "string", "Regex pattern to search for");
          ("depth", "integer", "Depth level to show summary at");
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ( "quiet_path",
            "string",
            "Stop ancestor propagation at pattern (optional)" );
        ]
      ~schema_required:[ "pattern"; "depth" ]
      (fun args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in

           let pattern = get_string_param args "pattern" in
           let depth =
             match get_optional_int_param args "depth" with
             | Some d -> d
             | None -> failwith "depth is required"
           in
           let show_times =
             Option.value (get_optional_bool_param args "show_times") ~default:false
           in
           let quiet_path = get_optional_string_param args "quiet_path" in

           (* Capture search output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           (* Get search results (cached or fresh) *)
           let results_table = get_search_results session ~pattern ~quiet_path in

           (* Get entries from results_table and filter to specified depth *)
           let filtered_entries = Q.get_entries_from_results ~results_table in
           let depth_entries =
             List.filter (fun e -> e.Minidebug_client.Query.depth = depth) filtered_entries
             |> List.sort_uniq (fun a b -> compare a.Minidebug_client.Query.scope_id b.Minidebug_client.Query.scope_id)
           in

           (* For deduplication, keep only unique scope_ids at this depth *)
           let seen = Hashtbl.create 256 in
           let unique_entries =
             List.filter
               (fun e ->
                 match e.Minidebug_client.Query.child_scope_id with
                 | Some id ->
                     if Hashtbl.mem seen id then false
                     else (
                       Hashtbl.add seen id ();
                       true)
                 | None -> true)
               depth_entries
           in

           (* Count actual matches (not propagated ancestors) *)
           let match_count =
             Hashtbl.fold
               (fun _key is_match acc -> if is_match then acc + 1 else acc)
               results_table 0
           in

           (* Output *)
           Format.fprintf fmt
             "Found %d matches for pattern '%s', showing %d unique entries at depth %d:\n\n"
             match_count pattern (List.length unique_entries) depth;
           List.iter
             (fun entry ->
               Format.fprintf fmt "#%d [%s] %s" entry.Minidebug_client.Query.scope_id entry.entry_type
                 entry.message;
               (match entry.location with
               | Some loc -> Format.fprintf fmt " @ %s" loc
               | None -> ());
               (if show_times then
                  match Minidebug_client.Renderer.elapsed_time entry with
                  | Some elapsed ->
                      Format.fprintf fmt " <%s>" (Minidebug_client.Renderer.format_elapsed_ns elapsed)
                  | None -> ());
               Format.fprintf fmt "\n")
             unique_entries;
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in

           Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in search-at-depth: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: search-intersection - Find scopes matching all patterns *)
  let _ =
    add_tool server ~name:"minidebug/search-intersection"
      ~description:
        "Find scopes that match ALL provided patterns (intersection). Supports 2-4 \
         patterns. Returns full tree context for each matching scope."
      ~schema_properties:
        [
          ("patterns", "array", "Array of 2-4 regex patterns (all must match)");
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum tree depth (optional)");
          ( "quiet_path",
            "string",
            "Stop ancestor propagation at pattern (optional)" );
          ("limit", "integer", "Limit number of results (optional)");
          ("offset", "integer", "Skip first n results (optional)");
        ]
      ~schema_required:[ "patterns" ]
      (fun args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in

           let patterns =
             match args with
             | `Assoc fields -> (
                 match List.assoc_opt "patterns" fields with
                 | Some (`List items) ->
                     List.map
                       (function
                         | `String s -> s
                         | _ -> failwith "patterns must be array of strings")
                       items
                 | _ -> failwith "patterns must be an array")
             | _ -> failwith "Expected JSON object"
           in

           if List.length patterns < 2 || List.length patterns > 4 then
             failwith "search-intersection requires 2-4 patterns";

           let show_times =
             Option.value (get_optional_bool_param args "show_times") ~default:false
           in
           let _max_depth = get_optional_int_param args "max_depth" in
           let quiet_path = get_optional_string_param args "quiet_path" in
           let limit = get_optional_int_param args "limit" in
           let offset = get_optional_int_param args "offset" in

           (* Capture search output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           (* Run separate search for each pattern (using cache) *)
           let all_results_tables =
             List.map
               (fun pattern ->
                 let results_table = get_search_results session ~pattern ~quiet_path in
                 (pattern, results_table))
               patterns
           in

           (* Extract scope IDs that actually match (not just propagated ancestors) from each search *)
           let matching_scope_ids_per_pattern =
             List.map
               (fun (pattern, results_table) ->
                 let scope_ids =
                   Hashtbl.fold
                     (fun (scope_id, _seq_id) is_match acc ->
                       if is_match then scope_id :: acc else acc)
                     results_table []
                   |> List.sort_uniq compare
                 in
                 (pattern, scope_ids))
               all_results_tables
           in

           (* Compute LCAs for all combinations of matches (one per pattern) *)
           let rec cartesian_product = function
             | [] -> [ [] ]
             | (pattern, ids) :: rest ->
                 let rest_product = cartesian_product rest in
                 List.concat_map
                   (fun id -> List.map (fun combo -> (pattern, id) :: combo) rest_product)
                   ids
           in

           let all_combinations = cartesian_product matching_scope_ids_per_pattern in

           (* Compute LCA for each combination *)
           let lcas =
             List.concat_map
               (fun combo ->
                 let scope_ids = List.map snd combo in
                 match Q.lowest_common_ancestor scope_ids with
                 | Some lca -> [ lca ]
                 | None ->
                     (* No common ancestor - scopes are in separate root trees *)
                     List.map (fun id -> Q.get_root_scope id) scope_ids)
               all_combinations
             |> List.sort_uniq compare
           in

           (* Get entries for LCA scopes *)
           let lca_entries =
             List.filter_map (fun lca_scope_id -> Q.find_scope_header ~scope_id:lca_scope_id)
               lcas
           in

           (* Apply pagination to LCA list *)
           let paginated_lca_entries =
             let entries = lca_entries in
             let entries = match offset with
               | None -> entries
               | Some off ->
                   if off < List.length entries then
                     List.filteri (fun i _ -> i >= off) entries
                   else []
             in
             match limit with
             | None -> entries
             | Some lim ->
                 if lim >= List.length entries then entries
                 else List.filteri (fun i _ -> i < lim) entries
           in

           (* Output *)
           let total_lcas = List.length lcas in
           let shown_lcas = List.length paginated_lca_entries in
           let start_idx = Option.value offset ~default:0 in
           let pattern_str = String.concat " AND " (List.map (Printf.sprintf "'%s'") patterns) in

           if limit <> None || offset <> None then
             Format.fprintf fmt
               "Found %d smallest subtrees containing all patterns (%s) (showing %d-%d):\n\n"
               total_lcas pattern_str start_idx (start_idx + shown_lcas)
           else
             Format.fprintf fmt
               "Found %d smallest subtrees containing all patterns (%s):\n\n" total_lcas
               pattern_str;

           (* Show per-pattern match counts *)
           Format.fprintf fmt "Per-pattern match counts:\n";
           List.iter
             (fun (pattern, scope_ids) ->
               Format.fprintf fmt "  '%s': %d scopes\n" pattern (List.length scope_ids))
             matching_scope_ids_per_pattern;
           Format.fprintf fmt "\n";

           (* Display LCA scopes compactly *)
           Format.fprintf fmt "Lowest Common Ancestor scopes (smallest subtrees):\n\n";
           List.iter
             (fun entry ->
               match entry.Minidebug_client.Query.child_scope_id with
               | Some lca_scope_id ->
                   let loc_str =
                     match entry.Minidebug_client.Query.location with
                     | Some loc -> Printf.sprintf " [%s]" loc
                     | None -> ""
                   in
                   let elapsed_str =
                     match Minidebug_client.Renderer.elapsed_time entry with
                     | Some ns when show_times ->
                         Printf.sprintf " (%s)" (Minidebug_client.Renderer.format_elapsed_ns ns)
                     | _ -> ""
                   in
                   Format.fprintf fmt "  Scope %d: %s%s%s\n" lca_scope_id entry.Minidebug_client.Query.message
                     loc_str elapsed_str
               | None -> ())
             paginated_lca_entries;
           Format.fprintf fmt "\n";
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in

           Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in search-intersection: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  (* Helper to parse comma-separated path strings *)
  let parse_path_param args param_name =
    match get_optional_string_param args param_name with
    | Some path_str -> String.split_on_char ',' path_str
    | None -> failwith (Printf.sprintf "%s is required" param_name)
  in

  (* Tool: search-extract - Search DAG path then extract with deduplication *)
  let _ =
    add_tool server ~name:"minidebug/search-extract"
      ~description:
        "Search for matches along a DAG path, then extract values at a different path with \
         change tracking. Paths are comma-separated patterns. Both paths must start with \
         the same pattern. Shows only changed values (deduplication)."
      ~schema_properties:
        [
          ( "search_path",
            "string",
            "Comma-separated search path patterns (e.g., 'fn_a,param_x')" );
          ( "extraction_path",
            "string",
            "Comma-separated extraction path patterns (e.g., 'fn_a,result')" );
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum depth from match (optional)");
        ]
      ~schema_required:[ "search_path"; "extraction_path" ]
      (fun args ->
         try
           let session = get_session () in
           let module Q = (val session.query : Minidebug_client.Query.S) in

           let search_path = parse_path_param args "search_path" in
           let extraction_path = parse_path_param args "extraction_path" in

           (* Validate that paths are non-empty and share first element *)
           (match (search_path, extraction_path) with
           | [], _ | _, [] -> failwith "search-extract requires non-empty paths"
           | s_first :: _, e_first :: _ when s_first <> e_first ->
               failwith
                 (Printf.sprintf
                    "Search and extraction paths must start with the same pattern. Search \
                     starts with '%s', extraction starts with '%s'"
                    s_first e_first)
           | _ -> ());

           let show_times =
             Option.value (get_optional_bool_param args "show_times") ~default:false
           in
           let max_depth = get_optional_int_param args "max_depth" in

           (* Capture search output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           (* Find all paths matching the search pattern *)
           let matching_paths = Q.find_matching_paths ~patterns:search_path in

           (* Extract the tail of extraction_path (removing shared first element) *)
           let extraction_tail =
             match extraction_path with _ :: tail -> tail | [] -> []
           in

           (* Track previous scope_id for deduplication *)
           let prev_scope_id = ref None in
           let total_matches = ref 0 in
           let unique_extractions = ref 0 in

           (* Process each match *)
           List.iter
             (fun (shared_scope_id, _ancestor_path) ->
               incr total_matches;
               (* Extract along the extraction path from the shared scope *)
               let extracted_scope_id_opt =
                 Q.extract_along_path ~start_scope_id:shared_scope_id
                   ~extraction_path:extraction_tail
               in
               match extracted_scope_id_opt with
               | None ->
                   (* Extraction path not found - skip this match *)
                   ()
               | Some extracted_scope_id ->
                   (* Check if this is a duplicate of the previous extraction *)
                   let is_duplicate =
                     match !prev_scope_id with
                     | Some prev when prev = extracted_scope_id -> true
                     | _ -> false
                   in
                   if not is_duplicate then (
                     incr unique_extractions;
                     prev_scope_id := Some extracted_scope_id;

                     (* Print the extracted subtree *)
                     Format.fprintf fmt "=== Match #%d at shared scope #%d ==>\n" !unique_extractions
                       shared_scope_id;

                     (* Get the scope entry for the extracted scope *)
                     let scope_children =
                       Q.get_scope_children ~parent_scope_id:extracted_scope_id
                     in
                     (* Find the header entry (if any) and build tree *)
                     (match scope_children with
                     | [] -> Format.fprintf fmt "(empty scope)\n\n"
                     | _ ->
                         let trees = Minidebug_client.Renderer.build_tree (module Q) ?max_depth scope_children in
                         let rendered_output =
                           Minidebug_client.Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
                             ~values_first_mode:true trees
                         in
                         Format.fprintf fmt "%s" rendered_output;
                         Format.fprintf fmt "\n")))
             matching_paths;

           (* Print summary *)
           Format.fprintf fmt
             "\nSearch-extract complete: %d total matches, %d unique extractions (skipped %d \
              consecutive duplicates)\n"
             !total_matches !unique_extractions (!total_matches - !unique_extractions);
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in

           Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in search-extract: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  server
