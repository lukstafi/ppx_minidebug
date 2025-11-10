(** MCP Server for ppx_minidebug database traces *)

module Query = Minidebug_client.Query
module I = Minidebug_client.Interactive

type render_context = {
  width : int;
  is_selected : bool;
  show_times : bool;
  margin_width : int;
  search_slots : I.slot_map;
  current_slot : I.SlotNumber.t;
  query : (module Query.S);
  values_first : bool;
}

(** Get color tag for a slot *)
let slot_tag = function
  | I.SlotNumber.S1 -> "G"
  | I.SlotNumber.S2 -> "C"
  | I.SlotNumber.S3 -> "M"
  | I.SlotNumber.S4 -> "Y"

(** Render a single line as text with markers *)
let render_line ctx item =
  match item.I.content with
  | Ellipsis { parent_scope_id; start_seq_id; end_seq_id; hidden_count } ->
      let scope_id_str = Printf.sprintf "%*d │ " ctx.margin_width parent_scope_id in
      let indent = String.make (item.indent_level * 2) ' ' in
      let text =
        Printf.sprintf "%s%s⋯ (%d hidden entries: seq %d-%d)" indent
          (if ctx.is_selected then ">>> " else "")
          hidden_count start_seq_id end_seq_id
      in
      let suffix = if ctx.is_selected then " <<<" else "" in
      scope_id_str ^ text ^ suffix
  | RealEntry entry ->
      let module Q = (val ctx.query) in
      (* Compute display ID *)
      let display_id =
        match entry.child_scope_id with
        | Some hid when hid >= 0 -> Some hid
        | Some _ -> None
        | None when entry.scope_id >= 0 -> Some entry.scope_id
        | None -> None
      in
      let scope_id_str =
        match display_id with
        | Some id -> Printf.sprintf "%*d │ " ctx.margin_width id
        | None -> String.make (ctx.margin_width + 3) ' '
      in

      (* Build content *)
      let indent = String.make (item.indent_level * 2) ' ' in
      let expansion_mark =
        if item.is_expandable then if item.is_expanded then "▼ " else "▶ " else "  "
      in

      (* Entry content - same logic as Notty version *)
      let content =
        match entry.child_scope_id with
        | Some hid when ctx.values_first && item.is_expanded -> (
            let children = Q.get_scope_children ~parent_scope_id:hid in
            let results, _non_results =
              List.partition (fun e -> e.Query.is_result) children
            in
            match results with
            | [ single_result ] when single_result.child_scope_id = None ->
                let result_data = Option.value ~default:"" single_result.data in
                let result_msg = single_result.message in
                let combined_result =
                  if result_msg <> "" && result_msg <> entry.message then
                    Printf.sprintf " => %s = %s" result_msg result_data
                  else Printf.sprintf " => %s" result_data
                in
                Printf.sprintf "%s%s[%s] %s%s" indent expansion_mark entry.entry_type
                  entry.message combined_result
            | _ ->
                let is_synthetic = entry.location = None in
                let display_text =
                  match (entry.message, entry.data, is_synthetic) with
                  | msg, Some data, true when msg <> "" ->
                      Printf.sprintf "%s: %s" msg data
                  | "", Some data, true -> data
                  | msg, _, _ when msg <> "" -> msg
                  | _ -> ""
                in
                Printf.sprintf "%s%s[%s] %s" indent expansion_mark entry.entry_type
                  display_text)
        | Some _ ->
            let display_text =
              let message = entry.message in
              let data = Option.value ~default:"" entry.data in
              if message <> "" then message else data
            in
            Printf.sprintf "%s%s[%s] %s" indent expansion_mark entry.entry_type
              display_text
        | None ->
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
        if ctx.show_times then
          match Query.elapsed_time entry with
          | Some elapsed -> Printf.sprintf " <%s>" (Query.format_elapsed_ns elapsed)
          | None -> ""
        else ""
      in

      let full_text = content ^ time_str in
      let content_width = ctx.width - String.length scope_id_str in
      let truncated =
        if I.Utf8.char_count full_text > content_width then
          I.Utf8.truncate full_text (content_width - 3) ^ "..."
        else full_text
      in
      let sanitized = I.sanitize_text truncated in

      (* Get search matches for highlighting *)
      let all_matches =
        I.get_all_search_matches ~search_slots:ctx.search_slots ~scope_id:entry.scope_id
          ~seq_id:entry.seq_id
      in

      (* Build prefix based on selection and highlighting *)
      let prefix, suffix =
        if ctx.is_selected then (">>> ", " <<<")
        else
          match all_matches with
          | [] -> ("    ", "")
          | matches ->
              let tags = List.map slot_tag matches |> String.concat "/" in
              (Printf.sprintf "[%s] " tags, "")
      in

      prefix ^ scope_id_str ^ sanitized ^ suffix

(** Render full screen as text *)
let render_screen state ~term_width ~term_height =
  let header_height = 2 in
  let footer_height = 2 in
  let content_height = term_height - header_height - footer_height in

  (* Calculate margin width *)
  let margin_width = String.length (string_of_int state.I.max_scope_id) in

  (* Calculate current scope progress *)
  let current_scope_id =
    if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
      match state.visible_items.(state.cursor).content with
      | Ellipsis { parent_scope_id; _ } -> parent_scope_id
      | RealEntry entry -> (
          let id_to_check =
            match entry.child_scope_id with Some hid -> hid | None -> entry.scope_id
          in
          match I.find_positive_ancestor_id state.query id_to_check with
          | Some id -> id
          | None -> 0)
    else 0
  in
  let progress_pct =
    if state.max_scope_id > 0 then
      float_of_int current_scope_id /. float_of_int state.max_scope_id *. 100.0
    else 0.0
  in

  (* Build header *)
  let header_line =
    match state.goto_input with
    | Some input -> Printf.sprintf "Goto Scope ID: %s_" input
    | None -> (
        match state.quiet_path_input with
        | Some input -> Printf.sprintf "Quiet Path: %s_" input
        | None -> (
            match state.search_input with
            | Some input -> Printf.sprintf "Search: %s_" input
            | None ->
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
                (* Build chronological status *)
                let chronological_status =
                  if state.status_history = [] then ""
                  else
                    let event_strings =
                      List.rev_map
                        (fun event ->
                          match event with
                          | I.SearchEvent (slot_num, search_type) -> (
                              match I.SlotMap.find_opt slot_num state.search_slots with
                              | Some slot ->
                                  let count = Hashtbl.length slot.results in
                                  let color_name = slot_tag slot_num in
                                  let count_str =
                                    if !(slot.completed_ref) then
                                      Printf.sprintf "[%d]" count
                                    else Printf.sprintf "[%d...]" count
                                  in
                                  let search_desc =
                                    match search_type with
                                    | RegularSearch term -> I.sanitize_text term
                                    | ExtractSearch { display_text; _ } ->
                                        I.sanitize_text display_text
                                  in
                                  Printf.sprintf "%s:%s%s" color_name search_desc
                                    count_str
                              | None -> "")
                          | QuietPathEvent qp_opt -> (
                              match qp_opt with
                              | Some qp -> Printf.sprintf "Q:%s" (I.sanitize_text qp)
                              | None -> "Q:cleared"))
                        state.status_history
                    in
                    let filtered = List.filter (fun s -> s <> "") event_strings in
                    if filtered = [] then "" else " | " ^ String.concat " " filtered
                in
                base_info ^ chronological_status))
  in

  (* Build content lines *)
  let visible_start = state.scroll_offset in
  let visible_end =
    min (visible_start + content_height) (Array.length state.visible_items)
  in

  let content_lines = ref [] in
  for i = visible_start to visible_end - 1 do
    let is_selected = i = state.cursor in
    let item = state.visible_items.(i) in
    let ctx =
      {
        width = term_width;
        is_selected;
        show_times = state.show_times;
        margin_width;
        search_slots = state.search_slots;
        current_slot = state.current_slot;
        query = state.query;
        values_first = state.values_first;
      }
    in
    let line = render_line ctx item in
    content_lines := line :: !content_lines
  done;

  (* Pad if needed *)
  for _ = 1 to content_height - (visible_end - visible_start) do
    content_lines := "" :: !content_lines
  done;

  (* Build footer *)
  let footer_line =
    match state.goto_input with
    | Some _ ->
        "[Enter] Goto scope ID | [Esc] Cancel | [Backspace] Delete | [0-9] Type ID"
    | None -> (
        match state.quiet_path_input with
        | Some _ -> "[Enter] Confirm quiet path | [Esc] Cancel | [Backspace] Delete"
        | None -> (
            match state.search_input with
            | Some _ -> "[Enter] Confirm search | [Esc] Cancel | [Backspace] Delete"
            | None ->
                "[↑/↓] Navigate | [Home/End] First/Last | [PgUp/PgDn] Page | [u/d] \
                 Quarter | [n/N] Next/Prev Match | [Enter/Space] Expand | [f] Fold | [/] \
                 Search | [g] Goto | [Q] Quiet | [t] Times | [v] Values | [o] Order | \
                 [q] Quit"))
  in

  (* Combine all parts *)
  let separator = String.make term_width '-' in
  String.concat "\n"
    ([ header_line; separator ] @ List.rev !content_lines @ [ separator; footer_line ])

(** Parse string command to command type for MCP TUI *)
let parse_command cmd_str =
  match String.trim cmd_str with
  (* Navigation *)
  | "j" | "down" -> Some (I.Navigate `Down)
  | "k" | "up" -> Some (I.Navigate `Up)
  | "h" | "left" -> Some (I.Navigate `Up) (* Vim-style alternative *)
  | "l" | "right" -> Some (I.Navigate `Down) (* Vim-style alternative *)
  | "u" | "quarter-up" -> Some (I.Navigate `QuarterUp)
  | "d" | "quarter-down" -> Some (I.Navigate `QuarterDown)
  | "page-up" | "pgup" -> Some (I.Navigate `PageUp)
  | "page-down" | "pgdn" -> Some (I.Navigate `PageDown)
  | "home" -> Some (I.Navigate `Home)
  | "end" -> Some (I.Navigate `End)
  (* Actions *)
  | "enter" | "space" | "expand" -> Some I.ToggleExpansion
  | "f" | "fold" -> Some I.Fold
  | "n" | "next" -> Some I.SearchNext
  | "N" | "prev" -> Some I.SearchPrev
  | "t" | "toggle-times" -> Some I.ToggleTimes
  | "v" | "toggle-values" -> Some I.ToggleValues
  | "o" | "toggle-order" -> Some I.ToggleSearchOrder
  | "q" | "quit" -> Some I.Quit
  (* Input modes - these accept arguments *)
  | s when String.starts_with ~prefix:"/" s ->
      (* Search: "/pattern" *)
      let pattern = String.sub s 1 (String.length s - 1) in
      if pattern = "" then Some (I.BeginSearch None)
      else Some (I.BeginSearch (Some pattern))
  | s when String.starts_with ~prefix:"g" s ->
      (* Goto: "g42" *)
      let rest = String.sub s 1 (String.length s - 1) in
      if rest = "" then Some (I.BeginGoto None)
      else (
        try
          let scope_id = int_of_string rest in
          Some (I.BeginGoto (Some scope_id))
        with Failure _ -> None)
  | s when String.starts_with ~prefix:"Q" s ->
      (* Quiet path: "Qpattern" *)
      let pattern = String.sub s 1 (String.length s - 1) in
      if pattern = "" then Some (I.BeginQuietPath None)
      else Some (I.BeginQuietPath (Some pattern))
  | _ -> None

open Mcp_sdk

(* Helper for extracting string parameter from JSON *)
let get_string_param json name =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt name fields with
      | Some (`String value) -> value
      | _ -> failwith (Printf.sprintf "Missing or invalid parameter: %s" name))
  | _ -> failwith "Expected JSON object"

(* Helper for extracting optional string parameter *)
let get_optional_string_param json name =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt name fields with
      | Some (`String value) -> Some value
      | Some `Null | None -> None
      | _ -> failwith (Printf.sprintf "Invalid parameter type: %s" name))
  | _ -> failwith "Expected JSON object"

(* Helper for extracting optional int parameter *)
let get_optional_int_param json name =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt name fields with
      | Some (`Int value) -> Some value
      | Some `Null | None -> None
      | _ -> failwith (Printf.sprintf "Invalid parameter type: %s" name))
  | _ -> failwith "Expected JSON object"

(* Helper for extracting optional bool parameter *)
let get_optional_bool_param json name =
  match json with
  | `Assoc fields -> (
      match List.assoc_opt name fields with
      | Some (`Bool value) -> Some value
      | Some `Null | None -> None
      | _ -> failwith (Printf.sprintf "Invalid parameter type: %s" name))
  | _ -> failwith "Expected JSON object"

(** Output budget machinery *)

(** Default output budget: 4KB to prevent unresponsive MCP server *)
let default_output_budget = 4_096

exception Output_budget_exceeded of { written : int; limit : int }
(** Exception raised when output budget exceeded *)

(** Create a formatter with output size budget. Raises Output_budget_exceeded when
    cumulative output exceeds budget. *)
let make_bounded_formatter ~budget buffer =
  let written = ref 0 in
  let check_and_write s pos len =
    written := !written + len;
    if !written > budget then
      raise (Output_budget_exceeded { written = !written; limit = budget })
    else Buffer.add_substring buffer s pos len
  in
  Format.formatter_of_out_functions
    {
      out_string = check_and_write;
      out_flush = (fun () -> ());
      out_newline =
        (fun () ->
          written := !written + 1;
          if !written > budget then
            raise (Output_budget_exceeded { written = !written; limit = budget });
          Buffer.add_char buffer '\n');
      out_spaces =
        (fun n ->
          written := !written + n;
          if !written > budget then
            raise (Output_budget_exceeded { written = !written; limit = budget });
          Buffer.add_string buffer (String.make n ' '));
      out_indent =
        (fun n ->
          written := !written + n;
          if !written > budget then
            raise (Output_budget_exceeded { written = !written; limit = budget });
          Buffer.add_string buffer (String.make n ' '));
    }

type tui_state = {
  state : I.view_state;
  last_update : float; (* Unix timestamp *)
}

type session_state = {
  db_path : string;
  query : (module Minidebug_client.Query.S); (* First-class module with DB connection *)
  search_cache : (string, (int * int, bool) Hashtbl.t) Hashtbl.t;
      (* pattern -> results_table: (scope_id, seq_id) -> is_match *)
  mutable tui_state : tui_state option; (* TUI state for interactive navigation *)
}
(** Session state for MCP server *)

(** Current server session - None means no database loaded *)
let current_session : session_state option ref = ref None

(** Get current session or fail *)
let get_session () =
  match !current_session with
  | Some session -> session
  | None -> failwith "No database initialized. Use minidebug/init-db first."

(** Initialize or reinitialize session with a database *)
let init_session db_path =
  (* Create Query module for this database *)
  let module Q = Minidebug_client.Query.Make (struct
    let db_path = db_path
  end) in
  let query = (module Q : Minidebug_client.Query.S) in
  let search_cache = Hashtbl.create 16 in
  current_session := Some { db_path; query; search_cache; tui_state = None };
  Logs.info (fun m -> m "Session initialized with database: %s" db_path)

(** Get or compute search results with caching. Cache key includes pattern and quiet_path
    to ensure correct results. *)
let get_search_results session ~pattern ~quiet_path =
  (* Create cache key from pattern + quiet_path *)
  let cache_key =
    match quiet_path with
    | None -> pattern
    | Some qp -> Printf.sprintf "%s|quiet:%s" pattern qp
  in

  (* Check cache first *)
  match Hashtbl.find_opt session.search_cache cache_key with
  | Some cached_results ->
      Logs.debug (fun m -> m "Using cached search results for pattern: %s" pattern);
      cached_results
  | None ->
      (* Cache miss - run search and cache results *)
      Logs.debug (fun m -> m "Cache miss, running search for pattern: %s" pattern);
      let module Q = (val session.query : Minidebug_client.Query.S) in
      let completed_ref = ref false in
      let results_table = Hashtbl.create 1024 in
      Q.populate_search_results ~search_term:pattern ~quiet_path
        ~search_order:Minidebug_client.Query.AscendingIds ~completed_ref ~results_table;
      (* Cache the results *)
      Hashtbl.add session.search_cache cache_key results_table;
      results_table

(* Create the MCP server *)
let create_server ?db_path () =
  (* Initialize session if db_path provided *)
  (match db_path with Some path -> init_session path | None -> ());

  let server = create_server ~name:"ppx_minidebug MCP Server" ~version:"0.1.0" () in
  let server = configure_server server ~with_tools:true ~with_resources:false () in

  (* Tool: init-db - Initialize or reinitialize database session *)
  let _ =
    add_tool server ~name:"minidebug/init-db"
      ~description:
        "Initialize or reinitialize the MCP server session with a database. This must be \
         called before any other operations if no database was specified at server \
         startup. Can also be used to switch to a different database."
      ~schema_properties:
        [ ("db_path", "string", "Path to the ppx_minidebug database file (.db)") ]
      ~schema_required:[ "db_path" ]
      (fun args ->
        try
          let db_path = get_string_param args "db_path" in

          (* Validate database exists and is readable *)
          if not (Sys.file_exists db_path) then
            failwith (Printf.sprintf "Database file not found: %s" db_path);

          (* Initialize session *)
          init_session db_path;

          Tool.create_tool_result
            [
              Mcp.make_text_content
                (Printf.sprintf "Successfully initialized session with database: %s"
                   db_path);
            ]
            ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in init-db: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: list-runs - List all trace runs in database *)
  let _ =
    add_tool server ~name:"minidebug/list-runs"
      ~description:"List all trace runs in the database with metadata"
      ~schema_properties:[] ~schema_required:[] (fun _args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          let runs = Q.get_runs () in

          (* Convert runs to JSON *)
          let runs_json =
            `List
              (List.map
                 (fun (run : Minidebug_client.Query.run_info) ->
                   `Assoc
                     [
                       ("run_id", `Int run.run_id);
                       ("timestamp", `String run.timestamp);
                       ("elapsed_ns", `Int run.elapsed_ns);
                       ("command_line", `String run.command_line);
                       ( "run_name",
                         match run.run_name with
                         | Some name -> `String name
                         | None -> `Null );
                     ])
                 runs)
          in

          Tool.create_tool_result
            [
              Mcp.make_text_content
                (Yojson.Safe.pretty_to_string
                   (`Assoc [ ("runs", runs_json); ("count", `Int (List.length runs)) ]));
            ]
            ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in list-runs: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: stats - Show database statistics *)
  let _ =
    add_tool server ~name:"minidebug/stats"
      ~description:"Show database statistics including size and deduplication metrics"
      ~schema_properties:[] ~schema_required:[] (fun _args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          (* Capture stats output using buffer-backed formatter *)
          let buffer = Buffer.create 1024 in
          let fmt = make_bounded_formatter ~budget:default_output_budget buffer in

          (* Get stats and format them *)
          (try
             let stats = Q.get_stats () in
             Format.fprintf fmt "Database Statistics\n";
             Format.fprintf fmt "===================\n";
             Format.fprintf fmt "Total entries: %d\n" stats.total_entries;
             Format.fprintf fmt "Total value references: %d\n" stats.total_values;
             Format.fprintf fmt "Unique values: %d\n" stats.unique_values;
             Format.fprintf fmt "Deduplication: %.1f%%\n" stats.dedup_percentage;
             Format.fprintf fmt "Database size: %d KB\n" stats.database_size_kb;
             Format.pp_print_flush fmt ()
           with Output_budget_exceeded { written; limit } ->
             Buffer.add_string buffer
               (Printf.sprintf
                  "\n[... truncated: output exceeded %d byte limit (wrote %d bytes)]"
                  limit written));

          let stats_text = Buffer.contents buffer in

          Tool.create_tool_result [ Mcp.make_text_content stats_text ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in stats: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: show-trace - Show full trace tree *)
  let _ =
    add_tool server ~name:"minidebug/show-trace"
      ~description:
        "Show full trace tree for a run. Returns formatted text output suitable for \
         viewing. For large traces, use max_depth parameter to limit output (e.g., \
         max_depth=20)."
      ~schema_properties:
        [
          ("run_id", "integer", "Run ID to show (optional, defaults to latest)");
          ("show_scope_ids", "boolean", "Show scope IDs (optional, default false)");
          ("show_times", "boolean", "Show elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum depth to display (optional)");
          ("values_first_mode", "boolean", "Show values first (optional, default false)");
        ]
      ~schema_required:[]
      (fun args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          let _run_id = get_optional_int_param args "run_id" in
          let show_scope_ids =
            Option.value (get_optional_bool_param args "show_scope_ids") ~default:false
          in
          let show_times =
            Option.value (get_optional_bool_param args "show_times") ~default:false
          in
          let max_depth = get_optional_int_param args "max_depth" in
          let values_first_mode =
            Option.value (get_optional_bool_param args "values_first_mode") ~default:false
          in

          (* Get latest run for summary *)
          let runs = Q.get_runs () in
          let latest_run =
            (match Q.get_latest_run_id () with
            | Some run_id ->
                List.find_opt (fun r -> r.Minidebug_client.Query.run_id = run_id) runs
            | None -> None)
            |> Option.get (* Safe: would have errored if no runs *)
          in

          (* Capture trace output using buffer-backed formatter *)
          let buffer = Buffer.create 4096 in
          let fmt = make_bounded_formatter ~budget:default_output_budget buffer in

          (* Generate run summary and trace *)
          (try
             Format.fprintf fmt "Run #%d\n" latest_run.run_id;
             Format.fprintf fmt "Timestamp: %s\n" latest_run.timestamp;
             Format.fprintf fmt "Command: %s\n" latest_run.command_line;
             Format.fprintf fmt "Elapsed: %s\n\n"
               (Query.format_elapsed_ns latest_run.elapsed_ns);

             (* Generate trace *)
             let roots = Q.get_root_entries ~with_values:false in
             let trees = Minidebug_cli.Renderer.build_tree (module Q) ?max_depth roots in
             let rendered =
               Minidebug_cli.Renderer.render_tree ~show_scope_ids ~show_times ~max_depth
                 ~values_first_mode trees
             in
             Format.fprintf fmt "%s" rendered;
             Format.pp_print_flush fmt ()
           with Output_budget_exceeded { written; limit } ->
             Buffer.add_string buffer
               (Printf.sprintf
                  "\n\
                   [... truncated: output exceeded %d byte limit (wrote %d bytes). Use \
                   max_depth parameter to reduce output.]"
                  limit written));

          let trace_text = Buffer.contents buffer in

          Tool.create_tool_result [ Mcp.make_text_content trace_text ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in show-trace: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: search-tree - Search with full tree context (best for LLM analysis) *)
  let _ =
    add_tool server ~name:"minidebug/search-tree"
      ~description:
        "Search entries with full ancestor tree context. Returns formatted text showing \
         each match with its complete path from root. This is the recommended search \
         tool for AI assistants to understand code execution flow. For large result \
         sets, use limit/offset parameters for pagination (e.g., limit=50) and max_depth \
         to limit tree depth. Uses SQL GLOB patterns (case-sensitive): pattern is \
         auto-wrapped as *pattern*. Wildcards: * (any chars), ? (one char), [abc] (char set)."
      ~schema_properties:
        [
          ( "pattern",
            "string",
            "SQL GLOB pattern to search for (auto-wrapped: 'error' becomes '*error*')" );
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum tree depth (optional)");
          ("quiet_path", "string", "Stop ancestor propagation at pattern (optional)");
          ("limit", "integer", "Limit number of results (optional)");
          ("offset", "integer", "Skip first n results (optional)");
        ]
      ~schema_required:[ "pattern" ]
      (fun args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          let pattern = get_string_param args "pattern" in
          let show_times =
            Option.value (get_optional_bool_param args "show_times") ~default:false
          in
          let max_depth = get_optional_int_param args "max_depth" in
          let quiet_path = get_optional_string_param args "quiet_path" in
          let limit = get_optional_int_param args "limit" in
          let offset = get_optional_int_param args "offset" in

          (* Capture search output using buffer-backed formatter *)
          let buffer = Buffer.create 4096 in
          let fmt = make_bounded_formatter ~budget:default_output_budget buffer in

          (try
             (* Get search results (cached or fresh) *)
             let results_table = get_search_results session ~pattern ~quiet_path in

             (* Extract matching entries from hash table *)
             let all_matching_scope_ids =
               Hashtbl.fold
                 (fun (scope_id, _seq_id) is_match acc ->
                   if is_match then scope_id :: acc else acc)
                 results_table []
               |> List.sort_uniq compare
             in

             (* Get all entries from DB and filter to only those in results_table *)
             let filtered_entries = Q.get_entries_from_results ~results_table in

             (* Build tree from filtered entries *)
             let all_trees =
               Minidebug_cli.Renderer.build_tree_from_entries filtered_entries
             in

             (* Apply pagination at the tree level (root scopes only) *)
             let trees =
               let t = all_trees in
               let t =
                 match offset with
                 | None -> t
                 | Some off ->
                     if off < List.length t then List.filteri (fun i _ -> i >= off) t
                     else []
               in
               match limit with
               | None -> t
               | Some lim ->
                   if lim >= List.length t then t else List.filteri (fun i _ -> i < lim) t
             in

             (* Output *)
             let total_scopes = List.length all_matching_scope_ids in
             let total_trees = List.length all_trees in
             let shown_trees = List.length trees in
             let start_idx = Option.value offset ~default:0 in
             if limit <> None || offset <> None then
               Format.fprintf fmt
                 "Found %d matching scopes for pattern '%s', %d root trees (showing \
                  trees %d-%d)\n\n"
                 total_scopes pattern total_trees start_idx (start_idx + shown_trees)
             else
               Format.fprintf fmt "Found %d matching scopes for pattern '%s'\n\n"
                 total_scopes pattern;
             let rendered =
               Minidebug_cli.Renderer.render_tree ~show_scope_ids:true ~show_times
                 ~max_depth ~values_first_mode:true trees
             in
             Format.fprintf fmt "%s" rendered;
             Format.pp_print_flush fmt ()
           with Output_budget_exceeded { written; limit = lim } ->
             Buffer.add_string buffer
               (Printf.sprintf
                  "\n\
                   [... truncated: output exceeded %d byte limit (wrote %d bytes). Use \
                   limit/offset/max_depth parameters to reduce output.]"
                  lim written));

          let output = Buffer.contents buffer in

          Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in search-tree: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: search-subtree - Search showing only matching subtrees *)
  let _ =
    add_tool server ~name:"minidebug/search-subtree"
      ~description:
        "Search entries and show only matching subtrees (pruned). Returns each match \
         with its descendants but prunes non-matching branches. For large result sets, \
         use limit parameter (e.g., limit=50) and max_depth to limit subtree depth. \
         Uses SQL GLOB patterns (auto-wrapped as *pattern*)."
      ~schema_properties:
        [
          ( "pattern",
            "string",
            "SQL GLOB pattern to search for (auto-wrapped: 'error' becomes '*error*')" );
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum depth from match (optional)");
          ("limit", "integer", "Limit number of results (optional)");
        ]
      ~schema_required:[ "pattern" ]
      (fun args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          let pattern = get_string_param args "pattern" in
          let show_times =
            Option.value (get_optional_bool_param args "show_times") ~default:false
          in
          let max_depth = get_optional_int_param args "max_depth" in
          let limit = get_optional_int_param args "limit" in

          (* Capture search output using buffer-backed formatter *)
          let buffer = Buffer.create 4096 in
          let fmt = make_bounded_formatter ~budget:default_output_budget buffer in

          (try
             (* Get search results (cached or fresh) *)
             let results_table = get_search_results session ~pattern ~quiet_path:None in

             (* Get entries from results_table (includes matches and propagated
                ancestors) *)
             let filtered_entries = Q.get_entries_from_results ~results_table in
             let full_trees =
               Minidebug_cli.Renderer.build_tree_from_entries filtered_entries
             in

             (* Prune tree: keep only nodes that have matches in their subtree *)
             let rec prune_tree node =
               let entry = node.Minidebug_cli.Renderer.entry in
               (* Check if this entry is a match *)
               let is_match = Hashtbl.mem results_table (entry.scope_id, entry.seq_id) in
               (* Recursively prune children *)
               let pruned_children = List.filter_map prune_tree node.children in
               (* Keep this node if it's a match OR if any child survived pruning *)
               if is_match || pruned_children <> [] then
                 Some { node with Minidebug_cli.Renderer.children = pruned_children }
               else None
             in

             let all_pruned_trees = List.filter_map prune_tree full_trees in

             (* Apply pagination to pruned trees (at root level) *)
             let pruned_trees =
               let trees = all_pruned_trees in
               let trees =
                 match limit with
                 | None -> trees
                 | Some lim ->
                     if lim >= List.length trees then trees
                     else List.filteri (fun i _ -> i < lim) trees
               in
               trees
             in

             (* Count actual matches (not propagated ancestors) *)
             let match_count =
               Hashtbl.fold
                 (fun _key is_match acc -> if is_match then acc + 1 else acc)
                 results_table 0
             in

             (* Output *)
             let total_trees = List.length all_pruned_trees in
             let shown_trees = List.length pruned_trees in
             if limit <> None then
               Format.fprintf fmt
                 "Found %d matches for pattern '%s', %d root trees (showing trees 0-%d):\n\n"
                 match_count pattern total_trees shown_trees
             else
               Format.fprintf fmt
                 "Found %d matches for pattern '%s', showing %d pruned subtrees:\n\n"
                 match_count pattern total_trees;
             let rendered =
               Minidebug_cli.Renderer.render_tree ~show_scope_ids:true ~show_times
                 ~max_depth ~values_first_mode:true pruned_trees
             in
             Format.fprintf fmt "%s" rendered;
             Format.pp_print_flush fmt ()
           with Output_budget_exceeded { written; limit = lim } ->
             Buffer.add_string buffer
               (Printf.sprintf
                  "\n\
                   [... truncated: output exceeded %d byte limit (wrote %d bytes). Use \
                   limit/max_depth parameters to reduce output.]"
                  lim written));

          let output = Buffer.contents buffer in

          Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in search-subtree: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: show-scope - Show specific scope with descendants *)
  let _ =
    add_tool server ~name:"minidebug/show-scope"
      ~description:
        "Show a specific scope by ID with its descendants and optional ancestors"
      ~schema_properties:
        [
          ("scope_id", "integer", "Scope ID to show");
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum depth from scope (optional)");
          ("show_ancestors", "boolean", "Include ancestor path (optional, default true)");
        ]
      ~schema_required:[ "scope_id" ]
      (fun args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          let scope_id =
            match get_optional_int_param args "scope_id" with
            | Some id -> id
            | None -> failwith "scope_id is required"
          in
          let show_times =
            Option.value (get_optional_bool_param args "show_times") ~default:false
          in
          let max_depth = get_optional_int_param args "max_depth" in
          let show_ancestors =
            Option.value (get_optional_bool_param args "show_ancestors") ~default:true
          in

          (* Capture scope output using buffer-backed formatter *)
          let buffer = Buffer.create 4096 in
          let fmt = make_bounded_formatter ~budget:default_output_budget buffer in

          (try
             (if show_ancestors then (
                (* Show path from root to this scope *)
                let ancestors = Q.get_ancestors ~scope_id in
                let filtered_entries = Q.get_entries_for_scopes ~scope_ids:ancestors in
                let trees =
                  Minidebug_cli.Renderer.build_tree_from_entries filtered_entries
                in
                Format.fprintf fmt "Ancestor path to scope %d:\n\n" scope_id;
                let rendered =
                  Minidebug_cli.Renderer.render_tree ~show_scope_ids:true ~show_times
                    ~max_depth ~values_first_mode:true trees
                in
                Format.fprintf fmt "%s" rendered)
              else
                (* Show just this scope and descendants *)
                let children = Q.get_scope_children ~parent_scope_id:scope_id in
                Format.fprintf fmt "Scope %d contents:\n\n" scope_id;
                let rendered = Minidebug_cli.Renderer.render_entries_json children in
                Format.fprintf fmt "%s\n" rendered);
             Format.pp_print_flush fmt ()
           with Output_budget_exceeded { written; limit } ->
             Buffer.add_string buffer
               (Printf.sprintf
                  "\n\
                   [... truncated: output exceeded %d byte limit (wrote %d bytes). Use \
                   max_depth parameter to reduce output.]"
                  limit written));

          let output = Buffer.contents buffer in

          Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in show-scope: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: get-ancestors - Get ancestor chain for navigation *)
  let _ =
    add_tool server ~name:"minidebug/get-ancestors"
      ~description:"Get the chain of ancestor scope IDs from root to the target scope"
      ~schema_properties:[ ("scope_id", "integer", "Scope ID to get ancestors for") ]
      ~schema_required:[ "scope_id" ]
      (fun args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          let scope_id =
            match get_optional_int_param args "scope_id" with
            | Some id -> id
            | None -> failwith "scope_id is required"
          in

          (* Capture ancestors output using buffer-backed formatter *)
          let buffer = Buffer.create 4096 in
          let fmt = make_bounded_formatter ~budget:default_output_budget buffer in

          (try
             (* Get all ancestor paths *)
             let all_paths = Q.get_all_ancestor_paths ~scope_id in

             (* Fetch header entries for ancestors *)
             let get_entry_for_scope ancestor_id =
               Q.find_scope_header ~scope_id:ancestor_id
             in

             if List.length all_paths = 1 then (
               Format.fprintf fmt "Ancestor path to scope %d:\n\n" scope_id;
               List.iter
                 (fun ancestor_id ->
                   match get_entry_for_scope ancestor_id with
                   | Some entry ->
                       let loc_str =
                         match entry.Minidebug_client.Query.location with
                         | Some loc -> Printf.sprintf " @ %s" loc
                         | None -> ""
                       in
                       Format.fprintf fmt "  #%d [%s] %s%s\n" ancestor_id
                         entry.Minidebug_client.Query.entry_type
                         entry.Minidebug_client.Query.message loc_str
                   | None -> ())
                 (List.hd all_paths))
             else (
               (* Multiple paths - simplified version showing just scope IDs *)
               Format.fprintf fmt "Found %d ancestor paths to scope %d:\n\n"
                 (List.length all_paths) scope_id;
               List.iteri
                 (fun i path ->
                   Format.fprintf fmt "Path %d: %s\n" (i + 1)
                     (String.concat " -> " (List.map string_of_int path)))
                 all_paths);
             Format.pp_print_flush fmt ()
           with Output_budget_exceeded { written; limit } ->
             Buffer.add_string buffer
               (Printf.sprintf
                  "\n[... truncated: output exceeded %d byte limit (wrote %d bytes)]"
                  limit written));

          let output = Buffer.contents buffer in

          Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in get-ancestors: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: get-children - Get child scope IDs for navigation *)
  let _ =
    add_tool server ~name:"minidebug/get-children"
      ~description:"Get the list of child scope IDs for a given scope"
      ~schema_properties:[ ("scope_id", "integer", "Scope ID to get children for") ]
      ~schema_required:[ "scope_id" ]
      (fun args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          let scope_id =
            match get_optional_int_param args "scope_id" with
            | Some id -> id
            | None -> failwith "scope_id is required"
          in

          (* Capture children output using buffer-backed formatter *)
          let buffer = Buffer.create 4096 in
          let fmt = make_bounded_formatter ~budget:default_output_budget buffer in

          (try
             (* Get children and extract child scope IDs *)
             let children = Q.get_scope_children ~parent_scope_id:scope_id in
             let child_scope_ids =
               List.filter_map
                 (fun e ->
                   match e.Minidebug_client.Query.child_scope_id with
                   | Some id -> Some id
                   | None -> None)
                 children
               |> List.sort_uniq compare
             in
             Format.fprintf fmt "Child scopes of %d: [ %s ]\n" scope_id
               (String.concat ", " (List.map string_of_int child_scope_ids));
             Format.pp_print_flush fmt ()
           with Output_budget_exceeded { written; limit } ->
             Buffer.add_string buffer
               (Printf.sprintf
                  "\n[... truncated: output exceeded %d byte limit (wrote %d bytes)]"
                  limit written));

          let output = Buffer.contents buffer in

          Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in get-children: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: show-subtree - Show subtree rooted at scope with ancestor path *)
  let _ =
    add_tool server ~name:"minidebug/show-subtree"
      ~description:
        "Show subtree rooted at a specific scope with optional ancestor path. Max depth \
         is INCREMENTAL from the target scope."
      ~schema_properties:
        [
          ("scope_id", "integer", "Scope ID to show subtree for");
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ( "max_depth",
            "integer",
            "Maximum INCREMENTAL depth from scope (optional, relative to target)" );
          ("show_ancestors", "boolean", "Include ancestor path (optional, default true)");
        ]
      ~schema_required:[ "scope_id" ]
      (fun args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          let scope_id =
            match get_optional_int_param args "scope_id" with
            | Some id -> id
            | None -> failwith "scope_id is required"
          in
          let show_times =
            Option.value (get_optional_bool_param args "show_times") ~default:false
          in
          let max_depth = get_optional_int_param args "max_depth" in
          let show_ancestors =
            Option.value (get_optional_bool_param args "show_ancestors") ~default:true
          in

          (* Capture subtree output using buffer-backed formatter *)
          let buffer = Buffer.create 4096 in
          let fmt = make_bounded_formatter ~budget:default_output_budget buffer in

          (try
             (if show_ancestors then (
                (* Get ancestor chain and build tree from filtered entries *)
                let ancestors = Q.get_ancestors ~scope_id in
                let filtered_entries = Q.get_entries_for_scopes ~scope_ids:ancestors in
                let trees =
                  Minidebug_cli.Renderer.build_tree_from_entries filtered_entries
                in

                Format.fprintf fmt "Subtree for scope %d (with ancestor path):\n\n"
                  scope_id;
                let rendered =
                  Minidebug_cli.Renderer.render_tree ~show_scope_ids:true ~show_times
                    ~max_depth ~values_first_mode:true trees
                in
                Format.fprintf fmt "%s" rendered)
              else
                (* Just show the subtree starting at scope_id *)
                (* Get all entries for this scope and its descendants *)
                let rec get_subtree_scope_ids sid =
                  let children = Q.get_scope_children ~parent_scope_id:sid in
                  let child_ids =
                    List.filter_map
                      (fun e -> e.Minidebug_client.Query.child_scope_id)
                      children
                  in
                  sid :: List.concat_map get_subtree_scope_ids child_ids
                in
                let all_scope_ids = get_subtree_scope_ids scope_id in
                let filtered_entries =
                  Q.get_entries_for_scopes ~scope_ids:all_scope_ids
                in
                let trees =
                  Minidebug_cli.Renderer.build_tree_from_entries filtered_entries
                in

                Format.fprintf fmt "Subtree for scope %d:\n\n" scope_id;
                let rendered =
                  Minidebug_cli.Renderer.render_tree ~show_scope_ids:true ~show_times
                    ~max_depth ~values_first_mode:true trees
                in
                Format.fprintf fmt "%s" rendered);
             Format.pp_print_flush fmt ()
           with Output_budget_exceeded { written; limit } ->
             Buffer.add_string buffer
               (Printf.sprintf
                  "\n\
                   [... truncated: output exceeded %d byte limit (wrote %d bytes). Use \
                   max_depth parameter to reduce output.]"
                  limit written));

          let output = Buffer.contents buffer in

          Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in show-subtree: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: search-at-depth - Search summary at specific depth *)
  let _ =
    add_tool server ~name:"minidebug/search-at-depth"
      ~description:
        "Search and show summary at a specific depth (TUI-like view). Good for large \
         traces where you want to see matches organized by depth level. Uses SQL GLOB \
         patterns (auto-wrapped as *pattern*)."
      ~schema_properties:
        [
          ( "pattern",
            "string",
            "SQL GLOB pattern to search for (auto-wrapped: 'error' becomes '*error*')" );
          ("depth", "integer", "Depth level to show summary at");
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ("quiet_path", "string", "Stop ancestor propagation at pattern (optional)");
        ]
      ~schema_required:[ "pattern"; "depth" ]
      (fun args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          let pattern = get_string_param args "pattern" in
          let depth =
            match get_optional_int_param args "depth" with
            | Some d -> d
            | None -> failwith "depth is required"
          in
          let show_times =
            Option.value (get_optional_bool_param args "show_times") ~default:false
          in
          let quiet_path = get_optional_string_param args "quiet_path" in

          (* Capture search output using buffer-backed formatter *)
          let buffer = Buffer.create 4096 in
          let fmt = make_bounded_formatter ~budget:default_output_budget buffer in

          (try
             (* Get search results (cached or fresh) *)
             let results_table = get_search_results session ~pattern ~quiet_path in

             (* Get entries from results_table and filter to specified depth *)
             let filtered_entries = Q.get_entries_from_results ~results_table in
             let depth_entries =
               List.filter
                 (fun e -> e.Minidebug_client.Query.depth = depth)
                 filtered_entries
               |> List.sort_uniq (fun a b ->
                      compare a.Minidebug_client.Query.scope_id
                        b.Minidebug_client.Query.scope_id)
             in

             (* For deduplication, keep only unique scope_ids at this depth *)
             let seen = Hashtbl.create 256 in
             let unique_entries =
               List.filter
                 (fun e ->
                   match e.Minidebug_client.Query.child_scope_id with
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
             Format.fprintf fmt
               "Found %d matches for pattern '%s', showing %d unique entries at depth \
                %d:\n\n"
               match_count pattern (List.length unique_entries) depth;
             List.iter
               (fun entry ->
                 Format.fprintf fmt "#%d [%s] %s" entry.Minidebug_client.Query.scope_id
                   entry.entry_type entry.message;
                 (match entry.location with
                 | Some loc -> Format.fprintf fmt " @ %s" loc
                 | None -> ());
                 (if show_times then
                    match Query.elapsed_time entry with
                    | Some elapsed ->
                        Format.fprintf fmt " <%s>"
                          (Query.format_elapsed_ns elapsed)
                    | None -> ());
                 Format.fprintf fmt "\n")
               unique_entries;
             Format.pp_print_flush fmt ()
           with Output_budget_exceeded { written; limit } ->
             Buffer.add_string buffer
               (Printf.sprintf
                  "\n[... truncated: output exceeded %d byte limit (wrote %d bytes)]"
                  limit written));

          let output = Buffer.contents buffer in

          Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in search-at-depth: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: search-intersection - Find scopes matching all patterns *)
  let _ =
    add_tool server ~name:"minidebug/search-intersection"
      ~description:
        "Find scopes that match ALL provided patterns (intersection). Supports 2-4 \
         patterns. Returns full tree context for each matching scope. For large result \
         sets, use limit/offset parameters (e.g., limit=50). Uses SQL GLOB patterns \
         (auto-wrapped as *pattern*)."
      ~schema_properties:
        [
          ( "patterns",
            "array",
            "Array of 2-4 SQL GLOB patterns (all must match, auto-wrapped as *pattern*)" );
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum tree depth (optional)");
          ("quiet_path", "string", "Stop ancestor propagation at pattern (optional)");
          ("limit", "integer", "Limit number of results (optional)");
          ("offset", "integer", "Skip first n results (optional)");
        ]
      ~schema_required:[ "patterns" ]
      (fun args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          let patterns =
            match args with
            | `Assoc fields -> (
                match List.assoc_opt "patterns" fields with
                | Some (`List items) ->
                    List.map
                      (function
                        | `String s -> s
                        | _ -> failwith "patterns must be array of strings")
                      items
                | _ -> failwith "patterns must be an array")
            | _ -> failwith "Expected JSON object"
          in

          if List.length patterns < 2 || List.length patterns > 4 then
            failwith "search-intersection requires 2-4 patterns";

          let show_times =
            Option.value (get_optional_bool_param args "show_times") ~default:false
          in
          let _max_depth = get_optional_int_param args "max_depth" in
          let quiet_path = get_optional_string_param args "quiet_path" in
          let limit = get_optional_int_param args "limit" in
          let offset = get_optional_int_param args "offset" in

          (* Capture search output using buffer-backed formatter *)
          let buffer = Buffer.create 4096 in
          let fmt = make_bounded_formatter ~budget:default_output_budget buffer in

          (try
             (* Run separate search for each pattern (using cache) *)
             let all_results_tables =
               List.map
                 (fun pattern ->
                   let results_table = get_search_results session ~pattern ~quiet_path in
                   (pattern, results_table))
                 patterns
             in

             (* Extract scope IDs that actually match (not just propagated ancestors) from
                each search *)
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

             (* Compute LCAs for all combinations of matches (one per pattern) *)
             let rec cartesian_product = function
               | [] -> [ [] ]
               | (pattern, ids) :: rest ->
                   let rest_product = cartesian_product rest in
                   List.concat_map
                     (fun id ->
                       List.map (fun combo -> (pattern, id) :: combo) rest_product)
                     ids
             in

             let all_combinations = cartesian_product matching_scope_ids_per_pattern in

             (* Compute LCA for each combination *)
             let lcas =
               List.concat_map
                 (fun combo ->
                   let scope_ids = List.map snd combo in
                   match Q.lowest_common_ancestor scope_ids with
                   | Some lca -> [ lca ]
                   | None ->
                       (* No common ancestor - scopes are in separate root trees *)
                       List.map (fun id -> Q.get_root_scope id) scope_ids)
                 all_combinations
               |> List.sort_uniq compare
             in

             (* Get entries for LCA scopes *)
             let lca_entries =
               List.filter_map
                 (fun lca_scope_id -> Q.find_scope_header ~scope_id:lca_scope_id)
                 lcas
             in

             (* Apply pagination to LCA list *)
             let paginated_lca_entries =
               let entries = lca_entries in
               let entries =
                 match offset with
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
             let total_lcas = List.length lcas in
             let shown_lcas = List.length paginated_lca_entries in
             let start_idx = Option.value offset ~default:0 in
             let pattern_str =
               String.concat " AND " (List.map (Printf.sprintf "'%s'") patterns)
             in

             if limit <> None || offset <> None then
               Format.fprintf fmt
                 "Found %d smallest subtrees containing all patterns (%s) (showing \
                  %d-%d):\n\n"
                 total_lcas pattern_str start_idx (start_idx + shown_lcas)
             else
               Format.fprintf fmt
                 "Found %d smallest subtrees containing all patterns (%s):\n\n" total_lcas
                 pattern_str;

             (* Show per-pattern match counts *)
             Format.fprintf fmt "Per-pattern match counts:\n";
             List.iter
               (fun (pattern, scope_ids) ->
                 Format.fprintf fmt "  '%s': %d scopes\n" pattern (List.length scope_ids))
               matching_scope_ids_per_pattern;
             Format.fprintf fmt "\n";

             (* Display LCA scopes compactly *)
             Format.fprintf fmt "Lowest Common Ancestor scopes (smallest subtrees):\n\n";
             List.iter
               (fun entry ->
                 match entry.Minidebug_client.Query.child_scope_id with
                 | Some lca_scope_id ->
                     let loc_str =
                       match entry.Minidebug_client.Query.location with
                       | Some loc -> Printf.sprintf " [%s]" loc
                       | None -> ""
                     in
                     let elapsed_str =
                       match Query.elapsed_time entry with
                       | Some ns when show_times ->
                           Printf.sprintf " (%s)"
                             (Query.format_elapsed_ns ns)
                       | _ -> ""
                     in
                     Format.fprintf fmt "  Scope %d: %s%s%s\n" lca_scope_id
                       entry.Minidebug_client.Query.message loc_str elapsed_str
                 | None -> ())
               paginated_lca_entries;
             Format.fprintf fmt "\n";
             Format.pp_print_flush fmt ()
           with Output_budget_exceeded { written; limit = lim } ->
             Buffer.add_string buffer
               (Printf.sprintf
                  "\n\
                   [... truncated: output exceeded %d byte limit (wrote %d bytes). Use \
                   limit/offset parameters to reduce output.]"
                  lim written));

          let output = Buffer.contents buffer in

          Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in search-intersection: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Helper to parse comma-separated path strings *)
  let parse_path_param args param_name =
    match get_optional_string_param args param_name with
    | Some path_str -> String.split_on_char ',' path_str
    | None -> failwith (Printf.sprintf "%s is required" param_name)
  in

  (* Tool: search-extract - Search DAG path then extract with deduplication *)
  let _ =
    add_tool server ~name:"minidebug/search-extract"
      ~description:
        "Search for matches along a DAG path, then extract values at a different path \
         with change tracking. Paths are comma-separated patterns. Both paths must start \
         with the same pattern. Shows only changed values (deduplication). Uses SQL GLOB \
         patterns (auto-wrapped as *pattern*)."
      ~schema_properties:
        [
          ( "search_path",
            "string",
            "Comma-separated SQL GLOB patterns (e.g., 'fn_a,param_x', auto-wrapped)" );
          ( "extraction_path",
            "string",
            "Comma-separated SQL GLOB patterns (e.g., 'fn_a,result', auto-wrapped)" );
          ("show_times", "boolean", "Include elapsed times (optional, default false)");
          ("max_depth", "integer", "Maximum depth from match (optional)");
        ]
      ~schema_required:[ "search_path"; "extraction_path" ]
      (fun args ->
        try
          let session = get_session () in
          let module Q = (val session.query : Minidebug_client.Query.S) in
          let search_path = parse_path_param args "search_path" in
          let extraction_path = parse_path_param args "extraction_path" in

          (* Validate that paths are non-empty and share first element *)
          (match (search_path, extraction_path) with
          | [], _ | _, [] -> failwith "search-extract requires non-empty paths"
          | s_first :: _, e_first :: _ when s_first <> e_first ->
              failwith
                (Printf.sprintf
                   "Search and extraction paths must start with the same pattern. Search \
                    starts with '%s', extraction starts with '%s'"
                   s_first e_first)
          | _ -> ());

          let show_times =
            Option.value (get_optional_bool_param args "show_times") ~default:false
          in
          let max_depth = get_optional_int_param args "max_depth" in

          (* Capture search output using buffer-backed formatter *)
          let buffer = Buffer.create 4096 in
          let fmt = make_bounded_formatter ~budget:default_output_budget buffer in

          (try
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
                       Format.fprintf fmt "=== Match #%d at shared scope #%d ==>\n"
                         !unique_extractions shared_scope_id;

                       (* Get the scope entry for the extracted scope *)
                       let scope_children =
                         Q.get_scope_children ~parent_scope_id:extracted_scope_id
                       in
                       (* Find the header entry (if any) and build tree *)
                       match scope_children with
                       | [] -> Format.fprintf fmt "(empty scope)\n\n"
                       | _ ->
                           let trees =
                             Minidebug_cli.Renderer.build_tree
                               (module Q)
                               ?max_depth scope_children
                           in
                           let rendered_output =
                             Minidebug_cli.Renderer.render_tree ~show_scope_ids:true
                               ~show_times ~max_depth ~values_first_mode:true trees
                           in
                           Format.fprintf fmt "%s" rendered_output;
                           Format.fprintf fmt "\n"))
               matching_paths;

             (* Print summary *)
             Format.fprintf fmt
               "\n\
                Search-extract complete: %d total matches, %d unique extractions \
                (skipped %d consecutive duplicates)\n"
               !total_matches !unique_extractions
               (!total_matches - !unique_extractions);
             Format.pp_print_flush fmt ()
           with Output_budget_exceeded { written; limit } ->
             Buffer.add_string buffer
               (Printf.sprintf
                  "\n\
                   [... truncated: output exceeded %d byte limit (wrote %d bytes). Use \
                   max_depth parameter to reduce output.]"
                  limit written));

          let output = Buffer.contents buffer in

          Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in search-extract: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: tui-execute - Execute TUI command sequence and return screen rendering *)
  let _ =
    add_tool server ~name:"minidebug/tui-execute"
      ~description:
        "Execute TUI command sequence and return screen rendering. Maintains stateful \
         navigation across calls (cursor position, expansions, searches persist). \
         Commands: j/k (down/up), u/d (quarter page), pgup/pgdn, home/end, enter/space \
         (expand), f (fold), n/N (next/prev match), /pattern (search with SQL GLOB - \
         auto-wrapped as *pattern*), g42 (goto scope), Qpattern (quiet path filter), \
         t (toggle times), v (toggle values), o (toggle search order), q (quit). \
         GLOB wildcards: * (any chars), ? (one char), [abc] (char set)."
      ~schema_properties:
        [
          ( "commands",
            "array",
            "Array of command strings to execute sequentially (e.g., ['j', 'j', 'enter', \
             '/error'])" );
          ("term_width", "integer", "Terminal width for rendering (default: 120)");
          ("term_height", "integer", "Terminal height for rendering (default: 40)");
        ]
      ~schema_required:[ "commands" ]
      (fun args ->
        try
          let session = get_session () in

          (* Extract parameters *)
          let commands =
            match args with
            | `Assoc fields -> (
                match List.assoc_opt "commands" fields with
                | Some (`List cmd_list) ->
                    List.map
                      (function
                        | `String s -> s
                        | _ -> failwith "Each command must be a string")
                      cmd_list
                | _ -> failwith "Missing or invalid 'commands' parameter")
            | _ -> failwith "Expected JSON object"
          in
          let term_width =
            match get_optional_int_param args "term_width" with
            | Some w -> w
            | None -> 120
          in
          let term_height =
            match get_optional_int_param args "term_height" with
            | Some h -> h
            | None -> 40
          in

          (* Get or initialize TUI state *)
          let state =
            match session.tui_state with
            | Some ts -> ts.state
            | None ->
                let module Q = (val session.query) in
                I.initial_state (module Q)
          in

          (* Execute command sequence *)
          let final_state =
            List.fold_left
              (fun st cmd_str ->
                match parse_command cmd_str with
                | Some command -> (
                    match I.handle_command st command ~height:term_height with
                    | Some new_state -> new_state
                    | None -> st (* Command returned None (quit) - keep current state *))
                | None ->
                    Logs.warn (fun m -> m "Unknown command: %s" cmd_str);
                    st)
              state commands
          in

          (* Update session *)
          session.tui_state <-
            Some { state = final_state; last_update = Unix.gettimeofday () };

          (* Render with text renderer *)
          let output = render_screen final_state ~term_width ~term_height in

          Tool.create_tool_result [ Mcp.make_text_content output ] ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in tui-execute: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  (* Tool: tui-reset - Reset TUI state to initial view *)
  let _ =
    add_tool server ~name:"minidebug/tui-reset"
      ~description:"Reset TUI state to initial view (clears navigation, search, expansions)"
      ~schema_properties:[] ~schema_required:[] (fun _args ->
        try
          let session = get_session () in
          session.tui_state <- None;
          Tool.create_tool_result
            [ Mcp.make_text_content "TUI state reset to initial view" ]
            ~is_error:false
        with e ->
          Logs.err (fun m -> m "Error in tui-reset: %s" (Printexc.to_string e));
          Tool.create_error_result (Printexc.to_string e))
  in

  server
