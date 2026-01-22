(* Test for Interactive.HighlightNext command

   Verifies that the command recursively expands highlighted scopes starting from cursor
   position, drilling down into nested highlights until reaching a leaf (non-expandable
   or already expanded highlight). *)

open Sexplib0.Sexp_conv

let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "test_highlight_next" in
  fun () -> rt

module Debug_runtime = (val _get_local_debug_runtime ())

let%debug_sexp level3 (x : int) : int = x * 2

let%debug_sexp level2 (x : int) : int =
  let a = level3 x in
  let b = level3 (x + 1) in
  a + b

let%debug_sexp level1 (x : int) : int =
  let y = level2 x in
  let z = level2 (x + 1) in
  y + z

let () =
  (* Generate a DB with nested scopes 3 levels deep *)
  ignore (level1 1);
  ignore (level1 10);

  let module Q =
    Minidebug_client.Query.Make (struct
      let db_path = "test_highlight_next_1.db"
    end)
  in

  let module I = Minidebug_client.Interactive in

  let root_entries = Q.get_root_entries ~with_values:false in
  if List.length root_entries < 2 then failwith "expected >=2 root entries";

  (* Find scope headers at each level *)
  let find_scope_headers entries =
    List.filter (fun e -> e.Minidebug_client.Query.child_scope_id <> None) entries
  in

  let first_root = List.hd (find_scope_headers root_entries) in
  let second_root = List.nth (find_scope_headers root_entries) 1 in

  let second_root_hid =
    match second_root.child_scope_id with
    | Some hid -> hid
    | None -> failwith "expected second root to be a scope header"
  in

  (* Get nested scopes inside second root *)
  let second_root_children = Q.get_scope_children ~parent_scope_id:second_root_hid in
  let nested_headers = find_scope_headers second_root_children in

  if List.length nested_headers < 1 then failwith "expected at least 1 nested scope";

  let nested_scope = List.hd nested_headers in
  let nested_hid =
    match nested_scope.child_scope_id with
    | Some hid -> hid
    | None -> failwith "expected nested scope to have child_scope_id"
  in

  (* Get deeply nested scope (level 3) *)
  let deep_children = Q.get_scope_children ~parent_scope_id:nested_hid in
  let deep_headers = find_scope_headers deep_children in

  (* Mark second_root, nested_scope, and a deep scope as highlighted *)
  let results = Hashtbl.create 16 in
  Hashtbl.replace results (second_root.scope_id, second_root.seq_id) true;
  Hashtbl.replace results (nested_scope.scope_id, nested_scope.seq_id) true;

  (* If we have a deep header, mark it too *)
  let deep_hid =
    match deep_headers with
    | h :: _ ->
        Hashtbl.replace results (h.scope_id, h.seq_id) true;
        h.child_scope_id
    | [] -> None
  in

  let slot : I.search_slot =
    {
      search_type = I.RegularSearch "test";
      domain_handle = None;
      completed_ref = ref true;
      results;
    }
  in

  let search_slots = I.SlotMap.add I.SlotNumber.S1 slot I.SlotMap.empty in

  (* Initialize state with injected highlights *)
  let state0 = I.initial_state (module Q) in
  let visible_items =
    I.build_visible_items
      (module Q)
      state0.expanded state0.values_first ~search_slots ~current_slot:state0.current_slot
      ~unfolded_ellipsis:state0.unfolded_ellipsis
  in

  (* Find first root in visible items to set cursor there *)
  let find_entry_idx entry =
    let rec loop i =
      if i >= Array.length visible_items then None
      else
        match visible_items.(i).I.content with
        | I.RealEntry e
          when e.Minidebug_client.Query.scope_id = entry.Minidebug_client.Query.scope_id
               && e.Minidebug_client.Query.seq_id = entry.Minidebug_client.Query.seq_id ->
            Some i
        | _ -> loop (i + 1)
    in
    loop 0
  in

  let first_root_idx =
    match find_entry_idx first_root with
    | Some i -> i
    | None -> failwith "couldn't find first root in visible items"
  in

  let state0 = { state0 with search_slots; visible_items; cursor = first_root_idx } in

  (* Execute HighlightNext command *)
  let state1 =
    match I.handle_command state0 I.HighlightNext ~height:40 with
    | None -> failwith "unexpected quit from HighlightNext"
    | Some st -> st
  in

  (* Verify second root was expanded *)
  if not (Hashtbl.mem state1.expanded second_root_hid) then
    failwith "expected second_root scope to be expanded";

  (* Verify nested scope was expanded (recursive expansion) *)
  if not (Hashtbl.mem state1.expanded nested_hid) then
    failwith "expected nested scope to be expanded";

  (* Verify deep scope was expanded if it exists *)
  (match deep_hid with
  | Some hid ->
      if not (Hashtbl.mem state1.expanded hid) then
        failwith "expected deep scope to be expanded"
  | None -> ());

  (* Verify cursor moved forward into the expanded region *)
  if state1.cursor <= first_root_idx then
    failwith
      (Printf.sprintf "expected cursor to move forward: was %d, now %d" first_root_idx
         state1.cursor);

  (* Test 2: Verify command does nothing when no more highlights *)
  let state2 =
    match I.handle_command state1 I.HighlightNext ~height:40 with
    | None -> failwith "unexpected quit"
    | Some st -> st
  in

  (* Cursor should stay roughly in place since all highlights are expanded *)
  if state2.cursor < state1.cursor then
    failwith "cursor should not move backwards when no more unexpanded highlights";

  Printf.printf "OK: HighlightNext recursively expands all nested highlighted scopes\n%!"
