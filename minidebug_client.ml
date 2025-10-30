(** In-process client for querying and displaying ppx_minidebug database traces *)

module CFormat = Format

(** Query layer for database access *)
module Query = struct
  type entry = {
    scope_id : int; (* Scope ID - groups all rows for a scope *)
    seq_id : int; (* Position within parent's children *)
    child_scope_id : int option; (* NULL for values, points to new scope for headers *)
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

  (** Helper: normalize db_path by removing versioned suffix (_N.db -> .db). Examples:
      debug_1.db -> debug.db, debug_23.db -> debug.db, debug.db -> debug.db *)
  let normalize_db_path db_path =
    let base = Filename.remove_extension db_path in
    let ext = Filename.extension db_path in
    (* Check if base ends with _N where N is a number *)
    let normalized_base =
      match String.rindex_opt base '_' with
      | None -> base
      | Some idx ->
          let suffix = String.sub base (idx + 1) (String.length base - idx - 1) in
          if
            String.length suffix > 0
            && String.for_all (fun c -> c >= '0' && c <= '9') suffix
          then String.sub base 0 idx (* Remove _N *)
          else base
    in
    normalized_base ^ ext

  (** Get all runs from metadata database. For versioned databases (schema v3+), this
      queries the metadata DB. Falls back to querying the versioned DB for backwards
      compatibility. *)
  let get_runs_from_meta_db meta_db_path =
    if not (Sys.file_exists meta_db_path) then []
    else
      let db = Sqlite3.db_open meta_db_path in
      let stmt =
        Sqlite3.prepare db
          "SELECT run_id, run_name, timestamp, elapsed_ns, command_line FROM runs ORDER \
           BY run_id DESC"
      in
      let runs = ref [] in
      let rec loop () =
        match Sqlite3.step stmt with
        | Sqlite3.Rc.ROW ->
            let run =
              {
                run_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0);
                timestamp = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 2);
                elapsed_ns = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 3);
                command_line = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 4);
                run_name =
                  (match Sqlite3.column stmt 1 with
                  | Sqlite3.Data.TEXT s -> Some s
                  | _ -> None);
              }
            in
            runs := run :: !runs;
            loop ()
        | _ -> ()
      in
      loop ();
      Sqlite3.finalize stmt |> ignore;
      Sqlite3.db_close db |> ignore;
      List.rev !runs

  (** Get all runs - tries metadata DB first, falls back to versioned DB for old schemas
  *)
  let get_runs db_path =
    (* Normalize path (debug_1.db -> debug.db) then look for metadata DB *)
    let normalized = normalize_db_path db_path in
    let base = Filename.remove_extension normalized in
    let meta_path = Printf.sprintf "%s_meta.db" base in
    match get_runs_from_meta_db meta_path with
    | [] ->
        (* No metadata DB or empty - this might be an old schema v2 database. Return empty
           list since v2 databases don't have runs table. *)
        []
    | runs -> runs

  (** Get latest run ID from metadata database *)
  let get_latest_run_id db_path =
    (* Normalize path (debug_1.db -> debug.db) then look for metadata DB *)
    let normalized = normalize_db_path db_path in
    let base = Filename.remove_extension normalized in
    let meta_path = Printf.sprintf "%s_meta.db" base in
    if not (Sys.file_exists meta_path) then None
    else
      let db = Sqlite3.db_open meta_path in
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
      Sqlite3.db_close db |> ignore;
      run_id

  (** Get entries for a specific run *)
  let get_entries db ?parent_id ?max_depth () =
    let base_query =
      {|
      SELECT
        e.scope_id,
        e.seq_id,
        e.child_scope_id,
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
    |}
    in

    let query =
      match (parent_id, max_depth) with
      | None, None -> base_query ^ " ORDER BY e.scope_id, e.seq_id"
      | Some _, None -> base_query ^ " WHERE e.scope_id = ? ORDER BY e.scope_id, e.seq_id"
      | None, Some _ -> base_query ^ " WHERE e.depth <= ? ORDER BY e.scope_id, e.seq_id"
      | Some _, Some _ ->
          base_query
          ^ " WHERE e.scope_id = ? AND e.depth <= ? ORDER BY e.scope_id, e.seq_id"
    in

    let stmt = Sqlite3.prepare db query in
    (match (parent_id, max_depth) with
    | None, None -> ()
    | Some pid, None -> Sqlite3.bind_int stmt 1 pid |> ignore
    | None, Some d -> Sqlite3.bind_int stmt 1 d |> ignore
    | Some pid, Some d ->
        Sqlite3.bind_int stmt 1 pid |> ignore;
        Sqlite3.bind_int stmt 2 d |> ignore);

    let entries = ref [] in
    let rec loop () =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          let entry =
            {
              scope_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0);
              seq_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 1);
              child_scope_id =
                (match Sqlite3.column stmt 2 with
                | Sqlite3.Data.INT id -> Some (Int64.to_int id)
                | _ -> None);
              depth = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 3);
              message =
                (match Sqlite3.column stmt 4 with Sqlite3.Data.TEXT s -> s | _ -> "");
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
  let search_entries db ~pattern =
    let entries = get_entries db () in
    let re = Re.compile (Re.Pcre.re pattern) in
    List.filter
      (fun entry ->
        Re.execp re entry.message
        || (match entry.location with Some loc -> Re.execp re loc | None -> false)
        || match entry.data with Some d -> Re.execp re d | None -> false)
      entries

  (** Get maximum scope_id for a run *)
  let get_max_scope_id db =
    let stmt = Sqlite3.prepare db "SELECT MAX(scope_id) FROM entries" in
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

  (** Get only root entries efficiently - roots are those with scope_id=0 *)
  let get_root_entries db ~with_values =
    let query =
      if with_values then
        (* Get entries at depth 0 and 1 - roots and their immediate children *)
        {|
      SELECT
        e.scope_id,
        e.seq_id,
        e.child_scope_id,
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
      WHERE e.depth <= 1
      ORDER BY e.scope_id, e.seq_id
    |}
      else
        (* Get only headers at root level (scope_id=0, child_scope_id NOT NULL) *)
        {|
      SELECT
        e.scope_id,
        e.seq_id,
        e.child_scope_id,
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
      WHERE e.scope_id = 0 AND e.child_scope_id IS NOT NULL
      ORDER BY e.seq_id
    |}
    in

    let stmt = Sqlite3.prepare db query in

    let entries = ref [] in
    let rec loop () =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          let entry =
            {
              scope_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0);
              seq_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 1);
              child_scope_id =
                (match Sqlite3.column stmt 2 with
                | Sqlite3.Data.INT id -> Some (Int64.to_int id)
                | _ -> None);
              depth = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 3);
              message =
                (match Sqlite3.column stmt 4 with Sqlite3.Data.TEXT s -> s | _ -> "");
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
  let has_children db ~parent_scope_id =
    let query =
      {|
      SELECT 1
      FROM entries
      WHERE scope_id = ?
      LIMIT 1
    |}
    in
    let stmt = Sqlite3.prepare db query in
    Sqlite3.bind_int stmt 1 parent_scope_id |> ignore;
    let has_child = match Sqlite3.step stmt with Sqlite3.Rc.ROW -> true | _ -> false in
    Sqlite3.finalize stmt |> ignore;
    has_child

  (** Get all parent scope_ids for a given entry. Returns empty list if no parents
      (root entry). Due to SexpCache deduplication, an entry can have multiple parents
      (DAG structure). *)
  let get_parent_ids db ~scope_id =
    let query =
      {|
      SELECT parent_id
      FROM entry_parents
      WHERE scope_id = ?
    |}
    in
    let stmt = Sqlite3.prepare db query in
    Sqlite3.bind_int stmt 1 scope_id |> ignore;

    let parent_ids = ref [] in
    let rec loop () =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW -> (
          match Sqlite3.column stmt 0 with
          | Sqlite3.Data.INT id ->
              parent_ids := Int64.to_int id :: !parent_ids;
              loop ()
          | Sqlite3.Data.NULL -> loop ()  (* Skip NULL parents *)
          | _ -> loop ())
      | _ -> ()
    in
    loop ();
    Sqlite3.finalize stmt |> ignore;
    List.rev !parent_ids  (* Preserve insertion order *)

  (** Get first parent scope_id for a given entry (for single-path operations).
      Returns None if no parent (root entry). *)
  let get_parent_id db ~scope_id =
    match get_parent_ids db ~scope_id with
    | [] -> None
    | first :: _ -> Some first

  let get_scope_children db ~parent_scope_id =
    let query =
      {|
      SELECT
        e.scope_id,
        e.seq_id,
        e.child_scope_id,
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
      WHERE e.scope_id = ?
      ORDER BY e.seq_id
    |}
    in

    let stmt = Sqlite3.prepare db query in
    Sqlite3.bind_int stmt 1 parent_scope_id |> ignore;

    let entries = ref [] in
    let rec loop () =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          let entry =
            {
              scope_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0);
              seq_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 1);
              child_scope_id =
                (match Sqlite3.column stmt 2 with
                | Sqlite3.Data.INT id -> Some (Int64.to_int id)
                | _ -> None);
              depth = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 3);
              message =
                (match Sqlite3.column stmt 4 with Sqlite3.Data.TEXT s -> s | _ -> "");
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

  (** Search ordering strategy. Note: scope_id temporal order is split by sign:
      - Positive IDs: 1 (oldest), 2, 3, ... 60311 (newest) - increasing = later
      - Negative IDs: -1 (oldest), -2, -3, ... -17774560 (newest) - more negative = later

      Neither ordering is chronological due to the sign split! *)
  type search_order =
    | AscendingIds
      (* ORDER BY scope_id ASC: newest-neg → oldest-neg → oldest-pos → newest-pos *)
    | DescendingIds
  (* ORDER BY scope_id DESC: newest-pos → oldest-pos → oldest-neg → newest-neg *)

  (** Populate search results hash table with entries matching search term. This is meant
      to run in a background Domain. Opens its own DB connection. Sets completed_ref to
      true when finished. Propagates highlights to ancestors unless quiet_path matches.

      Implementation: Interleaves stepping through the main search query with issuing
      ancestor lookup queries (via get_parent_id). SQLite handles multiple active prepared
      statements without issue. Propagates highlights immediately upon finding each match
      for real-time UI updates.

      Writes results to shared hash table (lock-free concurrent writes are safe). *)
  let populate_search_results db_path ~search_term ~quiet_path ~search_order
      ~completed_ref ~results_table =
    (* Log to file for debugging since TUI occupies terminal *)
    let log_debug msg =
      ignore msg
      (* Uncomment to enable debug logging: try let oc = open_out_gen [Open_append;
         Open_creat] 0o644 "/tmp/minidebug_search.log" in Printf.fprintf oc "[%s] %s\n"
         (Unix.gettimeofday () |> string_of_float) msg; close_out oc with _ -> () *)
    in

    Printexc.record_backtrace true;
    log_debug
      (Printf.sprintf "Starting search for '%s', quiet_path=%s" search_term
         (match quiet_path with Some q -> "'" ^ q ^ "'" | None -> "None"));

    (* Open a new database connection for this Domain (read-only for querying) *)
    log_debug (Printf.sprintf "Opening database: %s" db_path);
    let db = Sqlite3.db_open ~mode:`READONLY db_path in
    log_debug "Database opened successfully";

    try
      (* Clear the results hash table *)
      log_debug "Clearing results hash table...";
      Hashtbl.clear results_table;
      log_debug "Cleared results hash table";

      (* Stream entries instead of loading all into memory (DB is huge!) *)
      log_debug "Streaming entries and searching...";

      (* Compile regexes once for efficiency *)
      let search_regex = Re.Str.regexp_string search_term in
      let quiet_path_regex = Option.map Re.Str.regexp_string quiet_path in

      (* Helper to check if haystack contains needle using pre-compiled regex *)
      let contains_match haystack regex =
        try
          let _ = Re.Str.search_forward regex haystack 0 in
          true
        with Not_found -> false
      in

      (* Helper to check if entry matches quiet_path *)
      let matches_quiet_path entry =
        match quiet_path_regex with
        | None -> false
        | Some qp_regex -> (
            contains_match entry.message qp_regex
            || (match entry.location with
               | Some loc -> contains_match loc qp_regex
               | None -> false)
            || match entry.data with Some d -> contains_match d qp_regex | None -> false)
      in

      (* Helper to insert an entry into search results hash table *)
      let insert_entry ?(is_match = false) entry =
        Hashtbl.replace results_table (entry.scope_id, entry.seq_id) is_match
      in

      (* Stream entries, find matches, and build scope index in one pass *)
      let order_clause =
        match search_order with
        | AscendingIds ->
            "ORDER BY e.scope_id ASC, e.seq_id ASC"
            (* Negative IDs first, then positive *)
        | DescendingIds -> "ORDER BY e.scope_id DESC, e.seq_id ASC"
        (* Positive IDs first, then negative *)
      in
      let query =
        Printf.sprintf
          {|SELECT e.scope_id, e.seq_id, e.child_scope_id, e.depth,
                 m.value_content as message, l.value_content as location, d.value_content as data,
                 e.elapsed_start_ns, e.elapsed_end_ns, e.is_result, e.log_level, e.entry_type
          FROM entries e
          LEFT JOIN value_atoms m ON e.message_value_id = m.value_id
          LEFT JOIN value_atoms l ON e.location_value_id = l.value_id
          LEFT JOIN value_atoms d ON e.data_value_id = d.value_id
          %s|}
          order_clause
      in
      let query_stmt = Sqlite3.prepare db query in

      let scope_by_id = Hashtbl.create 1024 in
      let processed_count = ref 0 in
      let match_count = ref 0 in
      let propagated = Hashtbl.create 64 in
      (* Track propagated ancestors to avoid duplicates *)
      let propagation_count = ref 0 in

      (* Helper to eagerly fetch and cache a scope entry by ID. Strategy: First check
         cache, then query for the header entry that creates this scope. For incremental
         updates, we accept that some parent headers may not be found yet (they'll be
         highlighted when the streaming query reaches them). *)
      let get_scope_entry scope_id =
        match Hashtbl.find_opt scope_by_id scope_id with
        | Some entry -> Some entry
        | None ->
            (* Not in cache - fetch from database and cache it. Query finds the header
               entry that creates scope_id (child_scope_id = scope_id). NOTE: For
               incremental updates during streaming, this may return None if the header
               hasn't been scanned yet. That's OK - we'll highlight it when we reach
               it. *)
            let query =
              {|
              SELECT e.scope_id, e.seq_id, e.child_scope_id, e.depth,
                     m.value_content as message, l.value_content as location, d.value_content as data,
                     e.elapsed_start_ns, e.elapsed_end_ns, e.is_result, e.log_level, e.entry_type
              FROM entries e
              LEFT JOIN value_atoms m ON e.message_value_id = m.value_id
              LEFT JOIN value_atoms l ON e.location_value_id = l.value_id
              LEFT JOIN value_atoms d ON e.data_value_id = d.value_id
              WHERE e.child_scope_id = ?
              LIMIT 1
            |}
            in
            let stmt = Sqlite3.prepare db query in
            Sqlite3.bind_int stmt 1 scope_id |> ignore;
            let result =
              match Sqlite3.step stmt with
              | Sqlite3.Rc.ROW ->
                  let entry =
                    {
                      scope_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0);
                      seq_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 1);
                      child_scope_id =
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
                        | Sqlite3.Data.INT i -> Some (Int64.to_int i)
                        | _ -> None);
                      is_result =
                        (match Sqlite3.Data.to_bool (Sqlite3.column stmt 9) with
                        | Some b -> b
                        | None -> false);
                      log_level = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 10);
                      entry_type = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 11);
                    }
                  in
                  Hashtbl.add scope_by_id scope_id entry;
                  log_debug
                    (Printf.sprintf "  get_scope_entry: fetched and cached scope %d"
                       scope_id);
                  Some entry
              | _ ->
                  (* Header not found - either it doesn't exist, or hasn't been scanned
                     yet in streaming mode. For incremental updates, we'll just skip this
                     ancestor for now. *)
                  log_debug
                    (Printf.sprintf
                       "  get_scope_entry: scope %d header not found (may not be scanned \
                        yet)"
                       scope_id);
                  None
            in
            Sqlite3.finalize stmt |> ignore;
            result
      in

      (* Helper to propagate highlights to ancestors immediately *)
      let propagate_to_ancestors entry =
        (* For headers: entry.scope_id is the parent scope that contains this header For
           values: entry.scope_id is also the parent scope So we always want to start by
           highlighting the direct parent (entry.scope_id at seq_id=0), then propagate to
           its ancestors. *)
        log_debug
          (Printf.sprintf "propagate_to_ancestors: scope_id=%d, seq_id=%d, message='%s'"
             entry.scope_id entry.seq_id entry.message);

        (* First, add the direct parent scope (scope_id at seq_id=0) if it's not already
           highlighted *)
        let direct_parent_id = entry.scope_id in
        if not (Hashtbl.mem propagated direct_parent_id) then
          match get_scope_entry direct_parent_id with
          | Some parent_scope when matches_quiet_path parent_scope ->
              (* Direct parent matches quiet_path - mark it but don't add to results, stop
                 here *)
              Hashtbl.add propagated direct_parent_id ();
              log_debug
                (Printf.sprintf
                   "  propagate: direct parent %d matches quiet_path, stopping"
                   direct_parent_id)
          | Some parent_scope ->
              (* Direct parent doesn't match quiet_path - add it and propagate upward *)
              Hashtbl.add propagated direct_parent_id ();
              log_debug
                (Printf.sprintf "  propagate: adding direct parent %d to results"
                   direct_parent_id);
              insert_entry ~is_match:false parent_scope;
              incr propagation_count;

              (* Now propagate to ancestors. In a DAG, we must propagate through ALL
                 parent paths, not just one. *)
              let rec propagate_to_parent current_scope_id =
                let parent_ids = get_parent_ids db ~scope_id:current_scope_id in
                if parent_ids = [] then
                  log_debug
                    (Printf.sprintf
                       "  propagate: scope_id=%d has no parents (reached root)"
                       current_scope_id)
                else
                  List.iter
                    (fun parent_id ->
                      if Hashtbl.mem propagated parent_id then
                        log_debug
                          (Printf.sprintf
                             "  propagate: parent_id=%d already propagated, skipping"
                             parent_id)
                      else (
                        log_debug
                          (Printf.sprintf "  propagate: checking parent_id=%d" parent_id);
                        (* Eagerly fetch parent entry if not in cache *)
                        match get_scope_entry parent_id with
                        | Some parent_entry when matches_quiet_path parent_entry ->
                            (* Parent matches quiet_path, stop propagation on this path.
                               IMPORTANT: Mark in propagated table so other matches also
                               stop here! *)
                            Hashtbl.add propagated parent_id ();
                            log_debug
                              (Printf.sprintf
                                 "  propagate: parent_id=%d matches quiet_path, marking \
                                  and stopping propagation on this path"
                                 parent_id)
                        | Some parent_entry ->
                            (* Parent found and doesn't match quiet_path - mark it and
                               continue on this path *)
                            Hashtbl.add propagated parent_id ();
                            log_debug
                              (Printf.sprintf
                                 "  propagate: parent_id=%d doesn't match quiet_path, \
                                  adding to results"
                                 parent_id);
                            insert_entry ~is_match:false parent_entry;
                            incr propagation_count;
                            propagate_to_parent parent_id
                        | None ->
                            (* Parent entry not found in database - shouldn't happen but
                               handle gracefully *)
                            log_debug
                              (Printf.sprintf
                                 "  propagate: parent_id=%d not found in database, \
                                  stopping on this path"
                                 parent_id)))
                    parent_ids
              in
              propagate_to_parent direct_parent_id
          | None ->
              log_debug
                (Printf.sprintf "  propagate: direct parent %d not found in database"
                   direct_parent_id)
        else
          log_debug
            (Printf.sprintf "  propagate: direct parent %d already propagated"
               direct_parent_id)
      in

      let rec process_rows () =
        match Sqlite3.step query_stmt with
        | Sqlite3.Rc.ROW ->
            incr processed_count;

            let entry =
              {
                scope_id = Sqlite3.Data.to_int_exn (Sqlite3.column query_stmt 0);
                seq_id = Sqlite3.Data.to_int_exn (Sqlite3.column query_stmt 1);
                child_scope_id =
                  (match Sqlite3.column query_stmt 2 with
                  | Sqlite3.Data.INT id -> Some (Int64.to_int id)
                  | _ -> None);
                depth = Sqlite3.Data.to_int_exn (Sqlite3.column query_stmt 3);
                message =
                  (match Sqlite3.column query_stmt 4 with
                  | Sqlite3.Data.TEXT s -> s
                  | _ -> "");
                location =
                  (match Sqlite3.column query_stmt 5 with
                  | Sqlite3.Data.TEXT s -> Some s
                  | _ -> None);
                data =
                  (match Sqlite3.column query_stmt 6 with
                  | Sqlite3.Data.TEXT s -> Some s
                  | _ -> None);
                elapsed_start_ns = Sqlite3.Data.to_int_exn (Sqlite3.column query_stmt 7);
                elapsed_end_ns =
                  (match Sqlite3.column query_stmt 8 with
                  | Sqlite3.Data.INT i -> Some (Int64.to_int i)
                  | _ -> None);
                is_result =
                  (match Sqlite3.Data.to_bool (Sqlite3.column query_stmt 9) with
                  | Some b -> b
                  | None -> false);
                log_level = Sqlite3.Data.to_int_exn (Sqlite3.column query_stmt 10);
                entry_type = Sqlite3.Data.to_string_exn (Sqlite3.column query_stmt 11);
              }
            in

            (* Add to scope index if it's a scope *)
            (match entry.child_scope_id with
            | Some hid -> Hashtbl.add scope_by_id hid entry
            | None -> ());

            (* Check if it matches the search term using pre-compiled regex *)
            let matches =
              contains_match entry.message search_regex
              || (match entry.location with
                 | Some loc -> contains_match loc search_regex
                 | None -> false)
              ||
              match entry.data with
              | Some d -> contains_match d search_regex
              | None -> false
            in

            (* Also check if this is a scope header that should be retroactively
               highlighted because one of its descendants was already matched (when child
               was scanned before parent).

               This handles the case where: 1. A child entry was matched during streaming
               2. propagate_to_ancestors was called, which tried to fetch this header via
               get_scope_entry 3. But this header hadn't been scanned yet, so
               get_scope_entry returned None 4. The scope_id was marked in 'propagated'
               table, but the header entry was never added to results_table 5. Now we're
               scanning the actual header entry - we need to add it if its scope has
               matches *)
            let retroactive_highlight =
              match entry.child_scope_id with
              | Some hid ->
                  (* Check if THIS HEADER ENTRY is already in results_table *)
                  let header_already_highlighted =
                    Hashtbl.mem results_table (entry.scope_id, entry.seq_id)
                  in
                  if header_already_highlighted then false
                    (* Already highlighted, nothing to do *)
                  else
                    (* Check if any entries in this scope (hid) are already highlighted *)
                    let scope_has_match =
                      Hashtbl.fold
                        (fun (sid, _) _is_match acc -> acc || sid = hid)
                        results_table false
                    in
                    if scope_has_match then (
                      log_debug
                        (Printf.sprintf
                           "  Retroactive highlight: scope header \
                            (scope_id=%d,seq_id=%d) for child_scope_id=%d has matching \
                            descendants"
                           entry.scope_id entry.seq_id hid);
                      true)
                    else false
              | None -> false
            in

            if matches then (
              incr match_count;
              insert_entry ~is_match:true entry;
              (* Propagate to ancestors immediately if not a quiet_path match *)
              if not (matches_quiet_path entry) then propagate_to_ancestors entry)
            else if retroactive_highlight then
              if
                (* This scope header doesn't match search but has matching descendants -
                   highlight it *)
                not (matches_quiet_path entry)
              then (
                insert_entry ~is_match:false entry;
                Hashtbl.add propagated (Option.get entry.child_scope_id) ();
                incr propagation_count;
                (* Continue propagating to this scope's ancestors *)
                propagate_to_ancestors entry);
            if !processed_count mod 100000 = 0 then
              log_debug
                (Printf.sprintf
                   "Processed %d entries, found %d matches, propagated %d ancestors"
                   !processed_count !match_count !propagation_count);

            process_rows ()
        | Sqlite3.Rc.DONE -> ()
        | rc -> failwith (Printf.sprintf "Query failed: %s" (Sqlite3.Rc.to_string rc))
      in

      process_rows ();
      Sqlite3.finalize query_stmt |> ignore;
      log_debug
        (Printf.sprintf
           "Search complete. Processed %d entries, found %d matches, propagated %d \
            ancestors"
           !processed_count !match_count !propagation_count);
      log_debug
        (Printf.sprintf "Scope cache size: %d, Total results: %d"
           (Hashtbl.length scope_by_id)
           (Hashtbl.length results_table));

      (* Close the database connection *)
      Sqlite3.db_close db |> ignore;

      log_debug "Search completed successfully";

      (* Signal completion via shared memory *)
      completed_ref := true
    with exn ->
      log_debug
        (Printf.sprintf "ERROR: %s\n%s" (Printexc.to_string exn)
           (Printexc.get_backtrace ()));
      (* Close database on error *)
      (try Sqlite3.db_close db |> ignore with _ -> ());
      (* Still mark as completed even on error *)
      completed_ref := true

  (** Get ancestor entry IDs from a given entry up to root, following the first parent
      at each level. Returns list in order [scope_id; parent; grandparent; ...; root].

      Note: Due to SexpCache deduplication, entries can have multiple parents (DAG
      structure). This function returns ONE path through the DAG by always following
      the first parent. For operations requiring all paths, use get_all_ancestor_paths. *)
  let get_ancestors db ~scope_id =
    let rec collect_ancestors acc current_id =
      match get_parent_id db ~scope_id:current_id with
      | None -> List.rev acc (* Reached root *)
      | Some parent_id -> collect_ancestors (parent_id :: acc) parent_id
    in
    collect_ancestors [ scope_id ] scope_id

  (** Get ALL ancestor paths from a given entry to root(s). Returns list of paths, where
      each path is in order [scope_id; parent; grandparent; ...; root].

      Due to SexpCache deduplication, entries can have multiple parents (DAG structure).
      This function explores all paths through the DAG and returns them all. *)
  let get_all_ancestor_paths db ~scope_id =
    let rec collect_all_paths current_id =
      let parent_ids = get_parent_ids db ~scope_id:current_id in
      if parent_ids = [] then
        (* Reached root - return singleton path *)
        [ [ current_id ] ]
      else
        (* Recursively collect paths from all parents, prepending current_id to each *)
        List.concat_map
          (fun parent_id ->
            let parent_paths = collect_all_paths parent_id in
            List.map (fun path -> current_id :: path) parent_paths)
          parent_ids
    in
    let paths = collect_all_paths scope_id in
    (* Reverse each path to get root -> target order *)
    List.map List.rev paths

  (** Compute the lowest common ancestor (LCA) of a list of scope IDs.
      Returns None if scopes are in separate root-level trees (no common ancestor).
      For scopes in the same tree, returns their deepest common ancestor. *)
  let lowest_common_ancestor db scope_ids =
    match scope_ids with
    | [] -> None
    | [ single ] -> Some single
    | _ :: _ ->
        (* Get ancestor chains for all scopes (from root to scope) *)
        let ancestor_chains = List.map (fun id -> get_ancestors db ~scope_id:id) scope_ids in

        (* Find the deepest common ancestor by checking from deepest to shallowest *)
        let find_lca_in_chains chains =
          match chains with
          | [] -> None
          | first_chain :: _ ->
              (* Try each ancestor from deepest (last) to shallowest (first) *)
              let rec try_ancestors = function
                | [] -> None
                | candidate :: remaining ->
                    (* Check if this candidate is an ancestor of all scopes *)
                    if List.for_all (fun chain -> List.mem candidate chain) chains then
                      Some candidate
                    else
                      try_ancestors remaining
              in
              try_ancestors (List.rev first_chain)
        in
        find_lca_in_chains ancestor_chains

  (** Find root scope for a given scope (topmost ancestor, or self if at root) *)
  let get_root_scope db scope_id =
    let rec find_root current_id =
      match get_parent_id db ~scope_id:current_id with
      | None -> current_id (* No parent means this is the root *)
      | Some parent_id -> find_root parent_id
    in
    find_root scope_id

end

(** Tree renderer for terminal output *)
module Renderer = struct
  type tree_node = { entry : Query.entry; children : tree_node list }

  (** Build a tree node for a specific scope using database queries *)
  let rec build_node db ?max_depth ~current_depth header_entry =
    let should_descend =
      match max_depth with None -> true | Some d -> current_depth < d
    in

    if not should_descend then { entry = header_entry; children = [] }
    else
      match header_entry.Query.child_scope_id with
      | None -> { entry = header_entry; children = [] }
      | Some scope_id ->
          (* Get children from database - properly ordered by seq_id *)
          let children_entries = Query.get_scope_children db ~parent_scope_id:scope_id in

          (* Build child nodes *)
          let children =
            List.map
              (fun child ->
                match child.Query.child_scope_id with
                | Some _sub_scope_id ->
                    (* Recursively build subscope *)
                    build_node db ?max_depth ~current_depth:(current_depth + 1) child
                | None -> { entry = child; children = [] }
                (* Leaf value *))
              children_entries
          in

          { entry = header_entry; children }

  (** Build tree from database starting with given root entries (recommended) *)
  let build_tree db ?max_depth root_entries =
    (* Root entries are already sorted by seq_id from Query.get_root_entries *)
    List.map
      (fun root -> build_node db ?max_depth ~current_depth:0 root)
      root_entries

  (** Build tree from pre-loaded entries (for search/filter use cases).
      This is less efficient but needed when working with filtered entry sets. *)
  let build_tree_from_entries entries =
    (* Separate headers from values *)
    let headers, _values =
      List.partition (fun e -> e.Query.child_scope_id <> None) entries
    in

    (* Find root entries (scope_id = 0, which means they're children of the virtual root) *)
    let root_headers = List.filter (fun e -> e.Query.scope_id = 0) headers in

    (* Sort roots by seq_id *)
    let sorted_roots =
      List.sort (fun a b -> compare a.Query.seq_id b.Query.seq_id) root_headers
    in

    (* Build trees recursively from entries *)
    let rec build_from_entry header_entry =
      match header_entry.Query.child_scope_id with
      | None -> { entry = header_entry; children = [] }
      | Some scope_id ->
          (* Get children from entry list - already loaded *)
          let children_entries =
            List.filter (fun e -> e.Query.scope_id = scope_id) entries
            |> List.sort (fun a b -> compare a.Query.seq_id b.Query.seq_id)
          in

          let children =
            List.map
              (fun child ->
                match child.Query.child_scope_id with
                | Some _sub_scope_id -> build_from_entry child
                | None -> { entry = child; children = [] })
              children_entries
          in

          { entry = header_entry; children }
    in

    List.map build_from_entry sorted_roots

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
  let render_tree ?(show_scope_ids = false) ?(show_times = false) ?(max_depth = None)
      ?(values_first_mode = false) trees =
    let buf = Buffer.create 1024 in

    let rec render_node ~indent ~depth node =
      let entry = node.entry in
      let skip = match max_depth with Some d -> depth > d | None -> false in

      if not skip then (
        (* Indentation *)
        Buffer.add_string buf indent;

        (* Entry ID (optional) *)
        if show_scope_ids then
          Buffer.add_string buf (Printf.sprintf "#%d " entry.scope_id);

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
              if entry.is_result then Buffer.add_string buf (entry.message ^ " => ")
              else Buffer.add_string buf (entry.message ^ " = ");

            (match entry.data with Some data -> Buffer.add_string buf data | None -> ());

            Buffer.add_string buf "\n"
        | true, true, [ result_child ]
          when result_child.children = [] && result_child.entry.child_scope_id = None ->
            (* Scope node with single value result in values_first_mode: combine on one line *)
            (* Format: [type] message => result.message result_value <time> @ location *)
            (* NOTE: Only combine if result is a simple value, not a scope/header *)
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
            (* For synthetic scopes (no location), show data inline with message *)
            let is_synthetic = entry.location = None in

            (* Message and type *)
            Buffer.add_string buf (Printf.sprintf "[%s]" entry.entry_type);

            (* Show message and/or data *)
            (match (entry.message, entry.data, is_synthetic) with
            | msg, Some data, true when msg <> "" ->
                (* Synthetic scope with both message and data: show as "message: data" *)
                Buffer.add_string buf (Printf.sprintf " %s: %s" msg data)
            | "", Some data, true ->
                (* Synthetic scope with only data: show just data *)
                Buffer.add_string buf (Printf.sprintf " %s" data)
            | msg, _, _ when msg <> "" ->
                (* Has message: show it *)
                Buffer.add_string buf (Printf.sprintf " %s" msg)
            | _ -> ());

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

            (* Data (if present and not synthetic) *)
            (match entry.data with
            | Some data when has_children && not is_synthetic ->
                Buffer.add_string buf (indent ^ "  ");
                Buffer.add_string buf data;
                Buffer.add_string buf "\n"
            | _ -> ());

            (* Children *)
            let child_indent = indent ^ "  " in
            if values_first_mode then (
              match results with
              | [ result_child ]
                when result_child.children = []
                     && result_child.entry.child_scope_id = None ->
                  (* Single value result was combined with header, skip it *)
                  List.iter
                    (render_node ~indent:child_indent ~depth:(depth + 1))
                    non_results
              | _ ->
                  (* Multiple results or result is a header: render results first *)
                  List.iter (render_node ~indent:child_indent ~depth:(depth + 1)) results;
                  List.iter
                    (render_node ~indent:child_indent ~depth:(depth + 1))
                    non_results)
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
  let render_roots ?(show_times = false) ?(with_values = false)
      (entries : Query.entry list) =
    let buf = Buffer.create 1024 in

    (* Separate headers and values *)
    let headers =
      List.filter (fun (e : Query.entry) -> e.child_scope_id <> None) entries
    in
    let values = List.filter (fun (e : Query.entry) -> e.child_scope_id = None) entries in

    (* Sort headers by seq_id *)
    let sorted_headers =
      List.sort
        (fun (a : Query.entry) (b : Query.entry) -> compare a.seq_id b.seq_id)
        headers
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
          match header.child_scope_id with
          | Some hid ->
              let child_values =
                List.filter (fun (v : Query.entry) -> v.scope_id = hid) values
                |> List.sort (fun (a : Query.entry) (b : Query.entry) ->
                       compare a.seq_id b.seq_id)
              in
              List.iter
                (fun (child : Query.entry) ->
                  Buffer.add_string buf "  ";
                  if child.is_result then
                    if child.message <> "" then
                      Buffer.add_string buf (child.message ^ " => ")
                    else Buffer.add_string buf "=> "
                  else if child.message <> "" then
                    Buffer.add_string buf (child.message ^ " = ");
                  (match child.data with
                  | Some data -> Buffer.add_string buf data
                  | None -> ());
                  Buffer.add_string buf "\n")
                child_values
          | None -> ())
      sorted_headers;

    Buffer.contents buf

  (** JSON escaping helper *)
  let json_escape s =
    let buf = Buffer.create (String.length s) in
    String.iter
      (fun c ->
        match c with
        | '"' -> Buffer.add_string buf "\\\""
        | '\\' -> Buffer.add_string buf "\\\\"
        | '\n' -> Buffer.add_string buf "\\n"
        | '\r' -> Buffer.add_string buf "\\r"
        | '\t' -> Buffer.add_string buf "\\t"
        | c when Char.code c < 32 -> Printf.bprintf buf "\\u%04x" (Char.code c)
        | c -> Buffer.add_char buf c)
      s;
    Buffer.contents buf

  (** Render entry as JSON object *)
  let entry_to_json entry =
    let parts = ref [] in
    parts := Printf.sprintf "\"scope_id\": %d" entry.Query.scope_id :: !parts;
    parts := Printf.sprintf "\"seq_id\": %d" entry.seq_id :: !parts;
    (match entry.child_scope_id with
    | Some id -> parts := Printf.sprintf "\"child_scope_id\": %d" id :: !parts
    | None -> parts := "\"child_scope_id\": null" :: !parts);
    parts := Printf.sprintf "\"depth\": %d" entry.depth :: !parts;
    parts := Printf.sprintf "\"message\": \"%s\"" (json_escape entry.message) :: !parts;
    (match entry.location with
    | Some loc -> parts := Printf.sprintf "\"location\": \"%s\"" (json_escape loc) :: !parts
    | None -> parts := "\"location\": null" :: !parts);
    (match entry.data with
    | Some d -> parts := Printf.sprintf "\"data\": \"%s\"" (json_escape d) :: !parts
    | None -> parts := "\"data\": null" :: !parts);
    parts := Printf.sprintf "\"elapsed_start_ns\": %d" entry.elapsed_start_ns :: !parts;
    (match entry.elapsed_end_ns with
    | Some ns -> parts := Printf.sprintf "\"elapsed_end_ns\": %d" ns :: !parts
    | None -> parts := "\"elapsed_end_ns\": null" :: !parts);
    (match elapsed_time entry with
    | Some elapsed -> parts := Printf.sprintf "\"elapsed_ns\": %d" elapsed :: !parts
    | None -> parts := "\"elapsed_ns\": null" :: !parts);
    parts := Printf.sprintf "\"is_result\": %b" entry.is_result :: !parts;
    parts := Printf.sprintf "\"log_level\": %d" entry.log_level :: !parts;
    parts := Printf.sprintf "\"entry_type\": \"%s\"" (json_escape entry.entry_type) :: !parts;
    "{ " ^ String.concat ", " (List.rev !parts) ^ " }"

  (** Render tree node as JSON recursively *)
  let rec tree_node_to_json ?(max_depth = None) ~depth node =
    let skip = match max_depth with Some d -> depth > d | None -> false in
    if skip then "null"
    else
      let entry_json = entry_to_json node.entry in
      let children_json =
        if node.children = [] then "[]"
        else
          let child_jsons =
            List.map
              (fun child -> tree_node_to_json ~max_depth ~depth:(depth + 1) child)
              node.children
          in
          "[ " ^ String.concat ", " child_jsons ^ " ]"
      in
      Printf.sprintf "{ \"entry\": %s, \"children\": %s }" entry_json children_json

  (** Render trees as JSON array *)
  let render_tree_json ?(max_depth = None) trees =
    let tree_jsons = List.map (fun t -> tree_node_to_json ~max_depth ~depth:0 t) trees in
    "[ " ^ String.concat ", " tree_jsons ^ " ]"

  (** Render entries as JSON array *)
  let render_entries_json entries =
    let entry_jsons = List.map entry_to_json entries in
    "[ " ^ String.concat ", " entry_jsons ^ " ]"
end

(** Interactive TUI using Notty *)
module Interactive = struct
  open Notty
  open Notty_unix

  (** Poll for terminal event with timeout. Returns None on timeout. *)
  let event_with_timeout term timeout_sec =
    (* Get the input file descriptor from stdin *)
    let stdin_fd = Unix.stdin in
    (* Retry select on EINTR (interrupted system call) *)
    let rec select_with_retry () =
      try
        let ready, _, _ = Unix.select [ stdin_fd ] [] [] timeout_sec in
        if ready = [] then None (* Timeout *) else Some (Term.event term)
        (* Event available *)
      with Unix.Unix_error (Unix.EINTR, _, _) ->
        (* Interrupted by signal (e.g., SIGWINCH on terminal resize) - retry *)
        select_with_retry ()
    in
    select_with_retry ()

  type search_results = (int * int, bool) Hashtbl.t
  (** Hash table of (scope_id, seq_id) pairs matching a search term. Value: true = actual
      search match, false = propagated ancestor highlight. This is shared memory written
      by background Domain, read by main TUI loop. *)

  type search_slot = {
    search_term : string;
    domain_handle : unit Domain.t option; [@warning "-69"]
    completed_ref : bool ref; (* Shared memory flag set by Domain when finished *)
    results : search_results; (* Shared hash table written by Domain *)
  }

  module SlotNumber = struct
    type t = S1 | S2 | S3 | S4

    let compare = compare
    let next = function S1 -> S2 | S2 -> S3 | S3 -> S4 | S4 -> S1
    let prev = function S1 -> S4 | S2 -> S1 | S3 -> S2 | S4 -> S3
  end

  module SlotMap = Map.Make (SlotNumber)

  type slot_map = search_slot SlotMap.t

  (** Check if an entry matches any active search (returns slot number 1-4, or None).
      Checks slots in reverse chronological order to prioritize more recent searches. Slot
      ordering is determined by current_slot parameter. *)
  let get_search_match ~search_slots ~scope_id ~seq_id ~current_slot =
    (* Check slots in reverse chronological order *)
    let rec check_slot slot_number =
      match SlotMap.find_opt slot_number search_slots with
      | Some slot when Hashtbl.mem slot.results (scope_id, seq_id) -> Some slot_number
      | _ ->
          if slot_number = current_slot then None
          else check_slot (SlotNumber.prev slot_number)
    in
    check_slot (SlotNumber.prev current_slot)

  (** Get all search slots that match an entry (for checkered pattern highlighting).
      Returns list of slot numbers in order S1, S2, S3, S4. *)
  let get_all_search_matches ~search_slots ~scope_id ~seq_id =
    let matches = ref [] in
    SlotMap.iter
      (fun slot_number slot ->
        if Hashtbl.mem slot.results (scope_id, seq_id) then
          matches := slot_number :: !matches)
      search_slots;
    (* Sort in standard order: S1, S2, S3, S4 *)
    List.sort compare !matches

  (** Find next/previous search result in hash tables (across all entries, not just
      visible). Returns (scope_id, seq_id) of the next match, or None if no more matches.
      Search direction: forward=true searches for matches with (scope_id, seq_id) >
      current, forward=false searches for matches with (scope_id, seq_id) < current Note:
      searches across all 4 search slots. *)
  let find_next_search_result ~search_slots ~current_scope_id ~current_seq_id ~forward =
    (* Collect all actual matches (not propagated highlights) from all slots into a single
       list *)
    let all_matches = ref [] in
    SlotMap.iter
      (fun _idx slot ->
        Hashtbl.iter
          (fun key is_match -> if is_match then all_matches := key :: !all_matches)
          slot.results)
      search_slots;

    (* Sort by (scope_id, seq_id) *)
    let sorted_matches =
      List.sort
        (fun (e1, s1) (e2, s2) ->
          let c = compare e1 e2 in
          if c = 0 then compare s1 s2 else c)
        !all_matches
    in

    (* Find next/previous match *)
    let compare_fn =
      if forward then fun (e, s) ->
        e > current_scope_id || (e = current_scope_id && s > current_seq_id)
      else fun (e, s) ->
        e < current_scope_id || (e = current_scope_id && s < current_seq_id)
    in

    let candidates = List.filter compare_fn sorted_matches in
    if forward then
      (* Return first match in forward direction *)
      match candidates with
      | [] -> None
      | x :: _ -> Some x
    else
      (* Return last match in backward direction (closest to current) *)
      match List.rev candidates with
      | [] -> None
      | x :: _ -> Some x

  type view_state = {
    db : Sqlite3.db;
    db_path : string; (* Path to database file for spawning Domains *)
    cursor : int; (* Current cursor position in visible items *)
    scroll_offset : int; (* Top visible item index *)
    expanded : (int, unit) Hashtbl.t; (* Set of expanded scope_ids *)
    visible_items : visible_item array; (* Flattened view of tree *)
    show_times : bool;
    values_first : bool;
    max_scope_id : int; (* Maximum scope_id in this run *)
    search_slots : slot_map;
    current_slot : SlotNumber.t; (* Next slot to use *)
    search_input : string option; (* Active search input buffer *)
    quiet_path_input : string option; (* Active quiet path input buffer *)
    quiet_path : string option;
        (* Shared quiet path filter - stops highlight propagation *)
    search_order : Query.search_order; (* Ordering for search results *)
  }

  and visible_item = {
    entry : Query.entry;
    indent_level : int;
    is_expandable : bool;
    is_expanded : bool;
  }

  (** Find closest ancestor with positive ID by walking up the tree *)
  let rec find_positive_ancestor_id db scope_id =
    (* Base case: if this scope_id is positive, return it *)
    if scope_id >= 0 then Some scope_id
    else
      (* Negative scope_id - walk up to parent *)
      match Query.get_parent_id db ~scope_id with
      | Some parent_id -> find_positive_ancestor_id db parent_id
      | None -> None (* No parent found *)

  (** Build visible items list from database using lazy loading *)
  let build_visible_items db expanded values_first ~search_slots ~current_slot =
    let rec flatten_entry ~depth entry =
      (* Check if this entry actually has children *)
      let is_expandable =
        match entry.Query.child_scope_id with
        | Some hid -> Query.has_children db ~parent_scope_id:hid
        | None -> false
      in
      (* Use child_scope_id as the key - it uniquely identifies this scope *)
      let is_expanded =
        match entry.child_scope_id with
        | Some hid -> Hashtbl.mem expanded hid
        | None -> false
      in

      let visible = { entry; indent_level = depth; is_expandable; is_expanded } in

      (* Add children if this is expanded *)
      if is_expanded then
        match entry.child_scope_id with
        | Some hid ->
            (* Load children on demand *)
            let children = Query.get_scope_children db ~parent_scope_id:hid in
            (* In values_first mode, check if we have a single result child to combine *)
            let children_to_show =
              if values_first then
                let results, non_results =
                  List.partition (fun e -> e.Query.is_result) children
                in
                match results with
                | [ single_result ] ->
                    (* Don't combine if result is itself a scope/header (e.g., synthetic
                       scopes from boxify). Only combine simple value results with their
                       parent headers. *)
                    if single_result.child_scope_id = None then
                      (* Single childless result: normally skip it (will be combined with
                         header). BUT: if this result is a search match, we must show it
                         separately! *)
                      let result_is_search_match =
                        get_search_match ~search_slots ~scope_id:single_result.scope_id
                          ~seq_id:single_result.seq_id ~current_slot
                        <> None
                      in
                      if result_is_search_match then children
                        (* Show all children including the matched result *)
                      else non_results (* Skip result, combine with header *)
                    else
                      (* Result has children: show all *)
                      children
                | _ -> children (* Multiple results or no results: show all *)
              else children
            in
            visible :: List.concat_map (flatten_entry ~depth:(depth + 1)) children_to_show
        | None -> [ visible ]
      else [ visible ]
    in

    (* Start with root entries *)
    let roots = Query.get_root_entries db ~with_values:false in
    let items = List.concat_map (flatten_entry ~depth:0) roots in
    Array.of_list items

  (** Render a single line *)
  let render_line ~width ~is_selected ~show_times ~margin_width ~search_slots
      ~current_slot:_ ~db ~values_first item =
    let entry = item.entry in

    (* Entry ID margin - use child_scope_id for scopes, scope_id for values *)
    (* Don't display negative IDs (used for boxified/decomposed values) *)
    let display_id =
      match entry.child_scope_id with
      | Some hid when hid >= 0 ->
          Some hid (* This is a scope/header - show its actual scope ID *)
      | Some _ -> None (* Negative child_scope_id - hide it *)
      | None when entry.scope_id >= 0 ->
          Some entry.scope_id (* This is a value - show its parent scope ID *)
      | None -> None (* Negative scope_id - hide it *)
    in
    let scope_id_str =
      match display_id with
      | Some id -> Printf.sprintf "%*d │ " margin_width id
      | None -> String.make (margin_width + 3) ' ' (* Blank margin: spaces + " │ " *)
    in
    let content_width = width - String.length scope_id_str in

    let indent = String.make (item.indent_level * 2) ' ' in

    (* Expansion indicator *)
    let expansion_mark =
      if item.is_expandable then if item.is_expanded then "▼ " else "▶ " else "  "
    in

    (* Entry content *)
    let content =
      match item.entry.child_scope_id with
      | Some hid when values_first && item.is_expanded -> (
          (* Header/scope in values_first mode: check for single result child to
             combine *)
          let children = Query.get_scope_children db ~parent_scope_id:hid in
          let results, _non_results =
            List.partition (fun e -> e.Query.is_result) children
          in
          match results with
          | [ single_result ] ->
              (* Don't combine if result is itself a scope/header (e.g., synthetic scopes
                 from boxify). Only combine simple value results with their parent
                 headers. *)
              if single_result.child_scope_id = None then
                (* Combine result with header: [type] message => result_data *)
                let result_data = Option.value ~default:"" single_result.data in
                let result_msg = single_result.message in
                let combined_result =
                  if result_msg <> "" && result_msg <> entry.message then
                    Printf.sprintf " => %s = %s" result_msg result_data
                  else Printf.sprintf " => %s" result_data
                in
                Printf.sprintf "%s%s[%s] %s%s" indent expansion_mark entry.entry_type
                  entry.message combined_result
              else
                (* Result has children: normal rendering *)
                Printf.sprintf "%s%s[%s] %s" indent expansion_mark entry.entry_type
                  entry.message
          | _ ->
              (* Multiple results or no results: normal rendering *)
              (* For synthetic scopes (no location), show data inline with message *)
              let is_synthetic = entry.location = None in
              let display_text =
                match (entry.message, entry.data, is_synthetic) with
                | msg, Some data, true when msg <> "" -> Printf.sprintf "%s: %s" msg data
                | "", Some data, true -> data
                | msg, _, _ when msg <> "" -> msg
                | _ -> ""
              in
              Printf.sprintf "%s%s[%s] %s" indent expansion_mark entry.entry_type
                display_text)
      | Some _ ->
          (* Header/scope - normal rendering *)
          let display_text =
            let message = entry.message in
            let data = Option.value ~default:"" entry.data in
            if message <> "" then message else data
          in
          Printf.sprintf "%s%s[%s] %s" indent expansion_mark entry.entry_type display_text
      | None ->
          (* Value *)
          let display_text =
            let message = entry.message in
            let data = Option.value ~default:"" entry.data in
            let is_result = entry.is_result in
            (if message <> "" then message ^ " " else "")
            ^ (if is_result then "=> "
               else if message <> "" && data <> "" then "= "
               else "")
            ^ data
          in
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
      else full_text
    in

    (* Get all matching search slots for checkered pattern *)
    let all_matches =
      get_all_search_matches ~search_slots ~scope_id:entry.scope_id ~seq_id:entry.seq_id
    in

    (* Helper: get color attribute for a slot number *)
    let slot_color = function
      | SlotNumber.S1 -> A.(fg green) (* Search slot 1: green *)
      | SlotNumber.S2 -> A.(fg cyan) (* Search slot 2: cyan *)
      | SlotNumber.S3 -> A.(fg magenta) (* Search slot 3: magenta *)
      | SlotNumber.S4 -> A.(fg yellow) (* Search slot 4: yellow *)
    in

    (* Render line with appropriate highlighting *)
    let content_image, margin_image =
      if is_selected then
        (* Selection takes priority - blue background *)
        let attr = A.(bg lightblue ++ fg black) in
        (I.string attr truncated, I.string attr scope_id_str)
      else
        match all_matches with
        | [] ->
            (* No match: default (margin still yellow) *)
            (I.string A.empty truncated, I.string A.(fg yellow) scope_id_str)
        | [ single_match ] ->
            (* Single match: simple uniform coloring *)
            let attr = slot_color single_match in
            (I.string attr truncated, I.string attr scope_id_str)
        | multiple_matches when List.length multiple_matches >= 2 ->
            (* Multiple matches: checkered pattern - split text into segments *)
            let num_matches = List.length multiple_matches in
            let text_len = String.length truncated in
            (* Create min(num_matches * 2, text_len) segments *)
            let num_segments = min (num_matches * 2) text_len in
            let segment_size = max 1 (text_len / num_segments) in

            (* Build checkered content by alternating colors *)
            let content_segments = ref [] in
            let pos = ref 0 in
            let color_idx = ref 0 in
            while !pos < text_len do
              let remaining = text_len - !pos in
              let seg_len = min segment_size remaining in
              let segment = String.sub truncated !pos seg_len in
              let color = slot_color (List.nth multiple_matches (!color_idx mod num_matches)) in
              content_segments := I.string color segment :: !content_segments;
              pos := !pos + seg_len;
              color_idx := !color_idx + 1
            done;
            let content_img = I.hcat (List.rev !content_segments) in

            (* Margin uses first matching color *)
            let margin_color = slot_color (List.hd multiple_matches) in
            let margin_img = I.string margin_color scope_id_str in

            (content_img, margin_img)
        | _ ->
            (* Fallback (shouldn't happen) *)
            (I.string A.empty truncated, I.string A.(fg yellow) scope_id_str)
    in

    I.hcat [ margin_image; content_image ]

  (** Render the full screen *)
  let render_screen state term_height term_width =
    let header_height = 2 in
    let footer_height = 2 in
    let content_height = term_height - header_height - footer_height in

    (* Calculate margin width based on max_scope_id *)
    let margin_width = String.length (string_of_int state.max_scope_id) in

    (* Calculate progress indicator - find closest ancestor with positive ID *)
    let current_scope_id =
      if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
        let entry = state.visible_items.(state.cursor).entry in
        (* For scopes, use child_scope_id; for values, use scope_id *)
        let id_to_check =
          match entry.child_scope_id with Some hid -> hid | None -> entry.scope_id
        in
        match find_positive_ancestor_id state.db id_to_check with
        | Some id -> id
        | None -> 0
      else 0
    in
    let progress_pct =
      if state.max_scope_id > 0 then
        float_of_int current_scope_id /. float_of_int state.max_scope_id *. 100.0
      else 0.0
    in

    (* Header *)
    let header =
      let line1 =
        match state.quiet_path_input with
        | Some input ->
            (* Show quiet_path input prompt *)
            I.string A.(fg lightred) (Printf.sprintf "Quiet Path: %s_" input)
        | None -> (
            match state.search_input with
            | Some input ->
                (* Show search input prompt *)
                I.string A.(fg lightyellow) (Printf.sprintf "Search: %s_" input)
            | None ->
                (* Show run info and search status *)
                let search_order_str =
                  match state.search_order with
                  | Query.AscendingIds -> "Asc"
                  | Query.DescendingIds -> "Desc"
                in
                let base_info =
                  Printf.sprintf
                    "Items: %d | Times: %s | Values First: %s | Search: %s | Entry: \
                     %d/%d (%.1f%%)"
                    (Array.length state.visible_items)
                    (if state.show_times then "ON" else "OFF")
                    (if state.values_first then "ON" else "OFF")
                    search_order_str current_scope_id state.max_scope_id progress_pct
                in
                (* Build search status string *)
                let search_status =
                  let active_searches = ref [] in
                  SlotMap.iter
                    (fun idx slot ->
                      let count = Hashtbl.length slot.results in
                      let color_name =
                        match idx with S1 -> "G" | S2 -> "C" | S3 -> "M" | S4 -> "Y"
                      in
                      (* Show [...] while running, just [...] when complete *)
                      let count_str =
                        if !(slot.completed_ref) then Printf.sprintf "[%d]" count
                        else Printf.sprintf "[%d...]" count
                      in
                      active_searches :=
                        Printf.sprintf "%s:%s%s" color_name slot.search_term count_str
                        :: !active_searches)
                    state.search_slots;
                  if !active_searches = [] then ""
                  else " | " ^ String.concat " " (List.rev !active_searches)
                in
                (* Add quiet_path indicator if set *)
                let quiet_info =
                  match state.quiet_path with
                  | Some qp -> Printf.sprintf " | Q:%s" qp
                  | None -> ""
                in
                I.string A.(fg lightcyan) (base_info ^ search_status ^ quiet_info))
      in
      I.vcat [ line1; I.string A.(fg white) (String.make term_width '-') ]
    in

    (* Content lines *)
    let visible_start = state.scroll_offset in
    let visible_end =
      min (visible_start + content_height) (Array.length state.visible_items)
    in

    let content_lines = ref [] in
    for i = visible_start to visible_end - 1 do
      let is_selected = i = state.cursor in
      let item = state.visible_items.(i) in
      let line =
        render_line ~width:term_width ~is_selected ~show_times:state.show_times
          ~margin_width ~search_slots:state.search_slots ~current_slot:state.current_slot
          ~db:state.db ~values_first:state.values_first item
      in
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
        | Some _ -> "[Enter] Confirm quiet path | [Esc] Cancel | [Backspace] Delete"
        | None -> (
            match state.search_input with
            | Some _ -> "[Enter] Confirm search | [Esc] Cancel | [Backspace] Delete"
            | None ->
                "[↑/↓] Navigate | [Home/End] First/Last | [PgUp/PgDn] Page | [u/d] \
                 Quarter | [n/N] Next/Prev Match | [Enter/Space] Expand | [/] Search | \
                 [Q] Quiet | [t] Times | [v] Values | [o] Order | [q] Quit")
      in
      I.vcat
        [
          I.string A.(fg white) (String.make term_width '-');
          I.string A.(fg lightcyan) help_text;
        ]
    in

    I.vcat [ header; content; footer ]

  (** Toggle expansion of current item *)
  let toggle_expansion state =
    if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
      let item = state.visible_items.(state.cursor) in
      if item.is_expandable then
        match item.entry.child_scope_id with
        | Some hid ->
            (* Use child_scope_id as the unique key for this scope *)
            if Hashtbl.mem state.expanded hid then Hashtbl.remove state.expanded hid
            else Hashtbl.add state.expanded hid ();

            (* Rebuild visible items *)
            let new_visible =
              build_visible_items state.db state.expanded state.values_first
                ~search_slots:state.search_slots ~current_slot:state.current_slot
            in
            { state with visible_items = new_visible }
        | None -> state
      else state
    else state

  (** Find next/previous search result (searches hash tables, not just visible items).
      Returns updated state with cursor moved to the match and path auto-expanded, or None
      if no match. *)
  let find_and_jump_to_search_result state ~forward =
    (* Get current entry's (scope_id, seq_id) *)
    let current_scope_id, current_seq_id =
      if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
        let entry = state.visible_items.(state.cursor).entry in
        (entry.scope_id, entry.seq_id)
      else (0, 0)
      (* Start from beginning if cursor invalid *)
    in

    (* Query hash tables for next search match *)
    match
      find_next_search_result ~search_slots:state.search_slots ~current_scope_id
        ~current_seq_id ~forward
    with
    | None -> None (* No more search results *)
    | Some (target_scope_id, target_seq_id) -> (
        (* Expand all ancestors of the target entry. get_ancestors returns
           [target_scope_id; parent; grandparent; ...]. Since target entry lives inside
           target_scope_id, we must expand target_scope_id and all its ancestors to make
           the path visible. *)
        let ancestors = Query.get_ancestors state.db ~scope_id:target_scope_id in
        List.iter
          (fun ancestor_id -> Hashtbl.replace state.expanded ancestor_id ())
          ancestors;

        (* Rebuild visible items with expanded path *)
        let new_visible =
          build_visible_items state.db state.expanded state.values_first
            ~search_slots:state.search_slots ~current_slot:state.current_slot
        in

        (* Find the target entry in the new visible items *)
        let rec find_in_visible idx =
          if idx >= Array.length new_visible then None
            (* Entry not found after expansion - may be filtered or invalid *)
          else
            let item = new_visible.(idx) in
            if item.entry.scope_id = target_scope_id && item.entry.seq_id = target_seq_id
            then Some idx
            else find_in_visible (idx + 1)
        in

        match find_in_visible 0 with
        | None ->
            (* Couldn't find target in visible items - return updated state anyway so user
               sees the expanded path. The target may become visible after manual
               navigation. *)
            Some { state with visible_items = new_visible }
        | Some new_cursor ->
            (* Calculate scroll offset to center the match on screen *)
            let _, term_height = Term.size (Term.create ()) in
            let content_height = term_height - 4 in
            let new_scroll =
              if new_cursor < state.scroll_offset then new_cursor
              else if new_cursor >= state.scroll_offset + content_height then
                max 0 (new_cursor - (content_height / 2))
              else state.scroll_offset
            in
            Some
              {
                state with
                cursor = new_cursor;
                scroll_offset = new_scroll;
                visible_items = new_visible;
              })

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
              if String.length input > 0 then String.sub input 0 (String.length input - 1)
              else input
            in
            Some { state with quiet_path_input = Some new_input }
        | `ASCII c, _ when c >= ' ' && c <= '~' ->
            (* Add printable character *)
            Some { state with quiet_path_input = Some (input ^ String.make 1 c) }
        | _ -> Some state)
    | None -> (
        (* Handle search input mode *)
        match state.search_input with
        | Some input -> (
            match key with
            | `Escape, _ ->
                (* Cancel search input *)
                Some { state with search_input = None }
            | `Enter, _ ->
                (* Confirm search - spawn Domain to populate search hash table *)
                if String.length input > 0 then
                  let slot = state.current_slot in

                  (* Create shared completion flag and results hash table *)
                  let completed_ref = ref false in
                  let results_table = Hashtbl.create 1024 in

                  (* Spawn background search Domain - pass db_path not db handle *)
                  let domain_handle =
                    Domain.spawn (fun () ->
                        Query.populate_search_results state.db_path ~search_term:input
                          ~quiet_path:state.quiet_path ~search_order:state.search_order
                          ~completed_ref ~results_table)
                  in

                  (* Update search slots *)
                  let new_slots =
                    SlotMap.update slot
                      (fun _ ->
                        Some
                          {
                            search_term = input;
                            domain_handle = Some domain_handle;
                            completed_ref;
                            results = results_table;
                          })
                      state.search_slots
                  in

                  Some
                    {
                      state with
                      search_input = None;
                      search_slots = new_slots;
                      current_slot = SlotNumber.next slot;
                    }
                else
                  (* Empty input - just cancel *)
                  Some { state with search_input = None }
            | `Backspace, _ ->
                (* Remove last character *)
                let new_input =
                  if String.length input > 0 then
                    String.sub input 0 (String.length input - 1)
                  else input
                in
                Some { state with search_input = Some new_input }
            | `ASCII c, _ when c >= ' ' && c <= '~' ->
                (* Add printable character *)
                Some { state with search_input = Some (input ^ String.make 1 c) }
            | _ -> Some state)
        | None -> (
            (* Normal navigation mode *)
            match key with
            | `ASCII 'q', _ | `Escape, _ -> None (* Quit *)
            | `ASCII '/', _ ->
                (* Enter search mode *)
                Some { state with search_input = Some "" }
            | `ASCII 'Q', _ ->
                (* Enter quiet_path mode *)
                Some
                  {
                    state with
                    quiet_path_input = Some (Option.value ~default:"" state.quiet_path);
                  }
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
            | `Home, _ ->
                (* Jump to first entry *)
                Some { state with cursor = 0; scroll_offset = 0 }
            | `End, _ ->
                (* Jump to last entry *)
                let max_cursor = Array.length state.visible_items - 1 in
                let new_scroll = max 0 (max_cursor - content_height + 1) in
                Some { state with cursor = max_cursor; scroll_offset = new_scroll }
            | `Enter, _ | `ASCII ' ', _ -> Some (toggle_expansion state)
            | `ASCII 't', _ -> Some { state with show_times = not state.show_times }
            | `ASCII 'v', _ ->
                let new_values_first = not state.values_first in
                let new_visible =
                  build_visible_items state.db state.expanded new_values_first
                    ~search_slots:state.search_slots ~current_slot:state.current_slot
                in
                Some
                  {
                    state with
                    values_first = new_values_first;
                    visible_items = new_visible;
                  }
            | `ASCII 'o', _ ->
                (* Toggle search order *)
                let new_order =
                  match state.search_order with
                  | Query.AscendingIds -> Query.DescendingIds
                  | Query.DescendingIds -> Query.AscendingIds
                in
                Some { state with search_order = new_order }
            | `Page `Up, _ ->
                (* Page Up: Move cursor to top of screen, then scroll up by content_height
                   - 1 *)
                if state.cursor = state.scroll_offset then
                  (* Cursor already at top - scroll up one page, keeping one row
                     overlap *)
                  let new_scroll = max 0 (state.scroll_offset - (content_height - 1)) in
                  let new_cursor = new_scroll in
                  Some { state with cursor = new_cursor; scroll_offset = new_scroll }
                else
                  (* Move cursor to top of current view *)
                  Some { state with cursor = state.scroll_offset }
            | `Page `Down, _ ->
                (* Page Down: Move cursor to bottom of screen, then scroll down by
                   content_height - 1 *)
                let max_cursor = Array.length state.visible_items - 1 in
                let bottom_of_screen =
                  min max_cursor (state.scroll_offset + content_height - 1)
                in
                if state.cursor = bottom_of_screen then
                  (* Cursor already at bottom - scroll down one page, keeping one row
                     overlap *)
                  let new_scroll =
                    min
                      (max 0 (max_cursor - content_height + 1))
                      (state.scroll_offset + (content_height - 1))
                  in
                  let new_cursor = min max_cursor (new_scroll + content_height - 1) in
                  Some { state with cursor = new_cursor; scroll_offset = new_scroll }
                else
                  (* Move cursor to bottom of current view *)
                  Some { state with cursor = bottom_of_screen }
            | `ASCII 'u', _ ->
                (* Quarter-page Up: Scroll up by content_height / 4 *)
                let quarter_page = max 1 (content_height / 4) in
                let new_cursor = max 0 (state.cursor - quarter_page) in
                let new_scroll = max 0 (min state.scroll_offset new_cursor) in
                Some { state with cursor = new_cursor; scroll_offset = new_scroll }
            | `ASCII 'd', _ ->
                (* Quarter-page Down: Scroll down by content_height / 4 *)
                let max_cursor = Array.length state.visible_items - 1 in
                let quarter_page = max 1 (content_height / 4) in
                let new_cursor = min max_cursor (state.cursor + quarter_page) in
                let new_scroll =
                  if new_cursor >= state.scroll_offset + content_height then
                    min
                      (max 0 (max_cursor - content_height + 1))
                      (new_cursor - content_height + 1)
                  else state.scroll_offset
                in
                Some { state with cursor = new_cursor; scroll_offset = new_scroll }
            | `ASCII 'n', _ -> (
                (* Next search result - searches entire DB and auto-expands path *)
                match find_and_jump_to_search_result state ~forward:true with
                | Some new_state -> Some new_state
                | None -> Some state (* No more results, stay in place *))
            | `ASCII 'N', _ -> (
                (* Previous search result - searches entire DB and auto-expands path *)
                match find_and_jump_to_search_result state ~forward:false with
                | Some new_state -> Some new_state
                | None -> Some state (* No more results, stay in place *))
            | _ -> Some state))

  (** Main interactive loop *)
  let run db db_path =
    let expanded = Hashtbl.create 64 in
    let values_first = true in
    (* Initialize with empty search slots for initial build *)
    let empty_search_slots = SlotMap.empty in
    let visible_items =
      build_visible_items db expanded values_first ~search_slots:empty_search_slots
        ~current_slot:S1
    in
    let max_scope_id = Query.get_max_scope_id db in

    (* Initialize empty search slots (no persistence across TUI sessions) *)
    let initial_state =
      {
        db;
        db_path;
        cursor = 0;
        scroll_offset = 0;
        expanded;
        visible_items;
        show_times = true;
        values_first;
        max_scope_id;
        search_slots = SlotMap.empty;
        current_slot = S1;
        search_input = None;
        quiet_path_input = None;
        quiet_path = None;
        search_order = Query.AscendingIds;
        (* Default: uses index efficiently *)
      }
    in

    let term = Term.create () in

    let rec loop state =
      let term_width, term_height = Term.size term in
      let image = render_screen state term_height term_width in
      Term.image term image;

      (* Poll every 1/5th of a second to check for search updates *)
      match event_with_timeout term 0.2 with
      | Some event -> (
          match event with
          | `Key key -> (
              match handle_key state key term_height with
              | Some new_state -> loop new_state
              | None -> ())
          | `Resize _ -> loop state
          | #Notty.Unescape.event | `End -> loop state)
      | None ->
          (* Timeout - just redraw to update search status *)
          loop state
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
  let list_runs t = Query.get_runs t.db_path

  (** Get latest run *)
  let get_latest_run t =
    match Query.get_latest_run_id t.db_path with
    | Some run_id ->
        let runs = Query.get_runs t.db_path in
        List.find_opt (fun r -> r.Query.run_id = run_id) runs
    | None -> None

  (** Show run summary *)
  let show_run_summary t run_id =
    let runs = Query.get_runs t.db_path in
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
  let show_trace ?(show_scope_ids = false) ?(show_times = false) ?(max_depth = None)
      ?(values_first_mode = true) t =
    let roots = Query.get_root_entries t.db ~with_values:false in
    let trees = Renderer.build_tree t.db ?max_depth roots in
    let output =
      Renderer.render_tree ~show_scope_ids ~show_times ~max_depth ~values_first_mode trees
    in
    print_string output

  (** Show compact trace (function names only) *)
  let show_compact_trace t =
    let roots = Query.get_root_entries t.db ~with_values:false in
    let trees = Renderer.build_tree t.db ?max_depth:None roots in
    let output = Renderer.render_compact trees in
    print_string output

  (** Show root entries efficiently *)
  let show_roots ?(show_times = false) ?(with_values = false) t =
    let entries = Query.get_root_entries t.db ~with_values in
    let output = Renderer.render_roots ~show_times ~with_values entries in
    print_string output

  (** Search entries *)
  let search t ~pattern =
    let entries = Query.search_entries t.db ~pattern in
    Printf.printf "Found %d matching entries for pattern '%s':\n\n" (List.length entries)
      pattern;
    List.iter
      (fun entry ->
        Printf.printf "#%d [%s] %s" entry.Query.scope_id entry.entry_type entry.message;
        (match entry.location with Some loc -> Printf.printf " @ %s" loc | None -> ());
        Printf.printf "\n";
        match entry.data with Some data -> Printf.printf "  %s\n" data | None -> ())
      entries

  (** Export trace to markdown *)
  let export_markdown t ~output_file =
    let run = get_latest_run t in
    let roots = Query.get_root_entries t.db ~with_values:false in
    let trees = Renderer.build_tree t.db ?max_depth:None roots in

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
             else Printf.fprintf oc "%s  **=>** `%s`\n" indent data
         | None -> ());

      List.iter (render_node ~depth:(depth + 1)) node.Renderer.children
    in

    List.iter (render_node ~depth:0) trees;
    close_out oc;
    Printf.printf "Exported to %s\n" output_file

  (** Search with tree context - shows matching entries with their ancestor paths.
      Uses the populate_search_results approach from TUI for efficient ancestor propagation. *)
  let search_tree ?(quiet_path = None) ?(format = `Text) ?(show_times = false)
      ?(max_depth = None) ?(limit = None) ?(offset = None) t ~pattern =
    (* Run search synchronously using the same logic as TUI *)
    let completed_ref = ref false in
    let results_table = Hashtbl.create 1024 in
    Query.populate_search_results t.db_path ~search_term:pattern ~quiet_path
      ~search_order:Query.AscendingIds ~completed_ref ~results_table;

    (* Extract matching entries from hash table *)
    let all_matching_scope_ids =
      Hashtbl.fold
        (fun (scope_id, _seq_id) is_match acc ->
          if is_match then scope_id :: acc else acc)
        results_table []
      |> List.sort_uniq compare
    in

    (* Apply pagination to matching scope IDs *)
    let matching_scope_ids =
      let ids = all_matching_scope_ids in
      let ids = match offset with
        | None -> ids
        | Some off ->
            if off < List.length ids then
              List.filteri (fun i _ -> i >= off) ids
            else []
      in
      match limit with
      | None -> ids
      | Some lim ->
          if lim >= List.length ids then ids
          else List.filteri (fun i _ -> i < lim) ids
    in

    (* Get all entries from DB and filter to only those in results_table *)
    let all_entries = Query.get_entries t.db () in
    let filtered_entries =
      List.filter
        (fun e -> Hashtbl.mem results_table (e.Query.scope_id, e.Query.seq_id))
        all_entries
    in

    (* Build tree from filtered entries *)
    let all_trees = Renderer.build_tree_from_entries filtered_entries in

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
    (match format with
    | `Text ->
        let total_scopes = List.length all_matching_scope_ids in
        let total_trees = List.length all_trees in
        let shown_trees = List.length trees in
        let start_idx = Option.value offset ~default:0 in
        if limit <> None || offset <> None then
          Printf.printf "Found %d matching scopes for pattern '%s', %d root trees (showing trees %d-%d)\n\n"
            total_scopes pattern total_trees start_idx (start_idx + shown_trees)
        else
          Printf.printf "Found %d matching scopes for pattern '%s'\n\n"
            total_scopes pattern;
        let output =
          Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
            ~values_first_mode:true trees
        in
        print_string output
    | `Json ->
        let json = Renderer.render_tree_json ~max_depth trees in
        print_endline json);

    List.length matching_scope_ids

  (** Search and show only matching subtrees (prune non-matching branches).
      This builds a minimal tree containing only paths to matches. *)
  let search_subtree ?(quiet_path = None) ?(format = `Text) ?(show_times = false)
      ?(max_depth = None) ?(limit = None) ?(offset = None) t ~pattern =
    (* Run search to get results hash table *)
    let completed_ref = ref false in
    let results_table = Hashtbl.create 1024 in
    Query.populate_search_results t.db_path ~search_term:pattern ~quiet_path
      ~search_order:Query.AscendingIds ~completed_ref ~results_table;

    (* Get all entries and build full tree *)
    let all_entries = Query.get_entries t.db () in
    let full_trees = Renderer.build_tree_from_entries all_entries in

    (* Prune tree: keep only nodes that have matches in their subtree *)
    let rec prune_tree node =
      let entry = node.Renderer.entry in
      (* Check if this entry is a match *)
      let is_match = Hashtbl.mem results_table (entry.scope_id, entry.seq_id) in
      (* Recursively prune children *)
      let pruned_children =
        List.filter_map prune_tree node.children in
      (* Keep this node if it's a match OR if any child survived pruning *)
      if is_match || pruned_children <> [] then
        Some { node with Renderer.children = pruned_children }
      else None
    in

    let all_pruned_trees = List.filter_map prune_tree full_trees in

    (* Apply pagination to pruned trees (at root level) *)
    let pruned_trees =
      let trees = all_pruned_trees in
      let trees = match offset with
        | None -> trees
        | Some off ->
            if off < List.length trees then
              List.filteri (fun i _ -> i >= off) trees
            else []
      in
      match limit with
      | None -> trees
      | Some lim ->
          if lim >= List.length trees then trees
          else List.filteri (fun i _ -> i < lim) trees
    in

    (* Count actual matches (not propagated ancestors) *)
    let match_count =
      Hashtbl.fold
        (fun _key is_match acc -> if is_match then acc + 1 else acc)
        results_table 0
    in

    (* Output *)
    (match format with
    | `Text ->
        let total_trees = List.length all_pruned_trees in
        let shown_trees = List.length pruned_trees in
        let start_idx = Option.value offset ~default:0 in
        if limit <> None || offset <> None then
          Printf.printf "Found %d matches for pattern '%s', %d root trees (showing trees %d-%d):\n\n"
            match_count pattern total_trees start_idx (start_idx + shown_trees)
        else
          Printf.printf "Found %d matches for pattern '%s', showing %d pruned subtrees:\n\n"
            match_count pattern total_trees;
        let output =
          Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
            ~values_first_mode:true pruned_trees
        in
        print_string output
    | `Json ->
        let json = Renderer.render_tree_json ~max_depth pruned_trees in
        print_endline json);

    match_count

  (** Search intersection - find smallest subtrees containing all patterns (LCA-based).
      For each pattern, runs populate_search_results to get matching scopes.
      Then computes all LCAs (Lowest Common Ancestors) for combinations of matches
      (one match per pattern). Returns unique LCA scopes as the smallest subtrees. *)
  let search_intersection ?(quiet_path = None) ?(format = `Text) ?(show_times = false)
      ?max_depth:_ ?(limit = None) ?(offset = None) t ~patterns =
    (* Run separate search for each pattern *)
    let all_results_tables =
      List.map
        (fun pattern ->
          let completed_ref = ref false in
          let results_table = Hashtbl.create 1024 in
          Query.populate_search_results t.db_path ~search_term:pattern ~quiet_path
            ~search_order:Query.AscendingIds ~completed_ref ~results_table;
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

    (* Open database connection for LCA computation *)
    let db = Sqlite3.db_open ~mode:`READONLY t.db_path in

    (* Compute LCAs for all combinations of matches (one per pattern).
       This generates the Cartesian product of all match sets and computes LCA for each tuple. *)
    let lca_scope_ids =
      (* Generate Cartesian product of match sets *)
      let rec cartesian_product = function
        | [] -> [ [] ]
        | (pattern, ids) :: rest ->
            let rest_product = cartesian_product rest in
            List.concat_map
              (fun id -> List.map (fun combo -> (pattern, id) :: combo) rest_product)
              ids
      in

      let all_combinations = cartesian_product matching_scope_ids_per_pattern in

      (* Compute LCA for each combination. If no LCA exists (scopes in separate trees),
         fall back to returning the root scopes themselves. *)
      let lcas =
        List.concat_map
          (fun combo ->
            let scope_ids = List.map snd combo in
            match Query.lowest_common_ancestor db scope_ids with
            | Some lca -> [ lca ]
            | None ->
                (* No common ancestor - scopes are in separate root trees.
                   Return all root scopes as separate minimal subtrees. *)
                List.map (fun id -> Query.get_root_scope db id) scope_ids)
          all_combinations
        |> List.sort_uniq compare
      in

      Sqlite3.db_close db |> ignore;
      lcas
    in

    (* Get entries for LCA scopes (just the header entries for compact display) *)
    let all_entries = Query.get_entries t.db () in
    let lca_entries =
      List.filter_map
        (fun lca_scope_id ->
          (* Find the header entry that creates this scope *)
          List.find_opt
            (fun e ->
              match e.Query.child_scope_id with
              | Some child_id when child_id = lca_scope_id -> true
              | _ -> false)
            all_entries)
        lca_scope_ids
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
    (match format with
    | `Text ->
        let total_lcas = List.length lca_scope_ids in
        let shown_lcas = List.length paginated_lca_entries in
        let start_idx = Option.value offset ~default:0 in
        let pattern_str = String.concat " AND " (List.map (Printf.sprintf "'%s'") patterns) in

        if limit <> None || offset <> None then
          Printf.printf "Found %d smallest subtrees containing all patterns (%s) (showing %d-%d):\n\n"
            total_lcas pattern_str start_idx (start_idx + shown_lcas)
        else
          Printf.printf "Found %d smallest subtrees containing all patterns (%s):\n\n"
            total_lcas pattern_str;

        (* Show per-pattern match counts for debugging *)
        Printf.printf "Per-pattern match counts:\n";
        List.iter
          (fun (pattern, scope_ids) ->
            Printf.printf "  '%s': %d scopes\n" pattern (List.length scope_ids))
          matching_scope_ids_per_pattern;
        Printf.printf "\n";

        (* Display LCA scopes compactly: scope_id and header line only *)
        Printf.printf "Lowest Common Ancestor scopes (smallest subtrees):\n\n";
        List.iter
          (fun entry ->
            match entry.Query.child_scope_id with
            | Some lca_scope_id ->
                let loc_str = match entry.Query.location with
                  | Some loc -> Printf.sprintf " [%s]" loc
                  | None -> ""
                in
                let elapsed_str = match Renderer.elapsed_time entry with
                  | Some ns when show_times ->
                      Printf.sprintf " (%s)" (Renderer.format_elapsed_ns ns)
                  | _ -> ""
                in
                Printf.printf "  Scope %d: %s%s%s\n"
                  lca_scope_id entry.Query.message loc_str elapsed_str
            | None -> ())
          paginated_lca_entries;
        Printf.printf "\n"
    | `Json ->
        let json_entries =
          List.map
            (fun entry ->
              match entry.Query.child_scope_id with
              | Some lca_scope_id ->
                  Printf.sprintf
                    {|{"scope_id": %d, "message": "%s", "location": %s}|}
                    lca_scope_id
                    (String.escaped entry.Query.message)
                    (match entry.Query.location with
                    | Some loc -> Printf.sprintf "\"%s\"" (String.escaped loc)
                    | None -> "null")
              | None -> "")
            paginated_lca_entries
          |> List.filter (fun s -> s <> "")
        in
        Printf.printf "[%s]\n" (String.concat ", " json_entries));

    List.length lca_scope_ids

  (** Show a specific scope and its descendants *)
  let show_scope ?(format = `Text) ?(show_times = false) ?(max_depth = None)
      ?(show_ancestors = false) t ~scope_id =
    if show_ancestors then
      (* Show path from root to this scope *)
      let ancestors = Query.get_ancestors t.db ~scope_id in
      let all_entries = Query.get_entries t.db () in
      (* Filter to only ancestor scopes and the target scope *)
      let ancestor_set =
        List.fold_left (fun acc id -> Hashtbl.add acc id (); acc)
          (Hashtbl.create 16) ancestors
      in
      let filtered_entries =
        List.filter (fun e -> Hashtbl.mem ancestor_set e.Query.scope_id) all_entries
      in
      let trees = Renderer.build_tree_from_entries filtered_entries in
      (match format with
      | `Text ->
          Printf.printf "Ancestor path to scope %d:\n\n" scope_id;
          let output =
            Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
              ~values_first_mode:true trees
          in
          print_string output
      | `Json ->
          let json = Renderer.render_tree_json ~max_depth trees in
          print_endline json)
    else
      (* Show just this scope and descendants *)
      let children = Query.get_scope_children t.db ~parent_scope_id:scope_id in
      (match format with
      | `Text ->
          Printf.printf "Scope %d contents:\n\n" scope_id;
          let output = Renderer.render_entries_json children in
          print_string output;
          print_newline ()
      | `Json ->
          let json = Renderer.render_entries_json children in
          print_endline json)

  (** Show a specific scope subtree with ancestors (full tree rendering).
      The max_depth parameter is interpreted as INCREMENTAL depth from the target scope.
      Shows: ancestor path → target scope → descendants (up to max_depth levels below target). *)
  let show_subtree ?(format = `Text) ?(show_times = false) ?(max_depth = None)
      ?(show_ancestors = true) t ~scope_id =
    (* Strategy:
       1. If show_ancestors=true: Build tree from root down to scope_id (no depth limit on ancestors)
       2. At scope_id: Apply max_depth limit for descendants

       We accomplish this by:
       - Getting the ancestor chain from root to scope_id
       - Building a "spine" tree following that path
       - At the target scope_id, use max_depth for its subtree *)

    if show_ancestors then (
      (* Get ancestor chain (scope_id -> parent -> ... -> root) *)
      let ancestors = Query.get_ancestors t.db ~scope_id in

      (* Build ancestor path tree by filtering to just the ancestor path.
         We build trees from roots, then we'll walk down to find the target scope. *)
      let roots = Query.get_root_entries t.db ~with_values:false in

      (* Find which root is the ancestor - it's the LAST element in ancestors list *)
      let root_scope = List.nth ancestors (List.length ancestors - 1) in
      let root_entry_opt = List.find_opt
        (fun e -> match e.Query.child_scope_id with
          | Some id -> id = root_scope
          | None -> false)
        roots
      in

      match root_entry_opt with
      | None ->
          Printf.eprintf "Error: Could not find root entry for scope %d (root scope is %d)\n"
            scope_id root_scope;
          exit 1
      | Some root_entry ->
          (* Build full tree from root, but with special max_depth handling:
             - No depth limit until we reach scope_id
             - At scope_id, apply max_depth *)
          let tree = Renderer.build_node t.db ?max_depth ~current_depth:0 root_entry in

          (* Output *)
          match format with
          | `Text ->
              Printf.printf "Subtree for scope %d (with ancestor path):\n\n" scope_id;
              let output =
                Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth:None
                  ~values_first_mode:true [ tree ]
              in
              print_string output
          | `Json ->
              let json = Renderer.render_tree_json ~max_depth:None [ tree ] in
              print_endline json
    ) else (
      (* Just show the subtree starting at scope_id *)
      (* First, find the header entry for this scope *)
      let all_entries = Query.get_entries t.db () in
      let header_entry_opt =
        List.find_opt
          (fun e -> match e.Query.child_scope_id with
            | Some id -> id = scope_id
            | None -> false)
          all_entries
      in

      match header_entry_opt with
      | None ->
          Printf.eprintf "Error: Could not find header entry for scope %d\n" scope_id;
          exit 1
      | Some header_entry ->
          let tree = Renderer.build_node t.db ?max_depth ~current_depth:0 header_entry in

          match format with
          | `Text ->
              Printf.printf "Subtree for scope %d:\n\n" scope_id;
              let output =
                Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth:None
                  ~values_first_mode:true [ tree ]
              in
              print_string output
          | `Json ->
              let json = Renderer.render_tree_json ~max_depth:None [ tree ] in
              print_endline json
    )

  (** Show detailed information for a specific entry *)
  let show_entry ?(format = `Text) t ~scope_id ~seq_id =
    let all_entries = Query.get_entries t.db () in
    match
      List.find_opt
        (fun e -> e.Query.scope_id = scope_id && e.Query.seq_id = seq_id)
        all_entries
    with
    | None ->
        Printf.eprintf "Entry (%d, %d) not found\n" scope_id seq_id;
        exit 1
    | Some entry -> (
        match format with
        | `Text ->
            Printf.printf "Entry (%d, %d):\n" scope_id seq_id;
            Printf.printf "  Type: %s\n" entry.entry_type;
            Printf.printf "  Message: %s\n" entry.message;
            (match entry.location with
            | Some loc -> Printf.printf "  Location: %s\n" loc
            | None -> ());
            (match entry.data with
            | Some d -> Printf.printf "  Data: %s\n" d
            | None -> ());
            (match entry.child_scope_id with
            | Some id -> Printf.printf "  Child Scope ID: %d\n" id
            | None -> ());
            Printf.printf "  Depth: %d\n" entry.depth;
            Printf.printf "  Log Level: %d\n" entry.log_level;
            Printf.printf "  Is Result: %b\n" entry.is_result;
            (match Renderer.elapsed_time entry with
            | Some elapsed ->
                Printf.printf "  Elapsed: %s\n" (Renderer.format_elapsed_ns elapsed)
            | None -> ())
        | `Json ->
            let json = Renderer.entry_to_json entry in
            print_endline json)

  (** Get ancestors of a scope (returns ALL paths from root to target due to DAG structure) *)
  let get_ancestors ?(format = `Text) t ~scope_id =
    let all_paths = Query.get_all_ancestor_paths t.db ~scope_id in

    (* Fetch header entries for ancestors *)
    let all_entries = Query.get_entries t.db () in
    let get_entry_for_scope ancestor_id =
      (* Find the header entry that creates this scope *)
      List.find_opt
        (fun e -> match e.Query.child_scope_id with
          | Some cid -> cid = ancestor_id
          | None -> false)
        all_entries
    in

    match format with
    | `Text ->
        if List.length all_paths = 1 then (
          Printf.printf "Ancestor path to scope %d:\n\n" scope_id;
          List.iter
            (fun ancestor_id ->
              match get_entry_for_scope ancestor_id with
              | Some entry ->
                  let loc_str = match entry.Query.location with
                    | Some loc -> Printf.sprintf " @ %s" loc
                    | None -> ""
                  in
                  Printf.printf "  #%d [%s] %s%s\n"
                    ancestor_id entry.Query.entry_type entry.Query.message loc_str
              | None -> ())
            (List.hd all_paths)
        ) else (
          (* Multiple paths - use Hasse diagram style rendering *)
          Printf.printf "Found %d ancestor paths to scope %d (Hasse diagram view):\n\n"
            (List.length all_paths) scope_id;

          (* Collect all unique scopes and their parents from the paths *)
          let all_scopes = Hashtbl.create 1000 in
          let scope_parents_in_paths = Hashtbl.create 1000 in

          List.iter (fun path ->
            List.iter (fun sid -> Hashtbl.replace all_scopes sid ()) path;
            (* Paths are root -> target, so path[i] is parent of path[i+1] *)
            for i = 0 to List.length path - 2 do
              let parent = List.nth path i in
              let child = List.nth path (i + 1) in
              let parents_set =
                match Hashtbl.find_opt scope_parents_in_paths child with
                | None -> Hashtbl.create 10
                | Some s -> s
              in
              Hashtbl.replace parents_set parent ();
              Hashtbl.replace scope_parents_in_paths child parents_set
            done
          ) all_paths;

          (* Build levels using topological sort (BFS from roots) *)
          let scope_level = Hashtbl.create 1000 in
          let roots = Hashtbl.fold (fun sid () acc ->
            match Hashtbl.find_opt scope_parents_in_paths sid with
            | None -> sid :: acc  (* No parents in paths = root *)
            | Some _ -> acc
          ) all_scopes [] in

          (* BFS to assign levels *)
          let queue = Queue.create () in
          List.iter (fun root ->
            Hashtbl.add scope_level root 0;
            Queue.add root queue
          ) roots;

          while not (Queue.is_empty queue) do
            let current = Queue.take queue in
            let current_level = Hashtbl.find scope_level current in

            (* Find all children (scopes that have current as parent) *)
            Hashtbl.iter (fun child parents_set ->
              if Hashtbl.mem parents_set current then
                match Hashtbl.find_opt scope_level child with
                | None ->
                    (* First time seeing this child - assign level *)
                    Hashtbl.add scope_level child (current_level + 1);
                    Queue.add child queue
                | Some existing_level ->
                    (* Seen before - use maximum level (furthest from root) *)
                    let new_level = max existing_level (current_level + 1) in
                    if new_level > existing_level then (
                      Hashtbl.replace scope_level child new_level;
                      Queue.add child queue
                    )
            ) scope_parents_in_paths
          done;

          (* Group by level *)
          let levels = Hashtbl.create 100 in
          Hashtbl.iter (fun sid level ->
            let level_scopes =
              match Hashtbl.find_opt levels level with
              | None -> []
              | Some lst -> lst
            in
            Hashtbl.replace levels level (sid :: level_scopes)
          ) scope_level;

          let max_level = Hashtbl.fold (fun _ level acc -> max level acc) scope_level 0 in

          (* Print each level *)
          for level = 0 to max_level do
            match Hashtbl.find_opt levels level with
            | None -> ()
            | Some scope_ids ->
                let sorted_ids = List.sort compare scope_ids in
                Printf.printf "Level %d (%s, %d scopes):\n"
                  level
                  (if level = 0 then "roots"
                   else if level = max_level then "target"
                   else "intermediate")
                  (List.length sorted_ids);

                List.iter (fun ancestor_id ->
                  match get_entry_for_scope ancestor_id with
                  | Some entry ->
                      let loc_str = match entry.Query.location with
                        | Some loc -> Printf.sprintf " @ %s" loc
                        | None -> ""
                      in
                      Printf.printf "  #%d [%s] %s%s\n"
                        ancestor_id entry.Query.entry_type entry.Query.message loc_str
                  | None ->
                      Printf.printf "  #%d (no entry found)\n" ancestor_id
                ) sorted_ids;

                Printf.printf "\n"
          done
        )
    | `Json ->
        let json_paths =
          List.map
            (fun path ->
              let json_entries =
                List.filter_map
                  (fun ancestor_id ->
                    match get_entry_for_scope ancestor_id with
                    | Some entry ->
                        Some (Printf.sprintf
                          {|{"scope_id": %d, "entry_type": "%s", "message": "%s", "location": %s}|}
                          ancestor_id
                          entry.Query.entry_type
                          (String.escaped entry.Query.message)
                          (match entry.Query.location with
                            | Some loc -> Printf.sprintf "\"%s\"" (String.escaped loc)
                            | None -> "null"))
                    | None -> None)
                  path
              in
              Printf.sprintf "[ %s ]" (String.concat ", " json_entries))
            all_paths
        in
        if List.length all_paths = 1 then
          (* Single path - return as array *)
          print_endline (List.hd json_paths)
        else
          (* Multiple paths - return as array of arrays *)
          Printf.printf "[ %s ]\n" (String.concat ", " json_paths)

  (** Get parent of a scope *)
  let get_parent ?(format = `Text) t ~scope_id =
    match Query.get_parent_id t.db ~scope_id with
    | None ->
        (match format with
        | `Text -> Printf.printf "Scope %d has no parent (is root)\n" scope_id
        | `Json -> print_endline "null")
    | Some parent_id ->
        (match format with
        | `Text -> Printf.printf "Parent of scope %d: %d\n" scope_id parent_id
        | `Json -> Printf.printf "%d\n" parent_id)

  (** Get immediate children of a scope *)
  let get_children ?(format = `Text) t ~scope_id =
    let children = Query.get_scope_children t.db ~parent_scope_id:scope_id in
    let child_scope_ids =
      List.filter_map
        (fun e ->
          match e.Query.child_scope_id with Some id -> Some id | None -> None)
        children
      |> List.sort_uniq compare
    in
    match format with
    | `Text ->
        Printf.printf "Child scopes of %d: [ %s ]\n" scope_id
          (String.concat ", " (List.map string_of_int child_scope_ids))
    | `Json ->
        Printf.printf "[ %s ]\n"
          (String.concat ", " (List.map string_of_int child_scope_ids))

  (** Search and show only entries at a specific depth on paths to matches.
      This gives a TUI-like summary view - shows only the depth-N ancestors
      of matching entries, filtered by quiet_path. *)
  let search_at_depth ?(quiet_path = None) ?(format = `Text) ?(show_times = false)
      ~depth t ~pattern =
    (* Run search to get results hash table *)
    let completed_ref = ref false in
    let results_table = Hashtbl.create 1024 in
    Query.populate_search_results t.db_path ~search_term:pattern ~quiet_path
      ~search_order:Query.AscendingIds ~completed_ref ~results_table;

    (* Get all entries and filter to those in results *)
    let all_entries = Query.get_entries t.db () in
    let filtered_entries =
      List.filter
        (fun e -> Hashtbl.mem results_table (e.Query.scope_id, e.Query.seq_id))
        all_entries
    in

    (* Filter to only entries at the specified depth *)
    let depth_entries =
      List.filter (fun e -> e.Query.depth = depth) filtered_entries
      |> List.sort_uniq (fun a b -> compare a.Query.scope_id b.Query.scope_id)
    in

    (* For deduplication, keep only unique scope_ids at this depth *)
    let seen = Hashtbl.create 256 in
    let unique_entries =
      List.filter
        (fun e ->
          match e.Query.child_scope_id with
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
    match format with
    | `Text ->
        Printf.printf
          "Found %d matches for pattern '%s', showing %d unique entries at depth %d:\n\n"
          match_count pattern (List.length unique_entries) depth;
        List.iter
          (fun entry ->
            Printf.printf "#%d [%s] %s" entry.Query.scope_id entry.entry_type
              entry.message;
            (match entry.location with
            | Some loc -> Printf.printf " @ %s" loc
            | None -> ());
            (if show_times then
               match Renderer.elapsed_time entry with
               | Some elapsed ->
                   Printf.printf " <%s>" (Renderer.format_elapsed_ns elapsed)
               | None -> ());
            Printf.printf "\n")
          unique_entries
    | `Json ->
        let json = Renderer.render_entries_json unique_entries in
        print_endline json
end
