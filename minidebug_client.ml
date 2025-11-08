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
    db_file : string;
  }

  type stats = {
    total_entries : int;
    total_values : int;
    unique_values : int;
    dedup_percentage : float;
    database_size_kb : int;
  }

  type search_order =
    | AscendingIds
      (* ORDER BY scope_id ASC: newest-neg → oldest-neg → oldest-pos → newest-pos *)
    | DescendingIds
  (* ORDER BY scope_id DESC: newest-pos → oldest-pos → oldest-neg → newest-neg *)

  (** Module signature for Query operations - all functions access module-level DB connections *)
  module type S = sig
    val get_runs : unit -> run_info list
    val get_latest_run_id : unit -> int option
    val get_run_by_name : run_name:string -> run_info option
    val get_stats : unit -> stats
    val search_entries : pattern:string -> entry list
    val find_entry : scope_id:int -> seq_id:int -> entry option
    val find_scope_header : scope_id:int -> entry option
    val get_entries_for_scopes : scope_ids:int list -> entry list
    val get_entries_from_results : results_table:(int * int, bool) Hashtbl.t -> entry list
    val get_root_entries : with_values:bool -> entry list
    val get_scope_children : parent_scope_id:int -> entry list
    val has_children : parent_scope_id:int -> bool
    val get_parent_ids : scope_id:int -> int list
    val get_parent_id : scope_id:int -> int option
    val get_all_ancestor_paths : scope_id:int -> int list list
    val get_ancestors : scope_id:int -> int list
    val get_max_scope_id : unit -> int
    val lowest_common_ancestor : int list -> int option
    val get_root_scope : int -> int
    val find_matching_paths : patterns:string list -> (int * int list) list
    val extract_along_path :
      start_scope_id:int -> extraction_path:string list -> int option
    val populate_search_results :
      search_term:string ->
      quiet_path:string option ->
      search_order:search_order ->
      completed_ref:bool ref ->
      results_table:(int * int, bool) Hashtbl.t ->
      unit
    val populate_extract_search_results :
      search_path:string list ->
      extraction_path:string list ->
      quiet_path:string option ->
      completed_ref:bool ref ->
      results_table:(int * int, bool) Hashtbl.t ->
      unit
  end

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
          "SELECT run_id, run_name, timestamp, elapsed_ns, command_line, db_file FROM runs \
           ORDER BY run_id DESC"
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
                db_file = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 5);
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

  (** Functor creating Query module with connections to main DB and metadata DB *)
  module Make (Args : sig
    val db_path : string
  end) : S = struct
    (* Open main database connection *)
    let db = Sqlite3.db_open ~mode:`READONLY Args.db_path

    (* Derive and open metadata database connection *)
    let meta_db =
      let normalized = normalize_db_path Args.db_path in
      let base = Filename.remove_extension normalized in
      let meta_path = Printf.sprintf "%s_meta.db" base in
      if Sys.file_exists meta_path then Some (Sqlite3.db_open ~mode:`READONLY meta_path)
      else None

    (* Store db_path for Domain.spawn use cases *)
    let db_path = Args.db_path

    (** Get all runs - uses metadata DB connection *)
    let get_runs () =
      match meta_db with
      | None -> []
      | Some _mdb ->
          let normalized = normalize_db_path db_path in
          let base = Filename.remove_extension normalized in
          let meta_path = Printf.sprintf "%s_meta.db" base in
          get_runs_from_meta_db meta_path

    (** Get latest run ID from metadata database *)
    let get_latest_run_id =
      match meta_db with
      | None -> fun () -> None
      | Some mdb ->
          let stmt = Sqlite3.prepare mdb "SELECT MAX(run_id) FROM runs" in
          fun () ->
            Sqlite3.reset stmt |> ignore;
            let run_id =
              match Sqlite3.step stmt with
              | Sqlite3.Rc.ROW -> (
                  match Sqlite3.column stmt 0 with
                  | Sqlite3.Data.INT id -> Some (Int64.to_int id)
                  | _ -> None)
              | _ -> None
            in
            run_id

    (** Get run by name from metadata database *)
    let get_run_by_name =
      match meta_db with
      | None -> fun ~run_name:_ -> None
      | Some mdb ->
          let stmt =
            Sqlite3.prepare mdb
              "SELECT run_id, timestamp, elapsed_ns, command_line, run_name, db_file FROM \
               runs WHERE run_name = ?"
          in
          fun ~run_name ->
            Sqlite3.reset stmt |> ignore;
            Sqlite3.bind_text stmt 1 run_name |> ignore;
            let result =
              match Sqlite3.step stmt with
              | Sqlite3.Rc.ROW ->
                  let run_id = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0) in
                  let timestamp = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 1) in
                  let elapsed_ns = Sqlite3.Data.to_int_exn (Sqlite3.column stmt 2) in
                  let command_line = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 3) in
                  let run_name_opt =
                    match Sqlite3.column stmt 4 with
                    | Sqlite3.Data.TEXT s -> Some s
                    | _ -> None
                  in
                  let db_file = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 5) in
                  Some
                    { run_id; timestamp; elapsed_ns; command_line; run_name = run_name_opt; db_file }
              | _ -> None
            in
            result

    (** Get database statistics *)
    let get_stats =
      let stmt =
        Sqlite3.prepare db
          {|
        SELECT
          (SELECT COUNT(*) FROM entries) as total_entries,
          (SELECT COUNT(*) FROM value_atoms) as total_values,
          (SELECT COUNT(DISTINCT value_hash) FROM value_atoms) as unique_values
      |}
      in
      fun () ->
        Sqlite3.reset stmt |> ignore;
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
        stats

    (** Search entries by GLOB pattern (uses SQLite's GLOB operator for efficiency) *)
    let search_entries =
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
        WHERE m.value_content GLOB ? OR l.value_content GLOB ? OR d.value_content GLOB ?
        ORDER BY e.scope_id, e.seq_id
      |}
      in
      let stmt = Sqlite3.prepare db query in
      fun ~pattern ->
        (* Convert pattern to GLOB format if needed - for now use simple wildcard wrapping *)
        let glob_pattern = "*" ^ pattern ^ "*" in
        Sqlite3.reset stmt |> ignore;
        Sqlite3.bind_text stmt 1 glob_pattern |> ignore;
        Sqlite3.bind_text stmt 2 glob_pattern |> ignore;
        Sqlite3.bind_text stmt 3 glob_pattern |> ignore;
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
        List.rev !entries

    (** Find a specific entry by (scope_id, seq_id) *)
    let find_entry =
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
      WHERE e.scope_id = ? AND e.seq_id = ?
      LIMIT 1
    |}
    in
    let stmt = Sqlite3.prepare db query in
    fun ~scope_id ~seq_id ->
    Sqlite3.reset stmt |> ignore;
    Sqlite3.bind_int stmt 1 scope_id |> ignore;
    Sqlite3.bind_int stmt 2 seq_id |> ignore;
    let result =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          Some
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
      | _ -> None
    in
    result

    (** Find the header entry that creates a given scope (child_scope_id = scope_id) *)
    let find_scope_header =
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
      WHERE e.child_scope_id = ?
      LIMIT 1
    |}
    in
    let stmt = Sqlite3.prepare db query in
    fun ~scope_id ->
    Sqlite3.reset stmt |> ignore;
    Sqlite3.bind_int stmt 1 scope_id |> ignore;
    let result =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          Some
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
      | _ -> None
    in
    result

    (** Get entries for a list of scope_ids (useful for filtering by ancestor paths) *)
    let get_entries_for_scopes ~scope_ids =
    if scope_ids = [] then []
    else
      let placeholders = String.concat "," (List.map (fun _ -> "?") scope_ids) in
      let query =
        Printf.sprintf
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
      WHERE e.scope_id IN (%s)
      ORDER BY e.scope_id, e.seq_id
    |}
          placeholders
      in
      let stmt = Sqlite3.prepare db query in
      List.iteri (fun i scope_id -> Sqlite3.bind_int stmt (i + 1) scope_id |> ignore) scope_ids;
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

    (** Get entries from a results hashtable (as returned by populate_search_results).
        This is much more efficient than get_entries() + filter for large databases. *)
    let get_entries_from_results ~results_table =
      (* Extract all (scope_id, seq_id) pairs from hashtable *)
      let pairs =
        Hashtbl.fold (fun (scope_id, seq_id) _ acc -> (scope_id, seq_id) :: acc) results_table []
      in
      if pairs = [] then []
      else
        (* Group by scope_id for efficient batch querying *)
        let scope_ids = List.map fst pairs |> List.sort_uniq compare in
        let all_entries = get_entries_for_scopes ~scope_ids in
        (* Filter to only those in results_table *)
        List.filter (fun e -> Hashtbl.mem results_table (e.scope_id, e.seq_id)) all_entries

    (** Get maximum scope_id for a run *)
    let get_max_scope_id =
    let stmt = Sqlite3.prepare db "SELECT MAX(scope_id) FROM entries" in
    fun () ->
    Sqlite3.reset stmt |> ignore;
    let max_id =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW -> (
          match Sqlite3.column stmt 0 with
          | Sqlite3.Data.INT id -> Some (Int64.to_int id)
          | _ -> None)
      | _ -> None
    in
    Option.value ~default:0 max_id

    (** Get only root entries efficiently - roots are those with scope_id=0 *)
    let get_root_entries =
    (* Prepare both queries upfront *)
    let query_with_values =
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
    in
    let query_without_values =
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
    let stmt_with_values = Sqlite3.prepare db query_with_values in
    let stmt_without_values = Sqlite3.prepare db query_without_values in
    fun ~with_values ->
    let stmt = if with_values then stmt_with_values else stmt_without_values in
    Sqlite3.reset stmt |> ignore;

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
    List.rev !entries

    (** Check if an entry has any children (efficient query) *)
    let has_children =
    let query =
      {|
      SELECT 1
      FROM entries
      WHERE scope_id = ?
      LIMIT 1
    |}
    in
    let stmt = Sqlite3.prepare db query in
    fun ~parent_scope_id ->
    Sqlite3.reset stmt |> ignore;
    Sqlite3.bind_int stmt 1 parent_scope_id |> ignore;
    let has_child = match Sqlite3.step stmt with Sqlite3.Rc.ROW -> true | _ -> false in
    has_child

    (** Get all parent scope_ids for a given entry. Returns empty list if no parents
        (root entry). Due to SexpCache deduplication, an entry can have multiple parents
        (DAG structure). *)
    let get_parent_ids =
    let query =
      {|
      SELECT parent_id
      FROM entry_parents
      WHERE scope_id = ?
    |}
    in
    let stmt = Sqlite3.prepare db query in
    fun ~scope_id ->
    Sqlite3.reset stmt |> ignore;
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
    List.rev !parent_ids  (* Preserve insertion order *)

    (** Get first parent scope_id for a given entry (for single-path operations).
        Returns None if no parent (root entry). *)
    let get_parent_id ~scope_id =
      match get_parent_ids ~scope_id with
      | [] -> None
      | first :: _ -> Some first

    let get_scope_children =
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
    fun ~parent_scope_id ->
    Sqlite3.reset stmt |> ignore;
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
    List.rev !entries

  (** Search ordering strategy. Note: scope_id temporal order is split by sign:
      - Positive IDs: 1 (oldest), 2, 3, ... 60311 (newest) - increasing = later
      - Negative IDs: -1 (oldest), -2, -3, ... -17774560 (newest) - more negative = later

      Neither ordering is chronological due to the sign split! *)

    (** Populate search results hash table with entries matching search term. This is meant
      to run in a background Domain. Opens its own DB connection. Sets completed_ref to
      true when finished. Propagates highlights to ancestors unless quiet_path matches.

      Implementation: Interleaves stepping through the main search query with issuing
      ancestor lookup queries (via get_parent_id). SQLite handles multiple active prepared
      statements without issue. Propagates highlights immediately upon finding each match
      for real-time UI updates.

      Writes results to shared hash table (lock-free concurrent writes are safe). *)
    (* Cached prepared statement for streaming search queries *)
    let get_search_stream_stmt =
      let ascending_stmt = ref None in
      let descending_stmt = ref None in
      fun ~search_order ->
        let order_clause =
          match search_order with
          | AscendingIds ->
              "ORDER BY e.scope_id ASC, e.seq_id ASC"
          | DescendingIds ->
              "ORDER BY e.scope_id DESC, e.seq_id ASC"
        in
        let stmt_ref = match search_order with
          | AscendingIds -> ascending_stmt
          | DescendingIds -> descending_stmt
        in
        match !stmt_ref with
        | Some stmt -> stmt
        | None ->
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
            let stmt = Sqlite3.prepare db query in
            stmt_ref := Some stmt;
            stmt

    (* Cached prepared statement for fetching scope entry by child_scope_id *)
    let get_scope_entry_stmt =
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
      fun ~scope_id ->
        Sqlite3.reset stmt |> ignore;
        Sqlite3.bind_int stmt 1 scope_id |> ignore;
        stmt

    let populate_search_results ~search_term ~quiet_path ~search_order
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

      (* Use global database connection (safe when called from Domain.spawn since each
         Domain instantiates its own Query.Make functor with isolated state) *)
      log_debug (Printf.sprintf "Using global database connection for: %s" db_path);

      try
        Hashtbl.clear results_table;

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

        (* Get cached prepared statement for streaming *)
        let query_stmt = get_search_stream_stmt ~search_order in
        Sqlite3.reset query_stmt |> ignore;

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
              let stmt = get_scope_entry_stmt ~scope_id in
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
                  let parent_ids = get_parent_ids ~scope_id:current_scope_id in
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
        log_debug
          (Printf.sprintf
             "Search complete. Processed %d entries, found %d matches, propagated %d \
              ancestors"
             !processed_count !match_count !propagation_count);
        log_debug
          (Printf.sprintf "Scope cache size: %d, Total results: %d"
             (Hashtbl.length scope_by_id)
             (Hashtbl.length results_table));

        log_debug "Search completed successfully";

        (* Signal completion via shared memory *)
        completed_ref := true
      with exn ->
        log_debug
          (Printf.sprintf "ERROR: %s\n%s" (Printexc.to_string exn)
             (Printexc.get_backtrace ()));
        (* Still mark as completed even on error *)
        completed_ref := true

    (** Get ancestor entry IDs from a given entry up to root, following the first parent
        at each level. Returns list in order [scope_id; parent; grandparent; ...; root].

        Note: Due to SexpCache deduplication, entries can have multiple parents (DAG
        structure). This function returns ONE path through the DAG by always following
        the first parent. For operations requiring all paths, use get_all_ancestor_paths. *)
    let get_ancestors ~scope_id =
      let rec collect_ancestors acc current_id =
        match get_parent_id ~scope_id:current_id with
        | None -> List.rev acc (* Reached root *)
        | Some parent_id -> collect_ancestors (parent_id :: acc) parent_id
      in
      collect_ancestors [ scope_id ] scope_id

    (** Get ALL ancestor paths from a given entry to root(s). Returns list of paths, where
        each path is in order [scope_id; parent; grandparent; ...; root].

        Due to SexpCache deduplication, entries can have multiple parents (DAG structure).
        This function explores all paths through the DAG and returns them all. *)
    let get_all_ancestor_paths ~scope_id =
      let rec collect_all_paths current_id =
        let parent_ids = get_parent_ids ~scope_id:current_id in
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
    let lowest_common_ancestor scope_ids =
      match scope_ids with
      | [] -> None
      | [ single ] -> Some single
      | _ :: _ ->
          (* Get ancestor chains for all scopes (from root to scope) *)
          let ancestor_chains = List.map (fun id -> get_ancestors ~scope_id:id) scope_ids in

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
    let get_root_scope scope_id =
      let rec find_root current_id =
        match get_parent_id ~scope_id:current_id with
        | None -> current_id (* No parent means this is the root *)
        | Some parent_id -> find_root parent_id
      in
      find_root scope_id

  (** Check if an entry matches a pattern (substring match on message or data) *)
  let entry_matches_pattern entry pattern =
    let contains s =
      String.length s > 0
      && (Re.Str.string_match (Re.Str.regexp_string pattern) s 0
         ||
         try
           let _ = Re.Str.search_forward (Re.Str.regexp_string pattern) s 0 in
           true
         with Not_found -> false)
    in
    contains entry.message || (match entry.data with Some d -> contains d | None -> false)

    (** Check if a scope entry (header) matches a pattern by looking at its message field *)
    let _scope_entry_matches_pattern =
    (* Get the header entry that creates this scope *)
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
    fun ~scope_id ~pattern ->
    Sqlite3.reset stmt |> ignore;
    Sqlite3.bind_int stmt 1 scope_id |> ignore;
    let result =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW ->
          let message =
            match Sqlite3.column stmt 4 with Sqlite3.Data.TEXT s -> s | _ -> ""
          in
          let data =
            match Sqlite3.column stmt 6 with Sqlite3.Data.TEXT s -> Some s | _ -> None
          in
          let entry =
            {
              scope_id;
              seq_id = 0;
              child_scope_id = None;
              depth = 0;
              message;
              location = None;
              data;
              elapsed_start_ns = 0;
              elapsed_end_ns = None;
              is_result = false;
              log_level = 0;
              entry_type = "";
            }
          in
          entry_matches_pattern entry pattern
      | _ -> false
    in
    result

    (** Find all paths in the DAG matching a sequence of patterns.
        Returns list of (shared_scope_id, ancestor_path) tuples, where:
        - shared_scope_id is the scope_id of the last matching node (the "shared node")
        - ancestor_path is the list of scope_ids from root to shared_scope_id

        Algorithm:
        1. Reverse the search path for convenience
        2. Use the last pattern (first of reversed) to find initial candidates via populate_search_results
        3. For each candidate, climb up the DAG verifying parent patterns match
        4. Return those that successfully match the full path *)
    let find_matching_paths ~patterns =
      if patterns = [] then failwith "find_matching_paths: patterns list cannot be empty";

      (* Open database connection *)
      let local_db = Sqlite3.db_open ~mode:`READONLY db_path in

      (* Local helpers using local_db connection *)
      let local_get_parent_ids ~scope_id =
        let query =
          {|
          SELECT parent_id
          FROM entry_parents
          WHERE scope_id = ?
        |}
        in
        let stmt = Sqlite3.prepare local_db query in
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
      in

      let local_get_parent_id ~scope_id =
        match local_get_parent_ids ~scope_id with
        | [] -> None
        | first :: _ -> Some first
      in

      let local_get_ancestors ~scope_id =
        let rec collect_ancestors acc current_id =
          match local_get_parent_id ~scope_id:current_id with
          | None -> List.rev acc (* Reached root *)
          | Some parent_id -> collect_ancestors (parent_id :: acc) parent_id
        in
        collect_ancestors [ scope_id ] scope_id
      in

      let local_scope_entry_matches_pattern ~scope_id ~pattern =
        (* Get the header entry that creates this scope *)
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
        let stmt = Sqlite3.prepare local_db query in
        Sqlite3.bind_int stmt 1 scope_id |> ignore;
        let result =
          match Sqlite3.step stmt with
          | Sqlite3.Rc.ROW ->
              let message =
                match Sqlite3.column stmt 4 with Sqlite3.Data.TEXT s -> s | _ -> ""
              in
              let data =
                match Sqlite3.column stmt 6 with Sqlite3.Data.TEXT s -> Some s | _ -> None
              in
              let entry =
                {
                  scope_id;
                  seq_id = 0;
                  child_scope_id = None;
                  depth = 0;
                  message;
                  location = None;
                  data;
                  elapsed_start_ns = 0;
                  elapsed_end_ns = None;
                  is_result = false;
                  log_level = 0;
                  entry_type = "";
                }
              in
              entry_matches_pattern entry pattern
          | _ -> false
        in
        Sqlite3.finalize stmt |> ignore;
        result
      in

      (* Reverse the search path - we'll match from leaf to root *)
      let reversed_patterns = List.rev patterns in
      let last_pattern = List.hd reversed_patterns in
      let ancestor_patterns = List.tl reversed_patterns in

      (* Use populate_search_results to find initial candidates matching the last pattern *)
      let completed_ref = ref false in
      let results_table = Hashtbl.create 1024 in
      populate_search_results ~search_term:last_pattern ~quiet_path:None
        ~search_order:AscendingIds ~completed_ref ~results_table;

    (* Extract scope_ids that actually match (not just propagated ancestors) *)
    let candidate_scope_ids =
      Hashtbl.fold
        (fun (scope_id, _seq_id) is_match acc ->
          if is_match then scope_id :: acc else acc)
        results_table []
      |> List.sort_uniq compare
    in

      (* For each candidate, try to climb up the DAG matching the ancestor patterns.

         The candidate_id is the scope_id where the match was found. This could be:
         1. A scope created by an entry matching the last pattern (if it's a scope header)
         2. A scope containing a value entry matching the last pattern (if it's a value)

         In case (1), we check if this scope's parent matches the next pattern.
         In case (2), we check if this scope itself matches the next pattern (since the scope
                     contains the matching value). *)
      let rec climb_up_dag current_scope_id remaining_patterns ~first_is_value =
        match remaining_patterns with
        | [] ->
            (* Successfully matched all patterns - get full ancestor path *)
            let full_path = local_get_ancestors ~scope_id:current_scope_id in
            [ (current_scope_id, full_path) ]
        | pattern :: rest_patterns ->
            if first_is_value then
              (* The last match was a value inside current_scope_id, so check if
                 current_scope_id itself was created by an entry matching the pattern *)
              if local_scope_entry_matches_pattern ~scope_id:current_scope_id ~pattern then
                (* This scope matches the pattern *)
                if rest_patterns = [] then
                  (* No more patterns - we've matched everything! *)
                  let full_path = local_get_ancestors ~scope_id:current_scope_id in
                  [ (current_scope_id, full_path) ]
                else
                  (* More patterns remain - climb to parents *)
                  let parent_ids = local_get_parent_ids ~scope_id:current_scope_id in
                  List.concat_map
                    (fun parent_id -> climb_up_dag parent_id rest_patterns ~first_is_value:false)
                    parent_ids
              else []
            else
              (* The last match was a scope, so check if current scope matches the pattern *)
              if local_scope_entry_matches_pattern ~scope_id:current_scope_id ~pattern then
                (* This scope matches the pattern *)
                if rest_patterns = [] then
                  (* No more patterns - we've matched everything! *)
                  let full_path = local_get_ancestors ~scope_id:current_scope_id in
                  [ (current_scope_id, full_path) ]
                else
                  (* More patterns remain - climb to parents *)
                  let parent_ids = local_get_parent_ids ~scope_id:current_scope_id in
                  List.concat_map
                    (fun parent_id -> climb_up_dag parent_id rest_patterns ~first_is_value:false)
                    parent_ids
              else []
      in

      (* Try climbing from each candidate. We need to determine if each candidate
         represents a scope created by the match, or a scope containing a value match. *)
      let results =
        List.concat_map
          (fun candidate_id ->
            (* Check if this candidate scope was created by an entry matching the last pattern,
               or if it just contains a value matching the last pattern *)
            let is_value_match =
              not (local_scope_entry_matches_pattern ~scope_id:candidate_id ~pattern:last_pattern)
            in
            climb_up_dag candidate_id ancestor_patterns ~first_is_value:is_value_match)
          candidate_scope_ids
      in

      Sqlite3.db_close local_db |> ignore;
      results

    (** Extract along a path starting from a given scope.
        The extraction_path should have already had its first element removed
        (since it matches the search path's shared element).
        Returns Some scope_id if the path is successfully traversed, None otherwise.

        Special case: If the path ends at a value entry (child_scope_id = None),
        returns the current scope_id (parent of the value). *)
    let extract_along_path ~start_scope_id ~extraction_path =
      let rec traverse current_scope_id = function
        | [] -> Some current_scope_id (* Reached the end of extraction path *)
        | [ last_pattern ] ->
            (* Last element in path - can be a value or a scope *)
            let children = get_scope_children ~parent_scope_id:current_scope_id in
            let matching_child =
              List.find_opt (fun entry -> entry_matches_pattern entry last_pattern) children
            in
            (match matching_child with
            | Some child -> (
                match child.child_scope_id with
                | Some child_scope -> Some child_scope (* Descend into child scope *)
                | None -> Some current_scope_id (* Value entry - return current scope *))
            | None -> None)
        | pattern :: rest ->
            (* Not the last element - must be a scope to continue *)
            let children = get_scope_children ~parent_scope_id:current_scope_id in
            let matching_child =
              List.find_opt (fun entry -> entry_matches_pattern entry pattern) children
            in
            (match matching_child with
            | Some child when Option.is_some child.child_scope_id ->
                (* Found a matching header - continue traversal *)
                traverse (Option.get child.child_scope_id) rest
            | _ -> None (* No matching child found, or child is a value *))
      in
      traverse start_scope_id extraction_path

    (** Populate search results for extract-search operation: find matching search paths,
        extract along extraction paths, and highlight with deduplication based on
        extracted scope_id. Only the first occurrence (smallest shared_scope_id) for each
        unique extracted_scope_id is highlighted.

        Algorithm:
        1. Find all paths matching search_path using find_matching_paths
        2. For each match, extract along extraction_path from the shared node
        3. Track extracted_scope_id -> smallest_shared_scope_id for deduplication
        4. Highlight shared node and ancestors (starting from shared node's scope_id)
        5. Apply quiet_path filtering during ancestor propagation *)
    let populate_extract_search_results ~search_path ~extraction_path ~quiet_path
        ~completed_ref ~results_table =
      let log_debug msg =
        ignore msg
        (* Uncomment to enable debug logging: *)
        (* try let oc = open_out_gen [Open_append;
           Open_creat] 0o644 "/tmp/minidebug_extract_search.log" in Printf.fprintf oc
           "[%s] %s\n" (Unix.gettimeofday () |> string_of_float) msg; close_out oc with _ -> () *)
      in

      Printexc.record_backtrace true;
      log_debug
        (Printf.sprintf "Starting extract search: search_path=%s, extraction_path=%s"
           (String.concat "," search_path) (String.concat "," extraction_path));

      try
        Hashtbl.clear results_table;

        (* Validate inputs *)
        (match (search_path, extraction_path) with
        | [], _ | _, [] ->
            log_debug "ERROR: Empty paths provided";
            completed_ref := true;
            ()
        | s :: _, e :: _ when s <> e ->
            log_debug
              (Printf.sprintf
                 "ERROR: Paths must start with same pattern (got '%s' vs '%s')" s e);
            completed_ref := true;
            ()
        | _ ->
            (* Find all matching paths *)
            let matching_paths = find_matching_paths ~patterns:search_path in
            log_debug (Printf.sprintf "Found %d matching paths" (List.length matching_paths));

            (* Extract tail of extraction path (removing shared first element) *)
            let extraction_tail =
              match extraction_path with _ :: tail -> tail | [] -> []
            in

            (* Track: extracted_scope_id -> smallest_shared_scope_id *)
            let extracted_to_first_shared = Hashtbl.create 64 in

            (* Track: shared_scope_id -> list of highlighted (scope_id, seq_id) pairs *)
            let shared_to_highlighted = Hashtbl.create 64 in

            (* Compile quiet_path regex once *)
            let quiet_path_regex = Option.map Re.Str.regexp_string quiet_path in

            (* Track propagated ancestors to avoid duplicates *)
            let propagated = Hashtbl.create 64 in

            (* Helper to check if entry matches quiet_path *)
            let matches_quiet_path entry =
              match quiet_path_regex with
              | None -> false
              | Some qp_regex ->
                  let contains_match haystack regex =
                    try
                      let _ = Re.Str.search_forward regex haystack 0 in
                      true
                    with Not_found -> false
                  in
                  contains_match entry.message qp_regex
                  || (match entry.location with
                     | Some loc -> contains_match loc qp_regex
                     | None -> false)
                  || (match entry.data with
                     | Some d -> contains_match d qp_regex
                     | None -> false)
            in

            (* Helper to insert an entry into results table *)
            let insert_entry ?(is_match = false) entry =
              Hashtbl.replace results_table (entry.scope_id, entry.seq_id) is_match
            in

            (* Helper to get scope entry by scope_id (header that creates this scope) *)
            let get_scope_entry scope_id =
              let stmt = get_scope_entry_stmt ~scope_id in
              match Sqlite3.step stmt with
              | Sqlite3.Rc.ROW ->
                  Some
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
                      entry_type =
                        (match Sqlite3.column stmt 11 with
                        | Sqlite3.Data.TEXT s -> s
                        | _ -> "");
                    }
              | _ -> None
            in

            (* Helper to propagate highlights from shared node and its ancestors *)
            let highlight_shared_and_ancestors shared_scope_id =
              let highlighted_entries = ref [] in

              (* Get the shared node entry *)
              match get_scope_entry shared_scope_id with
              | None ->
                  log_debug
                    (Printf.sprintf "WARNING: Could not find entry for shared_scope_id=%d"
                       shared_scope_id)
              | Some shared_entry ->
                  (* Highlight the shared node itself *)
                  insert_entry ~is_match:true shared_entry;
                  highlighted_entries :=
                    (shared_entry.scope_id, shared_entry.seq_id) :: !highlighted_entries;
                  log_debug
                    (Printf.sprintf "Highlighted shared node: scope_id=%d, seq_id=%d"
                       shared_entry.scope_id shared_entry.seq_id);

                  (* Propagate to ancestors starting from shared node's parent (scope_id) *)
                  let rec propagate_to_parent current_scope_id =
                    let parent_ids = get_parent_ids ~scope_id:current_scope_id in
                    if parent_ids = [] then
                      log_debug
                        (Printf.sprintf "  propagate: scope_id=%d has no parents (reached root)"
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
                            match get_scope_entry parent_id with
                            | Some parent_entry when matches_quiet_path parent_entry ->
                                (* Parent matches quiet_path, stop propagation *)
                                Hashtbl.add propagated parent_id ();
                                log_debug
                                  (Printf.sprintf
                                     "  propagate: parent_id=%d matches quiet_path, stopping"
                                     parent_id)
                            | Some parent_entry ->
                                (* Parent doesn't match quiet_path - highlight and continue *)
                                Hashtbl.add propagated parent_id ();
                                insert_entry ~is_match:false parent_entry;
                                highlighted_entries :=
                                  (parent_entry.scope_id, parent_entry.seq_id)
                                  :: !highlighted_entries;
                                log_debug
                                  (Printf.sprintf
                                     "  propagate: highlighted parent_id=%d" parent_id);
                                propagate_to_parent parent_id
                            | None ->
                                log_debug
                                  (Printf.sprintf
                                     "  propagate: parent_id=%d not found in database" parent_id)))
                        parent_ids
                  in
                  propagate_to_parent shared_entry.scope_id;

                  (* Store highlighted entries for potential cleanup *)
                  Hashtbl.add shared_to_highlighted shared_scope_id !highlighted_entries
            in

            (* Process each matching path *)
            List.iter
              (fun (shared_scope_id, _ancestor_path) ->
                log_debug (Printf.sprintf "Processing shared_scope_id=%d" shared_scope_id);

                (* Extract along extraction path *)
                match
                  extract_along_path ~start_scope_id:shared_scope_id
                    ~extraction_path:extraction_tail
                with
                | None ->
                    log_debug
                      (Printf.sprintf
                         "  Extraction failed for shared_scope_id=%d (path not found)"
                         shared_scope_id)
                | Some extracted_scope_id ->
                    log_debug
                      (Printf.sprintf "  Extracted to scope_id=%d" extracted_scope_id);

                    (* Check deduplication *)
                    (match Hashtbl.find_opt extracted_to_first_shared extracted_scope_id with
                    | Some prev_shared when prev_shared <= shared_scope_id ->
                        (* Already seen with smaller or equal shared_scope_id, skip *)
                        log_debug
                          (Printf.sprintf
                             "  Skipping: already have smaller shared_scope_id=%d for \
                              extracted=%d"
                             prev_shared extracted_scope_id)
                    | Some prev_shared ->
                        (* Found smaller shared_scope_id, remove old highlights *)
                        log_debug
                          (Printf.sprintf
                             "  Replacing: found smaller shared_scope_id=%d (prev=%d) for \
                              extracted=%d"
                             shared_scope_id prev_shared extracted_scope_id);
                        (match Hashtbl.find_opt shared_to_highlighted prev_shared with
                        | Some old_entries ->
                            List.iter (Hashtbl.remove results_table) old_entries;
                            Hashtbl.remove shared_to_highlighted prev_shared;
                            log_debug
                              (Printf.sprintf "  Removed %d old highlights"
                                 (List.length old_entries))
                        | None -> ());
                        Hashtbl.replace extracted_to_first_shared extracted_scope_id
                          shared_scope_id;
                        (* Clear propagated for this path since we're re-highlighting *)
                        Hashtbl.clear propagated;
                        highlight_shared_and_ancestors shared_scope_id
                    | None ->
                        (* First occurrence *)
                        log_debug
                          (Printf.sprintf "  First occurrence for extracted=%d"
                             extracted_scope_id);
                        Hashtbl.add extracted_to_first_shared extracted_scope_id shared_scope_id;
                        highlight_shared_and_ancestors shared_scope_id))
              matching_paths;

            log_debug
              (Printf.sprintf "Extract search complete: %d unique extractions, %d total highlights"
                 (Hashtbl.length extracted_to_first_shared)
                 (Hashtbl.length results_table));
            completed_ref := true)
      with exn ->
        log_debug
          (Printf.sprintf "ERROR: %s\n%s" (Printexc.to_string exn)
             (Printexc.get_backtrace ()));
        completed_ref := true

  end
end

(** Tree renderer for terminal output *)
module Renderer = struct
  type tree_node = { entry : Query.entry; children : tree_node list }

  (** Build a tree node for a specific scope using database queries *)
  let rec build_node (module Q : Query.S) ?max_depth ~current_depth header_entry =
    let should_descend =
      match max_depth with None -> true | Some d -> current_depth < d
    in

    if not should_descend then { entry = header_entry; children = [] }
    else
      match header_entry.Query.child_scope_id with
      | None -> { entry = header_entry; children = [] }
      | Some scope_id ->
          (* Get children from database - properly ordered by seq_id *)
          let children_entries = Q.get_scope_children ~parent_scope_id:scope_id in

          (* Build child nodes *)
          let children =
            List.map
              (fun child ->
                match child.Query.child_scope_id with
                | Some _sub_scope_id ->
                    (* Recursively build subscope *)
                    build_node (module Q : Query.S) ?max_depth ~current_depth:(current_depth + 1) child
                | None -> { entry = child; children = [] }
                (* Leaf value *))
              children_entries
          in

          { entry = header_entry; children }

  (** Build tree from database starting with given root entries (recommended) *)
  let build_tree (module Q : Query.S) ?max_depth root_entries =
    (* Root entries are already sorted by seq_id from Query.get_root_entries *)
    List.map
      (fun root -> build_node (module Q) ?max_depth ~current_depth:0 root)
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

  (** Sanitize text for Notty: replace control chars (newlines, tabs, etc.) with spaces.
      Notty's I.string doesn't accept control characters (codes < 32 or = 127). *)
  let sanitize_for_notty s =
    String.map (fun c -> if Char.code c < 32 || Char.code c = 127 then ' ' else c) s

  (** UTF-8 aware string operations to avoid cutting multi-byte characters *)
  module Utf8 = struct
    (** Count UTF-8 characters (not bytes) in a string *)
    let char_count s =
      let count = ref 0 in
      let decoder = Uutf.decoder (`String s) in
      let rec loop () =
        match Uutf.decode decoder with
        | `Uchar _ ->
            incr count;
            loop ()
        | `End -> !count
        | `Malformed _ ->
            (* Skip malformed sequences and continue *)
            loop ()
        | `Await -> assert false
        (* Can't happen with `String input *)
      in
      loop ()

    (** Truncate string to at most n UTF-8 characters, returning valid UTF-8 *)
    let truncate s n =
      if n <= 0 then ""
      else
        let buf = Buffer.create (String.length s) in
        let count = ref 0 in
        let decoder = Uutf.decoder (`String s) in
        let rec loop () =
          if !count >= n then ()
          else
            match Uutf.decode decoder with
            | `Uchar u ->
                let encoder = Uutf.encoder `UTF_8 (`Buffer buf) in
                ignore (Uutf.encode encoder (`Uchar u));
                ignore (Uutf.encode encoder `End);
                incr count;
                loop ()
            | `End -> ()
            | `Malformed _ ->
                (* Skip malformed sequences *)
                loop ()
            | `Await -> assert false
            (* Can't happen with `String input *)
        in
        loop ();
        Buffer.contents buf

    (** Substring from character offset start with length characters (UTF-8 aware) *)
    let sub s start len =
      if start < 0 || len < 0 then invalid_arg "Utf8.sub: negative offset or length"
      else if len = 0 then ""
      else
        let buf = Buffer.create len in
        let count = ref 0 in
        let pos = ref 0 in
        let decoder = Uutf.decoder (`String s) in
        let rec loop () =
          match Uutf.decode decoder with
          | `Uchar u ->
              if !pos >= start && !count < len then (
                let encoder = Uutf.encoder `UTF_8 (`Buffer buf) in
                ignore (Uutf.encode encoder (`Uchar u));
                ignore (Uutf.encode encoder `End);
                incr count);
              incr pos;
              if !count < len then loop ()
          | `End -> ()
          | `Malformed _ ->
              (* Skip malformed sequences *)
              incr pos;
              loop ()
          | `Await -> assert false
          (* Can't happen with `String input *)
        in
        loop ();
        Buffer.contents buf
  end

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

  type search_type =
    | RegularSearch of string  (* Just the search term *)
    | ExtractSearch of {
        search_path : string list;
        extraction_path : string list;
        display_text : string;  (* For footer display *)
      }

  type search_slot = {
    search_type : search_type; [@warning "-69"]
        (* Used in status_history rendering, not just for building *)
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

  (** Chronological event tracking for status line display.
      Captures the order in which searches and quiet path changes occur. *)
  type status_event =
    | SearchEvent of SlotNumber.t * search_type
    | QuietPathEvent of string option  (* None = cleared, Some = set/updated *)

  type status_history = status_event list  (* Most recent first *)

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

  (** Ellipsis key: (parent_scope_id, start_seq_id, end_seq_id) *)
  module EllipsisKey = struct
    type t = int * int * int

    let compare = compare
  end

  module EllipsisSet = Set.Make (EllipsisKey)

  (** Content of a visible item - either a real entry or an ellipsis placeholder *)
  type visible_item_content =
    | RealEntry of Query.entry
    | Ellipsis of {
        parent_scope_id : int;
        start_seq_id : int;
        end_seq_id : int;
        hidden_count : int;
      }

  type view_state = {
    query : (module Query.S);
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
    status_history : status_history;
        (* Chronological event history for status line display *)
    unfolded_ellipsis : EllipsisSet.t;
        (* Set of manually unfolded ellipsis segments *)
    search_result_counts : (SlotNumber.t, int) Hashtbl.t;
        (* Track result counts per slot to detect search updates *)
  }

  and visible_item = {
    content : visible_item_content;
    indent_level : int;
    is_expandable : bool;
    is_expanded : bool;
  }

  (** Find closest ancestor with positive ID by walking up the tree *)
  let rec find_positive_ancestor_id (module Q : Query.S) scope_id =
    (* Base case: if this scope_id is positive, return it *)
    if scope_id >= 0 then Some scope_id
    else
      (* Negative scope_id - walk up to parent *)
      match Q.get_parent_id ~scope_id with
      | Some parent_id -> find_positive_ancestor_id (module Q) parent_id
      | None -> None (* No parent found *)

  (** Check if an entry is highlighted in any search slot *)
  let is_entry_highlighted ~search_slots ~scope_id ~seq_id =
    SlotMap.exists
      (fun _ slot -> Hashtbl.mem slot.results (scope_id, seq_id))
      search_slots

  (** Compute ellipsis segments for a list of child entries.
      Returns a list mixing real entries and ellipsis placeholders.

      Algorithm:
      1. Treat first and last child as "always highlighted" for context
      2. Identify which entries are highlighted (from search matches)
      3. Find contiguous non-highlighted sections between highlighted siblings
      4. If section has >3 entries AND not manually unfolded → create ellipsis
      5. Otherwise include all entries in that section
  *)
  let compute_ellipsis_segments ~parent_scope_id ~children ~search_slots ~unfolded_ellipsis =
    let num_children = List.length children in

    (* Handle trivial cases *)
    if num_children <= 4 then
      (* 4 or fewer children: always show all *)
      List.map (fun e -> `Entry e) children
    else
      (* Helper: check if an entry is highlighted by search *)
      let is_search_highlighted entry =
        is_entry_highlighted ~search_slots ~scope_id:entry.Query.scope_id
          ~seq_id:entry.seq_id
      in

      (* Build list of (entry, is_highlighted) pairs with indices *)
      let indexed_children =
        List.mapi (fun idx entry -> (idx, entry, is_search_highlighted entry)) children
      in

      (* Identify highlighted positions: first, last, and any search matches *)
      let highlighted_indices =
        let search_matches =
          List.filter_map
            (fun (idx, _entry, is_hl) -> if is_hl then Some idx else None)
            indexed_children
        in
        (* Always include first (0) and last (n-1) indices *)
        let with_boundaries = 0 :: (num_children - 1) :: search_matches in
        (* Remove duplicates and sort *)
        List.sort_uniq compare with_boundaries
      in

      (* Build segments between highlighted entries *)
      let rec build_segments acc prev_highlight_idx remaining_highlights =
        match remaining_highlights with
        | [] -> acc
        | next_highlight :: rest ->
            (* First, handle section between prev and next highlight (if any) *)
            let section_entries =
              List.filter
                (fun (idx, _, _) -> idx > prev_highlight_idx && idx < next_highlight)
                indexed_children
              |> List.map (fun (_, entry, _) -> entry)
            in
            let count = List.length section_entries in
            let acc_with_section =
              if count > 3 then
                (* Create ellipsis for middle section *)
                let start_seq = (List.hd section_entries).Query.seq_id in
                let end_seq = (List.nth section_entries (count - 1)).Query.seq_id in
                let key = (parent_scope_id, start_seq, end_seq) in
                if EllipsisSet.mem key unfolded_ellipsis then
                  (* Unfolded: show all entries *)
                  acc @ List.map (fun e -> `Entry e) section_entries
                else
                  (* Folded: create ellipsis *)
                  acc @ [ `Ellipsis (parent_scope_id, start_seq, end_seq, count) ]
              else if count > 0 then
                (* <= 3 entries: show all *)
                acc @ List.map (fun e -> `Entry e) section_entries
              else acc
            in

            (* Then, add the highlighted entry *)
            let highlighted_entry =
              List.find (fun (idx, _, _) -> idx = next_highlight) indexed_children
              |> fun (_, entry, _) -> entry
            in
            let new_acc = acc_with_section @ [ `Entry highlighted_entry ] in

            build_segments new_acc next_highlight rest
      in

      build_segments [] (-1) highlighted_indices

  (** Build visible items list from database using lazy loading *)
  let build_visible_items (module Q : Query.S) expanded values_first ~search_slots ~current_slot
      ~unfolded_ellipsis =
    let rec flatten_entry ~depth entry =
      (* Check if this entry actually has children *)
      let is_expandable =
        match entry.Query.child_scope_id with
        | Some hid -> Q.has_children ~parent_scope_id:hid
        | None -> false
      in
      (* Use child_scope_id as the key - it uniquely identifies this scope *)
      let is_expanded =
        match entry.child_scope_id with
        | Some hid -> Hashtbl.mem expanded hid
        | None -> false
      in

      let visible =
        {
          content = RealEntry entry;
          indent_level = depth;
          is_expandable;
          is_expanded;
        }
      in

      (* Add children if this is expanded *)
      if is_expanded then
        match entry.child_scope_id with
        | Some hid ->
            (* Load children on demand *)
            let children = Q.get_scope_children ~parent_scope_id:hid in
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
            (* Apply ellipsis logic to children *)
            let segments =
              compute_ellipsis_segments ~parent_scope_id:hid ~children:children_to_show
                ~search_slots ~unfolded_ellipsis
            in
            (* Flatten segments - either real entries or ellipsis placeholders *)
            let flattened_children =
              List.concat_map
                (function
                  | `Entry child_entry -> flatten_entry ~depth:(depth + 1) child_entry
                  | `Ellipsis (parent_id, start_seq, end_seq, hidden_count) ->
                      [
                        {
                          content =
                            Ellipsis
                              {
                                parent_scope_id = parent_id;
                                start_seq_id = start_seq;
                                end_seq_id = end_seq;
                                hidden_count;
                              };
                          indent_level = depth + 1;
                          is_expandable = true;
                          (* Ellipsis can be "expanded" to unfold *)
                          is_expanded = false;
                        };
                      ])
                segments
            in
            visible :: flattened_children
        | None -> [ visible ]
      else [ visible ]
    in

    (* Start with root entries - apply ellipsis logic at root level too *)
    let roots = Q.get_root_entries ~with_values:false in
    let root_segments =
      compute_ellipsis_segments ~parent_scope_id:0 ~children:roots ~search_slots
        ~unfolded_ellipsis
    in
    let items =
      List.concat_map
        (function
          | `Entry root_entry -> flatten_entry ~depth:0 root_entry
          | `Ellipsis (parent_id, start_seq, end_seq, hidden_count) ->
              [
                {
                  content =
                    Ellipsis
                      {
                        parent_scope_id = parent_id;
                        start_seq_id = start_seq;
                        end_seq_id = end_seq;
                        hidden_count;
                      };
                  indent_level = 0;
                  is_expandable = true;
                  is_expanded = false;
                };
              ])
        root_segments
    in
    Array.of_list items

  (** Render a single line *)
  let render_line ~width ~is_selected ~show_times ~margin_width ~search_slots
      ~current_slot:_ ~query:(module Q : Query.S) ~values_first item =
    match item.content with
    | Ellipsis { parent_scope_id; start_seq_id; end_seq_id; hidden_count } ->
        (* Render ellipsis placeholder *)
        let scope_id_str =
          Printf.sprintf "%*d │ " margin_width parent_scope_id
        in
        let indent = String.make (item.indent_level * 2) ' ' in
        let expansion_mark = "⋯ " in
        let text =
          Printf.sprintf "%s%s(%d hidden entries: seq %d-%d)%s" indent expansion_mark
            hidden_count start_seq_id end_seq_id (String.make (item.indent_level * 2) ' ')
        in
        let attr =
          if is_selected then A.(bg lightblue ++ fg black) else A.(fg (gray 12))
        in
        I.hcat
          [
            I.string (if is_selected then attr else A.(fg yellow)) scope_id_str;
            I.string attr text;
          ]
    | RealEntry entry ->
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
          match entry.child_scope_id with
          | Some hid when values_first && item.is_expanded -> (
          (* Header/scope in values_first mode: check for single result child to
             combine *)
          let children = Q.get_scope_children ~parent_scope_id:hid in
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
      let t =
        if Utf8.char_count full_text > content_width then
          Utf8.truncate full_text (content_width - 3) ^ "..."
        else full_text
      in
      sanitize_for_notty t
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
            let text_len = Utf8.char_count truncated in
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
              let segment = Utf8.sub truncated !pos seg_len in
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
        match state.visible_items.(state.cursor).content with
        | Ellipsis { parent_scope_id; _ } -> parent_scope_id
        | RealEntry entry ->
            (* For scopes, use child_scope_id; for values, use scope_id *)
            let id_to_check =
              match entry.child_scope_id with Some hid -> hid | None -> entry.scope_id
            in
            (match find_positive_ancestor_id state.query id_to_check with
            | Some id -> id
            | None -> 0)
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
            I.string A.(fg lightred)
              (sanitize_for_notty (Printf.sprintf "Quiet Path: %s_" input))
        | None -> (
            match state.search_input with
            | Some input ->
                (* Show search input prompt *)
                I.string A.(fg lightyellow)
                  (sanitize_for_notty (Printf.sprintf "Search: %s_" input))
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
                (* Build chronological status string from event history.
                   Shows searches and quiet path changes in the order they occurred. *)
                let chronological_status =
                  if state.status_history = [] then ""
                  else
                    let event_strings =
                      List.rev_map
                        (fun event ->
                          match event with
                          | SearchEvent (slot_num, search_type) -> (
                              (* Look up current search status *)
                              match SlotMap.find_opt slot_num state.search_slots with
                              | Some slot ->
                                  let count = Hashtbl.length slot.results in
                                  let color_name =
                                    match slot_num with
                                    | S1 -> "G"
                                    | S2 -> "C"
                                    | S3 -> "M"
                                    | S4 -> "Y"
                                  in
                                  let count_str =
                                    if !(slot.completed_ref) then Printf.sprintf "[%d]" count
                                    else Printf.sprintf "[%d...]" count
                                  in
                                  let search_desc =
                                    match search_type with
                                    | RegularSearch term -> sanitize_for_notty term
                                    | ExtractSearch { display_text; _ } ->
                                        sanitize_for_notty display_text
                                  in
                                  Printf.sprintf "%s:%s%s" color_name search_desc count_str
                              | None ->
                                  (* Slot was cleared/overwritten - shouldn't happen in normal flow *)
                                  "")
                          | QuietPathEvent qp_opt -> (
                              match qp_opt with
                              | Some qp ->
                                  Printf.sprintf "Q:%s" (sanitize_for_notty qp)
                              | None -> "Q:cleared"))
                        state.status_history
                    in
                    let filtered = List.filter (fun s -> s <> "") event_strings in
                    if filtered = [] then "" else " | " ^ String.concat " " filtered
                in
                I.string A.(fg lightcyan)
                  (sanitize_for_notty (base_info ^ chronological_status)))
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
          ~query:state.query ~values_first:state.values_first item
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

  (** Toggle expansion of current item (or unfold ellipsis) *)
  let toggle_expansion state =
    if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
      let item = state.visible_items.(state.cursor) in
      if item.is_expandable then
        match item.content with
        | Ellipsis { parent_scope_id; start_seq_id; end_seq_id; _ } ->
            (* Unfold ellipsis: add to unfolded set and rebuild *)
            let key = (parent_scope_id, start_seq_id, end_seq_id) in
            let new_unfolded = EllipsisSet.add key state.unfolded_ellipsis in
            let new_visible =
              build_visible_items state.query state.expanded state.values_first
                ~search_slots:state.search_slots ~current_slot:state.current_slot
                ~unfolded_ellipsis:new_unfolded
            in
            { state with visible_items = new_visible; unfolded_ellipsis = new_unfolded }
        | RealEntry entry -> (
            match entry.child_scope_id with
            | Some hid ->
                (* Use child_scope_id as the unique key for this scope *)
                if Hashtbl.mem state.expanded hid then Hashtbl.remove state.expanded hid
                else Hashtbl.add state.expanded hid ();

                (* Rebuild visible items *)
                let new_visible =
                  build_visible_items state.query state.expanded state.values_first
                    ~search_slots:state.search_slots ~current_slot:state.current_slot
                    ~unfolded_ellipsis:state.unfolded_ellipsis
                in
                { state with visible_items = new_visible }
            | None -> state)
      else state
    else state

  (** Find next/previous search result (searches hash tables, not just visible items).
      Returns updated state with cursor moved to the match and path auto-expanded, or None
      if no match. *)
  let find_and_jump_to_search_result state ~forward =
    (* Get current entry's (scope_id, seq_id) *)
    let current_scope_id, current_seq_id =
      if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
        match state.visible_items.(state.cursor).content with
        | Ellipsis { parent_scope_id; start_seq_id; _ } -> (parent_scope_id, start_seq_id)
        | RealEntry entry -> (entry.scope_id, entry.seq_id)
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
        let module Q = (val state.query) in
        let ancestors = Q.get_ancestors ~scope_id:target_scope_id in
        List.iter
          (fun ancestor_id -> Hashtbl.replace state.expanded ancestor_id ())
          ancestors;

        (* Rebuild visible items with expanded path *)
        let new_visible =
          build_visible_items state.query state.expanded state.values_first
            ~search_slots:state.search_slots ~current_slot:state.current_slot
            ~unfolded_ellipsis:state.unfolded_ellipsis
        in

        (* Find the target entry in the new visible items *)
        let rec find_in_visible idx =
          if idx >= Array.length new_visible then None
            (* Entry not found after expansion - may be filtered or invalid *)
          else
            let item = new_visible.(idx) in
            match item.content with
            | Ellipsis _ -> find_in_visible (idx + 1)
            | RealEntry entry ->
                if entry.scope_id = target_scope_id && entry.seq_id = target_seq_id then
                  Some idx
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
            (* Add quiet path event to chronological history.
               Only remove if the most recent event is also a QuietPathEvent (consecutive
               duplicates). This preserves the chronological record showing which searches
               were influenced by which quiet path filters. *)
            let filtered_history =
              match state.status_history with
              | QuietPathEvent _ :: rest ->
                  rest (* Remove previous quiet path to avoid consecutive duplicates *)
              | _ -> state.status_history (* Keep history if last event was a search *)
            in
            let new_history = QuietPathEvent new_quiet_path :: filtered_history in
            Some
              {
                state with
                quiet_path_input = None;
                quiet_path = new_quiet_path;
                status_history = new_history;
              }
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

                  (* Check if this is an extract search (contains '>') *)
                  let search_type, is_valid =
                    match String.index_opt input '>' with
                    | None ->
                        (* Regular search *)
                        (RegularSearch input, true)
                    | Some sep_idx ->
                        (* Extract search - parse paths *)
                        let search_part = String.sub input 0 sep_idx in
                        let extract_part =
                          String.sub input (sep_idx + 1) (String.length input - sep_idx - 1)
                        in
                        let search_path = String.split_on_char ',' search_part in
                        let extraction_path = String.split_on_char ',' extract_part in

                        (* Validate paths *)
                        let validate_path path =
                          List.for_all (fun s -> String.trim s <> "") path && path <> []
                        in
                        let valid_paths =
                          validate_path search_path && validate_path extraction_path
                        in
                        let same_first =
                          match (search_path, extraction_path) with
                          | s :: _, e :: _ -> String.trim s = String.trim e
                          | _ -> false
                        in

                        if valid_paths && same_first then
                          (* Trim whitespace from all path elements *)
                          let search_path = List.map String.trim search_path in
                          let extraction_path = List.map String.trim extraction_path in

                          (* Create display text with shared prefix removed from extraction *)
                          let display_text =
                            match extraction_path with
                            | _ :: tail when tail <> [] ->
                                Printf.sprintf "%s>%s" (String.concat "," search_path)
                                  (String.concat "," tail)
                            | _ ->
                                Printf.sprintf "%s>%s" (String.concat "," search_path)
                                  (String.concat "," extraction_path)
                          in
                          ( ExtractSearch { search_path; extraction_path; display_text },
                            true )
                        else (RegularSearch input, false)
                  in

                  if is_valid then (
                    (* Create shared completion flag and results hash table *)
                    let completed_ref = ref false in
                    let results_table = Hashtbl.create 1024 in

                    (* Spawn background search Domain based on search type *)
                    let domain_handle =
                      Domain.spawn (fun () ->
                          let module DomainQ = Query.Make (struct
                            let db_path = state.db_path
                          end) in
                          match search_type with
                          | RegularSearch search_term ->
                              DomainQ.populate_search_results ~search_term
                                ~quiet_path:state.quiet_path ~search_order:state.search_order
                                ~completed_ref ~results_table
                          | ExtractSearch { search_path; extraction_path; _ } ->
                              DomainQ.populate_extract_search_results ~search_path
                                ~extraction_path ~quiet_path:state.quiet_path ~completed_ref
                                ~results_table)
                    in

                    (* Update search slots *)
                    let new_slots =
                      SlotMap.update slot
                        (fun _ ->
                          Some
                            {
                              search_type;
                              domain_handle = Some domain_handle;
                              completed_ref;
                              results = results_table;
                            })
                        state.search_slots
                    in

                    (* Add search event to chronological history.
                       Remove any old search event for this slot (LRU behavior when slots wrap).
                       After filtering, deduplicate consecutive quiet path events. *)
                    let filtered_history =
                      List.filter
                        (fun event ->
                          match event with
                          | SearchEvent (old_slot, _) -> old_slot <> slot
                          | QuietPathEvent _ -> true)
                        state.status_history
                    in
                    (* Deduplicate consecutive quiet path events that may have been exposed
                       by removing the search event. Keep the more recent (first) one. *)
                    let rec deduplicate_consecutive acc = function
                      | [] -> List.rev acc
                      | (QuietPathEvent _ as qp) :: QuietPathEvent _ :: rest ->
                          (* Keep first (more recent) quiet path, skip second (older), continue *)
                          deduplicate_consecutive (qp :: acc) rest
                      | event :: rest -> deduplicate_consecutive (event :: acc) rest
                    in
                    let deduped_history = deduplicate_consecutive [] filtered_history in
                    let new_history = SearchEvent (slot, search_type) :: deduped_history in

                    (* Check if search results changed - invalidate ellipsis if so *)
                    let new_count = Hashtbl.length results_table in
                    let old_count =
                      match Hashtbl.find_opt state.search_result_counts slot with
                      | Some c -> c
                      | None -> -1
                    in
                    let search_changed = new_count <> old_count in

                    (* Update result counts *)
                    let new_result_counts = Hashtbl.copy state.search_result_counts in
                    Hashtbl.replace new_result_counts slot new_count;

                    (* If search changed, invalidate all ellipsis (clear unfolded set) *)
                    let new_unfolded =
                      if search_changed then EllipsisSet.empty else state.unfolded_ellipsis
                    in

                    (* Rebuild visible items if ellipsis was invalidated *)
                    let new_visible =
                      if search_changed then
                        build_visible_items state.query state.expanded state.values_first
                          ~search_slots:new_slots ~current_slot:state.current_slot
                          ~unfolded_ellipsis:new_unfolded
                      else state.visible_items
                    in

                    Some
                      {
                        state with
                        search_input = None;
                        search_slots = new_slots;
                        current_slot = SlotNumber.next slot;
                        status_history = new_history;
                        search_result_counts = new_result_counts;
                        unfolded_ellipsis = new_unfolded;
                        visible_items = new_visible;
                      })
                  else
                    (* Invalid extract search format - just cancel *)
                    Some { state with search_input = None }
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
                  build_visible_items state.query state.expanded new_values_first
                    ~search_slots:state.search_slots ~current_slot:state.current_slot
                    ~unfolded_ellipsis:state.unfolded_ellipsis
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
  let run (module Q : Query.S) db_path =
    let expanded = Hashtbl.create 64 in
    let values_first = true in
    (* Initialize with empty search slots for initial build *)
    let empty_search_slots = SlotMap.empty in
    let unfolded_ellipsis = EllipsisSet.empty in
    let visible_items =
      build_visible_items (module Q) expanded values_first ~search_slots:empty_search_slots
        ~current_slot:S1 ~unfolded_ellipsis
    in
    let max_scope_id = Q.get_max_scope_id () in

    (* Initialize empty search slots (no persistence across TUI sessions) *)
    let initial_state =
      {
        query = (module Q : Query.S);
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
        unfolded_ellipsis;
        search_result_counts = Hashtbl.create 4;
        status_history = [];
      }
    in

    let term = Term.create () in

    let rec loop state =
      (* Check if any search results have changed *)
      let state_with_updated_searches =
        let search_changed = ref false in
        let new_result_counts = Hashtbl.copy state.search_result_counts in
        SlotMap.iter
          (fun slot search_slot ->
            let new_count = Hashtbl.length search_slot.results in
            let old_count =
              match Hashtbl.find_opt state.search_result_counts slot with
              | Some c -> c
              | None -> -1
            in
            if new_count <> old_count then (
              search_changed := true;
              Hashtbl.replace new_result_counts slot new_count))
          state.search_slots;

        if !search_changed then
          (* Search results changed - invalidate ellipsis and rebuild *)
          let new_unfolded = EllipsisSet.empty in
          let new_visible =
            build_visible_items state.query state.expanded state.values_first
              ~search_slots:state.search_slots ~current_slot:state.current_slot
              ~unfolded_ellipsis:new_unfolded
          in
          {
            state with
            search_result_counts = new_result_counts;
            unfolded_ellipsis = new_unfolded;
            visible_items = new_visible;
          }
        else state
      in

      let term_width, term_height = Term.size term in
      let image = render_screen state_with_updated_searches term_height term_width in
      Term.image term image;

      (* Poll every 1/5th of a second to check for search updates *)
      match event_with_timeout term 0.2 with
      | Some event -> (
          match event with
          | `Key key -> (
              match handle_key state_with_updated_searches key term_height with
              | Some new_state -> loop new_state
              | None -> ())
          | `Resize _ -> loop state_with_updated_searches
          | #Notty.Unescape.event | `End -> loop state_with_updated_searches)
      | None ->
          (* Timeout - just redraw to update search status *)
          loop state_with_updated_searches
    in

    loop initial_state;
    Term.release term
end

(** Main client interface *)
module Client = struct
  type t = (module Query.S)

  let open_db db_path =
    let module Q = Query.Make (struct
      let db_path = db_path
    end) in
    (module Q : Query.S)

  let close _t = ()
  (* DB connections are closed when module goes out of scope *)

  (** List all runs *)
  let list_runs t =
    let module Q = (val t : Query.S) in
    Q.get_runs ()

  (** Get latest run *)
  let get_latest_run t =
    let module Q = (val t : Query.S) in
    match Q.get_latest_run_id () with
    | Some run_id ->
        let runs = Q.get_runs () in
        List.find_opt (fun r -> r.Query.run_id = run_id) runs
    | None -> None

  (** Get run by name *)
  let get_run_by_name t ~run_name =
    let module Q = (val t : Query.S) in
    Q.get_run_by_name ~run_name

  (** Open database by run name - looks up the run in the metadata DB and opens the
      corresponding versioned database file. Returns None if the run doesn't exist
      (e.g., when log_level prevents DB creation). *)
  let open_by_run_name ~meta_file_base ~run_name =
    let meta_file = meta_file_base ^ "_meta.db" in
    if not (Sys.file_exists meta_file) then None
    else
      (* Open metadata DB directly with SQLite, not through Client API *)
      let meta_db = Sqlite3.db_open ~mode:`READONLY meta_file in
      let stmt =
        Sqlite3.prepare meta_db "SELECT db_file FROM runs WHERE run_name = ?"
      in
      Sqlite3.bind_text stmt 1 run_name |> ignore;
      let result =
        match Sqlite3.step stmt with
        | Sqlite3.Rc.ROW ->
            let db_file = Sqlite3.Data.to_string_exn (Sqlite3.column stmt 0) in
            Sqlite3.finalize stmt |> ignore;
            Sqlite3.db_close meta_db |> ignore;
            (* Construct full path if needed *)
            let full_path =
              let dir = Filename.dirname meta_file_base in
              if dir = "." then db_file else Filename.concat dir db_file
            in
            Some (open_db full_path)
        | _ ->
            Sqlite3.finalize stmt |> ignore;
            Sqlite3.db_close meta_db |> ignore;
            None
      in
      result

  (** Show run summary *)
  let show_run_summary ?(output = Format.std_formatter) t run_id =
    let module Q = (val t : Query.S) in
    let runs = Q.get_runs () in
    match List.find_opt (fun r -> r.Query.run_id = run_id) runs with
    | Some run ->
        Format.fprintf output "Run #%d\n" run.run_id;
        Format.fprintf output "Timestamp: %s\n" run.timestamp;
        Format.fprintf output "Command: %s\n" run.command_line;
        Format.fprintf output "Elapsed: %s\n\n" (Renderer.format_elapsed_ns run.elapsed_ns)
    | None -> Format.fprintf output "Run #%d not found\n" run_id

  (** Show database statistics *)
  let show_stats ?(output = Format.std_formatter) t =
    let module Q = (val t : Query.S) in
    let stats = Q.get_stats () in
    Format.fprintf output "Database Statistics\n";
    Format.fprintf output "===================\n";
    Format.fprintf output "Total entries: %d\n" stats.total_entries;
    Format.fprintf output "Total value references: %d\n" stats.total_values;
    Format.fprintf output "Unique values: %d\n" stats.unique_values;
    Format.fprintf output "Deduplication: %.1f%%\n" stats.dedup_percentage;
    Format.fprintf output "Database size: %d KB\n" stats.database_size_kb

  (** Show trace tree for a run *)
  let show_trace ?(output = Format.std_formatter) ?(show_scope_ids = false)
      ?(show_times = false) ?(max_depth = None) ?(values_first_mode = true) t =
    let module Q = (val t : Query.S) in
    let roots = Q.get_root_entries ~with_values:false in
    let trees = Renderer.build_tree (module Q) ?max_depth roots in
    let rendered =
      Renderer.render_tree ~show_scope_ids ~show_times ~max_depth ~values_first_mode trees
    in
    Format.fprintf output "%s" rendered

  (** Show compact trace (function names only) *)
  let show_compact_trace ?(output = Format.std_formatter) t =
    let module Q = (val t : Query.S) in
    let roots = Q.get_root_entries ~with_values:false in
    let trees = Renderer.build_tree (module Q) ?max_depth:None roots in
    let rendered = Renderer.render_compact trees in
    Format.fprintf output "%s" rendered

  (** Show root entries efficiently *)
  let show_roots ?(output = Format.std_formatter) ?(show_times = false)
      ?(with_values = false) t =
    let module Q = (val t : Query.S) in
    let entries = Q.get_root_entries ~with_values in
    let rendered = Renderer.render_roots ~show_times ~with_values entries in
    Format.fprintf output "%s" rendered

  (** Search entries *)
  let search ?(output = Format.std_formatter) t ~pattern =
    let module Q = (val t : Query.S) in
    let entries = Q.search_entries ~pattern in
    Format.fprintf output "Found %d matching entries for pattern '%s':\n\n"
      (List.length entries) pattern;
    List.iter
      (fun entry ->
        Format.fprintf output "#%d [%s] %s" entry.Query.scope_id entry.entry_type
          entry.message;
        (match entry.location with
        | Some loc -> Format.fprintf output " @ %s" loc
        | None -> ());
        Format.fprintf output "\n";
        match entry.data with
        | Some data -> Format.fprintf output "  %s\n" data
        | None -> ())
      entries

  (** Export trace to markdown *)
  let export_markdown t ~output_file =
    let module Q = (val t : Query.S) in
    let run = get_latest_run t in
    let roots = Q.get_root_entries ~with_values:false in
    let trees = Renderer.build_tree (module Q) ?max_depth:None roots in

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
  let search_tree ?(output = Format.std_formatter) ?(quiet_path = None) ?(format = `Text)
      ?(show_times = false) ?(max_depth = None) ?(limit = None) ?(offset = None) t ~pattern
      =
    let module Q = (val t : Query.S) in
    (* Run search synchronously using the same logic as TUI *)
    let completed_ref = ref false in
    let results_table = Hashtbl.create 1024 in
    Q.populate_search_results ~search_term:pattern ~quiet_path
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
    let filtered_entries = Q.get_entries_from_results ~results_table in

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
          Format.fprintf output
            "Found %d matching scopes for pattern '%s', %d root trees (showing trees \
             %d-%d)\n\
             \n"
            total_scopes pattern total_trees start_idx (start_idx + shown_trees)
        else
          Format.fprintf output "Found %d matching scopes for pattern '%s'\n\n" total_scopes
            pattern;
        let rendered =
          Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
            ~values_first_mode:true trees
        in
        Format.fprintf output "%s" rendered
    | `Json ->
        let json = Renderer.render_tree_json ~max_depth trees in
        Format.fprintf output "%s\n" json);

    List.length matching_scope_ids

  (** Search and show only matching subtrees (prune non-matching branches).
      This builds a minimal tree containing only paths to matches. *)
  let search_subtree ?(output = Format.std_formatter) ?(quiet_path = None)
      ?(format = `Text) ?(show_times = false) ?(max_depth = None) ?(limit = None)
      ?(offset = None) t ~pattern =
    let module Q = (val t : Query.S) in
    (* Run search to get results hash table *)
    let completed_ref = ref false in
    let results_table = Hashtbl.create 1024 in
    Q.populate_search_results ~search_term:pattern ~quiet_path
      ~search_order:Query.AscendingIds ~completed_ref ~results_table;

    (* Get entries from results_table (includes matches and propagated ancestors) *)
    let filtered_entries = Q.get_entries_from_results ~results_table in
    let full_trees = Renderer.build_tree_from_entries filtered_entries in

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
          Format.fprintf output
            "Found %d matches for pattern '%s', %d root trees (showing trees %d-%d):\n\n"
            match_count pattern total_trees start_idx (start_idx + shown_trees)
        else
          Format.fprintf output
            "Found %d matches for pattern '%s', showing %d pruned subtrees:\n\n" match_count
            pattern total_trees;
        let rendered =
          Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
            ~values_first_mode:true pruned_trees
        in
        Format.fprintf output "%s" rendered
    | `Json ->
        let json = Renderer.render_tree_json ~max_depth pruned_trees in
        Format.fprintf output "%s\n" json);

    match_count

  (** Search intersection - find smallest subtrees containing all patterns (LCA-based).
      For each pattern, runs populate_search_results to get matching scopes.
      Then computes all LCAs (Lowest Common Ancestors) for combinations of matches
      (one match per pattern). Returns unique LCA scopes as the smallest subtrees. *)
  let search_intersection ?(output = Format.std_formatter) ?(quiet_path = None)
      ?(format = `Text) ?(show_times = false) ?max_depth:_ ?(limit = None) ?(offset = None)
      t ~patterns =
    let module Q = (val t : Query.S) in
    (* Run separate search for each pattern *)
    let all_results_tables =
      List.map
        (fun pattern ->
          let completed_ref = ref false in
          let results_table = Hashtbl.create 1024 in
          Q.populate_search_results ~search_term:pattern ~quiet_path
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
            match Q.lowest_common_ancestor scope_ids with
            | Some lca -> [ lca ]
            | None ->
                (* No common ancestor - scopes are in separate root trees.
                   Return all root scopes as separate minimal subtrees. *)
                List.map (fun id -> Q.get_root_scope id) scope_ids)
          all_combinations
        |> List.sort_uniq compare
      in
      lcas
    in

    (* Get entries for LCA scopes (just the header entries for compact display) *)
    let lca_entries =
      List.filter_map (fun lca_scope_id -> Q.find_scope_header ~scope_id:lca_scope_id)
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
          Format.fprintf output
            "Found %d smallest subtrees containing all patterns (%s) (showing %d-%d):\n\n"
            total_lcas pattern_str start_idx (start_idx + shown_lcas)
        else
          Format.fprintf output
            "Found %d smallest subtrees containing all patterns (%s):\n\n" total_lcas
            pattern_str;

        (* Show per-pattern match counts for debugging *)
        Format.fprintf output "Per-pattern match counts:\n";
        List.iter
          (fun (pattern, scope_ids) ->
            Format.fprintf output "  '%s': %d scopes\n" pattern (List.length scope_ids))
          matching_scope_ids_per_pattern;
        Format.fprintf output "\n";

        (* Display LCA scopes compactly: scope_id and header line only *)
        Format.fprintf output "Lowest Common Ancestor scopes (smallest subtrees):\n\n";
        List.iter
          (fun entry ->
            match entry.Query.child_scope_id with
            | Some lca_scope_id ->
                let loc_str =
                  match entry.Query.location with
                  | Some loc -> Printf.sprintf " [%s]" loc
                  | None -> ""
                in
                let elapsed_str =
                  match Renderer.elapsed_time entry with
                  | Some ns when show_times ->
                      Printf.sprintf " (%s)" (Renderer.format_elapsed_ns ns)
                  | _ -> ""
                in
                Format.fprintf output "  Scope %d: %s%s%s\n" lca_scope_id entry.Query.message
                  loc_str elapsed_str
            | None -> ())
          paginated_lca_entries;
        Format.fprintf output "\n"
    | `Json ->
        let json_entries =
          List.map
            (fun entry ->
              match entry.Query.child_scope_id with
              | Some lca_scope_id ->
                  Printf.sprintf {|{"scope_id": %d, "message": "%s", "location": %s}|}
                    lca_scope_id
                    (String.escaped entry.Query.message)
                    (match entry.Query.location with
                    | Some loc -> Printf.sprintf "\"%s\"" (String.escaped loc)
                    | None -> "null")
              | None -> "")
            paginated_lca_entries
          |> List.filter (fun s -> s <> "")
        in
        Format.fprintf output "[%s]\n" (String.concat ", " json_entries));

    List.length lca_scope_ids

  (** Show a specific scope and its descendants *)
  let show_scope ?(output = Format.std_formatter) ?(format = `Text) ?(show_times = false)
      ?(max_depth = None) ?(show_ancestors = false) t ~scope_id =
    let module Q = (val t : Query.S) in
    if show_ancestors then
      (* Show path from root to this scope *)
      let ancestors = Q.get_ancestors ~scope_id in
      let filtered_entries = Q.get_entries_for_scopes ~scope_ids:ancestors in
      let trees = Renderer.build_tree_from_entries filtered_entries in
      (match format with
      | `Text ->
          Format.fprintf output "Ancestor path to scope %d:\n\n" scope_id;
          let rendered =
            Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
              ~values_first_mode:true trees
          in
          Format.fprintf output "%s" rendered
      | `Json ->
          let json = Renderer.render_tree_json ~max_depth trees in
          Format.fprintf output "%s\n" json)
    else
      (* Show just this scope and descendants *)
      let children = Q.get_scope_children ~parent_scope_id:scope_id in
      (match format with
      | `Text ->
          Format.fprintf output "Scope %d contents:\n\n" scope_id;
          let rendered = Renderer.render_entries_json children in
          Format.fprintf output "%s\n" rendered
      | `Json ->
          let json = Renderer.render_entries_json children in
          Format.fprintf output "%s\n" json)

  (** Show a specific scope subtree with ancestors (full tree rendering).
      The max_depth parameter is interpreted as INCREMENTAL depth from the target scope.
      Shows: ancestor path → target scope → descendants (up to max_depth levels below target). *)
  let show_subtree ?(output = Format.std_formatter) ?(format = `Text) ?(show_times = false)
      ?(max_depth = None) ?(show_ancestors = true) t ~scope_id =
    let module Q = (val t : Query.S) in
    (* Strategy:
       1. If show_ancestors=true: Build tree from root down to scope_id (no depth limit on ancestors)
       2. At scope_id: Apply max_depth limit for descendants

       We accomplish this by:
       - Getting the ancestor chain from root to scope_id
       - Building a "spine" tree following that path
       - At the target scope_id, use max_depth for its subtree *)

    if show_ancestors then (
      (* Get ancestor chain (scope_id -> parent -> ... -> root) *)
      let ancestors = Q.get_ancestors ~scope_id in

      (* Build ancestor path tree by filtering to just the ancestor path.
         We build trees from roots, then we'll walk down to find the target scope. *)
      let roots = Q.get_root_entries ~with_values:false in

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
          let tree = Renderer.build_node (module Q) ?max_depth ~current_depth:0 root_entry in

          (* Output *)
          match format with
          | `Text ->
              Format.fprintf output "Subtree for scope %d (with ancestor path):\n\n" scope_id;
              let rendered =
                Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth:None
                  ~values_first_mode:true [ tree ]
              in
              Format.fprintf output "%s" rendered
          | `Json ->
              let json = Renderer.render_tree_json ~max_depth:None [ tree ] in
              Format.fprintf output "%s\n" json)
    else (
      (* Just show the subtree starting at scope_id *)
      (* First, find the header entry for this scope *)
      let header_entry_opt = Q.find_scope_header ~scope_id in

      match header_entry_opt with
      | None ->
          Printf.eprintf "Error: Could not find header entry for scope %d\n" scope_id;
          exit 1
      | Some header_entry ->
          let tree = Renderer.build_node (module Q) ?max_depth ~current_depth:0 header_entry in

          match format with
          | `Text ->
              Format.fprintf output "Subtree for scope %d:\n\n" scope_id;
              let rendered =
                Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth:None
                  ~values_first_mode:true [ tree ]
              in
              Format.fprintf output "%s" rendered
          | `Json ->
              let json = Renderer.render_tree_json ~max_depth:None [ tree ] in
              Format.fprintf output "%s\n" json)

  (** Show detailed information for a specific entry *)
  let show_entry ?(output = Format.std_formatter) ?(format = `Text) t ~scope_id ~seq_id =
    let module Q = (val t : Query.S) in
    match Q.find_entry ~scope_id ~seq_id with
    | None ->
        Printf.eprintf "Entry (%d, %d) not found\n" scope_id seq_id;
        exit 1
    | Some entry -> (
        match format with
        | `Text ->
            Format.fprintf output "Entry (%d, %d):\n" scope_id seq_id;
            Format.fprintf output "  Type: %s\n" entry.entry_type;
            Format.fprintf output "  Message: %s\n" entry.message;
            (match entry.location with
            | Some loc -> Format.fprintf output "  Location: %s\n" loc
            | None -> ());
            (match entry.data with
            | Some d -> Format.fprintf output "  Data: %s\n" d
            | None -> ());
            (match entry.child_scope_id with
            | Some id -> Format.fprintf output "  Child Scope ID: %d\n" id
            | None -> ());
            Format.fprintf output "  Depth: %d\n" entry.depth;
            Format.fprintf output "  Log Level: %d\n" entry.log_level;
            Format.fprintf output "  Is Result: %b\n" entry.is_result;
            (match Renderer.elapsed_time entry with
            | Some elapsed ->
                Format.fprintf output "  Elapsed: %s\n" (Renderer.format_elapsed_ns elapsed)
            | None -> ())
        | `Json ->
            let json = Renderer.entry_to_json entry in
            Format.fprintf output "%s\n" json)

  (** Get ancestors of a scope (returns ALL paths from root to target due to DAG structure) *)
  let get_ancestors ?(output = Format.std_formatter) ?(format = `Text) t ~scope_id =
    let module Q = (val t : Query.S) in
    let all_paths = Q.get_all_ancestor_paths ~scope_id in

    (* Fetch header entries for ancestors *)
    let get_entry_for_scope ancestor_id = Q.find_scope_header ~scope_id:ancestor_id in

    match format with
    | `Text ->
        if List.length all_paths = 1 then (
          Format.fprintf output "Ancestor path to scope %d:\n\n" scope_id;
          List.iter
            (fun ancestor_id ->
              match get_entry_for_scope ancestor_id with
              | Some entry ->
                  let loc_str = match entry.Query.location with
                    | Some loc -> Printf.sprintf " @ %s" loc
                    | None -> ""
                  in
                  Format.fprintf output "  #%d [%s] %s%s\n"
                    ancestor_id entry.Query.entry_type entry.Query.message loc_str
              | None -> ())
            (List.hd all_paths)
        ) else (
          (* Multiple paths - use Hasse diagram style rendering *)
          Format.fprintf output "Found %d ancestor paths to scope %d (Hasse diagram view):\n\n"
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
                Format.fprintf output "Level %d (%s, %d scopes):\n"
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
                      Format.fprintf output "  #%d [%s] %s%s\n"
                        ancestor_id entry.Query.entry_type entry.Query.message loc_str
                  | None ->
                      Format.fprintf output "  #%d (no entry found)\n" ancestor_id
                ) sorted_ids;

                Format.fprintf output "\n"
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
          Format.fprintf output "%s\n" (List.hd json_paths)
        else
          (* Multiple paths - return as array of arrays *)
          Format.fprintf output "[ %s ]\n" (String.concat ", " json_paths)

  (** Get parent of a scope *)
  let get_parent ?(output = Format.std_formatter) ?(format = `Text) t ~scope_id =
    let module Q = (val t : Query.S) in
    match Q.get_parent_id ~scope_id with
    | None ->
        (match format with
        | `Text -> Format.fprintf output "Scope %d has no parent (is root)\n" scope_id
        | `Json -> Format.fprintf output "%s\n" "null")
    | Some parent_id ->
        (match format with
        | `Text -> Format.fprintf output "Parent of scope %d: %d\n" scope_id parent_id
        | `Json -> Format.fprintf output "%d\n" parent_id)

  (** Get immediate children of a scope *)
  let get_children ?(output = Format.std_formatter) ?(format = `Text) t ~scope_id =
    let module Q = (val t : Query.S) in
    let children = Q.get_scope_children ~parent_scope_id:scope_id in
    let child_scope_ids =
      List.filter_map
        (fun e ->
          match e.Query.child_scope_id with Some id -> Some id | None -> None)
        children
      |> List.sort_uniq compare
    in
    match format with
    | `Text ->
        Format.fprintf output "Child scopes of %d: [ %s ]\n" scope_id
          (String.concat ", " (List.map string_of_int child_scope_ids))
    | `Json ->
        Format.fprintf output "[ %s ]\n"
          (String.concat ", " (List.map string_of_int child_scope_ids))

  (** Search and show only entries at a specific depth on paths to matches.
      This gives a TUI-like summary view - shows only the depth-N ancestors
      of matching entries, filtered by quiet_path. *)
  let search_at_depth ?(output = Format.std_formatter) ?(quiet_path = None) ?(format = `Text) ?(show_times = false)
      ~depth t ~pattern =
    let module Q = (val t : Query.S) in
    (* Run search to get results hash table *)
    let completed_ref = ref false in
    let results_table = Hashtbl.create 1024 in
    Q.populate_search_results ~search_term:pattern ~quiet_path
      ~search_order:Query.AscendingIds ~completed_ref ~results_table;

    (* Get entries from results_table and filter to specified depth *)
    let filtered_entries = Q.get_entries_from_results ~results_table in
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
        Format.fprintf output
          "Found %d matches for pattern '%s', showing %d unique entries at depth %d:\n\n"
          match_count pattern (List.length unique_entries) depth;
        List.iter
          (fun entry ->
            Format.fprintf output "#%d [%s] %s" entry.Query.scope_id entry.entry_type
              entry.message;
            (match entry.location with
            | Some loc -> Format.fprintf output " @ %s" loc
            | None -> ());
            (if show_times then
               match Renderer.elapsed_time entry with
               | Some elapsed ->
                   Format.fprintf output " <%s>" (Renderer.format_elapsed_ns elapsed)
               | None -> ());
            Format.fprintf output "\n")
          unique_entries
    | `Json ->
        let json = Renderer.render_entries_json unique_entries in
        Format.fprintf output "%s\n" json

  (** Search DAG with a path pattern, then extract along a different path with deduplication.
      For each match of search_path, extracts along extraction_path (which shares the first
      element with search_path). Prints each extracted subtree, skipping consecutive
      duplicates (same scope_id). *)
  let search_extract ?(output = Format.std_formatter) ?(format = `Text) ?(show_times = false) ?(max_depth = None) t
      ~search_path ~extraction_path =
    let module Q = (val t : Query.S) in
    (* Validate inputs *)
    (match (search_path, extraction_path) with
    | [], _ | _, [] -> failwith "search_extract: paths cannot be empty"
    | s :: _, e :: _ when s <> e ->
        failwith "search_extract: paths must start with same pattern"
    | _ -> ());

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
              (match format with
              | `Text ->
                  Format.fprintf output "=== Match #%d at shared scope #%d ==>\n" !unique_extractions
                    shared_scope_id;

                  (* Get the scope entry for the extracted scope *)
                  let scope_children =
                    Q.get_scope_children ~parent_scope_id:extracted_scope_id
                  in
                  (* Find the header entry (if any) and build tree *)
                  (match scope_children with
                  | [] -> Format.fprintf output "(empty scope)\n\n"
                  | _ ->
                      let trees = Renderer.build_tree (module Q) ?max_depth scope_children in
                      let rendered_output =
                        Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
                          ~values_first_mode:true trees
                      in
                      Format.fprintf output "%s" rendered_output;
                      Format.fprintf output "\n")
              | `Json ->
                  (* For JSON, output a structured object *)
                  let scope_children =
                    Q.get_scope_children ~parent_scope_id:extracted_scope_id
                  in
                  let trees = Renderer.build_tree (module Q) ?max_depth scope_children in
                  let tree_json = Renderer.render_tree_json ~max_depth trees in
                  Format.fprintf output
                    "{\"match_number\": %d, \"shared_scope_id\": %d, \
                     \"extracted_scope_id\": %d, \"tree\": %s}\n"
                    !unique_extractions shared_scope_id extracted_scope_id tree_json)))
      matching_paths;

    (* Print summary *)
    (match format with
    | `Text ->
        Format.fprintf output
          "\nSearch-extract complete: %d total matches, %d unique extractions (skipped %d \
           consecutive duplicates)\n"
          !total_matches !unique_extractions (!total_matches - !unique_extractions)
    | `Json -> ())

end
