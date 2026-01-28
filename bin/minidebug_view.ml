(** CLI tool for viewing ppx_minidebug database traces *)

let usage_msg =
  {|minidebug_view - View ppx_minidebug database traces

USAGE:
  minidebug_view <database> <command> [options]

COMMANDS:
  list                      List all runs in database
  stats                     Show database statistics
  show                      Show trace tree (latest run if no ID given)
  interactive               Interactive TUI for exploring trace (alias: tui)
  compact                   Show compact trace (function names only)
  roots                     Show root entries only (fast for large DBs)
  search <pattern>          Search entries by regex pattern (basic)
  search-tree <pattern>     Search with full tree context (shows ancestor paths)
  search-subtree <pattern>  Search showing only matching subtrees (pruned)
  search-at-depth <pattern> <depth>  Search summary at specific depth (TUI-like)
  search-intersection <pat1> <pat2> [<pat3> <pat4>]  Find scopes matching all patterns
  search-extract <search_path> <extraction_path>  Search DAG path then extract with deduplication
  show-scope <id>           Show specific scope and its descendants
  show-subtree <id>         Show subtree rooted at scope with ancestor path
  show-entry <sid> <seq>    Show detailed entry information
  get-ancestors <id>        Get ancestor scope IDs from root to target
  get-parent <id>           Get parent scope ID
  get-children <id>         Get child scope IDs
  export <file>             Export latest run to markdown
  tui-render                Render TUI state from DB (for CLI clients)
  tui-status                Show TUI status (state, search slots)
  tui-cmd <cmd> [<cmd>...]  Send commands to TUI server via DB queue

OPTIONS:
  --run=<id>              Specify run ID (for show, compact, search, roots)
  --entry-ids             Show entry IDs in output
  --times                 Show elapsed times
  --max-depth=<n>         Limit tree depth (INCREMENTAL for show-subtree)
  --values-first          Show result values as headers (values-first mode)
  --with-values           Include immediate children values (for roots command)
  --format=<fmt>          Output format: text (default) or json
  --quiet-path=<pattern>  Stop ancestor propagation at pattern (search-tree only)
  --ancestors             Show ancestors (show-scope, show-subtree: default true)
  --limit=<n>             Limit number of results (for search commands)
  --offset=<n>            Skip first n results (for search commands)
  --db-mode               Enable DB-backed TUI state (for interactive command)
  --client-id=<id>        Client ID for tui-cmd (default: cli-<pid>)
  --help                  Show this help message

NOTE: For show-subtree, --max-depth is INCREMENTAL (relative to target scope).
      E.g., if scope is at depth 5 and --max-depth=3, shows up to depth 8.

EXAMPLES:
  # Show latest trace
  minidebug_view trace.db show

  # Search with full context trees (for LLM analysis)
  minidebug_view trace.db search-tree "error" --format=json

  # Search showing only matching subtrees
  minidebug_view trace.db search-subtree "fib" --times

  # Search but stop context at test boundaries
  minidebug_view trace.db search-tree "error" --quiet-path="test_"

  # Get TUI-like summary at depth 4 (for huge traces)
  minidebug_view trace.db search-at-depth "(id 79)" 4 --quiet-path="env"

  # Find scopes matching multiple patterns (intersection)
  minidebug_view trace.db search-intersection "(id 79)" "(id 1802)" --format=json

  # Search and extract with change tracking (comma-separated paths)
  minidebug_view trace.db search-extract "fn_a,param_x" "fn_a,result" --times

  # Show specific scope with descendants
  minidebug_view trace.db show-scope 42 --depth=2 --format=json

  # Show subtree rooted at scope with ancestor path
  minidebug_view trace.db show-subtree 42 --max-depth=3 --times

  # Show ancestor path to a scope
  minidebug_view trace.db show-scope 42 --ancestors

  # Get navigation info
  minidebug_view trace.db get-ancestors 100
  minidebug_view trace.db get-children 42 --format=json

  # Start TUI in DB-backed mode (for AI agent access)
  minidebug_view trace.db tui --db-mode

  # CLI client: render current TUI state from DB
  minidebug_view trace.db tui-render

  # CLI client: send commands to TUI server
  minidebug_view trace.db tui-cmd down down enter /error

  # CLI client: check TUI status (searches, cursor, etc.)
  minidebug_view trace.db tui-status

SEARCH PATTERN SYNTAX:
  All search commands use SQL GLOB patterns (case-sensitive wildcard matching).
  Patterns are automatically wrapped with wildcards: "error" becomes "*error*"

  GLOB wildcards:
  - * matches any sequence of characters (including empty)
  - ? matches exactly one character
  - [abc] matches one character from the set
  - [^abc] matches one character NOT in the set

  Examples:
  - "error"       → matches "*error*" (finds "error" anywhere)
  - "Error*"      → matches "*Error**" (finds "Error" at start of word)
  - "test_[0-9]"  → matches "*test_[0-9]*" (finds "test_" followed by digit)
  - "fn?a"        → matches "*fn?a*" (finds "fn" + any char + "a")

  # Export to markdown
  minidebug_view trace.db export output.md
|}

type command =
  | List
  | Stats
  | Show
  | Interactive
  | Compact
  | Roots
  | Search of string
  | SearchTree of string
  | SearchSubtree of string
  | SearchAtDepth of string * int
  | SearchIntersection of string list
  | SearchExtract of string list * string list
  | ShowScope of int
  | ShowSubtree of int
  | ShowEntry of int * int
  | GetAncestors of int
  | GetParent of int
  | GetChildren of int
  | Export of string
  | TuiRender
  | TuiCmd of string list
  | TuiStatus
  | Help

type options = {
  show_scope_ids : bool;
  show_times : bool;
  max_depth : int option;
  values_first_mode : bool;
  with_values : bool;
  format : [ `Text | `Json ];
  quiet_path : string option;
  show_ancestors : bool;
  limit : int option;
  offset : int option;
  db_mode : bool;
  client_id : string;
}

let parse_args () =
  let args = Array.to_list Sys.argv in
  match args with
  | [] | [ _ ] ->
      Printf.eprintf "Error: Missing database argument\n%s\n" usage_msg;
      exit 1
  | _ :: db_path :: rest ->
      let cmd_ref = ref Help in
      let opts =
        ref
          {
            show_scope_ids = false;
            show_times = false;
            max_depth = None;
            values_first_mode = false;
            with_values = false;
            format = `Text;
            quiet_path = None;
            show_ancestors = false;
            limit = None;
            offset = None;
            db_mode = false;
            client_id = Printf.sprintf "cli-%d" (Unix.getpid ());
          }
      in

      let rec parse_rest = function
        | [] -> ()
        | "list" :: rest ->
            cmd_ref := List;
            parse_rest rest
        | "stats" :: rest ->
            cmd_ref := Stats;
            parse_rest rest
        | "show" :: rest ->
            cmd_ref := Show;
            parse_rest rest
        | ("interactive" | "tui") :: rest ->
            cmd_ref := Interactive;
            parse_rest rest
        | "compact" :: rest ->
            cmd_ref := Compact;
            parse_rest rest
        | "roots" :: rest ->
            cmd_ref := Roots;
            parse_rest rest
        | "search" :: pattern :: rest ->
            cmd_ref := Search pattern;
            parse_rest rest
        | "search-tree" :: pattern :: rest ->
            cmd_ref := SearchTree pattern;
            parse_rest rest
        | "search-subtree" :: pattern :: rest ->
            cmd_ref := SearchSubtree pattern;
            parse_rest rest
        | "search-at-depth" :: pattern :: depth_str :: rest ->
            cmd_ref := SearchAtDepth (pattern, int_of_string depth_str);
            parse_rest rest
        | "search-intersection" :: rest -> (
            (* Parse 2-4 patterns *)
            let rec collect_patterns acc remaining =
              match (remaining, acc) with
              | [], _ when List.length acc >= 2 ->
                  (List.rev acc, []) (* Valid: 2+ patterns collected *)
              | arg :: _, _ when String.starts_with ~prefix:"--" arg ->
                  if List.length acc >= 2 then (List.rev acc, remaining)
                  else (
                    Printf.eprintf "Error: search-intersection requires at least 2 patterns\n";
                    exit 1)
              | arg :: rest, _ when List.length acc < 4 ->
                  collect_patterns (arg :: acc) rest
              | _ :: _, _ ->
                  Printf.eprintf "Error: search-intersection supports at most 4 patterns\n";
                  exit 1
              | [], _ ->
                  Printf.eprintf "Error: search-intersection requires at least 2 patterns\n";
                  exit 1
            in
            let patterns, remaining = collect_patterns [] rest in
            cmd_ref := SearchIntersection patterns;
            parse_rest remaining)
        | "search-extract" :: search_path_str :: extraction_path_str :: rest ->
            let search_path = String.split_on_char ',' search_path_str in
            let extraction_path = String.split_on_char ',' extraction_path_str in
            (* Validate that paths are non-empty and share first element *)
            (match (search_path, extraction_path) with
            | [], _ | _, [] ->
                Printf.eprintf "Error: search-extract requires non-empty paths\n";
                exit 1
            | s_first :: _, e_first :: _ when s_first <> e_first ->
                Printf.eprintf "Error: search and extraction paths must start with the same pattern\n";
                Printf.eprintf "  Search path starts with: '%s'\n" s_first;
                Printf.eprintf "  Extraction path starts with: '%s'\n" e_first;
                exit 1
            | _ -> ());
            cmd_ref := SearchExtract (search_path, extraction_path);
            parse_rest rest
        | "show-scope" :: id_str :: rest ->
            cmd_ref := ShowScope (int_of_string id_str);
            parse_rest rest
        | "show-subtree" :: id_str :: rest ->
            cmd_ref := ShowSubtree (int_of_string id_str);
            parse_rest rest
        | "show-entry" :: sid_str :: seq_str :: rest ->
            cmd_ref := ShowEntry (int_of_string sid_str, int_of_string seq_str);
            parse_rest rest
        | "get-ancestors" :: id_str :: rest ->
            cmd_ref := GetAncestors (int_of_string id_str);
            parse_rest rest
        | "get-parent" :: id_str :: rest ->
            cmd_ref := GetParent (int_of_string id_str);
            parse_rest rest
        | "get-children" :: id_str :: rest ->
            cmd_ref := GetChildren (int_of_string id_str);
            parse_rest rest
        | "export" :: file :: rest ->
            cmd_ref := Export file;
            parse_rest rest
        | "tui-render" :: rest ->
            cmd_ref := TuiRender;
            parse_rest rest
        | "tui-status" :: rest ->
            cmd_ref := TuiStatus;
            parse_rest rest
        | "tui-cmd" :: rest ->
            (* Collect all non-option arguments as commands *)
            let rec collect_cmds acc = function
              | [] -> (List.rev acc, [])
              | arg :: rest when String.starts_with ~prefix:"--" arg ->
                  (List.rev acc, arg :: rest)
              | arg :: rest -> collect_cmds (arg :: acc) rest
            in
            let cmds, remaining = collect_cmds [] rest in
            if cmds = [] then (
              Printf.eprintf "Error: tui-cmd requires at least one command\n";
              exit 1);
            cmd_ref := TuiCmd cmds;
            parse_rest remaining
        | "--help" :: _ | "-h" :: _ -> cmd_ref := Help
        | opt :: rest when String.starts_with ~prefix:"--" opt -> (
            match String.split_on_char '=' opt with
            | [ "--max-depth"; d ] ->
                opts := { !opts with max_depth = Some (int_of_string d) };
                parse_rest rest
            | [ "--entry-ids" ] ->
                opts := { !opts with show_scope_ids = true };
                parse_rest rest
            | [ "--times" ] ->
                opts := { !opts with show_times = true };
                parse_rest rest
            | [ "--values-first" ] ->
                opts := { !opts with values_first_mode = true };
                parse_rest rest
            | [ "--with-values" ] ->
                opts := { !opts with with_values = true };
                parse_rest rest
            | [ "--format"; "json" ] ->
                opts := { !opts with format = `Json };
                parse_rest rest
            | [ "--format"; "text" ] ->
                opts := { !opts with format = `Text };
                parse_rest rest
            | [ "--quiet-path"; pattern ] ->
                opts := { !opts with quiet_path = Some pattern };
                parse_rest rest
            | [ "--ancestors" ] ->
                opts := { !opts with show_ancestors = true };
                parse_rest rest
            | [ "--limit"; n ] ->
                opts := { !opts with limit = Some (int_of_string n) };
                parse_rest rest
            | [ "--offset"; n ] ->
                opts := { !opts with offset = Some (int_of_string n) };
                parse_rest rest
            | [ "--db-mode" ] ->
                opts := { !opts with db_mode = true };
                parse_rest rest
            | [ "--client-id"; id ] ->
                opts := { !opts with client_id = id };
                parse_rest rest
            | _ ->
                Printf.eprintf "Unknown option: %s\n" opt;
                exit 1)
        | arg :: _ ->
            Printf.eprintf "Unknown argument: %s\n" arg;
            exit 1
      in

      parse_rest rest;
      (db_path, !cmd_ref, !opts)

let () =
  let db_path, cmd, opts = parse_args () in

  if cmd = Help then (
    print_endline usage_msg;
    exit 0);

  if not (Sys.file_exists db_path) then (
    Printf.eprintf "Error: Database file '%s' not found\n" db_path;
    exit 1);

  let client = Minidebug_cli.Cli.open_db db_path in

  try
    match cmd with
    | List ->
        let runs = Minidebug_cli.Cli.list_runs client in
        Printf.printf "Runs in %s:\n\n" db_path;
        List.iter
          (fun run ->
            Printf.printf "Run #%d - %s" run.Minidebug_client.Query.run_id run.timestamp;
            (match run.run_name with
            | Some name -> Printf.printf " [%s]" name
            | None -> ());
            Printf.printf "\n";
            Printf.printf "  Command: %s\n" run.command_line;
            Printf.printf "  Elapsed: %s\n\n"
              (Minidebug_client.Query.format_elapsed_ns run.elapsed_ns))
          runs
    | Stats -> Minidebug_cli.Cli.show_stats client
    | Show ->
        Minidebug_cli.Cli.(
          show_run_summary client (Option.get (get_latest_run client)).run_id);
        Minidebug_cli.Cli.show_trace client ~show_scope_ids:opts.show_scope_ids
          ~show_times:opts.show_times ~max_depth:opts.max_depth
          ~values_first_mode:opts.values_first_mode
    | Interactive ->
        (* Create Query module for interactive mode *)
        let module Q = Minidebug_client.Query.Make (struct
          let db_path = db_path
        end) in
        let initial_state = Minidebug_client.Interactive.initial_state (module Q) in
        let _term, command_stream, render_screen, output_size, finalize = Minidebug_tui.Tui.create_tui_callbacks () in
        if opts.db_mode then (
          (* DB-backed mode: create TUI DB context and use run_with_db *)
          let tui_db = Minidebug_client.Tui_db.create db_path in
          let db_callbacks = Minidebug_client.Tui_db.make_db_callbacks tui_db in
          Minidebug_client.Interactive.run_with_db (module Q) ~initial_state ~command_stream ~render_screen ~output_size ~finalize ~db_callbacks;
          Minidebug_client.Tui_db.close tui_db)
        else
          Minidebug_client.Interactive.run (module Q) ~initial_state ~command_stream ~render_screen ~output_size ~finalize
    | Compact ->
        Minidebug_cli.Cli.(
          show_run_summary client (Option.get (get_latest_run client)).run_id);
        Minidebug_cli.Cli.show_compact_trace client
    | Roots ->
        Minidebug_cli.Cli.(
          show_run_summary client (Option.get (get_latest_run client)).run_id);
        Minidebug_cli.Cli.show_roots client ~show_times:opts.show_times
          ~with_values:opts.with_values
    | Search pattern -> Minidebug_cli.Cli.search client ~pattern
    | SearchTree pattern ->
        let _ =
          Minidebug_cli.Cli.search_tree ~quiet_path:opts.quiet_path
            ~format:opts.format ~show_times:opts.show_times ~max_depth:opts.max_depth
            ~limit:opts.limit ~offset:opts.offset client ~pattern
        in
        ()
    | SearchSubtree pattern ->
        let _ =
          Minidebug_cli.Cli.search_subtree ~quiet_path:opts.quiet_path
            ~format:opts.format ~show_times:opts.show_times ~max_depth:opts.max_depth
            ~limit:opts.limit ~offset:opts.offset client ~pattern
        in
        ()
    | SearchAtDepth (pattern, depth) ->
        Minidebug_cli.Cli.search_at_depth ~quiet_path:opts.quiet_path
          ~format:opts.format ~show_times:opts.show_times ~depth client ~pattern
    | SearchIntersection patterns ->
        let _ =
          Minidebug_cli.Cli.search_intersection ~quiet_path:opts.quiet_path
            ~format:opts.format ~show_times:opts.show_times ~max_depth:opts.max_depth
            ~limit:opts.limit ~offset:opts.offset client ~patterns
        in
        ()
    | SearchExtract (search_path, extraction_path) ->
        Minidebug_cli.Cli.search_extract ~format:opts.format
          ~show_times:opts.show_times ~max_depth:opts.max_depth client ~search_path
          ~extraction_path
    | ShowScope scope_id ->
        Minidebug_cli.Cli.show_scope ~format:opts.format ~show_times:opts.show_times
          ~max_depth:opts.max_depth ~show_ancestors:opts.show_ancestors client ~scope_id
    | ShowSubtree scope_id ->
        Minidebug_cli.Cli.show_subtree ~format:opts.format ~show_times:opts.show_times
          ~max_depth:opts.max_depth ~show_ancestors:opts.show_ancestors client ~scope_id
    | ShowEntry (scope_id, seq_id) ->
        Minidebug_cli.Cli.show_entry ~format:opts.format client ~scope_id ~seq_id
    | GetAncestors scope_id ->
        Minidebug_cli.Cli.get_ancestors ~format:opts.format client ~scope_id
    | GetParent scope_id ->
        Minidebug_cli.Cli.get_parent ~format:opts.format client ~scope_id
    | GetChildren scope_id ->
        Minidebug_cli.Cli.get_children ~format:opts.format client ~scope_id
    | Export file -> Minidebug_cli.Cli.export_markdown client ~output_file:file
    | TuiRender ->
        (* Render current TUI state from DB using atomic snapshot read *)
        let module Q = Minidebug_client.Query.Make (struct
          let db_path = db_path
        end) in
        let tui_db = Minidebug_client.Tui_db.create db_path in
        (* Use read_snapshot for consistent read of all state *)
        let (revision, basic_state_opt, visible_items, _search_slots) =
          Minidebug_client.Tui_db.read_snapshot tui_db (module Q)
        in
        (match basic_state_opt with
        | None ->
            Printf.printf "No TUI state found in database.\n";
            Printf.printf "Start TUI server first: minidebug_view %s tui --db-mode\n" db_path
        | Some state ->
            Printf.printf "=== TUI State (revision %d) ===\n" revision;
            Printf.printf "Cursor: %d | Scroll: %d | Items: %d\n"
              state.cursor state.scroll_offset (Array.length visible_items);
            Printf.printf "Times: %s | Values First: %s | Max Scope: %d\n"
              (if state.show_times then "ON" else "OFF")
              (if state.values_first then "ON" else "OFF")
              state.max_scope_id;
            Printf.printf "\n--- Visible Items ---\n";
            Array.iteri
              (fun idx item ->
                let cursor_mark = if idx = state.cursor then ">" else " " in
                let indent = String.make (item.Minidebug_client.Interactive.indent_level * 2) ' ' in
                let expand_mark =
                  if item.is_expandable then
                    if item.is_expanded then "▼ " else "▶ "
                  else "  "
                in
                match item.content with
                | Minidebug_client.Interactive.RealEntry entry ->
                    let display_text =
                      if entry.Minidebug_client.Query.child_scope_id = None && item.is_expanded
                         && state.render_width > 0
                      then
                        let margin_width =
                          String.length (string_of_int state.max_scope_id)
                        in
                        let content_width =
                          max 1 (state.render_width - (margin_width + 3))
                        in
                        let line_width =
                          max 1
                            (content_width
                            - ((item.Minidebug_client.Interactive.indent_level * 2) + 2))
                        in
                        match
                          Minidebug_client.Interactive.leaf_body_lines ~line_width
                            ~show_times:state.show_times entry
                        with
                        | first :: _ -> first
                        | [] -> ""
                      else
                        match entry.Minidebug_client.Query.data with
                        | Some d when entry.message <> "" ->
                            Printf.sprintf "%s = %s" entry.message d
                        | Some d -> d
                        | None -> entry.message
                    in
                    Printf.printf "%s%s%s%s\n" cursor_mark indent expand_mark display_text
                | Minidebug_client.Interactive.Ellipsis { hidden_count; start_seq_id; end_seq_id; _ } ->
                    Printf.printf "%s%s⋯ (%d hidden: seq %d-%d)\n" cursor_mark indent hidden_count start_seq_id end_seq_id
                | Minidebug_client.Interactive.WrappedLine { text; _ } ->
                    Printf.printf "%s%s\n" cursor_mark text)
              visible_items);
        Minidebug_client.Tui_db.close tui_db
    | TuiCmd commands ->
        (* Send commands to TUI server via DB queue *)
        let tui_db = Minidebug_client.Tui_db.create db_path in
        let batch_id = Printf.sprintf "%s-%f" opts.client_id (Unix.gettimeofday ()) in
        List.iter
          (fun cmd ->
            match Minidebug_client.Tui_db.insert_command tui_db ~client_id:opts.client_id ~batch_id cmd with
            | Ok _ -> ()
            | Error e -> Printf.eprintf "Failed to insert command '%s': %s\n" cmd e)
          commands;
        (* Wait for commands to be processed *)
        (match Minidebug_client.Tui_db.wait_for_batch tui_db batch_id ~timeout_sec:10.0 with
        | Ok () -> Printf.printf "Commands processed successfully.\n"
        | Error e -> Printf.eprintf "Error: %s\n" e);
        Minidebug_client.Tui_db.close tui_db
    | TuiStatus ->
        (* Show TUI status using atomic snapshot read for consistency *)
        let module Q = Minidebug_client.Query.Make (struct
          let db_path = db_path
        end) in
        let tui_db = Minidebug_client.Tui_db.create db_path in
        (* Use read_snapshot for consistent read of all state *)
        let (revision, basic_state_opt, _visible_items, search_slots) =
          Minidebug_client.Tui_db.read_snapshot tui_db (module Q)
        in
        (match basic_state_opt with
        | None ->
            Printf.printf "No TUI state found in database.\n"
        | Some state ->
            Printf.printf "=== TUI Status (revision %d) ===\n" revision;
            Printf.printf "Cursor: %d | Scroll: %d | Max Scope: %d\n"
              state.cursor state.scroll_offset state.max_scope_id;
            Printf.printf "Times: %s | Values First: %s\n"
              (if state.show_times then "ON" else "OFF")
              (if state.values_first then "ON" else "OFF");
            (match state.quiet_path with
            | Some qp -> Printf.printf "Quiet Path: %s\n" qp
            | None -> ());
            Printf.printf "Expanded Scopes: %d\n" (List.length state.expanded_scopes);
            Printf.printf "\n--- Search Slots ---\n";
            if search_slots = [] then
              Printf.printf "No active searches.\n"
            else
              List.iter
                (fun slot ->
                  let status = if slot.Minidebug_client.Tui_db.completed then "done" else "searching..." in
                  let term_display =
                    match slot.search_term with
                    | Some t -> t
                    | None -> Option.value ~default:"" slot.display_text
                  in
                  Printf.printf "Slot %d: %s [%s] - %d results (%s)\n"
                    (match slot.slot_number with
                     | Minidebug_client.Interactive.SlotNumber.S1 -> 1
                     | S2 -> 2
                     | S3 -> 3
                     | S4 -> 4)
                    slot.search_type term_display slot.result_count status)
                search_slots);
        Minidebug_client.Tui_db.close tui_db
    | Help ->
        print_endline usage_msg;
        exit 0
  with
  | Failure msg ->
      Printf.eprintf "Error: %s\n" msg;
      Minidebug_cli.Cli.close client;
      exit 1
  | e ->
      Printf.eprintf "Error: %s\n" (Printexc.to_string e);
      Minidebug_cli.Cli.close client;
      exit 1
