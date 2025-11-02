(** Database-backed tracing runtime for ppx_minidebug.

    This module provides a database backend for storing debug traces with
    content-addressed deduplication. It implements the Debug_runtime interface and stores
    logs in a SQLite database with automatic deduplication of repeated values. *)

module CFormat = Format

(** Schema management and database initialization *)
module Schema = struct
  (** Database schema version for migration management *)
  let schema_version = 3

  (** Initialize metadata database with runs table. The metadata DB tracks all runs across
      versioned database files. *)
  let initialize_meta_db db =
    Sqlite3.exec db
      {|CREATE TABLE IF NOT EXISTS runs (
          run_id INTEGER PRIMARY KEY AUTOINCREMENT,
          run_name TEXT,
          timestamp TEXT NOT NULL,
          elapsed_ns INTEGER NOT NULL,
          command_line TEXT,
          db_file TEXT NOT NULL,
          status TEXT DEFAULT 'active'
        )|}
    |> ignore;
    Sqlite3.exec db
      "CREATE INDEX IF NOT EXISTS idx_runs_timestamp ON runs(timestamp DESC)"
    |> ignore;
    Sqlite3.exec db "CREATE INDEX IF NOT EXISTS idx_runs_name ON runs(run_name)" |> ignore;

    (* Schema version tracking for metadata DB *)
    Sqlite3.exec db
      {|CREATE TABLE IF NOT EXISTS schema_version (
          version INTEGER PRIMARY KEY
        )|}
    |> ignore;
    Sqlite3.exec db "INSERT OR IGNORE INTO schema_version (version) VALUES (3)" |> ignore

  (** Initialize versioned database tables (no runs table - that's in metadata DB) *)
  let initialize_db db =
    (* Value atoms table for content-addressed storage *)
    Sqlite3.exec db
      {|CREATE TABLE IF NOT EXISTS value_atoms (
          value_id INTEGER PRIMARY KEY AUTOINCREMENT,
          value_hash TEXT UNIQUE NOT NULL,
          value_content TEXT NOT NULL,
          value_type TEXT,
          size_bytes INTEGER
        )|}
    |> ignore;
    Sqlite3.exec db "CREATE INDEX IF NOT EXISTS idx_value_hash ON value_atoms(value_hash)"
    |> ignore;

    (* Entry parents table: tracks scope_id -> parent_id relationships.
       A scope can have multiple parents due to SexpCache deduplication (DAG structure).
       Composite PRIMARY KEY allows multiple parent_id values per scope_id. *)
    Sqlite3.exec db
      {|CREATE TABLE IF NOT EXISTS entry_parents (
          scope_id INTEGER NOT NULL,
          parent_id INTEGER,
          PRIMARY KEY (scope_id, parent_id)
        )|}
    |> ignore;

    (* Entries table with foreign keys to value_atoms. scope_id: ID of parent scope (all
       children share same scope_id). seq_id: position within parent's children list (0,
       1, 2...). child_scope_id: NULL for values/results, points to new scope ID for
       headers. is_result: false for headers and parameters, true for results. *)
    Sqlite3.exec db
      {|CREATE TABLE IF NOT EXISTS entries (
          scope_id INTEGER NOT NULL,
          seq_id INTEGER NOT NULL,
          child_scope_id INTEGER,
          depth INTEGER NOT NULL,
          message_value_id INTEGER REFERENCES value_atoms(value_id),
          location_value_id INTEGER REFERENCES value_atoms(value_id),
          data_value_id INTEGER REFERENCES value_atoms(value_id),
          structure_value_id INTEGER REFERENCES value_atoms(value_id),
          elapsed_start_ns INTEGER NOT NULL,
          elapsed_end_ns INTEGER,
          is_result BOOLEAN DEFAULT FALSE,
          log_level INTEGER,
          entry_type TEXT,
          PRIMARY KEY (scope_id, seq_id)
        )|}
    |> ignore;
    Sqlite3.exec db
      "CREATE INDEX IF NOT EXISTS idx_entries_child_scope ON entries(child_scope_id)"
    |> ignore;
    Sqlite3.exec db "CREATE INDEX IF NOT EXISTS idx_entries_depth ON entries(depth)"
    |> ignore;

    (* Schema version tracking *)
    Sqlite3.exec db
      {|CREATE TABLE IF NOT EXISTS schema_version (
          version INTEGER PRIMARY KEY
        )|}
    |> ignore;
    Sqlite3.exec db
      (Printf.sprintf "INSERT OR IGNORE INTO schema_version (version) VALUES (%d)"
         schema_version)
    |> ignore;

    (* Fast mode: optimize for performance with top-level transactions. - DELETE journal:
       simpler than WAL, lower overhead - synchronous=OFF: no fsync calls (trades
       durability for speed) - locking_mode=NORMAL: allows lock release on COMMIT (between
       top-level scopes)

       Each top-level scope is wrapped in BEGIN...COMMIT, giving transaction performance
       while allowing database access between top-level calls. *)
    Sqlite3.exec db "PRAGMA journal_mode=DELETE" |> ignore;
    Sqlite3.exec db "PRAGMA synchronous=OFF" |> ignore
end

(** Content-addressed value storage with O(1) deduplication *)
module ValueIntern = struct
  type t = {
    db : Sqlite3.db; [@warning "-69"]
    insert_stmt : Sqlite3.stmt;
    lookup_stmt : Sqlite3.stmt;
  }

  (** Create a new value interning context *)
  let create db =
    let insert_stmt =
      Sqlite3.prepare db
        "INSERT OR IGNORE INTO value_atoms (value_hash, value_content, value_type, \
         size_bytes) VALUES (?, ?, ?, ?)"
    in
    let lookup_stmt =
      Sqlite3.prepare db "SELECT value_id FROM value_atoms WHERE value_hash = ?"
    in
    { db; insert_stmt; lookup_stmt }

  (** Hash a string value for content addressing *)
  let hash_value content = Digest.to_hex (Digest.string content)

  (** Intern a value and return its value_id *)
  let intern t ~value_type content =
    let hash = hash_value content in
    let size = String.length content in

    (* Try to find existing value *)
    Sqlite3.reset t.lookup_stmt |> ignore;
    Sqlite3.bind_text t.lookup_stmt 1 hash |> ignore;

    match Sqlite3.step t.lookup_stmt with
    | Sqlite3.Rc.ROW ->
        (* Value already exists, return its ID *)
        let value_id = Sqlite3.Data.to_int_exn (Sqlite3.column t.lookup_stmt 0) in
        Sqlite3.reset t.lookup_stmt |> ignore;
        (* Reset to release locks *)
        value_id
    | _ ->
        Sqlite3.reset t.lookup_stmt |> ignore;

        (* Reset before insert *)

        (* Insert new value *)
        Sqlite3.reset t.insert_stmt |> ignore;
        Sqlite3.bind_text t.insert_stmt 1 hash |> ignore;
        Sqlite3.bind_text t.insert_stmt 2 content |> ignore;
        Sqlite3.bind_text t.insert_stmt 3 value_type |> ignore;
        Sqlite3.bind_int t.insert_stmt 4 size |> ignore;
        (match Sqlite3.step t.insert_stmt with
        | Sqlite3.Rc.DONE -> ()
        | _ -> failwith "Failed to insert value");
        Sqlite3.reset t.insert_stmt |> ignore;

        (* Reset to release locks *)

        (* Get the ID of the newly inserted or existing value *)
        Sqlite3.reset t.lookup_stmt |> ignore;
        Sqlite3.bind_text t.lookup_stmt 1 hash |> ignore;
        let value_id =
          match Sqlite3.step t.lookup_stmt with
          | Sqlite3.Rc.ROW -> Sqlite3.Data.to_int_exn (Sqlite3.column t.lookup_stmt 0)
          | _ -> failwith "Failed to retrieve value_id after insert"
        in
        Sqlite3.reset t.lookup_stmt |> ignore;
        (* Reset to release locks *)
        value_id

  (** Finalize prepared statements *)
  let finalize t =
    Sqlite3.finalize t.insert_stmt |> ignore;
    Sqlite3.finalize t.lookup_stmt |> ignore
end

(** Extended config module type *)
module type Db_config = sig
  include Minidebug_runtime.Shared_config
end

(** Find the next available run number by checking the metadata DB and filesystem.
    This is robust against multi-process scenarios. *)
let find_next_run_number meta_handle base_filename =
  (* First, check metadata DB for highest run number by parsing db_file names *)
  let max_from_meta =
    let stmt = Sqlite3.prepare meta_handle "SELECT db_file FROM runs" in
    let base_pattern = Filename.basename (Filename.remove_extension base_filename) ^ "_" in
    let ext = Filename.extension base_filename in
    let rec collect_max acc =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW -> (
          match Sqlite3.column stmt 0 with
          | Sqlite3.Data.TEXT db_file -> (
              (* Parse filename like "test_expect_test_5.db" *)
              if String.starts_with ~prefix:base_pattern db_file
                 && String.ends_with ~suffix:ext db_file then
                try
                  let start_idx = String.length base_pattern in
                  let end_idx = String.length db_file - String.length ext in
                  let num_str = String.sub db_file start_idx (end_idx - start_idx) in
                  let num = int_of_string num_str in
                  collect_max (max acc (Some num))
                with _ -> collect_max acc
              else collect_max acc)
          | _ -> collect_max acc)
      | Sqlite3.Rc.DONE -> acc
      | _ -> acc
    in
    let result = collect_max None in
    Sqlite3.finalize stmt |> ignore;
    result
  in

  (* Also check filesystem for any orphaned files *)
  let max_from_fs =
    let base = Filename.remove_extension base_filename in
    let dir = Filename.dirname base_filename in
    let base_name = Filename.basename base in
    let ext = Filename.extension base_filename in
    try
      let files = Sys.readdir dir in
      Array.fold_left
        (fun acc file ->
          let prefix = base_name ^ "_" in
          if String.starts_with ~prefix file && String.ends_with ~suffix:ext file then
            try
              let num_str =
                String.sub file (String.length prefix)
                  (String.length file - String.length prefix - String.length ext)
              in
              let num = int_of_string num_str in
              max acc (Some num)
            with _ -> acc
          else acc)
        None files
    with _ -> None
  in

  (* Take the maximum of both sources and add 1 *)
  let max_run =
    match (max_from_meta, max_from_fs) with
    | Some a, Some b -> max a b
    | Some a, None | None, Some a -> a
    | None, None -> 0
  in
  max_run + 1

(** Database backend implementing Debug_runtime interface *)
module DatabaseBackend (Log_to : Db_config) : Minidebug_runtime.Debug_runtime = struct
  open Log_to

  let log_level = ref init_log_level
  let max_nesting_depth = ref None
  let max_num_children = ref None

  (** Calculate the size of a sexp (number of atoms) *)
  let sexp_size sexp =
    let open Sexplib0.Sexp in
    let rec loop = function
      | Atom _ -> 1
      | List l -> List.fold_left ( + ) 0 (List.map loop l)
    in
    loop sexp

  type entry_info = {
    scope_id : int;
    parent_id : int option; [@warning "-69"]
    depth : int; [@warning "-69"]
    elapsed_start : Mtime.span; [@warning "-69"]
    mutable num_children : int;
    message : string; [@warning "-69"]
    fname : string; [@warning "-69"]
    log_level : int; [@warning "-69"]
  }

  let db_path = ref None
  let db = ref None
  let meta_db = ref None (* Metadata database handle *)
  let run_id = ref None (* Run ID from metadata database *)
  let intern = ref None

  let transaction_started =
    ref false (* Track if we've started the long-running transaction *)

  let stack : entry_info list ref = ref []
  let hidden_entries = ref []
  let root_seq_counter = ref 0 (* Counter for root-level entries *)
  let boxify_scope_id_counter = ref 0 (* Counter for synthetic scope_ids from boxify *)

  let orphaned_seq_counters =
    ref [] (* Per-scope_id counters for orphaned logs: (scope_id * seq_counter) list *)

  let logged_exceptions = ref []
  (* Track exceptions that have already been logged using physical equality *)

  (** Cache for boxified sexp structures - maps sexp content hash to scope_id. Enables
      deduplication of repeated substructures. Uses MD5 hash of sexp string for proper
      content-based deduplication. *)
  module SexpCache = struct
    let cache : (string, int) Hashtbl.t = Hashtbl.create 1000

    let hash sexp =
      (* Use MD5 hash of the sexp string representation for proper content equality *)
      let str = Sexplib0.Sexp.to_string sexp in
      Digest.to_hex (Digest.string str)

    let find_opt sexp =
      let h = hash sexp in
      Hashtbl.find_opt cache h

    let add sexp scope_id =
      let h = hash sexp in
      Hashtbl.add cache h scope_id
  end

  (** Initialize database connection *)
  let initialize_database base_filename =
    (* Open/create metadata database: debug.db -> debug_meta.db *)
    let meta_filename =
      let base = Filename.remove_extension base_filename in
      Printf.sprintf "%s_meta.db" base
    in
    let meta_handle = Sqlite3.db_open meta_filename in
    Sqlite3.busy_timeout meta_handle 5000;
    Schema.initialize_meta_db meta_handle;
    meta_db := Some meta_handle;

    (* Find next available run number by checking metadata DB and filesystem.
       This is robust against multi-process scenarios. *)
    let run_number = find_next_run_number meta_handle base_filename in

    (* Version the filename with run number: debug.db -> debug_1.db, debug_2.db, etc. *)
    let filename =
      let base = Filename.remove_extension base_filename in
      let ext = Filename.extension base_filename in
      Printf.sprintf "%s_%d%s" base run_number ext
    in

    (* Verify the file doesn't exist - if it does, we have a race condition *)
    if Sys.file_exists filename then
      failwith
        (Printf.sprintf
           "Race condition detected: database file '%s' already exists. This should not \
            happen with proper run number allocation."
           filename);

    let db_handle = Sqlite3.db_open filename in
    Sqlite3.busy_timeout db_handle 5000;
    (* Retry for up to 5 seconds on BUSY *)
    Schema.initialize_db db_handle;
    db := Some db_handle;
    db_path := Some filename;

    (* Create/update symlink from base filename to versioned file for convenience. This
       allows tools to reference the base name (debug.db) and get the latest run. *)
    (try
       if Sys.file_exists base_filename then Sys.remove base_filename;
       Unix.symlink (Filename.basename filename) base_filename
     with _ -> ());

    (* Create value interning context *)
    intern := Some (ValueIntern.create db_handle);

    (* Create new run record in metadata DB *)
    let timestamp =
      let buf = Buffer.create 512 in
      let formatter = CFormat.formatter_of_buffer buf in
      let tz_offset_s = Ptime_clock.current_tz_offset_s () in
      Ptime.(pp_human ~frac_s:6 ?tz_offset_s ()) formatter (Ptime_clock.now ());
      CFormat.pp_print_flush formatter ();
      Buffer.contents buf
    in
    let elapsed_ns =
      match Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns (Mtime_clock.elapsed ()) with
      | None -> 0
      | Some ns -> ns
    in
    let cmd = String.concat " " (Array.to_list Sys.argv) in
    (* Strip trailing space from global_prefix for storage in metadata DB *)
    let run_name_str =
      if global_prefix = "" then None else Some (String.trim global_prefix)
    in

    (* Check if metadata DB is accessible before attempting INSERT *)
    let check_stmt = Sqlite3.prepare meta_handle "SELECT 1" in
    (match Sqlite3.step check_stmt with
    | Sqlite3.Rc.ROW | Sqlite3.Rc.DONE -> ()
    | rc ->
        Sqlite3.finalize check_stmt |> ignore;
        let err_msg =
          Printf.sprintf
            "Metadata DB '%s' is not accessible (possibly locked): %s (error: %s)"
            meta_filename (Sqlite3.Rc.to_string rc) (Sqlite3.errmsg meta_handle)
        in
        failwith err_msg);
    Sqlite3.finalize check_stmt |> ignore;

    let stmt =
      Sqlite3.prepare meta_handle
        "INSERT INTO runs (run_name, timestamp, elapsed_ns, command_line, db_file, \
         status) VALUES (?, ?, ?, ?, ?, ?)"
    in
    (match run_name_str with
    | Some name -> Sqlite3.bind_text stmt 1 name
    | None -> Sqlite3.bind stmt 1 Sqlite3.Data.NULL)
    |> ignore;
    Sqlite3.bind_text stmt 2 timestamp |> ignore;
    Sqlite3.bind_int stmt 3 elapsed_ns |> ignore;
    Sqlite3.bind_text stmt 4 cmd |> ignore;
    Sqlite3.bind_text stmt 5 (Filename.basename filename) |> ignore;
    Sqlite3.bind_text stmt 6 "active" |> ignore;
    (match Sqlite3.step stmt with
    | Sqlite3.Rc.DONE -> ()
    | rc ->
        let err_msg =
          Printf.sprintf
            "Failed to create run in metadata DB '%s': %s (error: %s)\n\
             Context: run_name=%s, db_file=%s, cmd=%s"
            meta_filename (Sqlite3.Rc.to_string rc) (Sqlite3.errmsg meta_handle)
            (Option.value ~default:"<none>" run_name_str)
            (Filename.basename filename) cmd
        in
        failwith err_msg);
    Sqlite3.finalize stmt |> ignore;

    (* Get the run_id that was just inserted *)
    run_id := Some (Int64.to_int (Sqlite3.last_insert_rowid meta_handle));

    (* Register at_exit handler to automatically commit on normal exit *)
    at_exit (fun () ->
        try
          if !transaction_started then (
            Sqlite3.exec db_handle "COMMIT" |> ignore;
            transaction_started := false)
        with _ -> ());

    (* Register signal handlers to commit on interrupt (Ctrl+C, SIGTERM) *)
    let commit_and_exit _signal =
      (try
         if !transaction_started then (
           Sqlite3.exec db_handle "COMMIT" |> ignore;
           transaction_started := false;
           Printf.eprintf "\nDebug trace committed to %s before exit.\n%!" filename)
       with _ -> ());
      (* Re-raise signal to allow default handler to run *)
      raise Sys.Break
    in
    Sys.set_signal Sys.sigint (Sys.Signal_handle commit_and_exit);
    Sys.set_signal Sys.sigterm (Sys.Signal_handle commit_and_exit)

  (** Get or create database connection *)
  let get_db () =
    match !db with
    | Some db -> db
    | None ->
        let base_filename = debug_ch_name () in
        let filename =
          if Filename.check_suffix base_filename ".db" then base_filename
          else base_filename ^ ".db"
        in
        initialize_database filename;
        Option.get !db

  let get_intern () = Option.get !intern
  let check_log_level level = level <= !log_level

  (** Start transaction when entering a top-level scope. This is called from open_log when
      stack is empty. *)
  let begin_toplevel_transaction () =
    if not !transaction_started then (
      let db = get_db () in
      Sqlite3.exec db "BEGIN TRANSACTION" |> ignore;
      transaction_started := true)

  (** Commit transaction when leaving a top-level scope. This is called from close_log
      when stack becomes empty. This unlocks the database so other processes can read it.
  *)
  let commit_toplevel_transaction () =
    if !transaction_started then (
      let db = get_db () in
      Sqlite3.exec db "COMMIT" |> ignore;
      transaction_started := false)

  let should_log_path fname message =
    match Log_to.path_filter with
    | None -> true
    | Some (`Whitelist re) -> Re.execp re (fname ^ "/" ^ message)
    | Some (`Blacklist re) -> not (Re.execp re (fname ^ "/" ^ message))

  let should_log ~log_level ~fname ~message =
    check_log_level log_level && should_log_path fname message

  let open_log ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message ~scope_id
      ~log_level log_type =
    if not (should_log ~log_level ~fname ~message) then
      hidden_entries := scope_id :: !hidden_entries
    else
      let db = get_db () in
      let intern = get_intern () in
      let parent_scope_id, seq_id =
        match !stack with
        | [] ->
            (* Entering top-level scope - start transaction *)
            begin_toplevel_transaction ();
            let seq = !root_seq_counter in
            incr root_seq_counter;
            (None, seq)
        | parent :: _ -> (Some parent.scope_id, parent.num_children)
      in
      let depth = List.length !stack in
      let elapsed_start = Mtime_clock.elapsed () in

      (* Insert into entry_parents table *)
      let parent_stmt =
        Sqlite3.prepare db "INSERT INTO entry_parents (scope_id, parent_id) VALUES (?, ?)"
      in
      Sqlite3.bind_int parent_stmt 1 scope_id |> ignore;
      (match parent_scope_id with
      | None -> Sqlite3.bind parent_stmt 2 Sqlite3.Data.NULL
      | Some pid -> Sqlite3.bind_int parent_stmt 2 pid)
      |> ignore;
      (match Sqlite3.step parent_stmt with
      | Sqlite3.Rc.DONE -> ()
      | _ -> failwith "Failed to insert entry parent");
      Sqlite3.finalize parent_stmt |> ignore;

      (* Intern message *)
      let message_value_id = ValueIntern.intern intern ~value_type:"message" message in

      (* Intern location *)
      let location =
        Printf.sprintf "%s:%d:%d-%d:%d" fname start_lnum start_colnum end_lnum end_colnum
      in
      let location_value_id = ValueIntern.intern intern ~value_type:"location" location in

      (* Insert header row into entries table *)
      let stmt =
        Sqlite3.prepare db
          "INSERT INTO entries (scope_id, seq_id, child_scope_id, depth, \
           message_value_id, location_value_id, elapsed_start_ns, log_level, entry_type) \
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
      in
      (* scope_id is parent's scope_id (or 0 for root) *)
      (match parent_scope_id with
      | None -> Sqlite3.bind_int stmt 1 0 (* Root entries have scope_id = 0 *)
      | Some pid -> Sqlite3.bind_int stmt 1 pid)
      |> ignore;
      Sqlite3.bind_int stmt 2 seq_id |> ignore;
      Sqlite3.bind_int stmt 3 scope_id |> ignore;
      (* child_scope_id points to new scope *)
      Sqlite3.bind_int stmt 4 depth |> ignore;
      Sqlite3.bind_int stmt 5 message_value_id |> ignore;
      Sqlite3.bind_int stmt 6 location_value_id |> ignore;
      let elapsed_ns =
        match Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns elapsed_start with
        | None -> 0
        | Some ns -> ns
      in
      Sqlite3.bind_int stmt 7 elapsed_ns |> ignore;
      Sqlite3.bind_int stmt 8 log_level |> ignore;
      let entry_type_str =
        match log_type with `Diagn -> "diagn" | `Debug -> "debug" | `Track -> "track"
      in
      Sqlite3.bind_text stmt 9 entry_type_str |> ignore;

      (match Sqlite3.step stmt with
      | Sqlite3.Rc.DONE -> ()
      | rc ->
          let errmsg = Sqlite3.errmsg db in
          (* Query existing entry if there's a conflict *)
          let existing_info =
            let query_stmt =
              Sqlite3.prepare db
                "SELECT child_scope_id, depth, message_value_id, location_value_id, \
                 log_level, entry_type FROM entries WHERE scope_id = ? AND seq_id = ?"
            in
            Sqlite3.bind_int query_stmt 1
              (match parent_scope_id with None -> 0 | Some pid -> pid)
            |> ignore;
            Sqlite3.bind_int query_stmt 2 seq_id |> ignore;
            match Sqlite3.step query_stmt with
            | Sqlite3.Rc.ROW ->
                let existing =
                  Printf.sprintf
                    "Existing: child_scope_id=%s, depth=%s, message_value_id=%s, \
                     location_value_id=%s, log_level=%s, entry_type=%s"
                    (Sqlite3.Data.to_string_debug (Sqlite3.column query_stmt 0))
                    (Sqlite3.Data.to_string_debug (Sqlite3.column query_stmt 1))
                    (Sqlite3.Data.to_string_debug (Sqlite3.column query_stmt 2))
                    (Sqlite3.Data.to_string_debug (Sqlite3.column query_stmt 3))
                    (Sqlite3.Data.to_string_debug (Sqlite3.column query_stmt 4))
                    (Sqlite3.Data.to_string_debug (Sqlite3.column query_stmt 5))
                in
                Sqlite3.finalize query_stmt |> ignore;
                existing
            | _ ->
                Sqlite3.finalize query_stmt |> ignore;
                "No existing entry found"
          in
          failwith
            (Printf.sprintf
               "Failed to insert header entry: %s (rc=%s)\n\
                Trying to insert: scope_id=%d, seq_id=%d, child_scope_id=%d, depth=%d, \
                log_level=%d, entry_type=%s\n\
                %s"
               errmsg (Sqlite3.Rc.to_string rc)
               (match parent_scope_id with None -> 0 | Some pid -> pid)
               seq_id scope_id depth log_level entry_type_str existing_info));
      Sqlite3.finalize stmt |> ignore;

      (* Push to stack *)
      let entry =
        {
          scope_id;
          parent_id = parent_scope_id;
          depth;
          elapsed_start;
          num_children = 0;
          message;
          fname;
          log_level;
        }
      in
      stack := entry :: !stack;

      (* Update parent's child count *)
      match !stack with
      | _ :: parent :: _ -> parent.num_children <- parent.num_children + 1
      | _ -> ()

  let open_log_no_source ~message ~scope_id ~log_level log_type =
    open_log ~fname:"" ~start_lnum:0 ~start_colnum:0 ~end_lnum:0 ~end_colnum:0 ~message
      ~scope_id ~log_level log_type

  (** Generate a fresh synthetic scope_id for boxified values *)
  let get_boxify_scope_id () =
    decr boxify_scope_id_counter;
    !boxify_scope_id_counter

  (** Helper to insert a header entry with data into the database. Used for
      indentation-based sub-scopes. *)
  let insert_header_with_data ~parent_scope_id ~seq_id ~new_scope_id ~depth ~message
      ~content_str ~is_result =
    let db = get_db () in
    let intern = get_intern () in

    (* Insert into entry_parents table for the new scope *)
    let parent_stmt =
      Sqlite3.prepare db "INSERT INTO entry_parents (scope_id, parent_id) VALUES (?, ?)"
    in
    Sqlite3.bind_int parent_stmt 1 new_scope_id |> ignore;
    Sqlite3.bind_int parent_stmt 2 parent_scope_id |> ignore;
    (match Sqlite3.step parent_stmt with
    | Sqlite3.Rc.DONE -> ()
    | _ -> failwith "Failed to insert entry parent for header");
    Sqlite3.finalize parent_stmt |> ignore;

    (* Intern the message (parameter/result name) *)
    let message_value_id = ValueIntern.intern intern ~value_type:"message" message in

    (* Intern data content *)
    let value_type = if is_result then "result" else "value" in
    let data_value_id = ValueIntern.intern intern ~value_type content_str in

    (* Get elapsed time *)
    let elapsed_start = Mtime_clock.elapsed () in
    let elapsed_ns =
      match Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns elapsed_start with
      | None -> 0
      | Some ns -> ns
    in

    (* Insert header row with data into entries table *)
    let stmt =
      Sqlite3.prepare db
        "INSERT INTO entries (scope_id, seq_id, child_scope_id, depth, message_value_id, \
         data_value_id, elapsed_start_ns, elapsed_end_ns, is_result, log_level, \
         entry_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    in
    Sqlite3.bind_int stmt 1 parent_scope_id |> ignore;
    Sqlite3.bind_int stmt 2 seq_id |> ignore;
    Sqlite3.bind_int stmt 3 new_scope_id |> ignore;
    (* child_scope_id points to new scope *)
    Sqlite3.bind_int stmt 4 depth |> ignore;
    Sqlite3.bind_int stmt 5 message_value_id |> ignore;
    Sqlite3.bind_int stmt 6 data_value_id |> ignore;
    Sqlite3.bind_int stmt 7 elapsed_ns |> ignore;
    Sqlite3.bind_int stmt 8 elapsed_ns |> ignore;
    Sqlite3.bind_int stmt 9 (if is_result then 1 else 0) |> ignore;
    Sqlite3.bind_int stmt 10 !log_level |> ignore;
    Sqlite3.bind_text stmt 11 "value" |> ignore;

    (match Sqlite3.step stmt with
    | Sqlite3.Rc.DONE -> ()
    | rc ->
        let err_msg =
          Printf.sprintf "Failed to insert header with data: %s (scope_id=%d, seq_id=%d)"
            (Sqlite3.Rc.to_string rc) parent_scope_id seq_id
        in
        Sqlite3.finalize stmt |> ignore;
        failwith err_msg);
    Sqlite3.finalize stmt |> ignore

  (** Helper to insert a value entry into the database *)
  let insert_value_entry ~scope_id ~seq_id ~depth ~message ~content_str ~is_result =
    let db = get_db () in
    let intern = get_intern () in

    (* Intern the message (parameter/result name) *)
    let message_value_id = ValueIntern.intern intern ~value_type:"message" message in

    (* Intern value content *)
    let value_type = if is_result then "result" else "value" in
    let data_value_id = ValueIntern.intern intern ~value_type content_str in

    (* Get elapsed time *)
    let elapsed_start = Mtime_clock.elapsed () in
    let elapsed_ns =
      match Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns elapsed_start with
      | None -> 0
      | Some ns -> ns
    in

    (* Insert value row into entries table *)
    let stmt =
      Sqlite3.prepare db
        "INSERT INTO entries (scope_id, seq_id, child_scope_id, depth, message_value_id, \
         data_value_id, elapsed_start_ns, elapsed_end_ns, is_result, log_level, \
         entry_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    in
    Sqlite3.bind_int stmt 1 scope_id |> ignore;
    Sqlite3.bind_int stmt 2 seq_id |> ignore;
    Sqlite3.bind stmt 3 Sqlite3.Data.NULL |> ignore;
    (* child_scope_id is NULL for values *)
    Sqlite3.bind_int stmt 4 depth |> ignore;
    Sqlite3.bind_int stmt 5 message_value_id |> ignore;
    Sqlite3.bind_int stmt 6 data_value_id |> ignore;
    Sqlite3.bind_int stmt 7 elapsed_ns |> ignore;
    Sqlite3.bind_int stmt 8 elapsed_ns |> ignore;
    Sqlite3.bind_int stmt 9 (if is_result then 1 else 0) |> ignore;
    Sqlite3.bind_int stmt 10 1 |> ignore;
    (* log_level *)
    Sqlite3.bind_text stmt 11 "value" |> ignore;

    (match Sqlite3.step stmt with
    | Sqlite3.Rc.DONE -> ()
    | rc ->
        let err_msg =
          Printf.sprintf
            "Failed to insert value row: %s (scope_id=%d, seq_id=%d, depth=%d, \
             message=%S, content=%S)"
            (Sqlite3.Rc.to_string rc) scope_id seq_id depth message content_str
        in
        Sqlite3.finalize stmt |> ignore;
        failwith err_msg);
    Sqlite3.finalize stmt |> ignore

  (** Boxify a sexp: split it into multiple database entries with synthetic scope_ids.
      Directly inserts entries into the database, creating proper nested scope structure.
      Returns the number of entries inserted. *)
  let boxify ~descr ~depth ~parent_scope_id ~is_result sexp =
    let open Sexplib0.Sexp in
    (* Get seq_id allocator from parent's counter *)
    let parent_entry = List.find_opt (fun e -> e.scope_id = parent_scope_id) !stack in
    let seq_counter =
      ref (match parent_entry with Some p -> p.num_children | None -> 0)
    in
    let get_next_seq () =
      let s = !seq_counter in
      incr seq_counter;
      s
    in

    let boxify_threshold = 10 in
    let num_inserted = ref 0 in

    let rec loop ~is_toplevel ~depth ~parent_eid ~get_seq sexp =
      let message =
        if is_toplevel then match descr with Some d -> d | None -> "" else ""
      in
      let is_result = is_toplevel && is_result in

      (* Check cache for this sexp - reuse existing scope_id if found *)
      (* Uses MD5 content hash to avoid collisions from structurally similar sexps *)
      match SexpCache.find_opt sexp with
      | Some cached_scope_id when not is_toplevel ->
          (* Cache hit! Reuse the existing scope_id instead of creating new entries. We
             create a reference to the cached scope by inserting a header entry that
             points to it. We also insert into entry_parents to record this additional
             parent relationship (DAG structure). Only cache non-toplevel sexps to
             preserve descr/is_result. *)
          let seq_id = get_seq () in
          let db = get_db () in
          let intern = get_intern () in

          (* Insert into entry_parents to record the additional parent relationship *)
          let parent_stmt =
            Sqlite3.prepare db
              "INSERT OR IGNORE INTO entry_parents (scope_id, parent_id) VALUES (?, ?)"
          in
          Sqlite3.bind_int parent_stmt 1 cached_scope_id |> ignore;
          Sqlite3.bind_int parent_stmt 2 parent_eid |> ignore;
          (match Sqlite3.step parent_stmt with
          | Sqlite3.Rc.DONE -> ()
          | _ -> failwith "Failed to insert additional parent relationship for cache hit");
          Sqlite3.finalize parent_stmt |> ignore;

          (* Get the first atom from the cached sexp for the data field *)
          let first_atom =
            match sexp with
            | Atom s -> Some s
            | List (Atom s :: _) -> Some s
            | List _ -> Some "<scope>"
          in

          (* Intern the message if present *)
          let message_value_id =
            if message = "" then None
            else Some (ValueIntern.intern intern ~value_type:"message" message)
          in

          (* Intern data if present *)
          let data_value_id =
            match first_atom with
            | Some d -> Some (ValueIntern.intern intern ~value_type:"value" d)
            | None -> None
          in

          (* Get elapsed time *)
          let elapsed_start = Mtime_clock.elapsed () in
          let elapsed_ns =
            match Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns elapsed_start with
            | None -> 0
            | Some ns -> ns
          in

          (* Insert header row that references the cached scope *)
          let stmt =
            Sqlite3.prepare db
              "INSERT INTO entries (scope_id, seq_id, child_scope_id, depth, \
               message_value_id, data_value_id, elapsed_start_ns, elapsed_end_ns, \
               is_result, log_level, entry_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, \
               ?)"
          in
          Sqlite3.bind_int stmt 1 parent_eid |> ignore;
          Sqlite3.bind_int stmt 2 seq_id |> ignore;
          Sqlite3.bind_int stmt 3 cached_scope_id |> ignore;
          Sqlite3.bind_int stmt 4 depth |> ignore;
          (match message_value_id with
          | Some mid -> Sqlite3.bind_int stmt 5 mid
          | None -> Sqlite3.bind stmt 5 Sqlite3.Data.NULL)
          |> ignore;
          (match data_value_id with
          | Some did -> Sqlite3.bind_int stmt 6 did
          | None -> Sqlite3.bind stmt 6 Sqlite3.Data.NULL)
          |> ignore;
          Sqlite3.bind_int stmt 7 elapsed_ns |> ignore;
          Sqlite3.bind_int stmt 8 elapsed_ns |> ignore;
          Sqlite3.bind_int stmt 9 0 |> ignore;
          Sqlite3.bind_int stmt 10 !log_level |> ignore;
          Sqlite3.bind_text stmt 11 "value" |> ignore;

          (match Sqlite3.step stmt with
          | Sqlite3.Rc.DONE -> ()
          | rc ->
              failwith
                (Printf.sprintf "Failed to insert cached reference: %s"
                   (Sqlite3.Rc.to_string rc)));
          Sqlite3.finalize stmt |> ignore;
          incr num_inserted
      | _ -> (
          (* Cache miss or toplevel - process normally and cache the result *)
          (* Process the sexp and return the scope_id created for it (if any) *)
          let process_and_return_scope () =
            (* Check structure FIRST before applying size threshold. Always decompose List
               (Atom _ :: _) structures (ADT constructors) regardless of size to preserve
               navigable tree structure. *)
            match sexp with
            | List (Atom s :: body) ->
                (* Create a synthetic scope with first atom as header *)
                let synthetic_id = get_boxify_scope_id () in
                (* Insert header entry with first atom as content *)
                insert_header_with_data ~parent_scope_id:parent_eid ~seq_id:(get_seq ())
                  ~new_scope_id:synthetic_id ~depth ~message ~content_str:s ~is_result;
                incr num_inserted;
                (* Create new seq counter for the synthetic scope *)
                let synthetic_seq = ref 0 in
                let get_synthetic_seq () =
                  let s = !synthetic_seq in
                  incr synthetic_seq;
                  s
                in
                (* Recursively process remaining elements under the synthetic scope *)
                List.iter
                  (fun child ->
                    loop ~is_toplevel:false ~depth:(depth + 1) ~parent_eid:synthetic_id
                      ~get_seq:get_synthetic_seq child)
                  body;
                (* Return the scope_id we created for THIS sexp *)
                Some synthetic_id
            | List body when is_toplevel ->
                loop ~is_toplevel ~depth ~parent_eid ~get_seq
                  (List (Atom "<scope>" :: body));
                None
            | _ when sexp_size sexp < boxify_threshold ->
                (* Small enough - insert as single entry with pretty-printed content *)
                let content = Sexplib0.Sexp.to_string_hum sexp in
                insert_value_entry ~scope_id:parent_eid ~seq_id:(get_seq ()) ~depth
                  ~message ~content_str:content ~is_result;
                incr num_inserted;
                None
            | Atom s ->
                insert_value_entry ~scope_id:parent_eid ~seq_id:(get_seq ()) ~depth
                  ~message ~content_str:s ~is_result;
                incr num_inserted;
                None
            | List [] ->
                if is_toplevel then
                  if message <> "" || is_result then (
                    insert_value_entry ~scope_id:parent_eid ~seq_id:(get_seq ()) ~depth
                      ~message ~content_str:"()" ~is_result;
                    incr num_inserted);
                None
            | List [ s ] ->
                loop ~is_toplevel ~depth:(depth + 1) ~parent_eid ~get_seq s;
                None
            | List l ->
                (* Process each element of the list directly under current parent *)
                List.iter
                  (fun child ->
                    loop ~is_toplevel:false ~depth:(depth + 1) ~parent_eid ~get_seq child)
                  l;
                None
          in

          (* Process the sexp and get the scope_id created for it *)
          let created_scope_id_opt = process_and_return_scope () in

          (* Cache the scope_id if one was created and this is not a toplevel sexp *)
          match created_scope_id_opt with
          | Some created_scope_id when not is_toplevel ->
              SexpCache.add sexp created_scope_id
          | _ -> ())
    in

    loop ~is_toplevel:true ~depth ~parent_eid:parent_scope_id ~get_seq:get_next_seq sexp;

    (* Update parent's num_children counter *)
    (match parent_entry with
    | Some p -> p.num_children <- !seq_counter
    | None -> ());

    !num_inserted

  let log_value_common ~descr ~scope_id ~log_level:_ ~is_result content_str =
    if List.mem scope_id !hidden_entries then ()
    else
      let db = get_db () in
      let intern = get_intern () in

      (* Use stack top for dynamic scoping (supports %log_entry). If scope_id is in the
         stack, we're inside a valid scope, so use stack top. If scope_id is NOT in stack,
         treat as orphaned. *)
      let depth, seq_id, parent_scope_id =
        if List.exists (fun e -> e.scope_id = scope_id) !stack then
          (* scope_id is somewhere in the stack, use dynamic scoping (stack top) *)
          match !stack with
          | parent_entry :: _ ->
              (parent_entry.depth + 1, parent_entry.num_children, parent_entry.scope_id)
          | [] -> assert false (* Can't happen since we just checked stack is non-empty *)
        else
          (* scope_id not in stack - orphaned log. Query database for max seq_id to avoid
             conflicts with existing values/results *)
          let seq =
            match List.assoc_opt scope_id !orphaned_seq_counters with
            | Some counter ->
                let s = !counter in
                incr counter;
                s
            | None ->
                (* Find the maximum seq_id already used for this scope_id *)
                let max_seq_stmt =
                  Sqlite3.prepare db
                    "SELECT COALESCE(MAX(seq_id), -1) FROM entries WHERE scope_id = ?"
                in
                Sqlite3.bind_int max_seq_stmt 1 scope_id |> ignore;
                let max_seq =
                  match Sqlite3.step max_seq_stmt with
                  | Sqlite3.Rc.ROW ->
                      Sqlite3.Data.to_int_exn (Sqlite3.column max_seq_stmt 0)
                  | _ -> -1
                in
                Sqlite3.reset max_seq_stmt |> ignore;
                Sqlite3.finalize max_seq_stmt |> ignore;

                let start_seq = max_seq + 1 in
                let counter = ref (start_seq + 1) in
                orphaned_seq_counters := (scope_id, counter) :: !orphaned_seq_counters;
                start_seq
          in
          ( List.length !stack,
            seq,
            scope_id (* Use the passed scope_id for orphaned logs *) )
      in

      (* Intern the message (parameter/result name) *)
      let message =
        match descr with Some d -> d | None -> if is_result then "=>" else ""
      in
      let message_value_id = ValueIntern.intern intern ~value_type:"message" message in

      (* Intern value content *)
      let value_type = if is_result then "result" else "value" in
      let data_value_id = ValueIntern.intern intern ~value_type content_str in

      (* Get elapsed time *)
      let elapsed_start = Mtime_clock.elapsed () in
      let elapsed_ns =
        match Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns elapsed_start with
        | None -> 0
        | Some ns -> ns
      in

      (* Insert value row into entries table *)
      let stmt =
        Sqlite3.prepare db
          "INSERT INTO entries (scope_id, seq_id, child_scope_id, depth, \
           message_value_id, data_value_id, elapsed_start_ns, elapsed_end_ns, is_result, \
           log_level, entry_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
      in
      Sqlite3.bind_int stmt 1 parent_scope_id |> ignore;
      (* scope_id is the parent scope *)
      Sqlite3.bind_int stmt 2 seq_id |> ignore;
      Sqlite3.bind stmt 3 Sqlite3.Data.NULL |> ignore;
      (* child_scope_id is NULL for values *)
      Sqlite3.bind_int stmt 4 depth |> ignore;
      Sqlite3.bind_int stmt 5 message_value_id |> ignore;
      Sqlite3.bind_int stmt 6 data_value_id |> ignore;
      Sqlite3.bind_int stmt 7 elapsed_ns |> ignore;
      Sqlite3.bind_int stmt 8 elapsed_ns |> ignore;
      (* Same for start and end for value nodes *)
      Sqlite3.bind_int stmt 9 (if is_result then 1 else 0) |> ignore;
      Sqlite3.bind_int stmt 10 1 |> ignore;
      (* log_level *)
      Sqlite3.bind_text stmt 11 "value" |> ignore;

      (* entry_type *)
      (match Sqlite3.step stmt with
      | Sqlite3.Rc.DONE -> ()
      | rc ->
          let err_msg = Sqlite3.errmsg db in
          failwith
            (Printf.sprintf
               "Failed to insert value row: %s (error: %s, scope_id=%d, seq_id=%d)"
               (Sqlite3.Rc.to_string rc) err_msg parent_scope_id seq_id));
      Sqlite3.finalize stmt |> ignore;

      (* Increment parent's num_children counter *)
      match !stack with
      | parent_entry :: _ -> parent_entry.num_children <- parent_entry.num_children + 1
      | [] -> ()

  let log_value_sexp ?descr ~scope_id ~log_level ~is_result v =
    if not (check_log_level log_level) then ()
    else if List.mem scope_id !hidden_entries then ()
    else
      (* Force the lazy value to get actual content *)
      let sexp = Lazy.force v in
      if sexp = Sexplib0.Sexp.List [] then ()
      else if sexp_size sexp >= 10 then
        (* Boxify: split into multiple entries with proper nesting *)
        let depth =
          match List.find_opt (fun e -> e.scope_id = scope_id) !stack with
          | Some parent_entry -> parent_entry.depth + 1
          | None -> List.length !stack
        in
        (* boxify now handles insertion directly and returns number of entries inserted *)
        let _num_inserted =
          boxify ~descr ~depth ~parent_scope_id:scope_id ~is_result sexp
        in
        ()
      else
        (* Small sexp - pretty print and log as-is *)
        let content = Sexplib0.Sexp.to_string_hum sexp in
        log_value_common ~descr ~scope_id ~log_level ~is_result content

  let log_value_pp ?descr ~scope_id ~log_level ~pp ~is_result v =
    if not (check_log_level log_level) then ()
    else
      (* Force the lazy value to get actual content *)
      let value = Lazy.force v in
      let buf = Buffer.create 512 in
      let formatter = CFormat.formatter_of_buffer buf in
      pp formatter value;
      CFormat.pp_print_flush formatter ();
      let content = Buffer.contents buf in
      log_value_common ~descr ~scope_id ~log_level ~is_result content

  let log_value_show ?descr ~scope_id ~log_level ~is_result v =
    if not (check_log_level log_level) then ()
    else
      (* Force the lazy value to get actual content *)
      let content = Lazy.force v in
      log_value_common ~descr ~scope_id ~log_level ~is_result content

  let log_exception ~scope_id ~log_level exn =
    if not (check_log_level log_level) then ()
    else if not (List.exists (fun e -> e == exn) !logged_exceptions) then (
      logged_exceptions := exn :: !logged_exceptions;
      log_value_show ~descr:"<exception>" ~scope_id ~log_level ~is_result:false
        (lazy (Printexc.to_string exn)))

  let log_value_printbox ~scope_id ~log_level v =
    if not (check_log_level log_level) then ()
    else
      let content = PrintBox_text.to_string v in
      log_value_common ~descr:None ~scope_id ~log_level ~is_result:false content

  let exceeds ~value ~limit =
    match limit with None -> false | Some limit -> limit < value

  let close_log ~fname:_ ~start_lnum:_ ~scope_id =
    match !stack with
    | [] -> ()
    | top :: rest when top.scope_id = scope_id ->
        let elapsed_end = Mtime_clock.elapsed () in
        let db = get_db () in

        (* Step 1: Look up parent_id from entry_parents table *)
        let parent_stmt =
          Sqlite3.prepare db "SELECT parent_id FROM entry_parents WHERE scope_id = ?"
        in
        Sqlite3.bind_int parent_stmt 1 scope_id |> ignore;
        let parent_scope_id =
          match Sqlite3.step parent_stmt with
          | Sqlite3.Rc.ROW -> (
              match Sqlite3.column parent_stmt 0 with
              | Sqlite3.Data.INT id -> Some (Int64.to_int id)
              | Sqlite3.Data.NULL ->
                  Some 0 (* Root has parent_id = NULL, but we use 0 as scope_id *)
              | _ -> None)
          | _ -> None
        in
        Sqlite3.finalize parent_stmt |> ignore;

        (* Step 2: Update header row in entries table *)
        (match parent_scope_id with
        | Some parent_id ->
            let stmt =
              Sqlite3.prepare db
                "UPDATE entries SET elapsed_end_ns = ? WHERE scope_id = ? AND \
                 child_scope_id = ?"
            in
            let elapsed_ns =
              match Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns elapsed_end with
              | None -> 0
              | Some ns -> ns
            in
            Sqlite3.bind_int stmt 1 elapsed_ns |> ignore;
            Sqlite3.bind_int stmt 2 parent_id |> ignore;
            Sqlite3.bind_int stmt 3 scope_id |> ignore;

            (* Retry the update with exponential backoff if busy *)
            let rec retry_step attempts delay =
              Sqlite3.reset stmt |> ignore;
              match Sqlite3.step stmt with
              | Sqlite3.Rc.DONE -> ()
              | Sqlite3.Rc.BUSY when attempts > 0 ->
                  Unix.sleepf delay;
                  retry_step (attempts - 1) (min (delay *. 1.5) 0.1) (* Cap at 100ms *)
              | rc ->
                  failwith ("Failed to update entry end time: " ^ Sqlite3.Rc.to_string rc)
            in
            retry_step 50 0.001;
            (* Start with 1ms delay *)
            Sqlite3.finalize stmt |> ignore
        | None -> ());

        stack := rest;
        hidden_entries := List.filter (( <> ) scope_id) !hidden_entries;

        (* If stack is now empty, we're leaving a top-level scope - commit transaction and
           clear exception tracking *)
        if rest = [] then (
          commit_toplevel_transaction ();
          logged_exceptions := [])
    | _ -> ()

  let exceeds_max_nesting () =
    exceeds ~value:(List.length !stack) ~limit:!max_nesting_depth

  let exceeds_max_children () =
    match !stack with
    | [] -> false
    | { num_children; _ } :: _ -> exceeds ~value:num_children ~limit:!max_num_children

  let get_scope_id =
    let global_id = ref 0 in
    fun () ->
      incr global_id;
      !global_id

  let global_prefix = global_prefix
  let snapshot () = ()

  let no_debug_if condition =
    if not condition then ()
    else
      match !stack with
      | [] -> ()
      | top :: _ ->
          let db = get_db () in
          let scope_id = top.scope_id in

          (* Delete the entry and all its descendants from the database. Note: The entry
             remains on the stack, so subsequent log_value and close_log calls will
             continue to execute. Any values logged after this point become "orphaned" (no
             header to attach to) and are unreachable by the tree renderer. This is
             acceptable as they don't appear in output and cleaning them up would add
             complexity. The main DB size issue is content-addressed value storage. *)

          (* Iteratively collect all descendants using BFS *)
          let descendant_ids = ref [] in
          let to_process = ref [ scope_id ] in
          while !to_process <> [] do
            let current_ids = !to_process in
            to_process := [];

            List.iter
              (fun parent_scope_id ->
                (* Find direct children of this entry - look for headers with scope_id
                   matching parent *)
                let child_stmt =
                  Sqlite3.prepare db
                    "SELECT DISTINCT child_scope_id FROM entries WHERE scope_id = ? AND \
                     child_scope_id IS NOT NULL"
                in
                Sqlite3.bind_int child_stmt 1 parent_scope_id |> ignore;

                let rec collect_children () =
                  match Sqlite3.step child_stmt with
                  | Sqlite3.Rc.ROW ->
                      let child_id =
                        Sqlite3.Data.to_int_exn (Sqlite3.column child_stmt 0)
                      in
                      descendant_ids := child_id :: !descendant_ids;
                      to_process := child_id :: !to_process;
                      collect_children ()
                  | Sqlite3.Rc.DONE -> ()
                  | _ -> failwith "Failed to collect child entries"
                in
                collect_children ();
                Sqlite3.finalize child_stmt |> ignore)
              current_ids
          done;

          (* Delete all entries rows where scope_id matches this scope (values and child
             headers) *)
          let delete_children_stmt =
            Sqlite3.prepare db "DELETE FROM entries WHERE scope_id = ?"
          in
          Sqlite3.bind_int delete_children_stmt 1 scope_id |> ignore;
          (match Sqlite3.step delete_children_stmt with
          | Sqlite3.Rc.DONE -> ()
          | _ -> failwith "Failed to delete entry children");
          Sqlite3.finalize delete_children_stmt |> ignore;

          (* Delete the header row for this entry (which has child_scope_id = this
             scope) *)
          let delete_header_stmt =
            Sqlite3.prepare db "DELETE FROM entries WHERE child_scope_id = ?"
          in
          Sqlite3.bind_int delete_header_stmt 1 scope_id |> ignore;
          (match Sqlite3.step delete_header_stmt with
          | Sqlite3.Rc.DONE -> ()
          | _ -> failwith "Failed to delete entry header");
          Sqlite3.finalize delete_header_stmt |> ignore;

          (* Delete each descendant entry (all rows) - recursively *)
          List.iter
            (fun desc_id ->
              (* Delete children/values *)
              let delete_children_stmt =
                Sqlite3.prepare db "DELETE FROM entries WHERE scope_id = ?"
              in
              Sqlite3.bind_int delete_children_stmt 1 desc_id |> ignore;
              (match Sqlite3.step delete_children_stmt with
              | Sqlite3.Rc.DONE -> ()
              | _ -> failwith "Failed to delete descendant children");
              Sqlite3.finalize delete_children_stmt |> ignore;

              (* Delete header *)
              let delete_header_stmt =
                Sqlite3.prepare db "DELETE FROM entries WHERE child_scope_id = ?"
              in
              Sqlite3.bind_int delete_header_stmt 1 desc_id |> ignore;
              (match Sqlite3.step delete_header_stmt with
              | Sqlite3.Rc.DONE -> ()
              | _ -> failwith "Failed to delete descendant header");
              Sqlite3.finalize delete_header_stmt |> ignore)
            !descendant_ids

  let finish_and_cleanup () =
    match !db with
    | None -> ()
    | Some db_handle ->
        (* Commit the transaction if one was started *)
        if !transaction_started then (
          Sqlite3.exec db_handle "COMMIT" |> ignore;
          transaction_started := false);
        (match !intern with Some intern -> ValueIntern.finalize intern | None -> ());
        Sqlite3.db_close db_handle |> ignore;
        db := None;
        run_id := None;
        intern := None;

        (* Close metadata database *)
        (match !meta_db with
        | Some meta_handle -> Sqlite3.db_close meta_handle |> ignore
        | None -> ());
        meta_db := None
end

(** Create a database-specific config that doesn't create file channels *)
let db_config ?(time_tagged = Minidebug_runtime.Not_tagged)
    ?(elapsed_times = Minidebug_runtime.Not_reported)
    ?(location_format = Minidebug_runtime.Beg_pos) ?(print_scope_ids = false)
    ?(verbose_scope_ids = false) ?(run_name = "") ?(log_level = 9) ?path_filter
    db_filename : (module Db_config) =
  let module Config = struct
    let refresh_ch () = false
    let debug_ch () = stdout (* Unused for database backend *)
    let debug_ch_name () = db_filename
    let snapshot_ch () = ()
    let reset_to_snapshot () = ()
    let table_of_contents_ch = None
    let time_tagged = time_tagged
    let elapsed_times = elapsed_times
    let location_format = location_format
    let print_scope_ids = print_scope_ids
    let verbose_scope_ids = verbose_scope_ids
    let global_prefix = if run_name = "" then "" else run_name ^ " "
    let prefix_all_logs = false
    let split_files_after = None
    let toc_entry = Minidebug_runtime.And []
    let init_log_level = log_level
    let path_filter = path_filter
  end in
  (module Config)

(** Factory function to create a database runtime *)
let debug_db_file ?(time_tagged = Minidebug_runtime.Not_tagged)
    ?(elapsed_times = Minidebug_runtime.Not_reported)
    ?(location_format = Minidebug_runtime.Beg_pos) ?(print_scope_ids = false)
    ?(verbose_scope_ids = false) ?(run_name = "") ?(for_append = true) ?(log_level = 9)
    ?path_filter filename =
  let _ = for_append in
  (* Ignore for database backend *)
  let config =
    db_config ~time_tagged ~elapsed_times ~location_format ~print_scope_ids
      ~verbose_scope_ids ~run_name ~log_level ?path_filter filename
  in
  let module Config = (val config : Db_config) in
  let module Backend = DatabaseBackend (Config) in
  (module Backend : Minidebug_runtime.Debug_runtime)

(** Factory function for database runtime with channel (uses filename from config) *)
let debug_db ?(debug_ch = stdout) ?(time_tagged = Minidebug_runtime.Not_tagged)
    ?(elapsed_times = Minidebug_runtime.Not_reported)
    ?(location_format = Minidebug_runtime.Beg_pos) ?(print_scope_ids = false)
    ?(verbose_scope_ids = false) ?(run_name = "") ?(log_level = 9) ?path_filter () =
  (* For database backend, we ignore debug_ch and create a file-based config *)
  let _ = debug_ch in
  let filename = "debug" in
  debug_db_file ~time_tagged ~elapsed_times ~location_format ~print_scope_ids
    ~verbose_scope_ids ~run_name ~for_append:true ~log_level ?path_filter filename
