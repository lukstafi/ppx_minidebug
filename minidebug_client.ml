(** In-process client for querying and displaying ppx_minidebug database traces *)

module CFormat = Format

(** Query layer for database access *)
module Query = struct
  type entry = {
    entry_id : int; (* Scope ID - groups all rows for a scope *)
    seq_id : int; (* Position within parent's children *)
    header_entry_id : int option; (* NULL for values, points to new scope for headers *)
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
    run_name : string option;
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
    let stmt =
      Sqlite3.prepare db
        "SELECT run_id, timestamp, elapsed_ns, command_line FROM runs ORDER BY \
         run_id DESC"
    in
    let runs = ref [] in
    let rec loop () =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          let run =
            {
              run_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0);
              timestamp = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 1);
              elapsed_ns = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 2);
              command_line = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 3);
              run_name = None;
            }
          in
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
      | Sqlite3.Rc.ROW -> (
          match Sqlite3.column stmt 0 with
          | Sqlite3.Data.INT id -> Some (Int64.to_int id)
          | _ -> None)
      | _ -> None
    in
    Sqlite3.finalize stmt |> ignore;
    run_id

  (** Get entries for a specific run *)
  let get_entries db ~run_id ?parent_id ?max_depth () =
    let base_query =
      {|
      SELECT
        e.entry_id,
        e.seq_id,
        e.header_entry_id,
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
      LEFT JOIN value_atoms m ON e.message_value_id = m.value_id
      LEFT JOIN value_atoms l ON e.location_value_id = l.value_id
      LEFT JOIN value_atoms d ON e.data_value_id = d.value_id
      WHERE e.run_id = ?
    |}
    in

    let query =
      match (parent_id, max_depth) with
      | None, None -> base_query ^ " ORDER BY e.entry_id, e.seq_id"
      | Some _, None -> base_query ^ " AND e.entry_id = ? ORDER BY e.entry_id, e.seq_id"
      | None, Some _ -> base_query ^ " AND e.depth <= ? ORDER BY e.entry_id, e.seq_id"
      | Some _, Some _ ->
          base_query
          ^ " AND e.entry_id = ? AND e.depth <= ? ORDER BY e.entry_id, e.seq_id"
    in

    let stmt = Sqlite3.prepare db query in
    Sqlite3.bind_int stmt 1 run_id |> ignore;
    (match (parent_id, max_depth) with
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
          let entry =
            {
              entry_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0);
              seq_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 1);
              header_entry_id =
                (match Sqlite3.column stmt 2 with
                | Sqlite3.Data.INT id -> Some (Int64.to_int id)
                | _ -> None);
              depth = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 3);
              message =
                (match Sqlite3.column stmt 4 with
                | Sqlite3.Data.TEXT s -> s
                | _ -> "");
              location =
                (match Sqlite3.column stmt 5 with
                | Sqlite3.Data.TEXT s -> Some s
                | _ -> None);
              data =
                (match Sqlite3.column stmt 6 with
                | Sqlite3.Data.TEXT s -> Some s
                | _ -> None);
              elapsed_start_ns = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 7);
              elapsed_end_ns =
                (match Sqlite3.column stmt 8 with
                | Sqlite3.Data.INT ns -> Some (Int64.to_int ns)
                | _ -> None);
              is_result = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 9) = 1;
              log_level = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 10);
              entry_type = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 11);
            }
          in
          entries := entry :: !entries;
          loop ()
      | _ -> ()
    in
    loop ();
    Sqlite3.finalize stmt |> ignore;
    List.rev !entries

  (** Get database statistics *)
  let get_stats db db_path =
    let stmt =
      Sqlite3.prepare db
        {|
      SELECT
        (SELECT COUNT(*) FROM entries) as total_entries,
        (SELECT COUNT(*) FROM value_atoms) as total_values,
        (SELECT COUNT(DISTINCT value_hash) FROM value_atoms) as unique_values
    |}
    in

    let stats =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          let total_entries = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0) in
          let total_values = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 1) in
          let unique_values = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 2) in
          let dedup_percentage =
            if total_values = 0 then 0.0
            else
              100.0 *. (1.0 -. (float_of_int unique_values /. float_of_int total_values))
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
      | _ ->
          {
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
    List.filter
      (fun entry ->
        Re.execp re entry.message
        || (match entry.location with Some loc -> Re.execp re loc | None -> false)
        || match entry.data with Some d -> Re.execp re d | None -> false)
      entries

  (** Get maximum entry_id for a run *)
  let get_max_entry_id db ~run_id =
    let stmt = Sqlite3.prepare db "SELECT MAX(entry_id) FROM entries WHERE run_id = ?" in
    Sqlite3.bind_int stmt 1 run_id |> ignore;
    let max_id =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW -> (
          match Sqlite3.column stmt 0 with
          | Sqlite3.Data.INT id -> Some (Int64.to_int id)
          | _ -> None)
      | _ -> None
    in
    Sqlite3.finalize stmt |> ignore;
    Option.value ~default:0 max_id

  (** Get only root entries efficiently - roots are those with entry_id=0 *)
  let get_root_entries db ~run_id ~with_values =
    let query =
      if with_values then
        (* Get entries at depth 0 and 1 - roots and their immediate children *)
        {|
      SELECT
        e.entry_id,
        e.seq_id,
        e.header_entry_id,
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
      LEFT JOIN value_atoms m ON e.message_value_id = m.value_id
      LEFT JOIN value_atoms l ON e.location_value_id = l.value_id
      LEFT JOIN value_atoms d ON e.data_value_id = d.value_id
      WHERE e.run_id = ? AND e.depth <= 1
      ORDER BY e.entry_id, e.seq_id
    |}
      else
        (* Get only headers at root level (entry_id=0, header_entry_id NOT NULL) *)
        {|
      SELECT
        e.entry_id,
        e.seq_id,
        e.header_entry_id,
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
      LEFT JOIN value_atoms m ON e.message_value_id = m.value_id
      LEFT JOIN value_atoms l ON e.location_value_id = l.value_id
      LEFT JOIN value_atoms d ON e.data_value_id = d.value_id
      WHERE e.run_id = ? AND e.entry_id = 0 AND e.header_entry_id IS NOT NULL
      ORDER BY e.seq_id
    |}
    in

    let stmt = Sqlite3.prepare db query in
    Sqlite3.bind_int stmt 1 run_id |> ignore;

    let entries = ref [] in
    let rec loop () =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          let entry =
            {
              entry_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0);
              seq_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 1);
              header_entry_id =
                (match Sqlite3.column stmt 2 with
                | Sqlite3.Data.INT id -> Some (Int64.to_int id)
                | _ -> None);
              depth = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 3);
              message =
                (match Sqlite3.column stmt 4 with
                | Sqlite3.Data.TEXT s -> s
                | _ -> "");
              location =
                (match Sqlite3.column stmt 5 with
                | Sqlite3.Data.TEXT s -> Some s
                | _ -> None);
              data =
                (match Sqlite3.column stmt 6 with
                | Sqlite3.Data.TEXT s -> Some s
                | _ -> None);
              elapsed_start_ns = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 7);
              elapsed_end_ns =
                (match Sqlite3.column stmt 8 with
                | Sqlite3.Data.INT ns -> Some (Int64.to_int ns)
                | _ -> None);
              is_result = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 9) = 1;
              log_level = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 10);
              entry_type = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 11);
            }
          in
          entries := entry :: !entries;
          loop ()
      | _ -> ()
    in
    loop ();
    Sqlite3.finalize stmt |> ignore;
    List.rev !entries

  (** Check if an entry has any children (efficient query) *)
  let has_children db ~run_id ~parent_entry_id =
    let query =
      {|
      SELECT 1
      FROM entries
      WHERE run_id = ? AND entry_id = ?
      LIMIT 1
    |}
    in
    let stmt = Sqlite3.prepare db query in
    Sqlite3.bind_int stmt 1 run_id |> ignore;
    Sqlite3.bind_int stmt 2 parent_entry_id |> ignore;
    let has_child =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW -> true
      | _ -> false
    in
    Sqlite3.finalize stmt |> ignore;
    has_child

  (** Get parent entry_id for a given entry *)
  let get_parent_id db ~run_id ~entry_id =
    let query =
      {|
      SELECT parent_id
      FROM entry_parents
      WHERE run_id = ? AND entry_id = ?
    |}
    in
    let stmt = Sqlite3.prepare db query in
    Sqlite3.bind_int stmt 1 run_id |> ignore;
    Sqlite3.bind_int stmt 2 entry_id |> ignore;

    let parent_id =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW -> (
          match Sqlite3.column stmt 0 with
          | Sqlite3.Data.INT id -> Some (Int64.to_int id)
          | Sqlite3.Data.NULL -> None
          | _ -> None)
      | _ -> None
    in
    Sqlite3.finalize stmt |> ignore;
    parent_id

  let get_scope_children db ~run_id ~parent_entry_id =
    let query =
      {|
      SELECT
        e.entry_id,
        e.seq_id,
        e.header_entry_id,
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
      LEFT JOIN value_atoms m ON e.message_value_id = m.value_id
      LEFT JOIN value_atoms l ON e.location_value_id = l.value_id
      LEFT JOIN value_atoms d ON e.data_value_id = d.value_id
      WHERE e.run_id = ? AND e.entry_id = ?
      ORDER BY e.seq_id
    |}
    in

    let stmt = Sqlite3.prepare db query in
    Sqlite3.bind_int stmt 1 run_id |> ignore;
    Sqlite3.bind_int stmt 2 parent_entry_id |> ignore;

    let entries = ref [] in
    let rec loop () =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          let entry =
            {
              entry_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0);
              seq_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 1);
              header_entry_id =
                (match Sqlite3.column stmt 2 with
                | Sqlite3.Data.INT id -> Some (Int64.to_int id)
                | _ -> None);
              depth = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 3);
              message =
                (match Sqlite3.column stmt 4 with
                | Sqlite3.Data.TEXT s -> s
                | _ -> "");
              location =
                (match Sqlite3.column stmt 5 with
                | Sqlite3.Data.TEXT s -> Some s
                | _ -> None);
              data =
                (match Sqlite3.column stmt 6 with
                | Sqlite3.Data.TEXT s -> Some s
                | _ -> None);
              elapsed_start_ns = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 7);
              elapsed_end_ns =
                (match Sqlite3.column stmt 8 with
                | Sqlite3.Data.INT ns -> Some (Int64.to_int ns)
                | _ -> None);
              is_result = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 9) = 1;
              log_level = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 10);
              entry_type = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 11);
            }
          in
          entries := entry :: !entries;
          loop ()
      | _ -> ()
    in
    loop ();
    Sqlite3.finalize stmt |> ignore;
    List.rev !entries

  (** Clear search results table for a given slot (1-4) and run *)
  let clear_search_table db ~run_id ~slot =
    (* Use Sqlite3.exec for DELETE to ensure it executes immediately *)
    let query = Printf.sprintf "DELETE FROM search_results_%d WHERE run_id = %d" slot run_id in
    match Sqlite3.exec db query with
    | Sqlite3.Rc.OK -> ()
    | rc ->
        Printf.eprintf "Warning: Failed to clear search results for slot %d: %s\n%!"
          slot (Sqlite3.Rc.to_string rc)

  (** Populate search results table with entries matching search term.
      This is meant to run in a background Domain. Opens its own DB connection.
      Sets completed_ref to true when finished.
      Propagates highlights to ancestors unless quiet_path matches. *)
  let populate_search_results db_path ~run_id ~slot ~search_term ~quiet_path ~completed_ref =
    (* Log to file for debugging since TUI occupies terminal *)
    let log_error msg =
      try
        let oc = open_out_gen [Open_append; Open_creat] 0o644 "/tmp/minidebug_search.log" in
        Printf.fprintf oc "[%s] Slot %d: %s\n" (Unix.gettimeofday () |> string_of_float) slot msg;
        close_out oc
      with _ -> ()
    in

    try
      Printexc.record_backtrace true;
      log_error (Printf.sprintf "Starting search for '%s', quiet_path=%s" search_term
        (match quiet_path with Some q -> "'" ^ q ^ "'" | None -> "None"));

      (* Open a new database connection for this Domain *)
      let db = Sqlite3.db_open db_path in

      (* First clear the table for this run *)
      clear_search_table db ~run_id ~slot;

    (* Get all entries for this run *)
    let entries = get_entries db ~run_id () in

    (* Prepare insert statement *)
    let insert_query =
      Printf.sprintf
        "INSERT INTO search_results_%d (run_id, entry_id, seq_id, search_term) VALUES (?, ?, ?, ?)"
        slot
    in
    let stmt = Sqlite3.prepare db insert_query in

    (* Helper to check if haystack contains needle as substring *)
    let contains_substring haystack needle =
      try
        let _ = Re.Str.search_forward (Re.Str.regexp_string needle) haystack 0 in
        true
      with Not_found -> false
    in

    (* Helper to check if entry matches quiet_path *)
    let matches_quiet_path entry =
      match quiet_path with
      | None -> false
      | Some qp ->
          contains_substring entry.message qp
          || (match entry.location with
              | Some loc -> contains_substring loc qp
              | None -> false)
          || (match entry.data with
              | Some d -> contains_substring d qp
              | None -> false)
    in

    (* Helper to insert an entry into search results *)
    let insert_entry entry =
      Sqlite3.reset stmt |> ignore;
      Sqlite3.bind_int stmt 1 run_id |> ignore;
      Sqlite3.bind_int stmt 2 entry.entry_id |> ignore;
      Sqlite3.bind_int stmt 3 entry.seq_id |> ignore;
      Sqlite3.bind_text stmt 4 search_term |> ignore;
      (match Sqlite3.step stmt with
      | Sqlite3.Rc.DONE -> ()
      | _ -> ())
    in

    (* Build hash table for fast lookup of entries by header_entry_id *)
    let scope_by_id = Hashtbl.create (List.length entries) in
    List.iter (fun entry ->
      match entry.header_entry_id with
      | Some hid -> Hashtbl.add scope_by_id hid entry
      | None -> ()
    ) entries;

    (* Collect directly matching entries and mark for propagation *)
    let matches_to_propagate = ref [] in
    List.iter
      (fun (entry : entry) ->
        let matches =
          contains_substring entry.message search_term
          || (match entry.location with
              | Some loc -> contains_substring loc search_term
              | None -> false)
          || (match entry.data with
              | Some d -> contains_substring d search_term
              | None -> false)
        in
        if matches then (
          insert_entry entry;
          (* Mark for ancestor propagation if not a quiet_path match *)
          if not (matches_quiet_path entry) then
            matches_to_propagate := entry :: !matches_to_propagate
        ))
      entries;

    (* Propagate highlights to ancestors *)
    let propagated = Hashtbl.create 64 in  (* Track which entries we've already propagated to avoid duplicates *)
    let propagation_count = ref 0 in
    List.iter (fun entry ->
      (* Determine this entry's ID for looking up in entry_parents:
         - For scopes: use header_entry_id (the scope's own ID)
         - For values: use entry_id (their parent scope ID) *)
      let this_entry_id =
        match entry.header_entry_id with
        | Some hid -> hid  (* This is a scope *)
        | None -> entry.entry_id  (* This is a value, use its parent scope *)
      in

      let rec propagate_to_parent current_entry_id =
        match get_parent_id db ~run_id ~entry_id:current_entry_id with
        | None -> ()  (* Reached root *)
        | Some parent_id ->
            (* Skip if already propagated to this parent *)
            if not (Hashtbl.mem propagated parent_id) then (
              Hashtbl.add propagated parent_id ();

              (* Find the parent entry using hash table (O(1) instead of O(n)) *)
              match Hashtbl.find_opt scope_by_id parent_id with
              | Some parent_entry ->
                  (* Check if parent matches quiet_path - if so, stop propagation *)
                  if not (matches_quiet_path parent_entry) then (
                    insert_entry parent_entry;
                    incr propagation_count;
                    propagate_to_parent parent_id
                  )
              | None -> ()
            )
      in
      (* Start propagation from this entry's parent *)
      propagate_to_parent this_entry_id
    ) !matches_to_propagate;

    log_error (Printf.sprintf "Direct matches: %d, Propagated: %d" (List.length !matches_to_propagate) !propagation_count);

    Sqlite3.finalize stmt |> ignore;

      (* Close the database connection *)
      Sqlite3.db_close db |> ignore;

      log_error "Search completed successfully";

      (* Signal completion via shared memory *)
      completed_ref := true
    with exn ->
      log_error (Printf.sprintf "ERROR: %s\n%s" (Printexc.to_string exn) (Printexc.get_backtrace ()));
      (* Still mark as completed even on error *)
      completed_ref := true

  (** Check if an entry matches any active search (returns slot number 1-4, or None).
      Checks slots in reverse chronological order to prioritize more recent searches.
      Slot ordering is determined by current_slot parameter. *)
  let get_search_match db ~run_id ~entry_id ~seq_id ~current_slot =
    (* Check slots in reverse chronological order:
       most recent = (current_slot - 1 + 4) mod 4, then (current_slot - 2 + 4) mod 4, etc. *)
    let rec check_slot_offset offset =
      if offset >= 4 then
        None
      else
        let slot_index = (current_slot - 1 - offset + 8) mod 4 in
        let slot = slot_index + 1 in  (* DB tables are 1-indexed *)

        let query =
          Printf.sprintf
            "SELECT 1 FROM search_results_%d WHERE run_id = ? AND entry_id = ? AND seq_id = ?"
            slot
        in
        let stmt = Sqlite3.prepare db query in
        Sqlite3.bind_int stmt 1 run_id |> ignore;
        Sqlite3.bind_int stmt 2 entry_id |> ignore;
        Sqlite3.bind_int stmt 3 seq_id |> ignore;

        let result =
          match Sqlite3.step stmt with
          | Sqlite3.Rc.ROW -> Some slot
          | _ -> None
        in
        Sqlite3.finalize stmt |> ignore;

        match result with
        | Some _ -> result
        | None -> check_slot_offset (offset + 1)
    in
    check_slot_offset 0

  (** Get count of search results for a given slot *)
  let get_search_count db ~run_id ~slot =
    let query =
      Printf.sprintf
        "SELECT COUNT(*) FROM search_results_%d WHERE run_id = ?"
        slot
    in
    let stmt = Sqlite3.prepare db query in
    Sqlite3.bind_int stmt 1 run_id |> ignore;

    let count =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW -> Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0)
      | _ -> 0
    in
    Sqlite3.finalize stmt |> ignore;
    count

  (** Get existing search term for a slot, if any *)
  let get_existing_search db ~run_id ~slot =
    let query =
      Printf.sprintf
        "SELECT DISTINCT search_term FROM search_results_%d WHERE run_id = ? LIMIT 1"
        slot
    in
    let stmt = Sqlite3.prepare db query in
    Sqlite3.bind_int stmt 1 run_id |> ignore;

    let term =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW -> (
          match Sqlite3.column stmt 0 with
          | Sqlite3.Data.TEXT s -> Some s
          | _ -> None)
      | _ -> None
    in
    Sqlite3.finalize stmt |> ignore;
    term
end

(** Tree renderer for terminal output *)
module Renderer = struct
  type tree_node = { entry : Query.entry; children : tree_node list }

  (** Build tree structure from flat entry list *)
  let build_tree entries =
    (* Separate headers from values *)
    let headers, _values =
      List.partition (fun e -> e.Query.header_entry_id <> None) entries
    in

    (* Build tree recursively *)
    let rec build_node header_entry_id =
      (* Find the header row for this scope *)
      let header =
        List.find
          (fun e ->
            match e.Query.header_entry_id with
            | Some hid -> hid = header_entry_id
            | None -> false)
          headers
      in

      (* Get all children of this scope (all rows with entry_id = this scope's ID) *)
      let children_entries =
        List.filter
          (fun e -> e.Query.entry_id = header_entry_id)
          entries
      in

      (* Sort by seq_id *)
      let sorted_children_entries =
        List.sort (fun a b -> compare a.Query.seq_id b.Query.seq_id) children_entries
      in

      (* Build child nodes *)
      let children =
        List.map
          (fun child ->
            match child.Query.header_entry_id with
            | Some sub_scope_id ->
                build_node sub_scope_id (* Recursively build subscope *)
            | None -> { entry = child; children = [] }
            (* Leaf value *))
          sorted_children_entries
      in

      { entry = header; children }
    in

    (* Find root entries (entry_id = 0, which means they're children of the virtual
       root) *)
    let root_headers = List.filter (fun e -> e.Query.entry_id = 0) headers in

    (* Sort roots by seq_id *)
    let sorted_roots =
      List.sort (fun a b -> compare a.Query.seq_id b.Query.seq_id) root_headers
    in

    (* Build tree for each root *)
    List.map
      (fun root ->
        match root.Query.header_entry_id with
        | Some hid -> build_node hid
        | None -> { entry = root; children = [] })
      sorted_roots

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
  let render_tree ?(show_entry_ids = false) ?(show_times = false) ?(max_depth = None)
      ?(values_first_mode = false) trees =
    let buf = Buffer.create 1024 in

    let rec render_node ~indent ~depth node =
      let entry = node.entry in
      let skip = match max_depth with Some d -> depth > d | None -> false in

      if not skip then (
        (* Indentation *)
        Buffer.add_string buf indent;

        (* Entry ID (optional) *)
        if show_entry_ids then
          Buffer.add_string buf (Printf.sprintf "{#%d} " entry.entry_id);

        (* Split children for values_first_mode *)
        let results, non_results =
          if values_first_mode then
            List.partition (fun child -> child.entry.is_result) node.children
          else ([], node.children)
        in

        (* Determine rendering mode *)
        let has_children = node.children <> [] in
        match (has_children, values_first_mode, results) with
        | false, _, _ ->
            (* Leaf node: display as "name = value" or "name => value" for results *)
            if entry.message <> "" then
              if entry.is_result then
                Buffer.add_string buf (entry.message ^ " => ")
              else
                Buffer.add_string buf (entry.message ^ " = ");

            (match entry.data with Some data -> Buffer.add_string buf data | None -> ());

            Buffer.add_string buf "\n"
        | true, true, [ result_child ] when result_child.children = [] ->
            (* Scope node with single value result in values_first_mode: combine on one line *)
            (* Format: [type] message => result.message result_value <time> @ location *)
            Buffer.add_string buf
              (Printf.sprintf "[%s] %s" entry.entry_type entry.message);

            (* Add result value *)
            (match result_child.entry.data with
            | Some data
              when result_child.entry.message <> ""
                   && result_child.entry.message <> entry.message ->
                Buffer.add_string buf
                  (Printf.sprintf " => %s = %s" result_child.entry.message data)
            | Some data -> Buffer.add_string buf (Printf.sprintf " => %s" data)
            | None -> ());

            (* Elapsed time *)
            (if show_times then
               match elapsed_time entry with
               | Some elapsed ->
                   Buffer.add_string buf
                     (Printf.sprintf " <%s>" (format_elapsed_ns elapsed))
               | None -> ());

            (* Location *)
            (match entry.location with
            | Some loc -> Buffer.add_string buf (Printf.sprintf " @ %s" loc)
            | None -> ());

            Buffer.add_string buf "\n";

            (* Children: render non-result children (result was already combined with
               header) *)
            let child_indent = indent ^ "  " in
            List.iter (render_node ~indent:child_indent ~depth:(depth + 1)) non_results
        | true, _, _ ->
            (* Normal rendering mode - scope with children *)
            (* Message and type *)
            Buffer.add_string buf
              (Printf.sprintf "[%s] %s" entry.entry_type entry.message);

            (* Location *)
            (match entry.location with
            | Some loc -> Buffer.add_string buf (Printf.sprintf " @ %s" loc)
            | None -> ());

            (* Elapsed time *)
            (if show_times then
               match elapsed_time entry with
               | Some elapsed ->
                   Buffer.add_string buf
                     (Printf.sprintf " <%s>" (format_elapsed_ns elapsed))
               | None -> ());

            Buffer.add_string buf "\n";

            (* Data (if present and not a leaf) *)
            (match entry.data with
            | Some data when has_children ->
                Buffer.add_string buf (indent ^ "  ");
                Buffer.add_string buf data;
                Buffer.add_string buf "\n"
            | _ -> ());

            (* Children *)
            let child_indent = indent ^ "  " in
            if values_first_mode then
              match results with
              | [ result_child ] when result_child.children = [] ->
                  (* Single value result was combined with header, skip it *)
                  List.iter
                    (render_node ~indent:child_indent ~depth:(depth + 1))
                    non_results
              | _ ->
                  (* Multiple results or result is a header: render results first *)
                  List.iter (render_node ~indent:child_indent ~depth:(depth + 1)) results;
                  List.iter
                    (render_node ~indent:child_indent ~depth:(depth + 1))
                    non_results
            else
              List.iter
                (render_node ~indent:child_indent ~depth:(depth + 1))
                node.children)
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
      | Some elapsed ->
          Buffer.add_string buf (Printf.sprintf " <%s>" (format_elapsed_ns elapsed))
      | None -> ());

      Buffer.add_string buf "\n";

      let child_indent = indent ^ "  " in
      List.iter (render_node ~indent:child_indent) node.children
    in

    List.iter (render_node ~indent:"") trees;
    Buffer.contents buf

  (** Render root entries as a flat list *)
  let render_roots ?(show_times = false) ?(with_values = false) (entries : Query.entry list) =
    let buf = Buffer.create 1024 in

    (* Separate headers and values *)
    let headers = List.filter (fun (e : Query.entry) -> e.header_entry_id <> None) entries in
    let values = List.filter (fun (e : Query.entry) -> e.header_entry_id = None) entries in

    (* Sort headers by seq_id *)
    let sorted_headers =
      List.sort (fun (a : Query.entry) (b : Query.entry) -> compare a.seq_id b.seq_id) headers
    in

    List.iter
      (fun (header : Query.entry) ->
        (* Show entry type and message *)
        Buffer.add_string buf (Printf.sprintf "[%s] %s" header.entry_type header.message);

        (* Location *)
        (match header.location with
        | Some loc -> Buffer.add_string buf (Printf.sprintf " @ %s" loc)
        | None -> ());

        (* Elapsed time *)
        (if show_times then
           match elapsed_time header with
           | Some elapsed ->
               Buffer.add_string buf (Printf.sprintf " <%s>" (format_elapsed_ns elapsed))
           | None -> ());

        Buffer.add_string buf "\n";

        (* Show immediate children values if requested *)
        if with_values then
          match header.header_entry_id with
          | Some hid ->
              let child_values =
                List.filter (fun (v : Query.entry) -> v.entry_id = hid) values
                |> List.sort (fun (a : Query.entry) (b : Query.entry) ->
                       compare a.seq_id b.seq_id)
              in
              List.iter
                (fun (child : Query.entry) ->
                  Buffer.add_string buf "  ";
                  if child.is_result then (
                    if child.message <> "" then
                      Buffer.add_string buf (child.message ^ " => ")
                    else
                      Buffer.add_string buf "=> "
                  ) else if child.message <> "" then
                    Buffer.add_string buf (child.message ^ " = ");
                  (match child.data with
                  | Some data -> Buffer.add_string buf data
                  | None -> ());
                  Buffer.add_string buf "\n")
                child_values
          | None -> ())
      sorted_headers;

    Buffer.contents buf
end

(** Interactive TUI using Notty *)
module Interactive = struct
  open Notty
  open Notty_unix

  type search_slot = {
    search_term : string;
    domain_handle : unit Domain.t option; [@warning "-69"]
    completed_ref : bool ref; (* Shared memory flag set by Domain when finished *)
  }

  type view_state = {
    db : Sqlite3.db;
    db_path : string; (* Path to database file for spawning Domains *)
    run_id : int;
    cursor : int; (* Current cursor position in visible items *)
    scroll_offset : int; (* Top visible item index *)
    expanded : (int, unit) Hashtbl.t; (* Set of expanded entry_ids *)
    visible_items : visible_item array; (* Flattened view of tree *)
    show_times : bool;
    values_first : bool;
    max_entry_id : int; (* Maximum entry_id in this run *)
    search_slots : search_slot option array; (* 4 search slots, indexed 0-3 *)
    current_slot : int; (* Next slot to use (0-3) *)
    search_input : string option; (* Active search input buffer *)
    quiet_path_input : string option; (* Active quiet path input buffer *)
    quiet_path : string option; (* Shared quiet path filter - stops highlight propagation *)
  }

  and visible_item = {
    entry : Query.entry;
    indent_level : int;
    is_expandable : bool;
    is_expanded : bool;
  }

  (** Find closest ancestor with positive ID by walking up the tree *)
  let rec find_positive_ancestor_id db run_id entry_id =
    (* Base case: if this entry_id is positive, return it *)
    if entry_id >= 0 then
      Some entry_id
    else
      (* Negative entry_id - walk up to parent *)
      match Query.get_parent_id db ~run_id ~entry_id with
      | Some parent_id -> find_positive_ancestor_id db run_id parent_id
      | None -> None  (* No parent found *)

  (** Build visible items list from database using lazy loading *)
  let build_visible_items db run_id expanded =
    let rec flatten_entry ~depth entry =
      (* Check if this entry actually has children *)
      let is_expandable =
        match entry.Query.header_entry_id with
        | Some hid -> Query.has_children db ~run_id ~parent_entry_id:hid
        | None -> false
      in
      (* Use header_entry_id as the key - it uniquely identifies this scope *)
      let is_expanded =
        match entry.header_entry_id with
        | Some hid -> Hashtbl.mem expanded hid
        | None -> false
      in

      let visible = {
        entry;
        indent_level = depth;
        is_expandable;
        is_expanded;
      } in

      (* Add children if this is expanded *)
      if is_expanded then
        match entry.header_entry_id with
        | Some hid ->
            (* Load children on demand *)
            let children = Query.get_scope_children db ~run_id ~parent_entry_id:hid in
            visible :: List.concat_map (flatten_entry ~depth:(depth + 1)) children
        | None -> [ visible ]
      else [ visible ]
    in

    (* Start with root entries *)
    let roots = Query.get_root_entries db ~run_id ~with_values:false in
    let items = List.concat_map (flatten_entry ~depth:0) roots in
    Array.of_list items

  (** Render a single line *)
  let render_line ~width ~is_selected ~show_times ~margin_width ~db ~run_id ~current_slot item =
    let entry = item.entry in

    (* Check if this entry matches any search (prioritizes more recent searches) *)
    let search_slot_match = Query.get_search_match db ~run_id ~entry_id:entry.entry_id ~seq_id:entry.seq_id ~current_slot in

    (* Entry ID margin - use header_entry_id for scopes, entry_id for values *)
    (* Don't display negative IDs (used for boxified/decomposed values) *)
    let display_id =
      match entry.header_entry_id with
      | Some hid when hid >= 0 -> Some hid  (* This is a scope/header - show its actual scope ID *)
      | Some _ -> None  (* Negative header_entry_id - hide it *)
      | None when entry.entry_id >= 0 -> Some entry.entry_id  (* This is a value - show its parent scope ID *)
      | None -> None  (* Negative entry_id - hide it *)
    in
    let entry_id_str =
      match display_id with
      | Some id -> Printf.sprintf "%*d │ " margin_width id
      | None -> String.make (margin_width + 3) ' '  (* Blank margin: spaces + " │ " *)
    in
    let content_width = width - String.length entry_id_str in

    let indent = String.make (item.indent_level * 2) ' ' in

    (* Expansion indicator *)
    let expansion_mark =
      if item.is_expandable then
        if item.is_expanded then "▼ " else "▶ "
      else "  "
    in

    (* Entry content *)
    let content =
      let display_text =
        let message = entry.message in
        let data = Option.value ~default:"" entry.data in
        let is_result = entry.is_result in
        (if message <> "" then message ^ " " else "") ^
        (if is_result then "=> " else if message <> "" && data <> "" then "= " else "") ^
        data
      in
  match item.entry.header_entry_id with
      | Some _ ->
          (* Header/scope - use message if available, otherwise data, otherwise placeholder *)
          Printf.sprintf "%s%s[%s] %s" indent expansion_mark
            entry.entry_type display_text
      | None ->
          (* Value *)
          Printf.sprintf "%s  %s" indent display_text
    in

    (* Time *)
    let time_str =
      if show_times then
        match Renderer.elapsed_time entry with
        | Some elapsed -> Printf.sprintf " <%s>" (Renderer.format_elapsed_ns elapsed)
        | None -> ""
      else ""
    in

    let full_text = content ^ time_str in
    let truncated =
      if String.length full_text > content_width then
        String.sub full_text 0 (content_width - 3) ^ "..."
      else
        full_text
    in

    (* Determine highlighting colors based on search match and selection *)
    let (content_attr, margin_attr) =
      if is_selected then
        (* Selection takes priority - blue background *)
        (A.(bg lightblue ++ fg black), A.(bg lightblue ++ fg black))
      else
        match search_slot_match with
        | Some 1 -> (A.(fg green), A.(fg green))       (* Search slot 1: green *)
        | Some 2 -> (A.(fg cyan), A.(fg cyan))         (* Search slot 2: cyan *)
        | Some 3 -> (A.(fg magenta), A.(fg magenta))   (* Search slot 3: magenta *)
        | Some 4 -> (A.(fg yellow), A.(fg yellow))     (* Search slot 4: yellow *)
        | _ -> (A.empty, A.(fg yellow))                (* No match: default (margin still yellow) *)
    in

    I.hcat [ I.string margin_attr entry_id_str; I.string content_attr truncated ]

  (** Render the full screen *)
  let render_screen state term_height term_width =
    let header_height = 2 in
    let footer_height = 2 in
    let content_height = term_height - header_height - footer_height in

    (* Calculate margin width based on max_entry_id *)
    let margin_width = String.length (string_of_int state.max_entry_id) in

    (* Calculate progress indicator - find closest ancestor with positive ID *)
    let current_entry_id =
      if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
        let entry = state.visible_items.(state.cursor).entry in
        (* For scopes, use header_entry_id; for values, use entry_id *)
        let id_to_check =
          match entry.header_entry_id with
          | Some hid -> hid
          | None -> entry.entry_id
        in
        match find_positive_ancestor_id state.db state.run_id id_to_check with
        | Some id -> id
        | None -> 0
      else 0
    in
    let progress_pct =
      if state.max_entry_id > 0 then
        float_of_int current_entry_id /. float_of_int state.max_entry_id *. 100.0
      else 0.0
    in

    (* Header *)
    let header =
      let line1 =
        match state.quiet_path_input with
        | Some input ->
            (* Show quiet_path input prompt *)
            I.string A.(fg lightred)
              (Printf.sprintf "Quiet Path: %s_" input)
        | None -> (
            match state.search_input with
            | Some input ->
                (* Show search input prompt *)
                I.string A.(fg lightyellow)
                  (Printf.sprintf "Search: %s_" input)
        | None ->
            (* Show run info and search status *)
            let base_info =
              Printf.sprintf "Run #%d | Items: %d | Times: %s | Values First: %s | Entry: %d/%d (%.1f%%)"
                state.run_id
                (Array.length state.visible_items)
                (if state.show_times then "ON" else "OFF")
                (if state.values_first then "ON" else "OFF")
                current_entry_id
                state.max_entry_id
                progress_pct
            in
            (* Build search status string *)
            let search_status =
              let active_searches = ref [] in
              Array.iteri (fun idx slot_opt ->
                match slot_opt with
                | Some slot ->
                    let slot_num = idx + 1 in
                    let count = Query.get_search_count state.db ~run_id:state.run_id ~slot:slot_num in
                    let color_name = match slot_num with
                      | 1 -> "G" | 2 -> "C" | 3 -> "M" | 4 -> "Y" | _ -> "?" in
                    (* Show [...] while running, just [...] when complete *)
                    let count_str =
                      if !(slot.completed_ref) then
                        Printf.sprintf "[%d]" count
                      else
                        Printf.sprintf "[%d...]" count
                    in
                    active_searches := Printf.sprintf "%s:%s%s" color_name slot.search_term count_str :: !active_searches
                | None -> ()
              ) state.search_slots;
              if !active_searches = [] then ""
              else " | " ^ String.concat " " (List.rev !active_searches)
            in
            (* Add quiet_path indicator if set *)
            let quiet_info =
              match state.quiet_path with
              | Some qp -> Printf.sprintf " | Q:%s" qp
              | None -> ""
            in
            I.string A.(fg lightcyan) (base_info ^ search_status ^ quiet_info)
        )
      in
      I.vcat [
        line1;
        I.string A.(fg white) (String.make term_width '-');
      ]
    in

    (* Content lines *)
    let visible_start = state.scroll_offset in
    let visible_end = min (visible_start + content_height) (Array.length state.visible_items) in

    let content_lines = ref [] in
    for i = visible_start to visible_end - 1 do
      let is_selected = i = state.cursor in
      let item = state.visible_items.(i) in
      let line = render_line ~width:term_width ~is_selected ~show_times:state.show_times ~margin_width ~db:state.db ~run_id:state.run_id ~current_slot:state.current_slot item in
      content_lines := line :: !content_lines
    done;

    (* Pad if needed *)
    let padding_lines = content_height - (visible_end - visible_start) in
    for _ = 1 to padding_lines do
      content_lines := I.string A.empty "" :: !content_lines
    done;

    let content = I.vcat (List.rev !content_lines) in

    (* Footer *)
    let footer =
      let help_text =
        match state.quiet_path_input with
        | Some _ ->
            "[Enter] Confirm quiet path | [Esc] Cancel | [Backspace] Delete"
        | None -> (
            match state.search_input with
            | Some _ ->
                "[Enter] Confirm search | [Esc] Cancel | [Backspace] Delete"
            | None ->
                "[↑/↓] Navigate | [PgUp/PgDn] Page | [Enter] Expand | [/] Search | [Q] Quiet path | [t] Times | [v] Values | [q] Quit"
        )
      in
      I.vcat [
        I.string A.(fg white) (String.make term_width '-');
        I.string A.(fg lightcyan) help_text;
      ]
    in

    I.vcat [ header; content; footer ]

  (** Toggle expansion of current item *)
  let toggle_expansion state =
    if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
      let item = state.visible_items.(state.cursor) in
      if item.is_expandable then (
        match item.entry.header_entry_id with
        | Some hid ->
            (* Use header_entry_id as the unique key for this scope *)
            if Hashtbl.mem state.expanded hid then
              Hashtbl.remove state.expanded hid
            else
              Hashtbl.add state.expanded hid ();

            (* Rebuild visible items *)
            let new_visible = build_visible_items state.db state.run_id state.expanded in
            { state with visible_items = new_visible }
        | None -> state
      ) else state
    else state

  (** Handle key events *)
  let handle_key state key term_height =
    let content_height = term_height - 4 in

    (* Handle quiet_path input mode first *)
    match state.quiet_path_input with
    | Some input -> (
        match key with
        | `Escape, _ ->
            (* Cancel quiet_path input *)
            Some { state with quiet_path_input = None }

        | `Enter, _ ->
            (* Confirm quiet_path *)
            let new_quiet_path = if String.length input > 0 then Some input else None in
            Some { state with quiet_path_input = None; quiet_path = new_quiet_path }

        | `Backspace, _ ->
            (* Remove last character *)
            let new_input =
              if String.length input > 0 then
                String.sub input 0 (String.length input - 1)
              else
                input
            in
            Some { state with quiet_path_input = Some new_input }

        | `ASCII c, _ when c >= ' ' && c <= '~' ->
            (* Add printable character *)
            Some { state with quiet_path_input = Some (input ^ String.make 1 c) }

        | _ -> Some state
    )
    | None -> (
        (* Handle search input mode *)
        match state.search_input with
        | Some input -> (
        match key with
        | `Escape, _ ->
            (* Cancel search input *)
            Some { state with search_input = None }

        | `Enter, _ ->
            (* Confirm search - spawn Domain to populate search table *)
            if String.length input > 0 then
              let slot = state.current_slot in
              let slot_num = slot + 1 in  (* DB tables are 1-indexed *)

              (* Create shared completion flag *)
              let completed_ref = ref false in

              (* Spawn background search Domain - pass db_path not db handle *)
              let domain_handle =
                Domain.spawn (fun () ->
                  Query.populate_search_results state.db_path ~run_id:state.run_id ~slot:slot_num ~search_term:input ~quiet_path:state.quiet_path ~completed_ref
                )
              in

              (* Update search slots *)
              let new_slots = Array.copy state.search_slots in
              new_slots.(slot) <- Some { search_term = input; domain_handle = Some domain_handle; completed_ref };

              Some {
                state with
                search_input = None;
                search_slots = new_slots;
                current_slot = (slot + 1) mod 4;
              }
            else
              (* Empty input - just cancel *)
              Some { state with search_input = None }

        | `Backspace, _ ->
            (* Remove last character *)
            let new_input =
              if String.length input > 0 then
                String.sub input 0 (String.length input - 1)
              else
                input
            in
            Some { state with search_input = Some new_input }

        | `ASCII c, _ when c >= ' ' && c <= '~' ->
            (* Add printable character *)
            Some { state with search_input = Some (input ^ String.make 1 c) }

        | _ -> Some state
    )
    | None -> (
        (* Normal navigation mode *)
        match key with
        | `ASCII 'q', _ | `Escape, _ -> None (* Quit *)

        | `ASCII '/', _ ->
            (* Enter search mode *)
            Some { state with search_input = Some "" }

        | `ASCII 'Q', _ ->
            (* Enter quiet_path mode *)
            Some { state with quiet_path_input = Some (Option.value ~default:"" state.quiet_path) }

        | `Arrow `Up, _ | `ASCII 'k', _ ->
        let new_cursor = max 0 (state.cursor - 1) in
        let new_scroll =
          if new_cursor < state.scroll_offset then new_cursor
          else state.scroll_offset
        in
        Some { state with cursor = new_cursor; scroll_offset = new_scroll }

    | `Arrow `Down, _ | `ASCII 'j', _ ->
        let max_cursor = Array.length state.visible_items - 1 in
        let new_cursor = min max_cursor (state.cursor + 1) in
        let new_scroll =
          if new_cursor >= state.scroll_offset + content_height then
            new_cursor - content_height + 1
          else state.scroll_offset
        in
        Some { state with cursor = new_cursor; scroll_offset = new_scroll }

    | `Enter, _ ->
        Some (toggle_expansion state)

    | `ASCII 't', _ ->
        Some { state with show_times = not state.show_times }

    | `ASCII 'v', _ ->
        Some { state with values_first = not state.values_first }

    | `Page `Up, _ ->
        (* Page Up: Move cursor to top of screen, then scroll up by content_height - 1 *)
        if state.cursor = state.scroll_offset then
          (* Cursor already at top - scroll up one page, keeping one row overlap *)
          let new_scroll = max 0 (state.scroll_offset - (content_height - 1)) in
          let new_cursor = new_scroll in
          Some { state with cursor = new_cursor; scroll_offset = new_scroll }
        else
          (* Move cursor to top of current view *)
          Some { state with cursor = state.scroll_offset }

    | `Page `Down, _ ->
        (* Page Down: Move cursor to bottom of screen, then scroll down by content_height - 1 *)
        let max_cursor = Array.length state.visible_items - 1 in
        let bottom_of_screen = min max_cursor (state.scroll_offset + content_height - 1) in
        if state.cursor = bottom_of_screen then
          (* Cursor already at bottom - scroll down one page, keeping one row overlap *)
          let new_scroll = min (max 0 (max_cursor - content_height + 1))
                               (state.scroll_offset + (content_height - 1)) in
          let new_cursor = min max_cursor (new_scroll + content_height - 1) in
          Some { state with cursor = new_cursor; scroll_offset = new_scroll }
        else
          (* Move cursor to bottom of current view *)
          Some { state with cursor = bottom_of_screen }

        | _ -> Some state
    )
    )

  (** Main interactive loop *)
  let run db db_path run_id =
    let expanded = Hashtbl.create 64 in
    let visible_items = build_visible_items db run_id expanded in
    let max_entry_id = Query.get_max_entry_id db ~run_id in

    (* Load existing search results from database *)
    let initial_search_slots = Array.init 4 (fun idx ->
      let slot_num = idx + 1 in
      match Query.get_existing_search db ~run_id ~slot:slot_num with
      | Some search_term ->
          (* Found existing search - mark as completed since it's from a previous run *)
          Some { search_term; domain_handle = None; completed_ref = ref true }
      | None -> None
    ) in

    let initial_state = {
      db;
      db_path;
      run_id;
      cursor = 0;
      scroll_offset = 0;
      expanded;
      visible_items;
      show_times = true;
      values_first = true;
      max_entry_id;
      search_slots = initial_search_slots;
      current_slot = 0;
      search_input = None;
      quiet_path_input = None;
      quiet_path = None;
    } in

    let term = Term.create () in

    let rec loop state =
      let (term_width, term_height) = Term.size term in
      let image = render_screen state term_height term_width in
      Term.image term image;

      match Term.event term with
      | `Key key ->
          (match handle_key state key term_height with
          | Some new_state -> loop new_state
          | None -> ())
      | `Resize _ -> loop state
      | _ -> loop state
    in

    loop initial_state;
    Term.release term
end

(** Main client interface *)
module Client = struct
  type t = { db : Sqlite3.db; db_path : string }

  let open_db db_path =
    let db = Sqlite3.db_open ~mode:`READONLY db_path in
    { db; db_path }

  let close t = Sqlite3.db_close t.db |> ignore

  (** List all runs *)
  let list_runs t = Query.get_runs t.db

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
    | None -> Printf.printf "Run #%d not found\n" run_id

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
  let show_trace t ?(show_entry_ids = false) ?(show_times = false) ?(max_depth = None)
      ?(values_first_mode = true) run_id =
    let entries = Query.get_entries t.db ~run_id () in
    let trees = Renderer.build_tree entries in
    let output =
      Renderer.render_tree ~show_entry_ids ~show_times ~max_depth ~values_first_mode trees
    in
    print_string output

  (** Show compact trace (function names only) *)
  let show_compact_trace t run_id =
    let entries = Query.get_entries t.db ~run_id () in
    let trees = Renderer.build_tree entries in
    let output = Renderer.render_compact trees in
    print_string output

  (** Show root entries efficiently *)
  let show_roots t ?(show_times = false) ?(with_values = false) run_id =
    let entries = Query.get_root_entries t.db ~run_id ~with_values in
    let output = Renderer.render_roots ~show_times ~with_values entries in
    print_string output

  (** Search entries *)
  let search t ~run_id ~pattern =
    let entries = Query.search_entries t.db ~run_id ~pattern in
    Printf.printf "Found %d matching entries for pattern '%s':\n\n" (List.length entries)
      pattern;
    List.iter
      (fun entry ->
        Printf.printf "{#%d} [%s] %s" entry.Query.entry_id entry.entry_type entry.message;
        (match entry.location with Some loc -> Printf.printf " @ %s" loc | None -> ());
        Printf.printf "\n";
        match entry.data with Some data -> Printf.printf "  %s\n" data | None -> ())
      entries

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
        Printf.fprintf oc "- **Elapsed**: %s\n\n"
          (Renderer.format_elapsed_ns r.elapsed_ns)
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
      (if entry.is_result then
         match entry.data with
         | Some data ->
             if entry.message <> "" then
               Printf.fprintf oc "%s  **%s =>** `%s`\n" indent entry.message data
             else
               Printf.fprintf oc "%s  **=>** `%s`\n" indent data
         | None -> ());

      List.iter (render_node ~depth:(depth + 1)) node.Renderer.children
    in

    List.iter (render_node ~depth:0) trees;
    close_out oc;
    Printf.printf "Exported to %s\n" output_file
end
