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

  let client = Minidebug_client.Client.open_db db_path in

  try
    match cmd with
    | List ->
        let runs = Minidebug_client.Client.list_runs client in
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
              (Minidebug_client.Renderer.format_elapsed_ns run.elapsed_ns))
          runs
    | Stats -> Minidebug_client.Client.show_stats client
    | Show ->
        Minidebug_client.Client.(
          show_run_summary client (Option.get (get_latest_run client)).run_id);
        Minidebug_client.Client.show_trace client ~show_scope_ids:opts.show_scope_ids
          ~show_times:opts.show_times ~max_depth:opts.max_depth
          ~values_first_mode:opts.values_first_mode
    | Interactive ->
        (* Open database connection for interactive mode. Not READONLY so it can see
           writes from search Domains via WAL. *)
        let db = Sqlite3.db_open db_path in
        Minidebug_client.Interactive.run db db_path;
        Sqlite3.db_close db |> ignore
    | Compact ->
        Minidebug_client.Client.(
          show_run_summary client (Option.get (get_latest_run client)).run_id);
        Minidebug_client.Client.show_compact_trace client
    | Roots ->
        Minidebug_client.Client.(
          show_run_summary client (Option.get (get_latest_run client)).run_id);
        Minidebug_client.Client.show_roots client ~show_times:opts.show_times
          ~with_values:opts.with_values
    | Search pattern -> Minidebug_client.Client.search client ~pattern
    | SearchTree pattern ->
        let _ =
          Minidebug_client.Client.search_tree ~quiet_path:opts.quiet_path
            ~format:opts.format ~show_times:opts.show_times ~max_depth:opts.max_depth
            ~limit:opts.limit ~offset:opts.offset client ~pattern
        in
        ()
    | SearchSubtree pattern ->
        let _ =
          Minidebug_client.Client.search_subtree ~quiet_path:opts.quiet_path
            ~format:opts.format ~show_times:opts.show_times ~max_depth:opts.max_depth
            ~limit:opts.limit ~offset:opts.offset client ~pattern
        in
        ()
    | SearchAtDepth (pattern, depth) ->
        Minidebug_client.Client.search_at_depth ~quiet_path:opts.quiet_path
          ~format:opts.format ~show_times:opts.show_times ~depth client ~pattern
    | SearchIntersection patterns ->
        let _ =
          Minidebug_client.Client.search_intersection ~quiet_path:opts.quiet_path
            ~format:opts.format ~show_times:opts.show_times ~max_depth:opts.max_depth
            ~limit:opts.limit ~offset:opts.offset client ~patterns
        in
        ()
    | SearchExtract (search_path, extraction_path) ->
        Minidebug_client.Client.search_extract ~format:opts.format
          ~show_times:opts.show_times ~max_depth:opts.max_depth client ~search_path
          ~extraction_path
    | ShowScope scope_id ->
        Minidebug_client.Client.show_scope ~format:opts.format ~show_times:opts.show_times
          ~max_depth:opts.max_depth ~show_ancestors:opts.show_ancestors client ~scope_id
    | ShowSubtree scope_id ->
        Minidebug_client.Client.show_subtree ~format:opts.format ~show_times:opts.show_times
          ~max_depth:opts.max_depth ~show_ancestors:opts.show_ancestors client ~scope_id
    | ShowEntry (scope_id, seq_id) ->
        Minidebug_client.Client.show_entry ~format:opts.format client ~scope_id ~seq_id
    | GetAncestors scope_id ->
        Minidebug_client.Client.get_ancestors ~format:opts.format client ~scope_id
    | GetParent scope_id ->
        Minidebug_client.Client.get_parent ~format:opts.format client ~scope_id
    | GetChildren scope_id ->
        Minidebug_client.Client.get_children ~format:opts.format client ~scope_id
    | Export file -> Minidebug_client.Client.export_markdown client ~output_file:file
    | Help ->
        print_endline usage_msg;
        exit 0
  with
  | Failure msg ->
      Printf.eprintf "Error: %s\n" msg;
      Minidebug_client.Client.close client;
      exit 1
  | e ->
      Printf.eprintf "Error: %s\n" (Printexc.to_string e);
      Minidebug_client.Client.close client;
      exit 1
