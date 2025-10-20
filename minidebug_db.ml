(** Database-backed tracing runtime for ppx_minidebug.

    This module provides a database backend for storing debug traces with
    content-addressed deduplication. It implements the Debug_runtime interface and stores
    logs in a SQLite database with automatic deduplication of repeated values. *)

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

    (* Entries table with foreign keys to value_atoms. entry_id: ID of parent scope (all
       children share same entry_id). seq_id: position within parent's children list (0,
       1, 2...). header_entry_id: NULL for values/results, points to new scope ID for
       headers. is_result: false for headers and parameters, true for results. *)
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
    Sqlite3.exec db
      "CREATE INDEX IF NOT EXISTS idx_entries_header ON entries(run_id, header_entry_id)"
    |> ignore;
    Sqlite3.exec db
      "CREATE INDEX IF NOT EXISTS idx_entries_depth ON entries(run_id, depth)"
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
  let root_seq_counter = ref 0 (* Counter for root-level entries *)
  let boxify_entry_id_counter = ref 0 (* Counter for synthetic entry_ids from boxify *)

  let orphaned_seq_counters =
    ref [] (* Per-entry_id counters for orphaned logs: (entry_id * seq_counter) list *)

  (** Initialize database connection *)
  let initialize_database filename =
    let db_handle = Sqlite3.db_open filename in
    Sqlite3.busy_timeout db_handle 5000;
    (* Retry for up to 5 seconds on BUSY *)
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
      match Int64.unsigned_to_int @@ Mtime.Span.to_uint64_ns (Mtime_clock.elapsed ()) with
      | None -> 0
      | Some ns -> ns
    in
    let cmd = String.concat " " (Array.to_list Sys.argv) in
    let run_name = if global_prefix = "" then None else Some global_prefix in

    let stmt =
      Sqlite3.prepare db_handle
        "INSERT INTO runs (timestamp, elapsed_ns, command_line, run_name) VALUES (?, ?, \
         ?, ?)"
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
      let parent_entry_id, seq_id =
        match !stack with
        | [] ->
            let seq = !root_seq_counter in
            incr root_seq_counter;
            (None, seq)
        | parent :: _ -> (Some parent.entry_id, parent.num_children)
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
        Printf.sprintf "%s:%d:%d-%d:%d" fname start_lnum start_colnum end_lnum end_colnum
      in
      let location_value_id = ValueIntern.intern intern ~value_type:"location" location in

      (* Insert header row into entries table *)
      let stmt =
        Sqlite3.prepare db
          "INSERT INTO entries (run_id, entry_id, seq_id, header_entry_id, depth, \
           message_value_id, location_value_id, elapsed_start_ns, log_level, entry_type) \
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
      in
      Sqlite3.bind_int stmt 1 run_id |> ignore;
      (* entry_id is parent's entry_id (or 0 for root) *)
      (match parent_entry_id with
      | None -> Sqlite3.bind_int stmt 2 0 (* Root entries have entry_id = 0 *)
      | Some pid -> Sqlite3.bind_int stmt 2 pid)
      |> ignore;
      Sqlite3.bind_int stmt 3 seq_id |> ignore;
      Sqlite3.bind_int stmt 4 entry_id |> ignore;
      (* header_entry_id points to new scope *)
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
      | rc ->
          let errmsg = Sqlite3.errmsg db in
          (* Query existing entry if there's a conflict *)
          let existing_info =
            let query_stmt =
              Sqlite3.prepare db
                "SELECT header_entry_id, depth, message_value_id, location_value_id, \
                 log_level, entry_type FROM entries WHERE run_id = ? AND entry_id = ? \
                 AND seq_id = ?"
            in
            Sqlite3.bind_int query_stmt 1 run_id |> ignore;
            Sqlite3.bind_int query_stmt 2
              (match parent_entry_id with None -> 0 | Some pid -> pid)
            |> ignore;
            Sqlite3.bind_int query_stmt 3 seq_id |> ignore;
            match Sqlite3.step query_stmt with
            | Sqlite3.Rc.ROW ->
                let existing =
                  Printf.sprintf
                    "Existing: header_entry_id=%s, depth=%s, message_value_id=%s, \
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
                Trying to insert: run_id=%d, entry_id=%d, seq_id=%d, \
                header_entry_id=%d, depth=%d, log_level=%d, entry_type=%s\n\
                %s" errmsg (Sqlite3.Rc.to_string rc) run_id
               (match parent_entry_id with None -> 0 | Some pid -> pid)
               seq_id entry_id depth log_level entry_type_str existing_info));
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
      match !stack with
      | _ :: parent :: _ -> parent.num_children <- parent.num_children + 1
      | _ -> ()

  let open_log_no_source ~message ~entry_id ~log_level log_type =
    open_log ~fname:"" ~start_lnum:0 ~start_colnum:0 ~end_lnum:0 ~end_colnum:0 ~message
      ~entry_id ~log_level log_type

  (** Generate a fresh synthetic entry_id for boxified values *)
  let get_boxify_entry_id () =
    decr boxify_entry_id_counter;
    !boxify_entry_id_counter

  (** Helper to insert a header entry with data into the database.
      Used for indentation-based sub-scopes. *)
  let insert_header_with_data ~parent_entry_id ~seq_id ~new_entry_id ~depth ~content_str =
    let db = get_db () in
    let run_id = get_run_id () in
    let intern = get_intern () in

    (* Insert into entry_parents table for the new scope *)
    let parent_stmt =
      Sqlite3.prepare db
        "INSERT INTO entry_parents (run_id, entry_id, parent_id) VALUES (?, ?, ?)"
    in
    Sqlite3.bind_int parent_stmt 1 run_id |> ignore;
    Sqlite3.bind_int parent_stmt 2 new_entry_id |> ignore;
    Sqlite3.bind_int parent_stmt 3 parent_entry_id |> ignore;
    (match Sqlite3.step parent_stmt with
    | Sqlite3.Rc.DONE -> ()
    | _ -> failwith "Failed to insert entry parent for header");
    Sqlite3.finalize parent_stmt |> ignore;

    (* Intern data content *)
    let data_value_id = ValueIntern.intern intern ~value_type:"value" content_str in

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
        "INSERT INTO entries (run_id, entry_id, seq_id, header_entry_id, depth, \
         data_value_id, elapsed_start_ns, elapsed_end_ns, log_level, entry_type) \
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    in
    Sqlite3.bind_int stmt 1 run_id |> ignore;
    Sqlite3.bind_int stmt 2 parent_entry_id |> ignore;
    Sqlite3.bind_int stmt 3 seq_id |> ignore;
    Sqlite3.bind_int stmt 4 new_entry_id |> ignore;
    (* header_entry_id points to new scope *)
    Sqlite3.bind_int stmt 5 depth |> ignore;
    Sqlite3.bind_int stmt 6 data_value_id |> ignore;
    Sqlite3.bind_int stmt 7 elapsed_ns |> ignore;
    Sqlite3.bind_int stmt 8 elapsed_ns |> ignore;
    Sqlite3.bind_int stmt 9 !log_level |> ignore;
    Sqlite3.bind_text stmt 10 "value" |> ignore;

    (match Sqlite3.step stmt with
    | Sqlite3.Rc.DONE -> ()
    | rc ->
        let err_msg =
          Printf.sprintf "Failed to insert header with data: %s (entry_id=%d, seq_id=%d)"
            (Sqlite3.Rc.to_string rc) parent_entry_id seq_id
        in
        Sqlite3.finalize stmt |> ignore;
        failwith err_msg);
    Sqlite3.finalize stmt |> ignore

  (** Helper to insert a value entry into the database *)
  let insert_value_entry ~entry_id ~seq_id ~depth ~message ~content_str ~is_result =
    let db = get_db () in
    let run_id = get_run_id () in
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
        "INSERT INTO entries (run_id, entry_id, seq_id, header_entry_id, depth, \
         message_value_id, data_value_id, elapsed_start_ns, elapsed_end_ns, is_result, \
         log_level, entry_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    in
    Sqlite3.bind_int stmt 1 run_id |> ignore;
    Sqlite3.bind_int stmt 2 entry_id |> ignore;
    Sqlite3.bind_int stmt 3 seq_id |> ignore;
    Sqlite3.bind stmt 4 Sqlite3.Data.NULL |> ignore;
    (* header_entry_id is NULL for values *)
    Sqlite3.bind_int stmt 5 depth |> ignore;
    Sqlite3.bind_int stmt 6 message_value_id |> ignore;
    Sqlite3.bind_int stmt 7 data_value_id |> ignore;
    Sqlite3.bind_int stmt 8 elapsed_ns |> ignore;
    Sqlite3.bind_int stmt 9 elapsed_ns |> ignore;
    Sqlite3.bind_int stmt 10 (if is_result then 1 else 0) |> ignore;
    Sqlite3.bind_int stmt 11 1 |> ignore;
    (* log_level *)
    Sqlite3.bind_text stmt 12 "value" |> ignore;

    (match Sqlite3.step stmt with
    | Sqlite3.Rc.DONE -> ()
    | rc ->
        let err_msg =
          Printf.sprintf
            "Failed to insert value row: %s (entry_id=%d, seq_id=%d, depth=%d, \
             message=%S, content=%S)"
            (Sqlite3.Rc.to_string rc) entry_id seq_id depth message content_str
        in
        Sqlite3.finalize stmt |> ignore;
        failwith err_msg);
    Sqlite3.finalize stmt |> ignore

  (** Entry type for parsed indentation structure *)
  type indent_entry =
    | Value of int * int * string  (* seq_id, depth, content *)
    | Header of int * int * int * string * indent_entry list  (* seq_id, new_entry_id, depth, content, children *)

  (** Parse indentation structure of a multi-line string.
      Returns a list of entries where indentation increases create sub-scopes. *)
  let parse_indentation ~base_depth ~starting_seq str =
    let lines = String.split_on_char '\n' str in
    let non_empty_lines = List.filter (fun s -> String.trim s <> "") lines in

    if List.length non_empty_lines <= 1 then
      (* Single line or empty - no structure to parse *)
      []
    else
      let get_indent line =
        let rec count_spaces i =
          if i >= String.length line then i
          else match line.[i] with
          | ' ' | '\t' -> count_spaces (i + 1)
          | _ -> i
        in
        count_spaces 0
      in

      (* Find minimum indentation to use as baseline *)
      let min_indent =
        List.fold_left
          (fun acc line -> min acc (get_indent line))
          max_int
          non_empty_lines
      in

      (* Convert lines to (relative_indent, content) pairs *)
      let indent_lines = List.map (fun line ->
        let indent = get_indent line in
        let content = String.trim line in
        (indent - min_indent, content)
      ) non_empty_lines in

      (* Build tree: look ahead to see if next line is indented more *)
      let rec process_lines seq_num = function
        | [] -> []
        | [(indent, content)] ->
            (* Last line - always a value *)
            [Value (starting_seq + seq_num, base_depth + (indent / 2), content)]
        | (indent, content) :: ((next_indent, _) :: _ as rest) when next_indent > indent ->
            (* Next line is more indented - make this a header *)
            let new_entry_id = get_boxify_entry_id () in
            let children, remaining, next_seq = collect_children (next_indent, indent) (seq_num + 1) rest in
            let header = Header (starting_seq + seq_num, new_entry_id, base_depth + (indent / 2), content, children) in
            header :: process_lines next_seq remaining
        | (indent, content) :: rest ->
            (* Same or less indentation - regular value *)
            let value = Value (starting_seq + seq_num, base_depth + (indent / 2), content) in
            value :: process_lines (seq_num + 1) rest

      and collect_children (target_indent, parent_indent) seq_num = function
        | [] -> ([], [], seq_num)
        | ((indent, content) :: rest) when indent = target_indent ->
            (* Direct child at target indentation *)
            let child = Value (starting_seq + seq_num, base_depth + (indent / 2), content) in
            let more_children, remaining, next_seq = collect_children (target_indent, parent_indent) (seq_num + 1) rest in
            (child :: more_children, remaining, next_seq)
        | ((indent, _content) :: _rest) as all when indent > target_indent ->
            (* Deeper indentation - skip for now (simplified) *)
            ([], all, seq_num)
        | remaining ->
            (* Back to parent level or less indentation *)
            ([], remaining, seq_num)
      in

      process_lines 0 indent_lines

  (** Insert indentation entries into database *)
  let rec insert_indent_entries ~parent_entry_id entries =
    List.iter (function
      | Value (seq, depth, content) ->
          insert_value_entry ~entry_id:parent_entry_id ~seq_id:seq ~depth ~message:"" ~content_str:content ~is_result:false
      | Header (seq, new_entry_id, depth, content, children) ->
          (* Insert header with data *)
          insert_header_with_data ~parent_entry_id ~seq_id:seq ~new_entry_id ~depth ~content_str:content;
          (* Recursively insert children under the new entry_id *)
          insert_indent_entries ~parent_entry_id:new_entry_id children
    ) entries

  (** Boxify a sexp: split it into multiple database entries with synthetic entry_ids.
      Returns a list of (synthetic_entry_id, seq_id, depth, message, content_str) tuples.
  *)
  let boxify ~descr ~depth ~parent_entry_id sexp =
    let open Sexplib0.Sexp in
    (* Start seq_id from the parent's current num_children to avoid collisions *)
    let starting_seq =
      match List.find_opt (fun e -> e.entry_id = parent_entry_id) !stack with
      | Some parent_entry -> parent_entry.num_children
      | None -> 0
    in
    let parent_seq = ref starting_seq in
    let get_next_seq () =
      let s = !parent_seq in
      incr parent_seq;
      s
    in

    let boxify_threshold = 10 in

    let rec loop ~depth sexp =
      if sexp_size sexp < boxify_threshold then
        (* Small enough - return as single entry with pretty-printed content *)
        let content = Sexplib0.Sexp.to_string_hum sexp in
        [ (parent_entry_id, get_next_seq (), depth, "", content) ]
      else
        match sexp with
        | Atom s -> [ (parent_entry_id, get_next_seq (), depth, "", s) ]
        | List [] -> []
        | List [ s ] -> loop ~depth:(depth + 1) s
        | List (Atom s :: body) ->
            (* Create a synthetic scope for this subtree *)
            let _synthetic_id = get_boxify_entry_id () in
            (* Insert header entry *)
            let entries_ref = ref [ (parent_entry_id, get_next_seq (), depth, s, "") ] in
            (* Recursively process body *)
            List.iter
              (fun child ->
                let child_entries = loop ~depth:(depth + 1) child in
                entries_ref := !entries_ref @ child_entries)
              body;
            !entries_ref
        | List l ->
            (* Process each element of the list *)
            List.concat (List.map (loop ~depth:(depth + 1)) l)
    in

    (* Handle the initial descr wrapping *)
    match (sexp, descr) with
    | (Atom s | List [ Atom s ]), Some d ->
        [ (parent_entry_id, get_next_seq (), depth, d, s) ]
    | (Atom s | List [ Atom s ]), None ->
        [ (parent_entry_id, get_next_seq (), depth, "", s) ]
    | List [], Some d -> [ (parent_entry_id, get_next_seq (), depth, d, "") ]
    | List [], None -> []
    | List _, _ ->
        (* For large sexps, use structural splitting; for small ones, inline *)
        if sexp_size sexp < boxify_threshold then (
          (* Small enough - pretty print and inline *)
          let content = Sexplib0.Sexp.to_string_hum sexp in
          let msg = match descr with None -> "" | Some d -> d in
          let full_content = match descr with None -> content | Some d -> d ^ " = " ^ content in
          [ (parent_entry_id, get_next_seq (), depth, msg, full_content) ]
        ) else (
          (* Large sexp - use structural splitting *)
          let body_sexp =
            match (sexp, descr) with
            | List l, Some d -> List (Atom (d ^ " =") :: l)
            | List l, None -> List l
            | _ -> sexp
          in
          loop ~depth:(depth + 1) body_sexp
        )

  let log_value_common ~descr ~entry_id ~log_level:_ ~is_result content_str =
    if List.mem entry_id !hidden_entries then ()
    else
      let db = get_db () in
      let run_id = get_run_id () in
      let intern = get_intern () in

      (* Use stack top for dynamic scoping (supports %log_entry). If entry_id is in the
         stack, we're inside a valid scope, so use stack top. If entry_id is NOT in stack,
         treat as orphaned. *)
      let depth, seq_id, parent_entry_id =
        if List.exists (fun e -> e.entry_id = entry_id) !stack then
          (* entry_id is somewhere in the stack, use dynamic scoping (stack top) *)
          match !stack with
          | parent_entry :: _ ->
              (parent_entry.depth + 1, parent_entry.num_children, parent_entry.entry_id)
          | [] -> assert false (* Can't happen since we just checked stack is non-empty *)
        else
          (* entry_id not in stack - orphaned log. Query database for max seq_id to avoid
             conflicts with existing values/results *)
          let seq =
            match List.assoc_opt entry_id !orphaned_seq_counters with
            | Some counter ->
                let s = !counter in
                incr counter;
                s
            | None ->
                (* Find the maximum seq_id already used for this entry_id *)
                let max_seq_stmt =
                  Sqlite3.prepare db
                    "SELECT COALESCE(MAX(seq_id), -1) FROM entries WHERE run_id = ? AND \
                     entry_id = ?"
                in
                Sqlite3.bind_int max_seq_stmt 1 run_id |> ignore;
                Sqlite3.bind_int max_seq_stmt 2 entry_id |> ignore;
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
                orphaned_seq_counters := (entry_id, counter) :: !orphaned_seq_counters;
                start_seq
          in
          ( List.length !stack,
            seq,
            entry_id (* Use the passed entry_id for orphaned logs *) )
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
          "INSERT INTO entries (run_id, entry_id, seq_id, header_entry_id, depth, \
           message_value_id, data_value_id, elapsed_start_ns, elapsed_end_ns, is_result, \
           log_level, entry_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
      in
      Sqlite3.bind_int stmt 1 run_id |> ignore;
      Sqlite3.bind_int stmt 2 parent_entry_id |> ignore;
      (* entry_id is the parent scope *)
      Sqlite3.bind_int stmt 3 seq_id |> ignore;
      Sqlite3.bind stmt 4 Sqlite3.Data.NULL |> ignore;
      (* header_entry_id is NULL for values *)
      Sqlite3.bind_int stmt 5 depth |> ignore;
      Sqlite3.bind_int stmt 6 message_value_id |> ignore;
      Sqlite3.bind_int stmt 7 data_value_id |> ignore;
      Sqlite3.bind_int stmt 8 elapsed_ns |> ignore;
      Sqlite3.bind_int stmt 9 elapsed_ns |> ignore;
      (* Same for start and end for value nodes *)
      Sqlite3.bind_int stmt 10 (if is_result then 1 else 0) |> ignore;
      Sqlite3.bind_int stmt 11 1 |> ignore;
      (* log_level *)
      Sqlite3.bind_text stmt 12 "value" |> ignore;

      (* entry_type *)
      (match Sqlite3.step stmt with
      | Sqlite3.Rc.DONE -> ()
      | rc ->
          let err_msg = Sqlite3.errmsg db in
          failwith
            (Printf.sprintf
               "Failed to insert value row: %s (error: %s, entry_id=%d, seq_id=%d)"
               (Sqlite3.Rc.to_string rc) err_msg parent_entry_id seq_id));
      Sqlite3.finalize stmt |> ignore;

      (* Increment parent's num_children counter *)
      match !stack with
      | parent_entry :: _ -> parent_entry.num_children <- parent_entry.num_children + 1
      | [] -> ()

  let log_value_sexp ?descr ~entry_id ~log_level ~is_result v =
    if not (check_log_level log_level) then ()
    else if List.mem entry_id !hidden_entries then ()
    else
      (* Force the lazy value to get actual content *)
      let sexp = Lazy.force v in
      if sexp = Sexplib0.Sexp.List [] then ()
      else if sexp_size sexp >= 10 then (
        (* Boxify: split into multiple entries *)
        let depth =
          match List.find_opt (fun e -> e.entry_id = entry_id) !stack with
          | Some parent_entry -> parent_entry.depth + 1
          | None -> List.length !stack
        in
        let entries = boxify ~descr ~depth ~parent_entry_id:entry_id sexp in
        let num_inserted = ref 0 in
        List.iter
          (fun (eid, seq, d, msg, content) ->
            if content <> "" then (
              (* Check if content has multiple lines - if so, parse indentation *)
              let indent_entries = parse_indentation ~base_depth:d ~starting_seq:seq content in
              if indent_entries = [] then (
                (* Single line - insert as regular value *)
                insert_value_entry ~entry_id:eid ~seq_id:seq ~depth:d ~message:msg
                  ~content_str:content ~is_result;
                incr num_inserted
              ) else (
                (* Multi-line - insert with indentation structure *)
                insert_indent_entries ~parent_entry_id:eid indent_entries;
                let count_entries entries =
                  let rec count = function
                    | Value _ -> 1
                    | Header (_, _, _, _, children) -> 1 + List.fold_left (fun acc child -> acc + count child) 0 children
                  in
                  List.fold_left (fun acc entry -> acc + count entry) 0 entries
                in
                num_inserted := !num_inserted + count_entries indent_entries
              )
            ))
          entries;
        (* Update parent's num_children counter *)
        match List.find_opt (fun e -> e.entry_id = entry_id) !stack with
        | Some parent_entry ->
            parent_entry.num_children <- parent_entry.num_children + !num_inserted
        | None -> ())
      else (
        (* Small sexp - pretty print and potentially parse indentation *)
        let content = Sexplib0.Sexp.to_string_hum sexp in
        let depth =
          match List.find_opt (fun e -> e.entry_id = entry_id) !stack with
          | Some parent_entry -> parent_entry.depth + 1
          | None -> List.length !stack
        in
        let starting_seq =
          match List.find_opt (fun e -> e.entry_id = entry_id) !stack with
          | Some parent_entry -> parent_entry.num_children
          | None -> 0
        in
        let indent_entries = parse_indentation ~base_depth:depth ~starting_seq content in
        if indent_entries = [] then
          (* Single line - log as-is *)
          log_value_common ~descr ~entry_id ~log_level ~is_result content
        else (
          (* Multi-line - insert with proper nesting based on indentation *)
          insert_indent_entries ~parent_entry_id:entry_id indent_entries;
          (* Update parent's num_children counter *)
          let count_entries entries =
            let rec count = function
              | Value _ -> 1
              | Header (_, _, _, _, children) -> 1 + List.fold_left (fun acc child -> acc + count child) 0 children
            in
            List.fold_left (fun acc entry -> acc + count entry) 0 entries
          in
          match List.find_opt (fun e -> e.entry_id = entry_id) !stack with
          | Some parent_entry ->
              parent_entry.num_children <- parent_entry.num_children + count_entries indent_entries
          | None -> ()
        )
      )

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

  let exceeds ~value ~limit =
    match limit with None -> false | Some limit -> limit < value

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
          | Sqlite3.Rc.ROW -> (
              match Sqlite3.column parent_stmt 0 with
              | Sqlite3.Data.INT id -> Some (Int64.to_int id)
              | Sqlite3.Data.NULL ->
                  Some 0 (* Root has parent_id = NULL, but we use 0 as entry_id *)
              | _ -> None)
          | _ -> None
        in
        Sqlite3.finalize parent_stmt |> ignore;

        (* Step 2: Update header row in entries table *)
        (match parent_entry_id with
        | Some parent_id ->
            let stmt =
              Sqlite3.prepare db
                "UPDATE entries SET elapsed_end_ns = ? WHERE run_id = ? AND entry_id = ? \
                 AND header_entry_id = ?"
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

          (* Delete the entry and all its descendants from the database. Note: The entry
             remains on the stack, so subsequent log_value and close_log calls will
             continue to execute. Any values logged after this point become "orphaned" (no
             header to attach to) and are unreachable by the tree renderer. This is
             acceptable as they don't appear in output and cleaning them up would add
             complexity. The main DB size issue is content-addressed value storage. *)

          (* Iteratively collect all descendants using BFS *)
          let descendant_ids = ref [] in
          let to_process = ref [ entry_id ] in
          while !to_process <> [] do
            let current_ids = !to_process in
            to_process := [];

            List.iter
              (fun parent_entry_id ->
                (* Find direct children of this entry - look for headers with entry_id
                   matching parent *)
                let child_stmt =
                  Sqlite3.prepare db
                    "SELECT DISTINCT header_entry_id FROM entries WHERE run_id = ? AND \
                     entry_id = ? AND header_entry_id IS NOT NULL"
                in
                Sqlite3.bind_int child_stmt 1 run_id |> ignore;
                Sqlite3.bind_int child_stmt 2 parent_entry_id |> ignore;

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

          (* Delete all entries rows where entry_id matches this scope (values and child
             headers) *)
          let delete_children_stmt =
            Sqlite3.prepare db "DELETE FROM entries WHERE run_id = ? AND entry_id = ?"
          in
          Sqlite3.bind_int delete_children_stmt 1 run_id |> ignore;
          Sqlite3.bind_int delete_children_stmt 2 entry_id |> ignore;
          (match Sqlite3.step delete_children_stmt with
          | Sqlite3.Rc.DONE -> ()
          | _ -> failwith "Failed to delete entry children");
          Sqlite3.finalize delete_children_stmt |> ignore;

          (* Delete the header row for this entry (which has header_entry_id = this
             scope) *)
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
                Sqlite3.prepare db
                  "DELETE FROM entries WHERE run_id = ? AND header_entry_id = ?"
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
        (match !intern with Some intern -> ValueIntern.finalize intern | None -> ());
        Sqlite3.db_close db_handle |> ignore;
        db := None;
        run_id := None;
        intern := None
end

(** Create a database-specific config that doesn't create file channels *)
let db_config ?(time_tagged = Minidebug_runtime.Not_tagged)
    ?(elapsed_times = Minidebug_runtime.Not_reported)
    ?(location_format = Minidebug_runtime.Beg_pos) ?(print_entry_ids = false)
    ?(verbose_entry_ids = false) ?(run_name = "") ?(log_level = 9)
    ?path_filter db_filename : (module Db_config) =
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
    ?(verbose_entry_ids = false) ?(run_name = "") ?(for_append = true) ?(log_level = 9)
    ?path_filter filename =
  let _ = for_append in
  (* Ignore for database backend *)
  let config =
    db_config ~time_tagged ~elapsed_times ~location_format ~print_entry_ids
      ~verbose_entry_ids ~run_name ~log_level ?path_filter filename
  in
  let module Config = (val config : Db_config) in
  let module Backend = DatabaseBackend (Config) in
  (module Backend : Minidebug_runtime.Debug_runtime)

(** Factory function for database runtime with channel (uses filename from config) *)
let debug_db ?(debug_ch = stdout) ?(time_tagged = Minidebug_runtime.Not_tagged)
    ?(elapsed_times = Minidebug_runtime.Not_reported)
    ?(location_format = Minidebug_runtime.Beg_pos) ?(print_entry_ids = false)
    ?(verbose_entry_ids = false) ?(run_name = "") ?(log_level = 9)
    ?path_filter () =
  (* For database backend, we ignore debug_ch and create a file-based config *)
  let _ = debug_ch in
  let filename = "debug" in
  debug_db_file ~time_tagged ~elapsed_times ~location_format ~print_entry_ids
    ~verbose_entry_ids ~run_name ~for_append:true ~log_level ?path_filter filename
