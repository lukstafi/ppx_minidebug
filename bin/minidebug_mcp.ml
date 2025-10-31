(** MCP server executable for ppx_minidebug *)

let usage_msg =
  {|minidebug_mcp - Model Context Protocol server for ppx_minidebug

USAGE:
  minidebug_mcp <database_path>

DESCRIPTION:
  Starts an MCP server providing tools to query and analyze ppx_minidebug
  database traces. Communicates over stdio using JSON-RPC protocol.

  This server is designed to be used with MCP-compatible AI assistants like
  Claude Desktop, allowing them to directly query and analyze debug traces.

TOOLS PROVIDED:
  - minidebug/list-runs          List all trace runs with metadata
  - minidebug/stats               Show database statistics
  - minidebug/show-trace          Show full trace tree
  - minidebug/search-tree         Search with ancestor context (best for AI)
  - minidebug/search-subtree      Search showing only matching subtrees
  - minidebug/show-scope          Show specific scope by ID
  - minidebug/get-ancestors       Get ancestor chain for navigation

CONFIGURATION (for Claude Desktop):
  Add to ~/Library/Application Support/Claude/claude_desktop_config.json:

  {
    "mcpServers": {
      "ppx_minidebug": {
        "command": "minidebug_mcp",
        "args": ["/path/to/your/debug.db"]
      }
    }
  }

EXAMPLES:
  # Start server for a specific database
  minidebug_mcp trace.db

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
  (* Parse command line *)
  let db_path =
    if Array.length Sys.argv < 2 then (
      Printf.eprintf "Error: Missing database path argument\n\n%s\n" usage_msg;
      exit 1)
    else
      let arg = Sys.argv.(1) in
      if arg = "--help" || arg = "-h" then (
        print_endline usage_msg;
        exit 0)
      else if Sys.is_directory arg then
        match find_db_in_dir arg with
        | Ok path -> path
        | Error msg ->
            Printf.eprintf "Error: %s\n" msg;
            exit 1
      else if Sys.file_exists arg then arg
      else (
        Printf.eprintf "Error: Database file '%s' not found\n" arg;
        exit 1)
  in

  (* Verify database is valid *)
  (try
     let client = Minidebug_client.Client.open_db db_path in
     Minidebug_client.Client.close client
   with e ->
     Printf.eprintf "Error: Cannot open database '%s': %s\n" db_path
       (Printexc.to_string e);
     exit 1);

  (* Set up logging *)
  Logs.set_reporter (Logs.format_reporter ());
  Logs.set_level (Some Logs.Info);
  Logs.info (fun m -> m "Starting ppx_minidebug MCP server for database: %s" db_path);

  (* Create and run server *)
  Eio_main.run @@ fun env ->
  let server = Minidebug_mcp_server.create_server ~db_path in
  Logs.info (fun m -> m "MCP server initialized, waiting for requests...");
  Mcp_server.run_server env server
