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

(* Database path management *)
let current_db_path = ref None

let get_db_path () =
  match !current_db_path with
  | Some path -> path
  | None -> failwith "No database opened. Use minidebug/open-database first."

(* Create the MCP server *)
let create_server ~db_path =
  current_db_path := Some db_path;

  let server = create_server ~name:"ppx_minidebug MCP Server" ~version:"0.1.0" () in
  let server = configure_server server ~with_tools:true ~with_resources:false () in

  (* Tool: list-runs - List all trace runs in database *)
  let _ =
    add_tool server ~name:"minidebug/list-runs"
      ~description:"List all trace runs in the database with metadata"
      ~schema_properties:[] ~schema_required:[]
      (fun _args ->
         try
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in
           let runs = Minidebug_client.Client.list_runs client in
           Minidebug_client.Client.close client;

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
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in

           (* Capture stats output using buffer-backed formatter *)
           let buffer = Buffer.create 1024 in
           let fmt = Format.formatter_of_buffer buffer in

           (* Run stats with custom output channel *)
           Minidebug_client.Client.show_stats ~output:fmt client;
           Format.pp_print_flush fmt ();

           let stats_text = Buffer.contents buffer in
           Minidebug_client.Client.close client;

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
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in

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
           let latest_run =
             Minidebug_client.Client.get_latest_run client
             |> Option.get (* Safe: would have errored in open_db if no runs *)
           in

           (* Capture trace output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           (* Generate trace *)
           Minidebug_client.Client.show_run_summary ~output:fmt client latest_run.run_id;
           Minidebug_client.Client.show_trace ~output:fmt client ~show_scope_ids
             ~show_times ~max_depth ~values_first_mode;
           Format.pp_print_flush fmt ();

           let trace_text = Buffer.contents buffer in
           Minidebug_client.Client.close client;

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
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in

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

           let _num_matches =
             Minidebug_client.Client.search_tree ~output:fmt ~quiet_path ~format:`Text
               ~show_times ~max_depth ~limit ~offset client ~pattern
           in
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in
           Minidebug_client.Client.close client;

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
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in

           let pattern = get_string_param args "pattern" in
           let show_times =
             Option.value (get_optional_bool_param args "show_times") ~default:false
           in
           let max_depth = get_optional_int_param args "max_depth" in
           let limit = get_optional_int_param args "limit" in

           (* Capture search output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           let _num_matches =
             Minidebug_client.Client.search_subtree ~output:fmt ~quiet_path:None
               ~format:`Text ~show_times ~max_depth ~limit ~offset:None client ~pattern
           in
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in
           Minidebug_client.Client.close client;

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
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in

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

           Minidebug_client.Client.show_scope ~output:fmt ~format:`Text ~show_times
             ~max_depth ~show_ancestors client ~scope_id;
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in
           Minidebug_client.Client.close client;

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
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in

           let scope_id =
             match get_optional_int_param args "scope_id" with
             | Some id -> id
             | None -> failwith "scope_id is required"
           in

           (* Capture ancestors output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           Minidebug_client.Client.get_ancestors ~output:fmt ~format:`Text client ~scope_id;
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in
           Minidebug_client.Client.close client;

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
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in

           let scope_id =
             match get_optional_int_param args "scope_id" with
             | Some id -> id
             | None -> failwith "scope_id is required"
           in

           (* Capture children output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           Minidebug_client.Client.get_children ~output:fmt ~format:`Text client ~scope_id;
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in
           Minidebug_client.Client.close client;

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
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in

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

           Minidebug_client.Client.show_subtree ~output:fmt ~format:`Text ~show_times
             ~max_depth ~show_ancestors client ~scope_id;
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in
           Minidebug_client.Client.close client;

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
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in

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

           Minidebug_client.Client.search_at_depth ~output:fmt ~quiet_path ~format:`Text
             ~show_times ~depth client ~pattern;
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in
           Minidebug_client.Client.close client;

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
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in

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
           let max_depth = get_optional_int_param args "max_depth" in
           let quiet_path = get_optional_string_param args "quiet_path" in
           let limit = get_optional_int_param args "limit" in
           let offset = get_optional_int_param args "offset" in

           (* Capture search output using buffer-backed formatter *)
           let buffer = Buffer.create 4096 in
           let fmt = Format.formatter_of_buffer buffer in

           let _num_matches =
             Minidebug_client.Client.search_intersection ~output:fmt ~quiet_path
               ~format:`Text ~show_times ~max_depth ~limit ~offset client ~patterns
           in
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in
           Minidebug_client.Client.close client;

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
           let db_path = get_db_path () in
           let client = Minidebug_client.Client.open_db db_path in

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

           Minidebug_client.Client.search_extract ~output:fmt ~format:`Text ~show_times
             ~max_depth client ~search_path ~extraction_path;
           Format.pp_print_flush fmt ();

           let output = Buffer.contents buffer in
           Minidebug_client.Client.close client;

           Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
         with e ->
           Logs.err (fun m -> m "Error in search-extract: %s" (Printexc.to_string e));
           Tool.create_error_result (Printexc.to_string e))
  in

  server
