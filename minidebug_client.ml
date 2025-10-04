(** In-process client for querying and displaying ppx_minidebug database traces *)

module CFormat = Format

(** Query layer for database access *)
module Query = struct
  type entry = {
    entry_id : int;
    parent_id : int option;
    depth : int;
    message : string;
    location : string option;
    data : string option;
    elapsed_start_ns : int;
    elapsed_end_ns : int option;
    is_result : bool;
    log_level : int;
    entry_type : string;
  }

  type run_info = {
    run_id : int;
    timestamp : string;
    elapsed_ns : int;
    command_line : string;
  }

  type stats = {
    total_entries : int;
    total_values : int;
    unique_values : int;
    dedup_percentage : float;
    database_size_kb : int;
  }

  (** Get all runs from database *)
  let get_runs db =
    let stmt = Sqlite3.prepare db "SELECT run_id, timestamp, elapsed_ns, command_line FROM runs ORDER BY run_id DESC" in
    let runs = ref [] in
    let rec loop () =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          let run = {
            run_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0);
            timestamp = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 1);
            elapsed_ns = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 2);
            command_line = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 3);
          } in
          runs := run :: !runs;
          loop ()
      | _ -> ()
    in
    loop ();
    Sqlite3.finalize stmt |> ignore;
    List.rev !runs

  (** Get latest run ID *)
  let get_latest_run_id db =
    let stmt = Sqlite3.prepare db "SELECT MAX(run_id) FROM runs" in
    let run_id =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          (match Sqlite3.column stmt 0 with
          | Sqlite3.Data.INT id -> Some (Int64.to_int id)
          | _ -> None)
      | _ -> None
    in
    Sqlite3.finalize stmt |> ignore;
    run_id

  (** Get entries for a specific run *)
  let get_entries db ~run_id ?parent_id ?max_depth () =
    let base_query = {|
      SELECT
        e.entry_id,
        e.parent_id,
        e.depth,
        m.value_content as message,
        l.value_content as location,
        d.value_content as data,
        e.elapsed_start_ns,
        e.elapsed_end_ns,
        e.is_result,
        e.log_level,
        e.entry_type
      FROM entries e
      JOIN value_atoms m ON e.message_value_id = m.value_id
      LEFT JOIN value_atoms l ON e.location_value_id = l.value_id
      LEFT JOIN value_atoms d ON e.data_value_id = d.value_id
      WHERE e.run_id = ?
    |} in

    let query = match parent_id, max_depth with
      | None, None -> base_query ^ " ORDER BY e.entry_id"
      | Some _, None -> base_query ^ " AND e.parent_id = ? ORDER BY e.entry_id"
      | None, Some _ -> base_query ^ " AND e.depth <= ? ORDER BY e.entry_id"
      | Some _, Some _ -> base_query ^ " AND e.parent_id = ? AND e.depth <= ? ORDER BY e.entry_id"
    in

    let stmt = Sqlite3.prepare db query in
    Sqlite3.bind_int stmt 1 run_id |> ignore;
    (match parent_id, max_depth with
    | None, None -> ()
    | Some pid, None -> Sqlite3.bind_int stmt 2 pid |> ignore
    | None, Some d -> Sqlite3.bind_int stmt 2 d |> ignore
    | Some pid, Some d ->
        Sqlite3.bind_int stmt 2 pid |> ignore;
        Sqlite3.bind_int stmt 3 d |> ignore);

    let entries = ref [] in
    let rec loop () =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          let entry = {
            entry_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0);
            parent_id = (match Sqlite3.column stmt 1 with
              | Sqlite3.Data.INT id -> Some (Int64.to_int id)
              | _ -> None);
            depth = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 2);
            message = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 3);
            location = (match Sqlite3.column stmt 4 with
              | Sqlite3.Data.TEXT s -> Some s
              | _ -> None);
            data = (match Sqlite3.column stmt 5 with
              | Sqlite3.Data.TEXT s -> Some s
              | _ -> None);
            elapsed_start_ns = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 6);
            elapsed_end_ns = (match Sqlite3.column stmt 7 with
              | Sqlite3.Data.INT ns -> Some (Int64.to_int ns)
              | _ -> None);
            is_result = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 8) = 1;
            log_level = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 9);
            entry_type = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 10);
          } in
          entries := entry :: !entries;
          loop ()
      | _ -> ()
    in
    loop ();
    Sqlite3.finalize stmt |> ignore;
    List.rev !entries

  (** Get database statistics *)
  let get_stats db db_path =
    let stmt = Sqlite3.prepare db {|
      SELECT
        (SELECT COUNT(*) FROM entries) as total_entries,
        (SELECT COUNT(*) FROM value_atoms) as total_values,
        (SELECT COUNT(DISTINCT value_hash) FROM value_atoms) as unique_values
    |} in

    let stats =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          let total_entries = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0) in
          let total_values = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 1) in
          let unique_values = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 2) in
          let dedup_percentage =
            if total_values = 0 then 0.0
            else 100.0 *. (1.0 -. (float_of_int unique_values /. float_of_int total_values))
          in
          let size_kb =
            try
              let stat = Unix.stat db_path in
              stat.Unix.st_size / 1024
            with _ -> 0
          in
          {
            total_entries;
            total_values;
            unique_values;
            dedup_percentage;
            database_size_kb = size_kb;
          }
      | _ -> {
          total_entries = 0;
          total_values = 0;
          unique_values = 0;
          dedup_percentage = 0.0;
          database_size_kb = 0;
        }
    in
    Sqlite3.finalize stmt |> ignore;
    stats

  (** Search entries by regex pattern *)
  let search_entries db ~run_id ~pattern =
    let entries = get_entries db ~run_id () in
    let re = Re.compile (Re.Pcre.re pattern) in
    List.filter (fun entry ->
      Re.execp re entry.message ||
      (match entry.location with Some loc -> Re.execp re loc | None -> false) ||
      (match entry.data with Some d -> Re.execp re d | None -> false)
    ) entries
end

(** Tree renderer for terminal output *)
module Renderer = struct
  type tree_node = {
    entry : Query.entry;
    children : tree_node list;
  }

  (** Build tree structure from flat entry list *)
  let build_tree entries =
    let by_id = Hashtbl.create 100 in
    let roots = ref [] in

    (* Index all entries by ID *)
    List.iter (fun entry ->
      Hashtbl.add by_id entry.Query.entry_id entry
    ) entries;

    (* Build tree structure *)
    let rec build_node entry =
      let children_entries =
        List.filter (fun e ->
          match e.Query.parent_id with
          | Some pid -> pid = entry.Query.entry_id
          | None -> false
        ) entries
      in
      let children = List.map build_node children_entries in
      { entry; children }
    in

    (* Find roots (entries with no parent or parent not in list) *)
    List.iter (fun entry ->
      match entry.Query.parent_id with
      | None -> roots := entry :: !roots
      | Some pid ->
          if not (Hashtbl.mem by_id pid) then
            roots := entry :: !roots
    ) entries;

    List.map build_node (List.rev !roots)

  (** Format elapsed time *)
  let format_elapsed_ns ns =
    if ns < 1000 then Printf.sprintf "%dns" ns
    else if ns < 1_000_000 then Printf.sprintf "%.2fμs" (float_of_int ns /. 1e3)
    else if ns < 1_000_000_000 then Printf.sprintf "%.2fms" (float_of_int ns /. 1e6)
    else Printf.sprintf "%.2fs" (float_of_int ns /. 1e9)

  (** Calculate elapsed time for entry *)
  let elapsed_time entry =
    match entry.Query.elapsed_end_ns with
    | Some end_ns -> Some (end_ns - entry.elapsed_start_ns)
    | None -> None

  (** Render tree to string with indentation *)
  let render_tree ?(show_entry_ids=false) ?(show_times=false) ?(max_depth=None) ?(values_first_mode=false) trees =
    let buf = Buffer.create 1024 in

    let rec render_node ~indent ~depth node =
      let entry = node.entry in
      let skip = match max_depth with
        | Some d -> depth > d
        | None -> false
      in

      if not skip then begin
        (* Indentation *)
        Buffer.add_string buf indent;

        (* Entry ID (optional) *)
        if show_entry_ids then
          Buffer.add_string buf (Printf.sprintf "{#%d} " entry.entry_id);

        if values_first_mode && entry.is_result then begin
          (* In values_first_mode, result becomes the header *)
          (match entry.data with
          | Some data ->
              Buffer.add_string buf data;
              (* Elapsed time after result value *)
              if show_times then
                (match elapsed_time entry with
                | Some elapsed -> Buffer.add_string buf (Printf.sprintf " <%s>" (format_elapsed_ns elapsed))
                | None -> ());
              Buffer.add_string buf "\n";

              (* Location becomes a child item *)
              (match entry.location with
              | Some loc ->
                  Buffer.add_string buf (indent ^ "  ");
                  Buffer.add_string buf (Printf.sprintf "@ %s" loc);
                  Buffer.add_string buf "\n"
              | None -> ());

              (* Message as child item *)
              Buffer.add_string buf (indent ^ "  ");
              Buffer.add_string buf (Printf.sprintf "[%s] %s" entry.entry_type entry.message);
              Buffer.add_string buf "\n"
          | None ->
              (* No result data, fall back to normal rendering *)
              Buffer.add_string buf (Printf.sprintf "[%s] %s" entry.entry_type entry.message);
              (match entry.location with
              | Some loc -> Buffer.add_string buf (Printf.sprintf " @ %s" loc)
              | None -> ());
              if show_times then
                (match elapsed_time entry with
                | Some elapsed -> Buffer.add_string buf (Printf.sprintf " <%s>" (format_elapsed_ns elapsed))
                | None -> ());
              Buffer.add_string buf "\n");
        end else begin
          (* Normal rendering mode *)
          (* Message and type *)
          Buffer.add_string buf (Printf.sprintf "[%s] %s"
            entry.entry_type entry.message);

          (* Location *)
          (match entry.location with
          | Some loc -> Buffer.add_string buf (Printf.sprintf " @ %s" loc)
          | None -> ());

          (* Elapsed time *)
          if show_times then
            (match elapsed_time entry with
            | Some elapsed -> Buffer.add_string buf (Printf.sprintf " <%s>" (format_elapsed_ns elapsed))
            | None -> ());

          Buffer.add_string buf "\n";

          (* Data (if present) *)
          (match entry.data with
          | Some data when not entry.is_result ->
              Buffer.add_string buf (indent ^ "  ");
              Buffer.add_string buf data;
              Buffer.add_string buf "\n"
          | _ -> ());

          (* Result (if present) *)
          if entry.is_result then
            (match entry.data with
            | Some data ->
                Buffer.add_string buf (indent ^ "  => ");
                Buffer.add_string buf data;
                Buffer.add_string buf "\n"
            | None -> ());
        end;

        (* Children *)
        let child_indent = indent ^ "  " in
        List.iter (render_node ~indent:child_indent ~depth:(depth + 1)) node.children
      end
    in

    List.iter (render_node ~indent:"" ~depth:0) trees;
    Buffer.contents buf

  (** Render compact summary (just function calls) *)
  let render_compact trees =
    let buf = Buffer.create 1024 in

    let rec render_node ~indent node =
      let entry = node.entry in
      Buffer.add_string buf indent;
      Buffer.add_string buf (Printf.sprintf "%s" entry.message);

      (match elapsed_time entry with
      | Some elapsed -> Buffer.add_string buf (Printf.sprintf " <%s>" (format_elapsed_ns elapsed))
      | None -> ());

      Buffer.add_string buf "\n";

      let child_indent = indent ^ "  " in
      List.iter (render_node ~indent:child_indent) node.children
    in

    List.iter (render_node ~indent:"") trees;
    Buffer.contents buf
end

(** Main client interface *)
module Client = struct
  type t = {
    db : Sqlite3.db;
    db_path : string;
  }

  let open_db db_path =
    let db = Sqlite3.db_open ~mode:`READONLY db_path in
    { db; db_path }

  let close t =
    Sqlite3.db_close t.db |> ignore

  (** List all runs *)
  let list_runs t =
    Query.get_runs t.db

  (** Get latest run *)
  let get_latest_run t =
    match Query.get_latest_run_id t.db with
    | Some run_id ->
        let runs = Query.get_runs t.db in
        List.find_opt (fun r -> r.Query.run_id = run_id) runs
    | None -> None

  (** Show run summary *)
  let show_run_summary t run_id =
    let runs = Query.get_runs t.db in
    match List.find_opt (fun r -> r.Query.run_id = run_id) runs with
    | Some run ->
        Printf.printf "Run #%d\n" run.run_id;
        Printf.printf "Timestamp: %s\n" run.timestamp;
        Printf.printf "Command: %s\n" run.command_line;
        Printf.printf "Elapsed: %s\n\n" (Renderer.format_elapsed_ns run.elapsed_ns)
    | None ->
        Printf.printf "Run #%d not found\n" run_id

  (** Show database statistics *)
  let show_stats t =
    let stats = Query.get_stats t.db t.db_path in
    Printf.printf "Database Statistics\n";
    Printf.printf "===================\n";
    Printf.printf "Total entries: %d\n" stats.total_entries;
    Printf.printf "Total value references: %d\n" stats.total_values;
    Printf.printf "Unique values: %d\n" stats.unique_values;
    Printf.printf "Deduplication: %.1f%%\n" stats.dedup_percentage;
    Printf.printf "Database size: %d KB\n" stats.database_size_kb

  (** Show trace tree for a run *)
  let show_trace t ?(show_entry_ids=false) ?(show_times=false) ?(max_depth=None) ?(values_first_mode=false) run_id =
    let entries = Query.get_entries t.db ~run_id () in
    let trees = Renderer.build_tree entries in
    let output = Renderer.render_tree ~show_entry_ids ~show_times ~max_depth ~values_first_mode trees in
    print_string output

  (** Show compact trace (function names only) *)
  let show_compact_trace t run_id =
    let entries = Query.get_entries t.db ~run_id () in
    let trees = Renderer.build_tree entries in
    let output = Renderer.render_compact trees in
    print_string output

  (** Search entries *)
  let search t ~run_id ~pattern =
    let entries = Query.search_entries t.db ~run_id ~pattern in
    Printf.printf "Found %d matching entries for pattern '%s':\n\n" (List.length entries) pattern;
    List.iter (fun entry ->
      Printf.printf "{#%d} [%s] %s" entry.Query.entry_id entry.entry_type entry.message;
      (match entry.location with
      | Some loc -> Printf.printf " @ %s" loc
      | None -> ());
      Printf.printf "\n";
      (match entry.data with
      | Some data -> Printf.printf "  %s\n" data
      | None -> ())
    ) entries

  (** Export trace to markdown *)
  let export_markdown t ~run_id ~output_file =
    let runs = Query.get_runs t.db in
    let run = List.find_opt (fun r -> r.Query.run_id = run_id) runs in
    let entries = Query.get_entries t.db ~run_id () in
    let trees = Renderer.build_tree entries in

    let oc = open_out output_file in

    (* Header *)
    (match run with
    | Some r ->
        Printf.fprintf oc "# Trace Run #%d\n\n" r.run_id;
        Printf.fprintf oc "- **Timestamp**: %s\n" r.timestamp;
        Printf.fprintf oc "- **Command**: `%s`\n" r.command_line;
        Printf.fprintf oc "- **Elapsed**: %s\n\n" (Renderer.format_elapsed_ns r.elapsed_ns)
    | None -> ());

    Printf.fprintf oc "## Execution Trace\n\n";

    let rec render_node ~depth (node : Renderer.tree_node) =
      let entry = node.Renderer.entry in
      let indent = String.make (depth * 2) ' ' in

      (* Entry header *)
      Printf.fprintf oc "%s- **%s** `%s`" indent entry.entry_type entry.message;
      (match entry.location with
      | Some loc -> Printf.fprintf oc " *@ %s*" loc
      | None -> ());
      (match Renderer.elapsed_time entry with
      | Some elapsed -> Printf.fprintf oc " _%s_" (Renderer.format_elapsed_ns elapsed)
      | None -> ());
      Printf.fprintf oc "\n";

      (* Data *)
      (match entry.data with
      | Some data when not entry.is_result ->
          Printf.fprintf oc "%s  ```\n%s  %s\n%s  ```\n" indent indent data indent
      | _ -> ());

      (* Result *)
      if entry.is_result then
        (match entry.data with
        | Some data ->
            Printf.fprintf oc "%s  **=>** `%s`\n" indent data
        | None -> ());

      List.iter (render_node ~depth:(depth + 1)) node.Renderer.children
    in

    List.iter (render_node ~depth:0) trees;
    close_out oc;
    Printf.printf "Exported to %s\n" output_file
end
