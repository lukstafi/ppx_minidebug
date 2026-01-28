(** TUI state database persistence module.

    This module provides functions for serializing and deserializing TUI state
    to/from the SQLite database, enabling DB-backed TUI state for CLI client access.

    The TUI server writes state to DB after each change.
    CLI clients read state from DB to reconstruct the view.
    Commands flow through the tui_commands table. *)

module I = Interactive
module Q = Query

(** JSON serialization helpers *)
module Json = struct
  (** Encode a list of integers as JSON array string *)
  let encode_int_list ints =
    let items = List.map string_of_int ints in
    "[" ^ String.concat "," items ^ "]"

  (** Decode a JSON array string to list of integers *)
  let decode_int_list json =
    if json = "[]" || json = "" then []
    else
      let trimmed = String.sub json 1 (String.length json - 2) in
      if trimmed = "" then []
      else
        String.split_on_char ',' trimmed
        |> List.map (fun s -> int_of_string (String.trim s))

  (** Encode ellipsis set as JSON array of [parent, start, end] arrays *)
  let encode_ellipsis_set set =
    let items =
      I.EllipsisSet.fold
        (fun (parent, start, end_) acc ->
          Printf.sprintf "[%d,%d,%d]" parent start end_ :: acc)
        set []
    in
    "[" ^ String.concat "," (List.rev items) ^ "]"

  (** Decode JSON array of [parent, start, end] arrays to ellipsis set *)
  let decode_ellipsis_set json =
    if json = "[]" || json = "" then I.EllipsisSet.empty
    else
      (* Simple parser for [[a,b,c],[d,e,f],...] *)
      let rec parse_arrays s i acc =
        if i >= String.length s then acc
        else if s.[i] = '[' && (i = 0 || s.[i - 1] = ',' || s.[i - 1] = '[') then
          (* Find matching ] *)
          let rec find_end j depth =
            if j >= String.length s then j
            else if s.[j] = '[' then find_end (j + 1) (depth + 1)
            else if s.[j] = ']' then
              if depth = 1 then j else find_end (j + 1) (depth - 1)
            else find_end (j + 1) depth
          in
          let end_idx = find_end i 0 in
          let inner = String.sub s (i + 1) (end_idx - i - 1) in
          let nums = String.split_on_char ',' inner |> List.map String.trim in
          let acc' =
            match nums with
            | [ a; b; c ] ->
                let key = (int_of_string a, int_of_string b, int_of_string c) in
                I.EllipsisSet.add key acc
            | _ -> acc
          in
          parse_arrays s (end_idx + 1) acc'
        else parse_arrays s (i + 1) acc
      in
      parse_arrays json 1 I.EllipsisSet.empty

  (** Encode search type to JSON *)
  let encode_search_type = function
    | I.RegularSearch term ->
        Printf.sprintf {|{"type":"regular","term":%S}|} term
    | I.ExtractSearch { search_path; extraction_path; display_text } ->
        Printf.sprintf
          {|{"type":"extract","search_path":[%s],"extraction_path":[%s],"display_text":%S}|}
          (String.concat "," (List.map (Printf.sprintf "%S") search_path))
          (String.concat "," (List.map (Printf.sprintf "%S") extraction_path))
          display_text

  (** Encode status event to JSON *)
  let encode_status_event = function
    | I.SearchEvent (slot, search_type) ->
        let slot_num =
          match slot with I.SlotNumber.S1 -> 1 | S2 -> 2 | S3 -> 3 | S4 -> 4
        in
        Printf.sprintf {|{"event":"search","slot":%d,"search_type":%s}|} slot_num
          (encode_search_type search_type)
    | I.QuietPathEvent None -> {|{"event":"quiet_path","value":null}|}
    | I.QuietPathEvent (Some qp) ->
        Printf.sprintf {|{"event":"quiet_path","value":%S}|} qp

  (** Encode status history as JSON array *)
  let encode_status_history history =
    let items = List.map encode_status_event history in
    "[" ^ String.concat "," items ^ "]"

  (** Decode slot number from int *)
  let decode_slot_number = function
    | 1 -> I.SlotNumber.S1
    | 2 -> I.SlotNumber.S2
    | 3 -> I.SlotNumber.S3
    | 4 -> I.SlotNumber.S4
    | _ -> I.SlotNumber.S1

  (** Encode slot number to int *)
  let encode_slot_number = function
    | I.SlotNumber.S1 -> 1
    | I.SlotNumber.S2 -> 2
    | I.SlotNumber.S3 -> 3
    | I.SlotNumber.S4 -> 4
end

(** TUI database state management *)
type tui_db = {
  db : Sqlite3.db;
  mutable tables_initialized : bool;
}

(** Initialize TUI state tables. These tables support DB-backed TUI state for CLI client
    access. *)
let initialize_tui_tables db =
  (* Core state table - singleton row for TUI state *)
  Sqlite3.exec db
    {|CREATE TABLE IF NOT EXISTS tui_state (
        id INTEGER PRIMARY KEY DEFAULT 1,
        revision INTEGER NOT NULL DEFAULT 0,
        cursor INTEGER NOT NULL DEFAULT 0,
        scroll_offset INTEGER NOT NULL DEFAULT 0,
        show_times BOOLEAN NOT NULL DEFAULT 1,
        values_first BOOLEAN NOT NULL DEFAULT 1,
        current_slot INTEGER NOT NULL DEFAULT 1,
        search_order TEXT NOT NULL DEFAULT 'asc',
        quiet_path TEXT,
        search_input TEXT,
        quiet_path_input TEXT,
        goto_input TEXT,
        max_scope_id INTEGER NOT NULL DEFAULT 0,
        updated_at REAL NOT NULL DEFAULT (unixepoch()),
        expanded_scopes TEXT NOT NULL DEFAULT '[]',
        unfolded_ellipsis TEXT NOT NULL DEFAULT '[]',
        status_history TEXT NOT NULL DEFAULT '[]'
      )|}
  |> ignore;

  (* Insert singleton row if not exists *)
  Sqlite3.exec db "INSERT OR IGNORE INTO tui_state (id) VALUES (1)" |> ignore;

  (* Visible items table - flattened view of tree *)
  Sqlite3.exec db
    {|CREATE TABLE IF NOT EXISTS tui_visible_items (
        idx INTEGER PRIMARY KEY,
        content_type TEXT NOT NULL,
        scope_id INTEGER,
        seq_id INTEGER,
        parent_scope_id INTEGER,
        start_seq_id INTEGER,
        end_seq_id INTEGER,
        hidden_count INTEGER,
        indent_level INTEGER NOT NULL,
        is_expandable BOOLEAN NOT NULL,
        is_expanded BOOLEAN NOT NULL,
        is_value_long BOOLEAN NOT NULL DEFAULT 0,
        is_value_expanded BOOLEAN NOT NULL DEFAULT 0
      )|}
  |> ignore;
  Sqlite3.exec db
    "CREATE INDEX IF NOT EXISTS idx_tui_visible_items_content ON \
     tui_visible_items(content_type, scope_id, seq_id)"
  |> ignore;

  (* Search slots table - 4 independent search slots *)
  Sqlite3.exec db
    {|CREATE TABLE IF NOT EXISTS tui_search_slots (
        slot_number INTEGER PRIMARY KEY,
        search_type TEXT NOT NULL,
        search_term TEXT,
        search_path TEXT,
        extraction_path TEXT,
        display_text TEXT,
        completed BOOLEAN NOT NULL DEFAULT 0,
        started_at REAL,
        updated_at REAL,
        error_text TEXT
      )|}
  |> ignore;

  (* Search results table - matches per slot *)
  Sqlite3.exec db
    {|CREATE TABLE IF NOT EXISTS tui_search_results (
        slot_number INTEGER NOT NULL,
        scope_id INTEGER NOT NULL,
        seq_id INTEGER NOT NULL,
        is_match BOOLEAN NOT NULL,
        PRIMARY KEY (slot_number, scope_id, seq_id)
      )|}
  |> ignore;
  Sqlite3.exec db
    "CREATE INDEX IF NOT EXISTS idx_tui_search_results_lookup ON \
     tui_search_results(scope_id, seq_id)"
  |> ignore;

  (* Command queue table - CLI clients write, TUI server reads *)
  Sqlite3.exec db
    {|CREATE TABLE IF NOT EXISTS tui_commands (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL,
        batch_id TEXT,
        command TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        error_text TEXT,
        created_at REAL NOT NULL DEFAULT (unixepoch()),
        processed_at REAL
      )|}
  |> ignore;
  Sqlite3.exec db
    "CREATE INDEX IF NOT EXISTS idx_tui_commands_pending ON tui_commands(status, id)"
  |> ignore;
  Sqlite3.exec db
    "CREATE INDEX IF NOT EXISTS idx_tui_commands_by_batch ON tui_commands(batch_id, id)"
  |> ignore

(** Create a TUI database context *)
let create db_path =
  let db = Sqlite3.db_open db_path in
  Sqlite3.busy_timeout db 5000;
  (* Enable WAL mode and busy timeout for concurrent access *)
  Sqlite3.exec db "PRAGMA journal_mode=WAL" |> ignore;
  Sqlite3.exec db "PRAGMA busy_timeout=5000" |> ignore;
  { db; tables_initialized = false }

(** Ensure TUI tables are initialized *)
let ensure_tables tui_db =
  if not tui_db.tables_initialized then (
    initialize_tui_tables tui_db.db;
    tui_db.tables_initialized <- true)

(** Close TUI database connection *)
let close tui_db = Sqlite3.db_close tui_db.db |> ignore

(** Convert Hashtbl keys to list *)
let hashtbl_keys_to_list tbl =
  Hashtbl.fold (fun k _v acc -> k :: acc) tbl []

(** Internal: Write tui_state fields to database (assumes transaction is active) *)
let write_state_in_txn db (state : I.view_state) =
  let expanded_scopes = hashtbl_keys_to_list state.expanded in
  let expanded_json = Json.encode_int_list expanded_scopes in
  let unfolded_json = Json.encode_ellipsis_set state.unfolded_ellipsis in
  let status_json = Json.encode_status_history state.status_history in

  let search_order_str =
    match state.search_order with Q.AscendingIds -> "asc" | Q.DescendingIds -> "desc"
  in

  let current_slot_int = Json.encode_slot_number state.current_slot in

  let stmt =
    Sqlite3.prepare db
      {|UPDATE tui_state SET
          revision = revision + 1,
          cursor = ?,
          scroll_offset = ?,
          show_times = ?,
          values_first = ?,
          current_slot = ?,
          search_order = ?,
          quiet_path = ?,
          search_input = ?,
          quiet_path_input = ?,
          goto_input = ?,
          max_scope_id = ?,
          updated_at = unixepoch(),
          expanded_scopes = ?,
          unfolded_ellipsis = ?,
          status_history = ?
        WHERE id = 1|}
  in

  Sqlite3.bind_int stmt 1 state.cursor |> ignore;
  Sqlite3.bind_int stmt 2 state.scroll_offset |> ignore;
  Sqlite3.bind_int stmt 3 (if state.show_times then 1 else 0) |> ignore;
  Sqlite3.bind_int stmt 4 (if state.values_first then 1 else 0) |> ignore;
  Sqlite3.bind_int stmt 5 current_slot_int |> ignore;
  Sqlite3.bind_text stmt 6 search_order_str |> ignore;

  (match state.quiet_path with
  | Some qp -> Sqlite3.bind_text stmt 7 qp
  | None -> Sqlite3.bind stmt 7 Sqlite3.Data.NULL)
  |> ignore;

  (match state.search_input with
  | Some si -> Sqlite3.bind_text stmt 8 si
  | None -> Sqlite3.bind stmt 8 Sqlite3.Data.NULL)
  |> ignore;

  (match state.quiet_path_input with
  | Some qpi -> Sqlite3.bind_text stmt 9 qpi
  | None -> Sqlite3.bind stmt 9 Sqlite3.Data.NULL)
  |> ignore;

  (match state.goto_input with
  | Some gi -> Sqlite3.bind_text stmt 10 gi
  | None -> Sqlite3.bind stmt 10 Sqlite3.Data.NULL)
  |> ignore;

  Sqlite3.bind_int stmt 11 state.max_scope_id |> ignore;
  Sqlite3.bind_text stmt 12 expanded_json |> ignore;
  Sqlite3.bind_text stmt 13 unfolded_json |> ignore;
  Sqlite3.bind_text stmt 14 status_json |> ignore;

  (match Sqlite3.step stmt with
  | Sqlite3.Rc.DONE -> ()
  | rc -> failwith ("Failed to update tui_state: " ^ Sqlite3.Rc.to_string rc));
  Sqlite3.finalize stmt |> ignore

(** Internal: Write visible items to database (assumes transaction is active) *)
let write_visible_items_in_txn db (items : I.visible_item array) =
  (* Clear existing items *)
  Sqlite3.exec db "DELETE FROM tui_visible_items" |> ignore;

  let stmt =
    Sqlite3.prepare db
      {|INSERT INTO tui_visible_items
        (idx, content_type, scope_id, seq_id, parent_scope_id, start_seq_id,
         end_seq_id, hidden_count, indent_level, is_expandable, is_expanded,
         is_value_long, is_value_expanded)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)|}
  in

  Array.iteri
    (fun idx item ->
      Sqlite3.reset stmt |> ignore;
      Sqlite3.bind_int stmt 1 idx |> ignore;

      (match item.I.content with
      | I.RealEntry entry ->
          Sqlite3.bind_text stmt 2 "entry" |> ignore;
          Sqlite3.bind_int stmt 3 entry.Q.scope_id |> ignore;
          Sqlite3.bind_int stmt 4 entry.Q.seq_id |> ignore;
          Sqlite3.bind stmt 5 Sqlite3.Data.NULL |> ignore;
          Sqlite3.bind stmt 6 Sqlite3.Data.NULL |> ignore;
          Sqlite3.bind stmt 7 Sqlite3.Data.NULL |> ignore;
          Sqlite3.bind stmt 8 Sqlite3.Data.NULL |> ignore
      | I.Ellipsis { parent_scope_id; start_seq_id; end_seq_id; hidden_count } ->
          Sqlite3.bind_text stmt 2 "ellipsis" |> ignore;
          Sqlite3.bind stmt 3 Sqlite3.Data.NULL |> ignore;
          Sqlite3.bind stmt 4 Sqlite3.Data.NULL |> ignore;
          Sqlite3.bind_int stmt 5 parent_scope_id |> ignore;
          Sqlite3.bind_int stmt 6 start_seq_id |> ignore;
          Sqlite3.bind_int stmt 7 end_seq_id |> ignore;
          Sqlite3.bind_int stmt 8 hidden_count |> ignore);

      Sqlite3.bind_int stmt 9 item.indent_level |> ignore;
      Sqlite3.bind_int stmt 10 (if item.is_expandable then 1 else 0) |> ignore;
      Sqlite3.bind_int stmt 11 (if item.is_expanded then 1 else 0) |> ignore;
      Sqlite3.bind_int stmt 12 (if item.is_value_long then 1 else 0) |> ignore;
      Sqlite3.bind_int stmt 13 (if item.is_value_expanded then 1 else 0) |> ignore;

      match Sqlite3.step stmt with
      | Sqlite3.Rc.DONE -> ()
      | rc -> failwith ("Failed to insert visible item: " ^ Sqlite3.Rc.to_string rc))
    items;

  Sqlite3.finalize stmt |> ignore

(** Internal: Write search slots and results to database (assumes transaction is active) *)
let write_search_results_in_txn db (slots : I.slot_map) =
  (* Clear existing search data *)
  Sqlite3.exec db "DELETE FROM tui_search_slots" |> ignore;
  Sqlite3.exec db "DELETE FROM tui_search_results" |> ignore;

  let slot_stmt =
    Sqlite3.prepare db
      {|INSERT INTO tui_search_slots
        (slot_number, search_type, search_term, search_path, extraction_path,
         display_text, completed, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, unixepoch())|}
  in

  let result_stmt =
    Sqlite3.prepare db
      {|INSERT INTO tui_search_results (slot_number, scope_id, seq_id, is_match)
        VALUES (?, ?, ?, ?)|}
  in

  I.SlotMap.iter
    (fun slot_num slot ->
      let slot_int = Json.encode_slot_number slot_num in
      Sqlite3.reset slot_stmt |> ignore;
      Sqlite3.bind_int slot_stmt 1 slot_int |> ignore;

      (match slot.I.search_type with
      | I.RegularSearch term ->
          Sqlite3.bind_text slot_stmt 2 "regular" |> ignore;
          Sqlite3.bind_text slot_stmt 3 term |> ignore;
          Sqlite3.bind slot_stmt 4 Sqlite3.Data.NULL |> ignore;
          Sqlite3.bind slot_stmt 5 Sqlite3.Data.NULL |> ignore;
          Sqlite3.bind_text slot_stmt 6 term |> ignore
      | I.ExtractSearch { search_path; extraction_path; display_text } ->
          Sqlite3.bind_text slot_stmt 2 "extract" |> ignore;
          Sqlite3.bind slot_stmt 3 Sqlite3.Data.NULL |> ignore;
          (* Store as valid JSON arrays with surrounding brackets *)
          Sqlite3.bind_text slot_stmt 4
            ("[" ^ String.concat "," (List.map (Printf.sprintf "%S") search_path) ^ "]")
          |> ignore;
          Sqlite3.bind_text slot_stmt 5
            ("[" ^ String.concat "," (List.map (Printf.sprintf "%S") extraction_path) ^ "]")
          |> ignore;
          Sqlite3.bind_text slot_stmt 6 display_text |> ignore);

      Sqlite3.bind_int slot_stmt 7 (if !(slot.completed_ref) then 1 else 0) |> ignore;

      (match Sqlite3.step slot_stmt with
      | Sqlite3.Rc.DONE -> ()
      | rc -> failwith ("Failed to insert search slot: " ^ Sqlite3.Rc.to_string rc));

      (* Insert results for this slot *)
      Hashtbl.iter
        (fun (scope_id, seq_id) is_match ->
          Sqlite3.reset result_stmt |> ignore;
          Sqlite3.bind_int result_stmt 1 slot_int |> ignore;
          Sqlite3.bind_int result_stmt 2 scope_id |> ignore;
          Sqlite3.bind_int result_stmt 3 seq_id |> ignore;
          Sqlite3.bind_int result_stmt 4 (if is_match then 1 else 0) |> ignore;
          match Sqlite3.step result_stmt with
          | Sqlite3.Rc.DONE -> ()
          | rc ->
              failwith ("Failed to insert search result: " ^ Sqlite3.Rc.to_string rc))
        slot.results)
    slots;

  Sqlite3.finalize slot_stmt |> ignore;
  Sqlite3.finalize result_stmt |> ignore

(** Write full TUI state atomically in a single transaction.
    This ensures revision increment and all dependent tables are consistent. *)
let persist_state_atomic tui_db (state : I.view_state) =
  ensure_tables tui_db;
  let db = tui_db.db in
  (* Use IMMEDIATE to acquire write lock immediately, preventing read-committed races *)
  Sqlite3.exec db "BEGIN IMMEDIATE" |> ignore;
  (try
     write_state_in_txn db state;
     write_visible_items_in_txn db state.I.visible_items;
     write_search_results_in_txn db state.I.search_slots;
     Sqlite3.exec db "COMMIT" |> ignore
   with e ->
     Sqlite3.exec db "ROLLBACK" |> ignore;
     raise e)

(** Read current revision number *)
let read_revision tui_db =
  ensure_tables tui_db;
  let db = tui_db.db in
  let stmt = Sqlite3.prepare db "SELECT revision FROM tui_state WHERE id = 1" in
  let revision =
    match Sqlite3.step stmt with
    | Sqlite3.Rc.ROW -> Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0)
    | _ -> 0
  in
  Sqlite3.finalize stmt |> ignore;
  revision

(** Read basic TUI state (without reconstructing full view_state) *)
type basic_state = {
  revision : int;
  cursor : int;
  scroll_offset : int;
  show_times : bool;
  values_first : bool;
  current_slot : I.SlotNumber.t;
  search_order : Q.search_order;
  quiet_path : string option;
  search_input : string option;
  quiet_path_input : string option;
  goto_input : string option;
  max_scope_id : int;
  expanded_scopes : int list;
  unfolded_ellipsis : I.EllipsisSet.t;
}

let read_basic_state tui_db =
  ensure_tables tui_db;
  let db = tui_db.db in
  let stmt =
    Sqlite3.prepare db
      {|SELECT revision, cursor, scroll_offset, show_times, values_first,
               current_slot, search_order, quiet_path, search_input,
               quiet_path_input, goto_input, max_scope_id, expanded_scopes,
               unfolded_ellipsis
        FROM tui_state WHERE id = 1|}
  in
  let result =
    match Sqlite3.step stmt with
    | Sqlite3.Rc.ROW ->
        let col_text i =
          match Sqlite3.column stmt i with
          | Sqlite3.Data.TEXT s -> Some s
          | _ -> None
        in
        let col_int i = Sqlite3.Data.to_int_exn (Sqlite3.column stmt i) in
        let col_bool i = col_int i = 1 in

        let search_order =
          match col_text 6 with
          | Some "desc" -> Q.DescendingIds
          | _ -> Q.AscendingIds
        in

        Some
          {
            revision = col_int 0;
            cursor = col_int 1;
            scroll_offset = col_int 2;
            show_times = col_bool 3;
            values_first = col_bool 4;
            current_slot = Json.decode_slot_number (col_int 5);
            search_order;
            quiet_path = col_text 7;
            search_input = col_text 8;
            quiet_path_input = col_text 9;
            goto_input = col_text 10;
            max_scope_id = col_int 11;
            expanded_scopes = Json.decode_int_list (Option.value ~default:"[]" (col_text 12));
            unfolded_ellipsis =
              Json.decode_ellipsis_set (Option.value ~default:"[]" (col_text 13));
          }
    | _ -> None
  in
  Sqlite3.finalize stmt |> ignore;
  result

(** Read visible items from database *)
let read_visible_items tui_db (module Q : Q.S) =
  ensure_tables tui_db;
  let db = tui_db.db in
  let stmt =
    Sqlite3.prepare db
      {|SELECT idx, content_type, scope_id, seq_id, parent_scope_id, start_seq_id,
               end_seq_id, hidden_count, indent_level, is_expandable, is_expanded,
               is_value_long, is_value_expanded
        FROM tui_visible_items ORDER BY idx|}
  in

  let items = ref [] in
  let rec collect () =
    match Sqlite3.step stmt with
    | Sqlite3.Rc.ROW ->
        let col_int i = Sqlite3.Data.to_int_exn (Sqlite3.column stmt i) in
        let col_int_opt i =
          match Sqlite3.column stmt i with
          | Sqlite3.Data.INT n -> Some (Int64.to_int n)
          | _ -> None
        in
        let col_text i =
          match Sqlite3.column stmt i with
          | Sqlite3.Data.TEXT s -> s
          | _ -> ""
        in
        let col_bool i = col_int i = 1 in

        let content_type = col_text 1 in
        let content =
          if content_type = "entry" then
            let scope_id = col_int 2 in
            let seq_id = col_int 3 in
            match Q.find_entry ~scope_id ~seq_id with
            | Some entry -> Some (I.RealEntry entry)
            | None -> None
          else
            match
              (col_int_opt 4, col_int_opt 5, col_int_opt 6, col_int_opt 7)
            with
            | Some parent, Some start_seq, Some end_seq, Some hidden ->
                Some
                  (I.Ellipsis
                     {
                       parent_scope_id = parent;
                       start_seq_id = start_seq;
                       end_seq_id = end_seq;
                       hidden_count = hidden;
                     })
            | _ -> None
        in

        (match content with
        | Some c ->
            let item : I.visible_item =
              {
                content = c;
                indent_level = col_int 8;
                is_expandable = col_bool 9;
                is_expanded = col_bool 10;
                is_value_long = col_bool 11;
                is_value_expanded = col_bool 12;
              }
            in
            items := item :: !items
        | None -> ());
        collect ()
    | Sqlite3.Rc.DONE -> ()
    | rc -> failwith ("Failed to read visible items: " ^ Sqlite3.Rc.to_string rc)
  in
  collect ();
  Sqlite3.finalize stmt |> ignore;
  Array.of_list (List.rev !items)

(** Read search slots metadata *)
type search_slot_info = {
  slot_number : I.SlotNumber.t;
  search_type : string;
  search_term : string option;
  display_text : string option;
  completed : bool;
  result_count : int;
}

let read_search_slots tui_db =
  ensure_tables tui_db;
  let db = tui_db.db in

  (* First get result counts per slot *)
  let counts = Hashtbl.create 4 in
  let count_stmt =
    Sqlite3.prepare db
      "SELECT slot_number, COUNT(*) FROM tui_search_results GROUP BY slot_number"
  in
  let rec collect_counts () =
    match Sqlite3.step count_stmt with
    | Sqlite3.Rc.ROW ->
        let slot = Sqlite3.Data.to_int_exn (Sqlite3.column count_stmt 0) in
        let count = Sqlite3.Data.to_int_exn (Sqlite3.column count_stmt 1) in
        Hashtbl.replace counts slot count;
        collect_counts ()
    | Sqlite3.Rc.DONE -> ()
    | _ -> ()
  in
  collect_counts ();
  Sqlite3.finalize count_stmt |> ignore;

  let stmt =
    Sqlite3.prepare db
      {|SELECT slot_number, search_type, search_term, display_text, completed
        FROM tui_search_slots ORDER BY slot_number|}
  in

  let slots = ref [] in
  let rec collect () =
    match Sqlite3.step stmt with
    | Sqlite3.Rc.ROW ->
        let col_int i = Sqlite3.Data.to_int_exn (Sqlite3.column stmt i) in
        let col_text_opt i =
          match Sqlite3.column stmt i with
          | Sqlite3.Data.TEXT s -> Some s
          | _ -> None
        in
        let col_bool i = col_int i = 1 in

        let slot_num = col_int 0 in
        let info =
          {
            slot_number = Json.decode_slot_number slot_num;
            search_type = Option.value ~default:"" (col_text_opt 1);
            search_term = col_text_opt 2;
            display_text = col_text_opt 3;
            completed = col_bool 4;
            result_count = (match Hashtbl.find_opt counts slot_num with
                           | Some c -> c
                           | None -> 0);
          }
        in
        slots := info :: !slots;
        collect ()
    | Sqlite3.Rc.DONE -> ()
    | rc -> failwith ("Failed to read search slots: " ^ Sqlite3.Rc.to_string rc)
  in
  collect ();
  Sqlite3.finalize stmt |> ignore;
  List.rev !slots

(** Consistent snapshot read: reads all state under a single transaction.
    Returns (revision, basic_state option, visible_items, search_slots).
    Uses read-committed isolation - the transaction ensures all reads see the same snapshot. *)
let read_snapshot tui_db (module Q : Q.S) =
  ensure_tables tui_db;
  let db = tui_db.db in
  (* Start read transaction *)
  Sqlite3.exec db "BEGIN" |> ignore;
  (try
     let revision = read_revision tui_db in
     let basic_state = read_basic_state tui_db in
     let visible_items = read_visible_items tui_db (module Q) in
     let search_slots = read_search_slots tui_db in
     Sqlite3.exec db "COMMIT" |> ignore;
     (revision, basic_state, visible_items, search_slots)
   with e ->
     Sqlite3.exec db "ROLLBACK" |> ignore;
     raise e)

(** Insert a command into the queue *)
let insert_command tui_db ~client_id ?batch_id command =
  ensure_tables tui_db;
  let db = tui_db.db in
  let stmt =
    Sqlite3.prepare db
      {|INSERT INTO tui_commands (client_id, batch_id, command, status, created_at)
        VALUES (?, ?, ?, 'pending', unixepoch())|}
  in
  Sqlite3.bind_text stmt 1 client_id |> ignore;
  (match batch_id with
  | Some bid -> Sqlite3.bind_text stmt 2 bid
  | None -> Sqlite3.bind stmt 2 Sqlite3.Data.NULL)
  |> ignore;
  Sqlite3.bind_text stmt 3 command |> ignore;
  let result =
    match Sqlite3.step stmt with
    | Sqlite3.Rc.DONE -> Ok (Int64.to_int (Sqlite3.last_insert_rowid db))
    | rc -> Error ("Failed to insert command: " ^ Sqlite3.Rc.to_string rc)
  in
  Sqlite3.finalize stmt |> ignore;
  result

(** Poll for pending commands *)
type pending_command = {
  cmd_id : int;
  client_id : string;
  batch_id : string option;
  command : string;
}

let poll_pending_commands tui_db =
  ensure_tables tui_db;
  let db = tui_db.db in
  let stmt =
    Sqlite3.prepare db
      {|SELECT id, client_id, batch_id, command
        FROM tui_commands
        WHERE status = 'pending'
        ORDER BY id ASC|}
  in

  let commands = ref [] in
  let rec collect () =
    match Sqlite3.step stmt with
    | Sqlite3.Rc.ROW ->
        let col_int i = Sqlite3.Data.to_int_exn (Sqlite3.column stmt i) in
        let col_text i =
          match Sqlite3.column stmt i with
          | Sqlite3.Data.TEXT s -> s
          | _ -> ""
        in
        let col_text_opt i =
          match Sqlite3.column stmt i with
          | Sqlite3.Data.TEXT s -> Some s
          | _ -> None
        in
        let cmd =
          {
            cmd_id = col_int 0;
            client_id = col_text 1;
            batch_id = col_text_opt 2;
            command = col_text 3;
          }
        in
        commands := cmd :: !commands;
        collect ()
    | Sqlite3.Rc.DONE -> ()
    | rc -> failwith ("Failed to poll commands: " ^ Sqlite3.Rc.to_string rc)
  in
  collect ();
  Sqlite3.finalize stmt |> ignore;
  List.rev !commands

(** Mark a command as processing *)
let mark_command_processing tui_db cmd_id =
  ensure_tables tui_db;
  let db = tui_db.db in
  let stmt =
    Sqlite3.prepare db
      "UPDATE tui_commands SET status = 'processing' WHERE id = ?"
  in
  Sqlite3.bind_int stmt 1 cmd_id |> ignore;
  let _ = Sqlite3.step stmt in
  Sqlite3.finalize stmt |> ignore

(** Mark a command as done *)
let mark_command_done tui_db cmd_id =
  ensure_tables tui_db;
  let db = tui_db.db in
  let stmt =
    Sqlite3.prepare db
      "UPDATE tui_commands SET status = 'done', processed_at = unixepoch() WHERE id = ?"
  in
  Sqlite3.bind_int stmt 1 cmd_id |> ignore;
  let _ = Sqlite3.step stmt in
  Sqlite3.finalize stmt |> ignore

(** Mark a command as error *)
let mark_command_error tui_db cmd_id error_text =
  ensure_tables tui_db;
  let db = tui_db.db in
  let stmt =
    Sqlite3.prepare db
      {|UPDATE tui_commands
        SET status = 'error', error_text = ?, processed_at = unixepoch()
        WHERE id = ?|}
  in
  Sqlite3.bind_text stmt 1 error_text |> ignore;
  Sqlite3.bind_int stmt 2 cmd_id |> ignore;
  let _ = Sqlite3.step stmt in
  Sqlite3.finalize stmt |> ignore

(** Check if a batch is complete.
    A batch is complete when no commands are 'pending' or 'processing'.
    Also verifies batch actually exists to avoid false positives on empty/unknown batches. *)
let is_batch_complete tui_db batch_id =
  ensure_tables tui_db;
  let db = tui_db.db in
  (* Check that the batch exists *)
  let exists_stmt =
    Sqlite3.prepare db "SELECT COUNT(*) FROM tui_commands WHERE batch_id = ?"
  in
  Sqlite3.bind_text exists_stmt 1 batch_id |> ignore;
  let total_count =
    match Sqlite3.step exists_stmt with
    | Sqlite3.Rc.ROW -> Sqlite3.Data.to_int_exn (Sqlite3.column exists_stmt 0)
    | _ -> 0
  in
  Sqlite3.finalize exists_stmt |> ignore;
  if total_count = 0 then false (* Batch doesn't exist *)
  else
    (* Check for pending OR processing commands *)
    let stmt =
      Sqlite3.prepare db
        "SELECT COUNT(*) FROM tui_commands WHERE batch_id = ? AND status IN ('pending', 'processing')"
    in
    Sqlite3.bind_text stmt 1 batch_id |> ignore;
    let incomplete_count =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.ROW -> Sqlite3.Data.to_int_exn (Sqlite3.column stmt 0)
      | _ -> -1
    in
    Sqlite3.finalize stmt |> ignore;
    incomplete_count = 0

(** Get batch errors *)
let get_batch_errors tui_db batch_id =
  ensure_tables tui_db;
  let db = tui_db.db in
  let stmt =
    Sqlite3.prepare db
      {|SELECT command, error_text FROM tui_commands
        WHERE batch_id = ? AND status = 'error'|}
  in
  Sqlite3.bind_text stmt 1 batch_id |> ignore;
  let errors = ref [] in
  let rec collect () =
    match Sqlite3.step stmt with
    | Sqlite3.Rc.ROW ->
        let col_text i =
          match Sqlite3.column stmt i with
          | Sqlite3.Data.TEXT s -> s
          | _ -> ""
        in
        let cmd = col_text 0 in
        let err = col_text 1 in
        errors := (cmd, err) :: !errors;
        collect ()
    | Sqlite3.Rc.DONE -> ()
    | _ -> ()
  in
  collect ();
  Sqlite3.finalize stmt |> ignore;
  List.rev !errors

(** Wait for batch completion with timeout *)
let wait_for_batch tui_db batch_id ~timeout_sec =
  let start_time = Unix.gettimeofday () in
  let rec poll () =
    if Unix.gettimeofday () -. start_time > timeout_sec then Error "Timeout waiting for batch"
    else if is_batch_complete tui_db batch_id then
      let errors = get_batch_errors tui_db batch_id in
      if errors = [] then Ok () else Error (Printf.sprintf "Batch had errors: %s"
        (String.concat "; " (List.map (fun (c, e) -> Printf.sprintf "%s: %s" c e) errors)))
    else (
      Unix.sleepf 0.05;
      poll ())
  in
  poll ()

(** Create db_callbacks for Interactive.run_with_db.
    Converts Tui_db pending_command to Interactive.pending_command.
    Uses persist_state_atomic for atomic snapshot writes. *)
let make_db_callbacks tui_db : I.db_callbacks =
  let persist_state state =
    persist_state_atomic tui_db state
  in
  let poll_commands () =
    let db_cmds = poll_pending_commands tui_db in
    List.map
      (fun db_cmd ->
        {
          I.cmd_id = db_cmd.cmd_id;
          client_id = db_cmd.client_id;
          batch_id = db_cmd.batch_id;
          command = db_cmd.command;
        })
      db_cmds
  in
  let mark_processing = mark_command_processing tui_db in
  let mark_done = mark_command_done tui_db in
  let mark_error = mark_command_error tui_db in
  { I.persist_state; poll_commands; mark_processing; mark_done; mark_error }
