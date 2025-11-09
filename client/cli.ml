(** Main client interface *)

module Query = Minidebug_client.Query

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
    corresponding versioned database file. Returns None if the run doesn't exist (e.g.,
    when log_level prevents DB creation). *)
let open_by_run_name ~meta_file_base ~run_name =
  let meta_file = meta_file_base ^ "_meta.db" in
  if not (Sys.file_exists meta_file) then None
  else
    (* Open metadata DB directly with SQLite, not through Client API *)
    let meta_db = Sqlite3.db_open ~mode:`READONLY meta_file in
    let stmt = Sqlite3.prepare meta_db "SELECT db_file FROM runs WHERE run_name = ?" in
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
      Format.fprintf output "Elapsed: %s\n\n" (Query.format_elapsed_ns run.elapsed_ns)
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
      Printf.fprintf oc "- **Elapsed**: %s\n\n" (Query.format_elapsed_ns r.elapsed_ns)
  | None -> ());

  Printf.fprintf oc "## Execution Trace\n\n";

  let rec render_node ~depth (node : Renderer.tree_node) =
    let entry = node.Renderer.entry in
    let indent = String.make (depth * 2) ' ' in

    (* Entry header *)
    Printf.fprintf oc "%s- **%s** `%s`" indent entry.entry_type entry.message;
    (match entry.location with Some loc -> Printf.fprintf oc " *@ %s*" loc | None -> ());
    (match Query.elapsed_time entry with
    | Some elapsed -> Printf.fprintf oc " _%s_" (Query.format_elapsed_ns elapsed)
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

(** Search with tree context - shows matching entries with their ancestor paths. Uses the
    populate_search_results approach from TUI for efficient ancestor propagation. *)
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
      (fun (scope_id, _seq_id) is_match acc -> if is_match then scope_id :: acc else acc)
      results_table []
    |> List.sort_uniq compare
  in

  (* Apply pagination to matching scope IDs *)
  let matching_scope_ids =
    let ids = all_matching_scope_ids in
    let ids =
      match offset with
      | None -> ids
      | Some off ->
          if off < List.length ids then List.filteri (fun i _ -> i >= off) ids else []
    in
    match limit with
    | None -> ids
    | Some lim ->
        if lim >= List.length ids then ids else List.filteri (fun i _ -> i < lim) ids
  in

  (* Get all entries from DB and filter to only those in results_table *)
  let filtered_entries = Q.get_entries_from_results ~results_table in

  (* Build tree from filtered entries *)
  let all_trees = Renderer.build_tree_from_entries filtered_entries in

  (* Apply pagination at the tree level (root scopes only) *)
  let trees =
    let t = all_trees in
    let t =
      match offset with
      | None -> t
      | Some off ->
          if off < List.length t then List.filteri (fun i _ -> i >= off) t else []
    in
    match limit with
    | None -> t
    | Some lim -> if lim >= List.length t then t else List.filteri (fun i _ -> i < lim) t
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
           %d-%d)\n\n"
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

(** Search and show only matching subtrees (prune non-matching branches). This builds a
    minimal tree containing only paths to matches. *)
let search_subtree ?(output = Format.std_formatter) ?(quiet_path = None) ?(format = `Text)
    ?(show_times = false) ?(max_depth = None) ?(limit = None) ?(offset = None) t ~pattern
    =
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
    let pruned_children = List.filter_map prune_tree node.children in
    (* Keep this node if it's a match OR if any child survived pruning *)
    if is_match || pruned_children <> [] then
      Some { node with Renderer.children = pruned_children }
    else None
  in

  let all_pruned_trees = List.filter_map prune_tree full_trees in

  (* Apply pagination to pruned trees (at root level) *)
  let pruned_trees =
    let trees = all_pruned_trees in
    let trees =
      match offset with
      | None -> trees
      | Some off ->
          if off < List.length trees then List.filteri (fun i _ -> i >= off) trees else []
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

(** Search intersection - find smallest subtrees containing all patterns (LCA-based). For
    each pattern, runs populate_search_results to get matching scopes. Then computes all
    LCAs (Lowest Common Ancestors) for combinations of matches (one match per pattern).
    Returns unique LCA scopes as the smallest subtrees. *)
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

  (* Extract scope IDs that actually match (not just propagated ancestors) from each
     search *)
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

  (* Compute LCAs for all combinations of matches (one per pattern). This generates the
     Cartesian product of all match sets and computes LCA for each tuple. *)
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

    (* Compute LCA for each combination. If no LCA exists (scopes in separate trees), fall
       back to returning the root scopes themselves. *)
    let lcas =
      List.concat_map
        (fun combo ->
          let scope_ids = List.map snd combo in
          match Q.lowest_common_ancestor scope_ids with
          | Some lca -> [ lca ]
          | None ->
              (* No common ancestor - scopes are in separate root trees. Return all root
                 scopes as separate minimal subtrees. *)
              List.map (fun id -> Q.get_root_scope id) scope_ids)
        all_combinations
      |> List.sort_uniq compare
    in
    lcas
  in

  (* Get entries for LCA scopes (just the header entries for compact display) *)
  let lca_entries =
    List.filter_map
      (fun lca_scope_id -> Q.find_scope_header ~scope_id:lca_scope_id)
      lca_scope_ids
  in

  (* Apply pagination to LCA list *)
  let paginated_lca_entries =
    let entries = lca_entries in
    let entries =
      match offset with
      | None -> entries
      | Some off ->
          if off < List.length entries then List.filteri (fun i _ -> i >= off) entries
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
      let pattern_str =
        String.concat " AND " (List.map (Printf.sprintf "'%s'") patterns)
      in

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
                match Query.elapsed_time entry with
                | Some ns when show_times ->
                    Printf.sprintf " (%s)" (Query.format_elapsed_ns ns)
                | _ -> ""
              in
              Format.fprintf output "  Scope %d: %s%s%s\n" lca_scope_id
                entry.Query.message loc_str elapsed_str
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
    match format with
    | `Text ->
        Format.fprintf output "Ancestor path to scope %d:\n\n" scope_id;
        let rendered =
          Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth
            ~values_first_mode:true trees
        in
        Format.fprintf output "%s" rendered
    | `Json ->
        let json = Renderer.render_tree_json ~max_depth trees in
        Format.fprintf output "%s\n" json
  else
    (* Show just this scope and descendants *)
    let children = Q.get_scope_children ~parent_scope_id:scope_id in
    match format with
    | `Text ->
        Format.fprintf output "Scope %d contents:\n\n" scope_id;
        let rendered = Renderer.render_entries_json children in
        Format.fprintf output "%s\n" rendered
    | `Json ->
        let json = Renderer.render_entries_json children in
        Format.fprintf output "%s\n" json

(** Show a specific scope subtree with ancestors (full tree rendering). The max_depth
    parameter is interpreted as INCREMENTAL depth from the target scope. Shows: ancestor
    path → target scope → descendants (up to max_depth levels below target). *)
let show_subtree ?(output = Format.std_formatter) ?(format = `Text) ?(show_times = false)
    ?(max_depth = None) ?(show_ancestors = true) t ~scope_id =
  let module Q = (val t : Query.S) in
  (* Strategy: 1. If show_ancestors=true: Build tree from root down to scope_id (no depth
     limit on ancestors) 2. At scope_id: Apply max_depth limit for descendants

     We accomplish this by: - Getting the ancestor chain from root to scope_id - Building
     a "spine" tree following that path - At the target scope_id, use max_depth for its
     subtree *)
  if show_ancestors then
    (* Get ancestor chain (scope_id -> parent -> ... -> root) *)
    let ancestors = Q.get_ancestors ~scope_id in

    (* Build ancestor path tree by filtering to just the ancestor path. We build trees
       from roots, then we'll walk down to find the target scope. *)
    let roots = Q.get_root_entries ~with_values:false in

    (* Find which root is the ancestor - it's the LAST element in ancestors list *)
    let root_scope = List.nth ancestors (List.length ancestors - 1) in
    let root_entry_opt =
      List.find_opt
        (fun e ->
          match e.Query.child_scope_id with Some id -> id = root_scope | None -> false)
        roots
    in

    match root_entry_opt with
    | None ->
        Printf.eprintf
          "Error: Could not find root entry for scope %d (root scope is %d)\n" scope_id
          root_scope;
        exit 1
    | Some root_entry -> (
        (* Build full tree from root, but with special max_depth handling: - No depth
           limit until we reach scope_id - At scope_id, apply max_depth *)
        let tree =
          Renderer.build_node (module Q) ?max_depth ~current_depth:0 root_entry
        in

        (* Output *)
        match format with
        | `Text ->
            Format.fprintf output "Subtree for scope %d (with ancestor path):\n\n"
              scope_id;
            let rendered =
              Renderer.render_tree ~show_scope_ids:true ~show_times ~max_depth:None
                ~values_first_mode:true [ tree ]
            in
            Format.fprintf output "%s" rendered
        | `Json ->
            let json = Renderer.render_tree_json ~max_depth:None [ tree ] in
            Format.fprintf output "%s\n" json)
  else
    (* Just show the subtree starting at scope_id *)
    (* First, find the header entry for this scope *)
    let header_entry_opt = Q.find_scope_header ~scope_id in

    match header_entry_opt with
    | None ->
        Printf.eprintf "Error: Could not find header entry for scope %d\n" scope_id;
        exit 1
    | Some header_entry -> (
        let tree =
          Renderer.build_node (module Q) ?max_depth ~current_depth:0 header_entry
        in

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
      | `Text -> (
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
          match Query.elapsed_time entry with
          | Some elapsed ->
              Format.fprintf output "  Elapsed: %s\n" (Query.format_elapsed_ns elapsed)
          | None -> ())
      | `Json ->
          let json = Renderer.entry_to_json entry in
          Format.fprintf output "%s\n" json)

(** Get ancestors of a scope (returns ALL paths from root to target due to DAG structure)
*)
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
                let loc_str =
                  match entry.Query.location with
                  | Some loc -> Printf.sprintf " @ %s" loc
                  | None -> ""
                in
                Format.fprintf output "  #%d [%s] %s%s\n" ancestor_id
                  entry.Query.entry_type entry.Query.message loc_str
            | None -> ())
          (List.hd all_paths))
      else (
        (* Multiple paths - use Hasse diagram style rendering *)
        Format.fprintf output
          "Found %d ancestor paths to scope %d (Hasse diagram view):\n\n"
          (List.length all_paths) scope_id;

        (* Collect all unique scopes and their parents from the paths *)
        let all_scopes = Hashtbl.create 1000 in
        let scope_parents_in_paths = Hashtbl.create 1000 in

        List.iter
          (fun path ->
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
            done)
          all_paths;

        (* Build levels using topological sort (BFS from roots) *)
        let scope_level = Hashtbl.create 1000 in
        let roots =
          Hashtbl.fold
            (fun sid () acc ->
              match Hashtbl.find_opt scope_parents_in_paths sid with
              | None -> sid :: acc (* No parents in paths = root *)
              | Some _ -> acc)
            all_scopes []
        in

        (* BFS to assign levels *)
        let queue = Queue.create () in
        List.iter
          (fun root ->
            Hashtbl.add scope_level root 0;
            Queue.add root queue)
          roots;

        while not (Queue.is_empty queue) do
          let current = Queue.take queue in
          let current_level = Hashtbl.find scope_level current in

          (* Find all children (scopes that have current as parent) *)
          Hashtbl.iter
            (fun child parents_set ->
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
                      Queue.add child queue))
            scope_parents_in_paths
        done;

        (* Group by level *)
        let levels = Hashtbl.create 100 in
        Hashtbl.iter
          (fun sid level ->
            let level_scopes =
              match Hashtbl.find_opt levels level with None -> [] | Some lst -> lst
            in
            Hashtbl.replace levels level (sid :: level_scopes))
          scope_level;

        let max_level = Hashtbl.fold (fun _ level acc -> max level acc) scope_level 0 in

        (* Print each level *)
        for level = 0 to max_level do
          match Hashtbl.find_opt levels level with
          | None -> ()
          | Some scope_ids ->
              let sorted_ids = List.sort compare scope_ids in
              Format.fprintf output "Level %d (%s, %d scopes):\n" level
                (if level = 0 then "roots"
                 else if level = max_level then "target"
                 else "intermediate")
                (List.length sorted_ids);

              List.iter
                (fun ancestor_id ->
                  match get_entry_for_scope ancestor_id with
                  | Some entry ->
                      let loc_str =
                        match entry.Query.location with
                        | Some loc -> Printf.sprintf " @ %s" loc
                        | None -> ""
                      in
                      Format.fprintf output "  #%d [%s] %s%s\n" ancestor_id
                        entry.Query.entry_type entry.Query.message loc_str
                  | None -> Format.fprintf output "  #%d (no entry found)\n" ancestor_id)
                sorted_ids;

              Format.fprintf output "\n"
        done)
  | `Json ->
      let json_paths =
        List.map
          (fun path ->
            let json_entries =
              List.filter_map
                (fun ancestor_id ->
                  match get_entry_for_scope ancestor_id with
                  | Some entry ->
                      Some
                        (Printf.sprintf
                           {|{"scope_id": %d, "entry_type": "%s", "message": "%s", "location": %s}|}
                           ancestor_id entry.Query.entry_type
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
  | None -> (
      match format with
      | `Text -> Format.fprintf output "Scope %d has no parent (is root)\n" scope_id
      | `Json -> Format.fprintf output "%s\n" "null")
  | Some parent_id -> (
      match format with
      | `Text -> Format.fprintf output "Parent of scope %d: %d\n" scope_id parent_id
      | `Json -> Format.fprintf output "%d\n" parent_id)

(** Get immediate children of a scope *)
let get_children ?(output = Format.std_formatter) ?(format = `Text) t ~scope_id =
  let module Q = (val t : Query.S) in
  let children = Q.get_scope_children ~parent_scope_id:scope_id in
  let child_scope_ids =
    List.filter_map
      (fun e -> match e.Query.child_scope_id with Some id -> Some id | None -> None)
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

(** Search and show only entries at a specific depth on paths to matches. This gives a
    TUI-like summary view - shows only the depth-N ancestors of matching entries, filtered
    by quiet_path. *)
let search_at_depth ?(output = Format.std_formatter) ?(quiet_path = None)
    ?(format = `Text) ?(show_times = false) ~depth t ~pattern =
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
             match Query.elapsed_time entry with
             | Some elapsed ->
                 Format.fprintf output " <%s>" (Query.format_elapsed_ns elapsed)
             | None -> ());
          Format.fprintf output "\n")
        unique_entries
  | `Json ->
      let json = Renderer.render_entries_json unique_entries in
      Format.fprintf output "%s\n" json

(** Search DAG with a path pattern, then extract along a different path with
    deduplication. For each match of search_path, extracts along extraction_path (which
    shares the first element with search_path). Prints each extracted subtree, skipping
    consecutive duplicates (same scope_id). *)
let search_extract ?(output = Format.std_formatter) ?(format = `Text)
    ?(show_times = false) ?(max_depth = None) t ~search_path ~extraction_path =
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
  let extraction_tail = match extraction_path with _ :: tail -> tail | [] -> [] in

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
            match format with
            | `Text -> (
                Format.fprintf output "=== Match #%d at shared scope #%d ==>\n"
                  !unique_extractions shared_scope_id;

                (* Get the scope entry for the extracted scope *)
                let scope_children =
                  Q.get_scope_children ~parent_scope_id:extracted_scope_id
                in
                (* Find the header entry (if any) and build tree *)
                match scope_children with
                | [] -> Format.fprintf output "(empty scope)\n\n"
                | _ ->
                    let trees =
                      Renderer.build_tree (module Q) ?max_depth scope_children
                    in
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
                  !unique_extractions shared_scope_id extracted_scope_id tree_json))
    matching_paths;

  (* Print summary *)
  match format with
  | `Text ->
      Format.fprintf output
        "\n\
         Search-extract complete: %d total matches, %d unique extractions (skipped %d \
         consecutive duplicates)\n"
        !total_matches !unique_extractions
        (!total_matches - !unique_extractions)
  | `Json -> ()
