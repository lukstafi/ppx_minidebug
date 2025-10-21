(** CLI tool for viewing ppx_minidebug database traces *)

let usage_msg =
  {|minidebug_view - View ppx_minidebug database traces

USAGE:
  minidebug_view <database> <command> [options]

COMMANDS:
  list                    List all runs in database
  stats                   Show database statistics
  show [run_id]           Show trace tree (latest run if no ID given)
  interactive [run_id]    Interactive TUI for exploring trace (alias: tui)
  compact [run_id]        Show compact trace (function names only)
  roots [run_id]          Show root entries only (fast for large DBs)
  search <pattern>        Search entries by regex pattern
  export <file>           Export latest run to markdown

OPTIONS:
  --run=<id>              Specify run ID (for show, compact, search, roots)
  --entry-ids             Show entry IDs in output
  --times                 Show elapsed times
  --max-depth=<n>         Limit tree depth
  --values-first          Show result values as headers (values-first mode)
  --with-values           Include immediate children values (for roots command)
  --help                  Show this help message

EXAMPLES:
  # Show latest trace
  minidebug_view trace.db show

  # Show root entries only (efficient for large DBs)
  minidebug_view trace.db roots --times

  # Show root entries with their immediate children
  minidebug_view trace.db roots --with-values --times

  # Show specific run with entry IDs and times
  minidebug_view trace.db show --run=1 --entry-ids --times

  # Search for function calls matching pattern
  minidebug_view trace.db search "fib"

  # Export to markdown
  minidebug_view trace.db export output.md
|}

type command =
  | List
  | Stats
  | Show of int option
  | Interactive of int option
  | Compact of int option
  | Roots of int option
  | Search of string
  | Export of string
  | Help

type options = {
  show_entry_ids : bool;
  show_times : bool;
  max_depth : int option;
  run_id : int option;
  values_first_mode : bool;
  with_values : bool;
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
            show_entry_ids = false;
            show_times = false;
            max_depth = None;
            run_id = None;
            values_first_mode = false;
            with_values = false;
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
        | "show" :: rest -> (
            match rest with
            | id :: rest' when String.length id > 0 && id.[0] <> '-' ->
                cmd_ref := Show (Some (int_of_string id));
                parse_rest rest'
            | _ ->
                cmd_ref := Show None;
                parse_rest rest)
        | ("interactive" | "tui") :: rest -> (
            match rest with
            | id :: rest' when String.length id > 0 && id.[0] <> '-' ->
                cmd_ref := Interactive (Some (int_of_string id));
                parse_rest rest'
            | _ ->
                cmd_ref := Interactive None;
                parse_rest rest)
        | "compact" :: rest -> (
            match rest with
            | id :: rest' when String.length id > 0 && id.[0] <> '-' ->
                cmd_ref := Compact (Some (int_of_string id));
                parse_rest rest'
            | _ ->
                cmd_ref := Compact None;
                parse_rest rest)
        | "roots" :: rest -> (
            match rest with
            | id :: rest' when String.length id > 0 && id.[0] <> '-' ->
                cmd_ref := Roots (Some (int_of_string id));
                parse_rest rest'
            | _ ->
                cmd_ref := Roots None;
                parse_rest rest)
        | "search" :: pattern :: rest ->
            cmd_ref := Search pattern;
            parse_rest rest
        | "export" :: file :: rest ->
            cmd_ref := Export file;
            parse_rest rest
        | "--help" :: _ | "-h" :: _ -> cmd_ref := Help
        | opt :: rest when String.starts_with ~prefix:"--" opt -> (
            match String.split_on_char '=' opt with
            | [ "--run"; id ] ->
                opts := { !opts with run_id = Some (int_of_string id) };
                parse_rest rest
            | [ "--max-depth"; d ] ->
                opts := { !opts with max_depth = Some (int_of_string d) };
                parse_rest rest
            | [ "--entry-ids" ] ->
                opts := { !opts with show_entry_ids = true };
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
    | Show run_id_opt ->
        let run_id =
          match (run_id_opt, opts.run_id) with
          | Some id, _ | _, Some id -> id
          | None, None -> (
              match Minidebug_client.Client.get_latest_run client with
              | Some run -> run.run_id
              | None ->
                  Printf.eprintf "Error: No runs found in database\n";
                  exit 1)
        in
        Minidebug_client.Client.show_run_summary client run_id;
        Minidebug_client.Client.show_trace client ~show_entry_ids:opts.show_entry_ids
          ~show_times:opts.show_times ~max_depth:opts.max_depth
          ~values_first_mode:opts.values_first_mode run_id
    | Interactive run_id_opt ->
        let run_id =
          match (run_id_opt, opts.run_id) with
          | Some id, _ | _, Some id -> id
          | None, None -> (
              match Minidebug_client.Client.get_latest_run client with
              | Some run -> run.run_id
              | None ->
                  Printf.eprintf "Error: No runs found in database\n";
                  exit 1)
        in
        (* Open a separate database connection for interactive mode *)
        let db = Sqlite3.db_open ~mode:`READONLY db_path in
        Minidebug_client.Interactive.run db db_path run_id;
        Sqlite3.db_close db |> ignore
    | Compact run_id_opt ->
        let run_id =
          match (run_id_opt, opts.run_id) with
          | Some id, _ | _, Some id -> id
          | None, None -> (
              match Minidebug_client.Client.get_latest_run client with
              | Some run -> run.run_id
              | None ->
                  Printf.eprintf "Error: No runs found in database\n";
                  exit 1)
        in
        Minidebug_client.Client.show_run_summary client run_id;
        Minidebug_client.Client.show_compact_trace client run_id
    | Roots run_id_opt ->
        let run_id =
          match (run_id_opt, opts.run_id) with
          | Some id, _ | _, Some id -> id
          | None, None -> (
              match Minidebug_client.Client.get_latest_run client with
              | Some run -> run.run_id
              | None ->
                  Printf.eprintf "Error: No runs found in database\n";
                  exit 1)
        in
        Minidebug_client.Client.show_run_summary client run_id;
        Minidebug_client.Client.show_roots client ~show_times:opts.show_times
          ~with_values:opts.with_values run_id
    | Search pattern ->
        let run_id =
          match opts.run_id with
          | Some id -> id
          | None -> (
              match Minidebug_client.Client.get_latest_run client with
              | Some run -> run.run_id
              | None ->
                  Printf.eprintf "Error: No runs found in database\n";
                  exit 1)
        in
        Minidebug_client.Client.search client ~run_id ~pattern
    | Export file ->
        let run_id =
          match opts.run_id with
          | Some id -> id
          | None -> (
              match Minidebug_client.Client.get_latest_run client with
              | Some run -> run.run_id
              | None ->
                  Printf.eprintf "Error: No runs found in database\n";
                  exit 1)
        in
        Minidebug_client.Client.export_markdown client ~run_id ~output_file:file
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
