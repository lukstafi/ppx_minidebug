(** Query layer for database access *)

type entry = {
  scope_id : int; (** Scope ID - groups all rows for a scope *)
  seq_id : int; (** Position within parent's children *)
  child_scope_id : int option; (** NULL for values, points to new scope for headers *)
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
    (** ORDER BY scope_id ASC: newest-neg → oldest-neg → oldest-pos → newest-pos *)
  | DescendingIds
(** ORDER BY scope_id DESC: newest-pos → oldest-pos → oldest-neg → newest-neg *)


(** Format elapsed time *)
let format_elapsed_ns ns =
  if ns < 1000 then Printf.sprintf "%dns" ns
  else if ns < 1_000_000 then Printf.sprintf "%.2fμs" (float_of_int ns /. 1e3)
  else if ns < 1_000_000_000 then Printf.sprintf "%.2fms" (float_of_int ns /. 1e6)
  else Printf.sprintf "%.2fs" (float_of_int ns /. 1e9)

(** Calculate elapsed time for entry *)
let elapsed_time entry =
  match entry.elapsed_end_ns with
  | Some end_ns -> Some (end_ns - entry.elapsed_start_ns)
  | None -> None

(** Module signature for Query operations - all functions access module-level DB
    connections *)
module type S = sig
  val db_path : string
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
  val extract_along_path : start_scope_id:int -> extraction_path:string list -> int option

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
                  {
                    run_id;
                    timestamp;
                    elapsed_ns;
                    command_line;
                    run_name = run_name_opt;
                    db_file;
                  }
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
      (* Convert pattern to GLOB format if needed - for now use simple wildcard
         wrapping *)
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
      List.iteri
        (fun i scope_id -> Sqlite3.bind_int stmt (i + 1) scope_id |> ignore)
        scope_ids;
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

  (** Get entries from a results hashtable (as returned by populate_search_results). This
      is much more efficient than get_entries() + filter for large databases. *)
  let get_entries_from_results ~results_table =
    (* Extract all (scope_id, seq_id) pairs from hashtable *)
    let pairs =
      Hashtbl.fold
        (fun (scope_id, seq_id) _ acc -> (scope_id, seq_id) :: acc)
        results_table []
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
      let has_child =
        match Sqlite3.step stmt with Sqlite3.Rc.ROW -> true | _ -> false
      in
      has_child

  (** Get all parent scope_ids for a given entry. Returns empty list if no parents (root
      entry). Due to SexpCache deduplication, an entry can have multiple parents (DAG
      structure). *)
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
            | Sqlite3.Data.NULL -> loop () (* Skip NULL parents *)
            | _ -> loop ())
        | _ -> ()
      in
      loop ();
      List.rev !parent_ids (* Preserve insertion order *)

  (** Get first parent scope_id for a given entry (for single-path operations). Returns
      None if no parent (root entry). *)
  let get_parent_id ~scope_id =
    match get_parent_ids ~scope_id with [] -> None | first :: _ -> Some first

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

  (* Cached prepared statement for streaming search queries *)

  (** Populate search results hash table with entries matching search term. This is meant
      to run in a background Domain. Opens its own DB connection. Sets completed_ref to
      true when finished. Propagates highlights to ancestors unless quiet_path matches.

      Implementation: Interleaves stepping through the main search query with issuing
      ancestor lookup queries (via get_parent_id). SQLite handles multiple active prepared
      statements without issue. Propagates highlights immediately upon finding each match
      for real-time UI updates.

      Writes results to shared hash table (lock-free concurrent writes are safe). *)
  let get_search_stream_stmt =
    let ascending_stmt = ref None in
    let descending_stmt = ref None in
    fun ~search_order ->
      let order_clause =
        match search_order with
        | AscendingIds -> "ORDER BY e.scope_id ASC, e.seq_id ASC"
        | DescendingIds -> "ORDER BY e.scope_id DESC, e.seq_id ASC"
      in
      let stmt_ref =
        match search_order with
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

  let populate_search_results ~search_term ~quiet_path ~search_order ~completed_ref
      ~results_table =
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

  (** Get ancestor entry IDs from a given entry up to root, following the first parent at
      each level. Returns list in order [scope_id; parent; grandparent; ...; root].

      Note: Due to SexpCache deduplication, entries can have multiple parents (DAG
      structure). This function returns ONE path through the DAG by always following the
      first parent. For operations requiring all paths, use get_all_ancestor_paths. *)
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

  (** Compute the lowest common ancestor (LCA) of a list of scope IDs. Returns None if
      scopes are in separate root-level trees (no common ancestor). For scopes in the same
      tree, returns their deepest common ancestor. *)
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
                    else try_ancestors remaining
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
    contains entry.message || match entry.data with Some d -> contains d | None -> false

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

  (** Find all paths in the DAG matching a sequence of patterns. Returns list of
      (shared_scope_id, ancestor_path) tuples, where:
      - shared_scope_id is the scope_id of the last matching node (the "shared node")
      - ancestor_path is the list of scope_ids from root to shared_scope_id

      Algorithm: 1. Reverse the search path for convenience 2. Use the last pattern (first
      of reversed) to find initial candidates via populate_search_results 3. For each
      candidate, climb up the DAG verifying parent patterns match 4. Return those that
      successfully match the full path *)
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
            | Sqlite3.Data.NULL -> loop () (* Skip NULL parents *)
            | _ -> loop ())
        | _ -> ()
      in
      loop ();
      Sqlite3.finalize stmt |> ignore;
      List.rev !parent_ids (* Preserve insertion order *)
    in

    let local_get_parent_id ~scope_id =
      match local_get_parent_ids ~scope_id with [] -> None | first :: _ -> Some first
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

       The candidate_id is the scope_id where the match was found. This could be: 1. A
       scope created by an entry matching the last pattern (if it's a scope header) 2. A
       scope containing a value entry matching the last pattern (if it's a value)

       In case (1), we check if this scope's parent matches the next pattern. In case (2),
       we check if this scope itself matches the next pattern (since the scope contains
       the matching value). *)
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
                  (fun parent_id ->
                    climb_up_dag parent_id rest_patterns ~first_is_value:false)
                  parent_ids
            else []
          else if
            (* The last match was a scope, so check if current scope matches the
               pattern *)
            local_scope_entry_matches_pattern ~scope_id:current_scope_id ~pattern
          then
            (* This scope matches the pattern *)
            if rest_patterns = [] then
              (* No more patterns - we've matched everything! *)
              let full_path = local_get_ancestors ~scope_id:current_scope_id in
              [ (current_scope_id, full_path) ]
            else
              (* More patterns remain - climb to parents *)
              let parent_ids = local_get_parent_ids ~scope_id:current_scope_id in
              List.concat_map
                (fun parent_id ->
                  climb_up_dag parent_id rest_patterns ~first_is_value:false)
                parent_ids
          else []
    in

    (* Try climbing from each candidate. We need to determine if each candidate represents
       a scope created by the match, or a scope containing a value match. *)
    let results =
      List.concat_map
        (fun candidate_id ->
          (* Check if this candidate scope was created by an entry matching the last
             pattern, or if it just contains a value matching the last pattern *)
          let is_value_match =
            not
              (local_scope_entry_matches_pattern ~scope_id:candidate_id
                 ~pattern:last_pattern)
          in
          climb_up_dag candidate_id ancestor_patterns ~first_is_value:is_value_match)
        candidate_scope_ids
    in

    Sqlite3.db_close local_db |> ignore;
    results

  (** Extract along a path starting from a given scope. The extraction_path should have
      already had its first element removed (since it matches the search path's shared
      element). Returns Some scope_id if the path is successfully traversed, None
      otherwise.

      Special case: If the path ends at a value entry (child_scope_id = None), returns the
      current scope_id (parent of the value). *)
  let extract_along_path ~start_scope_id ~extraction_path =
    let rec traverse current_scope_id = function
      | [] -> Some current_scope_id (* Reached the end of extraction path *)
      | [ last_pattern ] -> (
          (* Last element in path - can be a value or a scope *)
          let children = get_scope_children ~parent_scope_id:current_scope_id in
          let matching_child =
            List.find_opt (fun entry -> entry_matches_pattern entry last_pattern) children
          in
          match matching_child with
          | Some child -> (
              match child.child_scope_id with
              | Some child_scope -> Some child_scope (* Descend into child scope *)
              | None -> Some current_scope_id (* Value entry - return current scope *))
          | None -> None)
      | pattern :: rest -> (
          (* Not the last element - must be a scope to continue *)
          let children = get_scope_children ~parent_scope_id:current_scope_id in
          let matching_child =
            List.find_opt (fun entry -> entry_matches_pattern entry pattern) children
          in
          match matching_child with
          | Some child when Option.is_some child.child_scope_id ->
              (* Found a matching header - continue traversal *)
              traverse (Option.get child.child_scope_id) rest
          | _ -> None (* No matching child found, or child is a value *))
    in
    traverse start_scope_id extraction_path

  (** Populate search results for extract-search operation: find matching search paths,
      extract along extraction paths, and highlight with deduplication based on extracted
      scope_id. Only the first occurrence (smallest shared_scope_id) for each unique
      extracted_scope_id is highlighted.

      Algorithm: 1. Find all paths matching search_path using find_matching_paths 2. For
      each match, extract along extraction_path from the shared node 3. Track
      extracted_scope_id -> smallest_shared_scope_id for deduplication 4. Highlight shared
      node and ancestors (starting from shared node's scope_id) 5. Apply quiet_path
      filtering during ancestor propagation *)
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
         (String.concat "," search_path)
         (String.concat "," extraction_path));

    try
      Hashtbl.clear results_table;

      (* Validate inputs *)
      match (search_path, extraction_path) with
      | [], _ | _, [] ->
          log_debug "ERROR: Empty paths provided";
          completed_ref := true;
          ()
      | s :: _, e :: _ when s <> e ->
          log_debug
            (Printf.sprintf "ERROR: Paths must start with same pattern (got '%s' vs '%s')"
               s e);
          completed_ref := true;
          ()
      | _ ->
          (* Find all matching paths *)
          let matching_paths = find_matching_paths ~patterns:search_path in
          log_debug
            (Printf.sprintf "Found %d matching paths" (List.length matching_paths));

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
            | Some qp_regex -> (
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
                ||
                match entry.data with
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
                          match get_scope_entry parent_id with
                          | Some parent_entry when matches_quiet_path parent_entry ->
                              (* Parent matches quiet_path, stop propagation *)
                              Hashtbl.add propagated parent_id ();
                              log_debug
                                (Printf.sprintf
                                   "  propagate: parent_id=%d matches quiet_path, \
                                    stopping"
                                   parent_id)
                          | Some parent_entry ->
                              (* Parent doesn't match quiet_path - highlight and
                                 continue *)
                              Hashtbl.add propagated parent_id ();
                              insert_entry ~is_match:false parent_entry;
                              highlighted_entries :=
                                (parent_entry.scope_id, parent_entry.seq_id)
                                :: !highlighted_entries;
                              log_debug
                                (Printf.sprintf "  propagate: highlighted parent_id=%d"
                                   parent_id);
                              propagate_to_parent parent_id
                          | None ->
                              log_debug
                                (Printf.sprintf
                                   "  propagate: parent_id=%d not found in database"
                                   parent_id)))
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
              | Some extracted_scope_id -> (
                  log_debug
                    (Printf.sprintf "  Extracted to scope_id=%d" extracted_scope_id);

                  (* Check deduplication *)
                  match Hashtbl.find_opt extracted_to_first_shared extracted_scope_id with
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
                      Hashtbl.add extracted_to_first_shared extracted_scope_id
                        shared_scope_id;
                      highlight_shared_and_ancestors shared_scope_id))
            matching_paths;

          log_debug
            (Printf.sprintf
               "Extract search complete: %d unique extractions, %d total highlights"
               (Hashtbl.length extracted_to_first_shared)
               (Hashtbl.length results_table));
          completed_ref := true
    with exn ->
      log_debug
        (Printf.sprintf "ERROR: %s\n%s" (Printexc.to_string exn)
           (Printexc.get_backtrace ()));
      completed_ref := true
end
