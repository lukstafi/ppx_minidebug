(** Tree renderer for terminal output *)

module Query = Minidebug_client.Query

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
                  build_node
                    (module Q : Query.S)
                    ?max_depth ~current_depth:(current_depth + 1) child
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

(** Build tree from pre-loaded entries (for search/filter use cases). This is less
    efficient but needed when working with filtered entry sets. *)
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
      if show_scope_ids then Buffer.add_string buf (Printf.sprintf "#%d " entry.scope_id);

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
          Buffer.add_string buf (Printf.sprintf "[%s] %s" entry.entry_type entry.message);

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
             match Query.elapsed_time entry with
             | Some elapsed ->
                 Buffer.add_string buf
                   (Printf.sprintf " <%s>" (Query.format_elapsed_ns elapsed))
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
             match Query.elapsed_time entry with
             | Some elapsed ->
                 Buffer.add_string buf
                   (Printf.sprintf " <%s>" (Query.format_elapsed_ns elapsed))
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
              when result_child.children = [] && result_child.entry.child_scope_id = None
              ->
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
            List.iter (render_node ~indent:child_indent ~depth:(depth + 1)) node.children)
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

    (match Query.elapsed_time entry with
    | Some elapsed ->
        Buffer.add_string buf (Printf.sprintf " <%s>" (Query.format_elapsed_ns elapsed))
    | None -> ());

    Buffer.add_string buf "\n";

    let child_indent = indent ^ "  " in
    List.iter (render_node ~indent:child_indent) node.children
  in

  List.iter (render_node ~indent:"") trees;
  Buffer.contents buf

(** Render root entries as a flat list *)
let render_roots ?(show_times = false) ?(with_values = false) (entries : Query.entry list)
    =
  let buf = Buffer.create 1024 in

  (* Separate headers and values *)
  let headers = List.filter (fun (e : Query.entry) -> e.child_scope_id <> None) entries in
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
         match Query.elapsed_time header with
         | Some elapsed ->
             Buffer.add_string buf (Printf.sprintf " <%s>" (Query.format_elapsed_ns elapsed))
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
  (match Query.elapsed_time entry with
  | Some elapsed -> parts := Printf.sprintf "\"elapsed_ns\": %d" elapsed :: !parts
  | None -> parts := "\"elapsed_ns\": null" :: !parts);
  parts := Printf.sprintf "\"is_result\": %b" entry.is_result :: !parts;
  parts := Printf.sprintf "\"log_level\": %d" entry.log_level :: !parts;
  parts :=
    Printf.sprintf "\"entry_type\": \"%s\"" (json_escape entry.entry_type) :: !parts;
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
