(** MCP server executable for ppx_minidebug *)

let usage_msg =
  {|minidebug_mcp - Model Context Protocol server for ppx_minidebug

USAGE:
  minidebug_mcp [database_path]

DESCRIPTION:
  Starts an MCP server providing tools to query and analyze ppx_minidebug
  database traces. Communicates over stdio using JSON-RPC protocol.

  This server is designed to be used with MCP-compatible AI assistants like
  Claude Desktop, allowing them to directly query and analyze debug traces.

  The database path is now OPTIONAL. If not provided at startup, use the
  minidebug/init-db tool to initialize a session with a database.

TOOLS PROVIDED:
  - minidebug/init-db             Initialize/switch database session (NEW)
  - minidebug/list-runs           List all trace runs with metadata
  - minidebug/stats               Show database statistics
  - minidebug/show-trace          Show full trace tree
  - minidebug/search-tree         Search with ancestor context (best for AI)
  - minidebug/search-subtree      Search showing only matching subtrees
  - minidebug/show-scope          Show specific scope by ID
  - minidebug/get-ancestors       Get ancestor chain for navigation
  - minidebug/get-children        Get child scopes for navigation
  - minidebug/show-subtree        Show subtree rooted at scope
  - minidebug/search-at-depth     Search at specific depth
  - minidebug/search-intersection Find scopes matching all patterns
  - minidebug/search-extract      Extract values along DAG path

CONFIGURATION (for Claude Desktop):
  Add to ~/Library/Application Support/Claude/claude_desktop_config.json:

  # Option 1: With database path (auto-initializes session)
  {
    "mcpServers": {
      "ppx_minidebug": {
        "command": "minidebug_mcp",
        "args": ["/path/to/your/debug.db"]
      }
    }
  }

  # Option 2: Without database path (use init-db tool to set database)
  {
    "mcpServers": {
      "ppx_minidebug": {
        "command": "minidebug_mcp",
        "args": []
      }
    }
  }

EXAMPLES:
  # Start server for a specific database (classic mode)
  minidebug_mcp trace.db

  # Start server without database (lazy initialization mode)
  minidebug_mcp

  # Use with database auto-discovery (looks for *.db in current directory)
  minidebug_mcp .

For more information, see: https://github.com/lukstafi/ppx_minidebug
|}

let find_db_in_dir dir =
  let files = Sys.readdir dir in
  let db_files =
    Array.to_list files
    |> List.filter (fun f ->
           Filename.check_suffix f ".db" && not (Filename.check_suffix f "_meta.db"))
  in
  match db_files with
  | [] -> Error "No .db files found in current directory"
  | [ file ] -> Ok (Filename.concat dir file)
  | files ->
      Error
        (Printf.sprintf "Multiple .db files found: %s\nPlease specify one explicitly."
           (String.concat ", " files))

let () =
  (* Parse command line - database path is now optional *)
  let db_path_opt =
    if Array.length Sys.argv < 2 then None
    else
      let arg = Sys.argv.(1) in
      if arg = "--help" || arg = "-h" then (
        print_endline usage_msg;
        exit 0)
      else if Sys.is_directory arg then
        match find_db_in_dir arg with
        | Ok path -> Some path
        | Error msg ->
            Printf.eprintf "Error: %s\n" msg;
            exit 1
      else if Sys.file_exists arg then Some arg
      else (
        Printf.eprintf "Error: Database file '%s' not found\n" arg;
        exit 1)
  in

  (* Verify database is valid if provided *)
  (match db_path_opt with
  | Some db_path ->
      (try
         let client = Minidebug_cli.Cli.open_db db_path in
         Minidebug_cli.Cli.close client
       with e ->
         Printf.eprintf "Error: Cannot open database '%s': %s\n" db_path
           (Printexc.to_string e);
         exit 1)
  | None -> ());

  (* Set up logging *)
  Logs.set_reporter (Logs.format_reporter ());
  Logs.set_level (Some Logs.Info);

  (match db_path_opt with
  | Some db_path ->
      Logs.info (fun m -> m "Starting ppx_minidebug MCP server for database: %s" db_path)
  | None ->
      Logs.info (fun m ->
          m
            "Starting ppx_minidebug MCP server (no database specified - use \
             minidebug/init-db tool)"));

  (* Create and run server *)
  Eio_main.run @@ fun env ->
  let server = Minidebug_mcp.create_server ?db_path:db_path_opt () in
  Logs.info (fun m -> m "MCP server initialized, waiting for requests...");
  Mcp_server.run_sdtio_server env server
