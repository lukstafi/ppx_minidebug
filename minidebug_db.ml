(** Database-backed tracing runtime for ppx_minidebug.

    This module provides a database backend for storing debug traces with content-addressed
    deduplication. It implements the Debug_runtime interface and stores logs in a SQLite
    database with automatic deduplication of repeated values. *)

module CFormat = Format

(** Schema management and database initialization *)
module Schema = struct
  (** Database schema version for migration management *)
  let schema_version = 1

  (** Initialize database tables if they don't exist *)
  let initialize_db db =
    (* Run table definitions *)
    Sqlite3.exec db
      {|CREATE TABLE IF NOT EXISTS runs (
          run_id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT NOT NULL,
          elapsed_ns INTEGER NOT NULL,
          command_line TEXT,
          run_name TEXT
        )|}
    |> ignore;

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

    (* Entry parents table: tracks entry_id -> parent_id relationships *)
    Sqlite3.exec db
      {|CREATE TABLE IF NOT EXISTS entry_parents (
          run_id INTEGER NOT NULL,
          entry_id INTEGER NOT NULL,
          parent_id INTEGER,
          PRIMARY KEY (run_id, entry_id),
          FOREIGN KEY (run_id) REFERENCES runs(run_id)
        )|}
    |> ignore;

    (* Entries table with foreign keys to value_atoms.
       entry_id: ID of parent scope (all children share same entry_id).
       seq_id: position within parent's children list (0, 1, 2...).
       header_entry_id: NULL for values/results, points to new scope ID for headers.
       is_result: false for headers and parameters, true for results. *)
    Sqlite3.exec db
      {|CREATE TABLE IF NOT EXISTS entries (
          run_id INTEGER NOT NULL,
          entry_id INTEGER NOT NULL,
          seq_id INTEGER NOT NULL,
          header_entry_id INTEGER,
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
          PRIMARY KEY (run_id, entry_id, seq_id),
          FOREIGN KEY (run_id) REFERENCES runs(run_id)
        )|}
    |> ignore;
    Sqlite3.exec db "CREATE INDEX IF NOT EXISTS idx_entries_header ON entries(run_id, header_entry_id)"
    |> ignore;
    Sqlite3.exec db "CREATE INDEX IF NOT EXISTS idx_entries_depth ON entries(run_id, depth)"
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

    (* Enable WAL mode for concurrent access *)
    Sqlite3.exec db "PRAGMA journal_mode=WAL" |> ignore;
    Sqlite3.exec db "PRAGMA synchronous=NORMAL" |> ignore
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
        Sqlite3.Data.to_int_exn (Sqlite3.column t.lookup_stmt 0)
    | _ ->
        (* Insert new value *)
        Sqlite3.reset t.insert_stmt |> ignore;
        Sqlite3.bind_text t.insert_stmt 1 hash |> ignore;
        Sqlite3.bind_text t.insert_stmt 2 content |> ignore;
        Sqlite3.bind_text t.insert_stmt 3 value_type |> ignore;
        Sqlite3.bind_int t.insert_stmt 4 size |> ignore;
        (match Sqlite3.step t.insert_stmt with
        | Sqlite3.Rc.DONE -> ()
        | _ -> failwith "Failed to insert value");

        (* Get the ID of the newly inserted or existing value *)
        Sqlite3.reset t.lookup_stmt |> ignore;
        Sqlite3.bind_text t.lookup_stmt 1 hash |> ignore;
        (match Sqlite3.step t.lookup_stmt with
        | Sqlite3.Rc.ROW -> Sqlite3.Data.to_int_exn (Sqlite3.column t.lookup_stmt 0)
        | _ -> failwith "Failed to retrieve value_id after insert")

  (** Finalize prepared statements *)
  let finalize t =
    Sqlite3.finalize t.insert_stmt |> ignore;
    Sqlite3.finalize t.lookup_stmt |> ignore
end

(** Database backend implementing Debug_runtime interface *)
module DatabaseBackend (Log_to : Minidebug_runtime.Shared_config) :
  Minidebug_runtime.Debug_runtime = struct
  open Log_to

  let log_level = ref init_log_level
  let max_nesting_depth = ref None
  let max_num_children = ref None

  type entry_info = {
    entry_id : int;
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
  let run_id = ref None
  let intern = ref None
  let stack : entry_info list ref = ref []
  let hidden_entries = ref []
  let root_seq_counter = ref 0  (* Counter for root-level entries *)

  (** Initialize database connection *)
  let initialize_database filename =
    let db_handle = Sqlite3.db_open filename in
    Schema.initialize_db db_handle;
    db := Some db_handle;
    db_path := Some filename;

    (* Create value interning context *)
    intern := Some (ValueIntern.create db_handle);

    (* Create new run *)
    let timestamp =
      let buf = Buffer.create 512 in
      let formatter = CFormat.formatter_of_buffer buf in
      let tz_offset_s = Ptime_clock.current_tz_offset_s () in
      Ptime.(pp_human ~frac_s:6 ?tz_offset_s ()) formatter (Ptime_clock.now ());
      CFormat.pp_print_flush formatter ();
      Buffer.contents buf
    in
    let elapsed_ns =
      match
        Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns (Mtime_clock.elapsed ())
      with
      | None -> 0
      | Some ns -> ns
    in
    let cmd = String.concat " " (Array.to_list Sys.argv) in
    let run_name = if global_prefix = "" then None else Some global_prefix in

    let stmt =
      Sqlite3.prepare db_handle
        "INSERT INTO runs (timestamp, elapsed_ns, command_line, run_name) VALUES (?, ?, ?, ?)"
    in
    Sqlite3.bind_text stmt 1 timestamp |> ignore;
    Sqlite3.bind_int stmt 2 elapsed_ns |> ignore;
    Sqlite3.bind_text stmt 3 cmd |> ignore;
    (match run_name with
    | Some name -> Sqlite3.bind_text stmt 4 name
    | None -> Sqlite3.bind stmt 4 Sqlite3.Data.NULL)
    |> ignore;
    (match Sqlite3.step stmt with
    | Sqlite3.Rc.DONE -> ()
    | _ -> failwith "Failed to create run");
    Sqlite3.finalize stmt |> ignore;

    run_id := Some (Int64.to_int (Sqlite3.last_insert_rowid db_handle))

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

  let get_run_id () = Option.get !run_id
  let get_intern () = Option.get !intern

  let check_log_level level = level <= !log_level

  let should_log_path fname message =
    match Log_to.path_filter with
    | None -> true
    | Some (`Whitelist re) -> Re.execp re (fname ^ "/" ^ message)
    | Some (`Blacklist re) -> not (Re.execp re (fname ^ "/" ^ message))

  let should_log ~log_level ~fname ~message =
    check_log_level log_level && should_log_path fname message

  let open_log ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum ~message ~entry_id
      ~log_level log_type =
    if not (should_log ~log_level ~fname ~message) then
      hidden_entries := entry_id :: !hidden_entries
    else
      let db = get_db () in
      let run_id = get_run_id () in
      let intern = get_intern () in
      let parent_entry_id, seq_id = match !stack with
        | [] ->
            let seq = !root_seq_counter in
            incr root_seq_counter;
            None, seq
        | parent :: _ -> Some parent.entry_id, parent.num_children
      in
      let depth = List.length !stack in
      let elapsed_start = Mtime_clock.elapsed () in

      (* Insert into entry_parents table *)
      let parent_stmt =
        Sqlite3.prepare db
          "INSERT INTO entry_parents (run_id, entry_id, parent_id) VALUES (?, ?, ?)"
      in
      Sqlite3.bind_int parent_stmt 1 run_id |> ignore;
      Sqlite3.bind_int parent_stmt 2 entry_id |> ignore;
      (match parent_entry_id with
      | None -> Sqlite3.bind parent_stmt 3 Sqlite3.Data.NULL
      | Some pid -> Sqlite3.bind_int parent_stmt 3 pid)
      |> ignore;
      (match Sqlite3.step parent_stmt with
      | Sqlite3.Rc.DONE -> ()
      | _ -> failwith "Failed to insert entry parent");
      Sqlite3.finalize parent_stmt |> ignore;

      (* Intern message *)
      let message_value_id = ValueIntern.intern intern ~value_type:"message" message in

      (* Intern location *)
      let location =
        Printf.sprintf "%s:%d:%d-%d:%d" fname start_lnum start_colnum end_lnum
          end_colnum
      in
      let location_value_id = ValueIntern.intern intern ~value_type:"location" location in

      (* Insert header row into entries table *)
      let stmt =
        Sqlite3.prepare db
          "INSERT INTO entries (run_id, entry_id, seq_id, header_entry_id, depth, message_value_id, \
           location_value_id, elapsed_start_ns, log_level, entry_type) VALUES (?, ?, ?, ?, \
           ?, ?, ?, ?, ?, ?)"
      in
      Sqlite3.bind_int stmt 1 run_id |> ignore;
      (* entry_id is parent's entry_id (or 0 for root) *)
      (match parent_entry_id with
      | None -> Sqlite3.bind_int stmt 2 0  (* Root entries have entry_id = 0 *)
      | Some pid -> Sqlite3.bind_int stmt 2 pid)
      |> ignore;
      Sqlite3.bind_int stmt 3 seq_id |> ignore;
      Sqlite3.bind_int stmt 4 entry_id |> ignore;  (* header_entry_id points to new scope *)
      Sqlite3.bind_int stmt 5 depth |> ignore;
      Sqlite3.bind_int stmt 6 message_value_id |> ignore;
      Sqlite3.bind_int stmt 7 location_value_id |> ignore;
      let elapsed_ns =
        match Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns elapsed_start with
        | None -> 0
        | Some ns -> ns
      in
      Sqlite3.bind_int stmt 8 elapsed_ns |> ignore;
      Sqlite3.bind_int stmt 9 log_level |> ignore;
      let entry_type_str =
        match log_type with `Diagn -> "diagn" | `Debug -> "debug" | `Track -> "track"
      in
      Sqlite3.bind_text stmt 10 entry_type_str |> ignore;

      (match Sqlite3.step stmt with
      | Sqlite3.Rc.DONE -> ()
      | _ -> failwith "Failed to insert header entry");
      Sqlite3.finalize stmt |> ignore;

      (* Push to stack *)
      let entry =
        {
          entry_id;
          parent_id = parent_entry_id;
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
      (match !stack with
      | _ :: parent :: _ -> parent.num_children <- parent.num_children + 1
      | _ -> ())

  let open_log_no_source ~message ~entry_id ~log_level log_type =
    open_log ~fname:"" ~start_lnum:0 ~start_colnum:0 ~end_lnum:0 ~end_colnum:0 ~message
      ~entry_id ~log_level log_type

  let log_value_common ~descr ~entry_id ~log_level:_ ~is_result content_str =
    if List.mem entry_id !hidden_entries then ()
    else
      let db = get_db () in
      let run_id = get_run_id () in
      let intern = get_intern () in

      (* Get depth and seq_id from the entry's stack info *)
      let depth, seq_id =
        match List.find_opt (fun e -> e.entry_id = entry_id) !stack with
        | Some parent_entry -> parent_entry.depth + 1, parent_entry.num_children
        | None -> List.length !stack, 0  (* Fallback *)
      in

      (* Intern the message (parameter/result name) *)
      let message = match descr with Some d -> d | None -> if is_result then "=>" else "" in
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
          "INSERT INTO entries (run_id, entry_id, seq_id, header_entry_id, depth, message_value_id, \
           data_value_id, elapsed_start_ns, elapsed_end_ns, is_result, log_level, entry_type) \
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
      in
      Sqlite3.bind_int stmt 1 run_id |> ignore;
      Sqlite3.bind_int stmt 2 entry_id |> ignore;  (* entry_id is the parent scope *)
      Sqlite3.bind_int stmt 3 seq_id |> ignore;
      Sqlite3.bind stmt 4 Sqlite3.Data.NULL |> ignore;  (* header_entry_id is NULL for values *)
      Sqlite3.bind_int stmt 5 depth |> ignore;
      Sqlite3.bind_int stmt 6 message_value_id |> ignore;
      Sqlite3.bind_int stmt 7 data_value_id |> ignore;
      Sqlite3.bind_int stmt 8 elapsed_ns |> ignore;
      Sqlite3.bind_int stmt 9 elapsed_ns |> ignore;  (* Same for start and end for value nodes *)
      Sqlite3.bind_int stmt 10 (if is_result then 1 else 0) |> ignore;
      Sqlite3.bind_int stmt 11 1 |> ignore;  (* log_level *)
      Sqlite3.bind_text stmt 12 "value" |> ignore;  (* entry_type *)

      (match Sqlite3.step stmt with
      | Sqlite3.Rc.DONE -> ()
      | _ -> failwith "Failed to insert value row");
      Sqlite3.finalize stmt |> ignore;

      (* Increment parent's num_children counter *)
      (match List.find_opt (fun e -> e.entry_id = entry_id) !stack with
      | Some parent_entry -> parent_entry.num_children <- parent_entry.num_children + 1
      | None -> ())

  let log_value_sexp ?descr ~entry_id ~log_level ~is_result v =
    if not (check_log_level log_level) then ()
    else
      (* Force the lazy value to get actual content *)
      let sexp = Lazy.force v in
      if sexp = Sexplib0.Sexp.List [] then ()
      else
        let content = Sexplib0.Sexp.to_string_mach sexp in
        log_value_common ~descr ~entry_id ~log_level ~is_result content

  let log_value_pp ?descr ~entry_id ~log_level ~pp ~is_result v =
    if not (check_log_level log_level) then ()
    else
      (* Force the lazy value to get actual content *)
      let value = Lazy.force v in
      let buf = Buffer.create 512 in
      let formatter = CFormat.formatter_of_buffer buf in
      pp formatter value;
      CFormat.pp_print_flush formatter ();
      let content = Buffer.contents buf in
      log_value_common ~descr ~entry_id ~log_level ~is_result content

  let log_value_show ?descr ~entry_id ~log_level ~is_result v =
    if not (check_log_level log_level) then ()
    else
      (* Force the lazy value to get actual content *)
      let content = Lazy.force v in
      log_value_common ~descr ~entry_id ~log_level ~is_result content

  let log_value_printbox ~entry_id ~log_level v =
    if not (check_log_level log_level) then ()
    else
      let content = PrintBox_text.to_string v in
      log_value_common ~descr:None ~entry_id ~log_level ~is_result:false content

  let exceeds ~value ~limit = match limit with None -> false | Some limit -> limit < value

  let close_log ~fname:_ ~start_lnum:_ ~entry_id =
    match !stack with
    | [] -> ()
    | top :: rest when top.entry_id = entry_id ->
        let elapsed_end = Mtime_clock.elapsed () in
        let db = get_db () in
        let run_id = get_run_id () in

        (* Step 1: Look up parent_id from entry_parents table *)
        let parent_stmt =
          Sqlite3.prepare db
            "SELECT parent_id FROM entry_parents WHERE run_id = ? AND entry_id = ?"
        in
        Sqlite3.bind_int parent_stmt 1 run_id |> ignore;
        Sqlite3.bind_int parent_stmt 2 entry_id |> ignore;
        let parent_entry_id =
          match Sqlite3.step parent_stmt with
          | Sqlite3.Rc.ROW ->
              (match Sqlite3.column parent_stmt 0 with
              | Sqlite3.Data.INT id -> Some (Int64.to_int id)
              | Sqlite3.Data.NULL -> Some 0  (* Root has parent_id = NULL, but we use 0 as entry_id *)
              | _ -> None)
          | _ -> None
        in
        Sqlite3.finalize parent_stmt |> ignore;

        (* Step 2: Update header row in entries table *)
        (match parent_entry_id with
        | Some parent_id ->
            let stmt =
              Sqlite3.prepare db
                "UPDATE entries SET elapsed_end_ns = ? WHERE run_id = ? AND entry_id = ? AND header_entry_id = ?"
            in
            let elapsed_ns =
              match Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns elapsed_end with
              | None -> 0
              | Some ns -> ns
            in
            Sqlite3.bind_int stmt 1 elapsed_ns |> ignore;
            Sqlite3.bind_int stmt 2 run_id |> ignore;
            Sqlite3.bind_int stmt 3 parent_id |> ignore;
            Sqlite3.bind_int stmt 4 entry_id |> ignore;

            (match Sqlite3.step stmt with
            | Sqlite3.Rc.DONE -> ()
            | _ -> failwith "Failed to update entry end time");
            Sqlite3.finalize stmt |> ignore
        | None -> ());

        stack := rest;
        hidden_entries := List.filter (( <> ) entry_id) !hidden_entries
    | _ -> ()

  let exceeds_max_nesting () =
    exceeds ~value:(List.length !stack) ~limit:!max_nesting_depth

  let exceeds_max_children () =
    match !stack with
    | [] -> false
    | { num_children; _ } :: _ -> exceeds ~value:num_children ~limit:!max_num_children

  let get_entry_id =
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
          let run_id = get_run_id () in
          let entry_id = top.entry_id in

          (* Delete the entry and all its descendants from the database.
             Note: The entry remains on the stack, so subsequent log_value and close_log
             calls will continue to execute. Any values logged after this point become
             "orphaned" (no header to attach to) and are unreachable by the tree renderer.
             This is acceptable as they don't appear in output and cleaning them up would
             add complexity. The main DB size issue is content-addressed value storage. *)

          (* Iteratively collect all descendants using BFS *)
          let descendant_ids = ref [] in
          let to_process = ref [entry_id] in
          while !to_process <> [] do
            let current_ids = !to_process in
            to_process := [];

            List.iter (fun parent_entry_id ->
              (* Find direct children of this entry - look for headers with entry_id matching parent *)
              let child_stmt =
                Sqlite3.prepare db
                  "SELECT DISTINCT header_entry_id FROM entries WHERE run_id = ? AND entry_id = ? AND header_entry_id IS NOT NULL"
              in
              Sqlite3.bind_int child_stmt 1 run_id |> ignore;
              Sqlite3.bind_int child_stmt 2 parent_entry_id |> ignore;

              let rec collect_children () =
                match Sqlite3.step child_stmt with
                | Sqlite3.Rc.ROW ->
                    let child_id = Sqlite3.Data.to_int_exn (Sqlite3.column child_stmt 0) in
                    descendant_ids := child_id :: !descendant_ids;
                    to_process := child_id :: !to_process;
                    collect_children ()
                | Sqlite3.Rc.DONE -> ()
                | _ -> failwith "Failed to collect child entries"
              in
              collect_children ();
              Sqlite3.finalize child_stmt |> ignore
            ) current_ids
          done;

          (* Delete all entries rows where entry_id matches this scope (values and child headers) *)
          let delete_children_stmt =
            Sqlite3.prepare db
              "DELETE FROM entries WHERE run_id = ? AND entry_id = ?"
          in
          Sqlite3.bind_int delete_children_stmt 1 run_id |> ignore;
          Sqlite3.bind_int delete_children_stmt 2 entry_id |> ignore;
          (match Sqlite3.step delete_children_stmt with
          | Sqlite3.Rc.DONE -> ()
          | _ -> failwith "Failed to delete entry children");
          Sqlite3.finalize delete_children_stmt |> ignore;

          (* Delete the header row for this entry (which has header_entry_id = this scope) *)
          let delete_header_stmt =
            Sqlite3.prepare db
              "DELETE FROM entries WHERE run_id = ? AND header_entry_id = ?"
          in
          Sqlite3.bind_int delete_header_stmt 1 run_id |> ignore;
          Sqlite3.bind_int delete_header_stmt 2 entry_id |> ignore;
          (match Sqlite3.step delete_header_stmt with
          | Sqlite3.Rc.DONE -> ()
          | _ -> failwith "Failed to delete entry header");
          Sqlite3.finalize delete_header_stmt |> ignore;

          (* Delete each descendant entry (all rows) - recursively *)
          List.iter
            (fun desc_id ->
              (* Delete children/values *)
              let delete_children_stmt =
                Sqlite3.prepare db "DELETE FROM entries WHERE run_id = ? AND entry_id = ?"
              in
              Sqlite3.bind_int delete_children_stmt 1 run_id |> ignore;
              Sqlite3.bind_int delete_children_stmt 2 desc_id |> ignore;
              (match Sqlite3.step delete_children_stmt with
              | Sqlite3.Rc.DONE -> ()
              | _ -> failwith "Failed to delete descendant children");
              Sqlite3.finalize delete_children_stmt |> ignore;

              (* Delete header *)
              let delete_header_stmt =
                Sqlite3.prepare db "DELETE FROM entries WHERE run_id = ? AND header_entry_id = ?"
              in
              Sqlite3.bind_int delete_header_stmt 1 run_id |> ignore;
              Sqlite3.bind_int delete_header_stmt 2 desc_id |> ignore;
              (match Sqlite3.step delete_header_stmt with
              | Sqlite3.Rc.DONE -> ()
              | _ -> failwith "Failed to delete descendant header");
              Sqlite3.finalize delete_header_stmt |> ignore)
            !descendant_ids

  let finish_and_cleanup () =
    match !db with
    | None -> ()
    | Some db_handle ->
        (match !intern with
        | Some intern -> ValueIntern.finalize intern
        | None -> ());
        Sqlite3.db_close db_handle |> ignore;
        db := None;
        run_id := None;
        intern := None
end

(** Create a database-specific config that doesn't create file channels *)
let db_config ?(time_tagged = Minidebug_runtime.Not_tagged)
    ?(elapsed_times = Minidebug_runtime.Not_reported)
    ?(location_format = Minidebug_runtime.Beg_pos) ?(print_entry_ids = false)
    ?(verbose_entry_ids = false) ?(run_name = "") ?(log_level = 9) ?path_filter
    db_filename : (module Minidebug_runtime.Shared_config) =
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
    let print_entry_ids = print_entry_ids
    let verbose_entry_ids = verbose_entry_ids
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
    ?(location_format = Minidebug_runtime.Beg_pos) ?(print_entry_ids = false)
    ?(verbose_entry_ids = false) ?(run_name = "") ?(for_append = true)
    ?(log_level = 9) ?path_filter filename =
  let _ = for_append in (* Ignore for database backend *)
  let config =
    db_config ~time_tagged ~elapsed_times ~location_format ~print_entry_ids
      ~verbose_entry_ids ~run_name ~log_level ?path_filter filename
  in
  let module Config = (val config : Minidebug_runtime.Shared_config) in
  (module DatabaseBackend (Config) : Minidebug_runtime.Debug_runtime)

(** Factory function for database runtime with channel (uses filename from config) *)
let debug_db ?(debug_ch = stdout) ?(time_tagged = Minidebug_runtime.Not_tagged)
    ?(elapsed_times = Minidebug_runtime.Not_reported)
    ?(location_format = Minidebug_runtime.Beg_pos) ?(print_entry_ids = false)
    ?(verbose_entry_ids = false) ?(run_name = "") ?(log_level = 9) ?path_filter () =
  (* For database backend, we ignore debug_ch and create a file-based config *)
  let _ = debug_ch in
  let filename = "debug" in
  debug_db_file ~time_tagged ~elapsed_times ~location_format ~print_entry_ids
    ~verbose_entry_ids ~run_name ~for_append:true ~log_level ?path_filter filename
