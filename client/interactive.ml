(** Shared types and utilities for both TUI and MCP frontends *)

(** Sanitize text: replace control chars (newlines, tabs, etc.) with spaces. *)
let sanitize_text s =
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

type search_results = (int * int, bool) Hashtbl.t
(** Hash table of (scope_id, seq_id) pairs matching a search term. Value: true = actual
    search match, false = propagated ancestor highlight. This is shared memory written by
    background Domain, read by main TUI loop. *)

type search_type =
  | RegularSearch of string (* Just the search term *)
  | ExtractSearch of {
      search_path : string list;
      extraction_path : string list;
      display_text : string; (* For footer display *)
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

(** Chronological event tracking for status line display. Captures the order in which
    searches and quiet path changes occur. *)
type status_event =
  | SearchEvent of SlotNumber.t * search_type
  | QuietPathEvent of string option (* None = cleared, Some = set/updated *)

type status_history = status_event list (* Most recent first *)

(** Check if an entry matches any active search (returns slot number 1-4, or None). Checks
    slots in reverse chronological order to prioritize more recent searches. Slot ordering
    is determined by current_slot parameter. *)
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

(** Get all search slots that match an entry (for checkered pattern highlighting). Returns
    list of slot numbers in order S1, S2, S3, S4. *)
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
    Search direction: forward=true searches for matches with (scope_id, seq_id) > current,
    forward=false searches for matches with (scope_id, seq_id) < current Note: searches
    across all 4 search slots. *)
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
    else fun (e, s) -> e < current_scope_id || (e = current_scope_id && s < current_seq_id)
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

(** Content of a visible item - either a real entry, an ellipsis placeholder, or an
    expanded value continuation line *)
type visible_item_content =
  | RealEntry of Query.entry
  | Ellipsis of {
      parent_scope_id : int;
      start_seq_id : int;
      end_seq_id : int;
      hidden_count : int;
    }
  | ExpandedValueLine of {
      entry : Query.entry; (* Reference to parent entry for search highlighting *)
      line_text : string; (* The text content for this line *)
      line_num : int; (* 0-indexed line number within the expanded value *)
      total_lines : int; (* Total number of lines in the expanded value *)
    }

type view_state = {
  query : (module Query.S);
  db_path : string; (* Path to database file for spawning Domains *)
  cursor : int; (* Current cursor position in visible items *)
  scroll_offset : int; (* Top visible item index *)
  expanded : (int, unit) Hashtbl.t; (* Set of expanded scope_ids *)
  expanded_values : (int * int, unit) Hashtbl.t;
      (* Set of (scope_id, seq_id) pairs for values expanded to multiline *)
  visible_items : visible_item array; (* Flattened view of tree *)
  show_times : bool;
  values_first : bool;
  max_scope_id : int; (* Maximum scope_id in this run *)
  search_slots : slot_map;
  current_slot : SlotNumber.t; (* Next slot to use *)
  search_input : string option; (* Active search input buffer *)
  quiet_path_input : string option; (* Active quiet path input buffer *)
  goto_input : string option; (* Active goto input buffer *)
  quiet_path : string option; (* Shared quiet path filter - stops highlight propagation *)
  search_order : Query.search_order; (* Ordering for search results *)
  status_history : status_history;
      (* Chronological event history for status line display *)
  unfolded_ellipsis : EllipsisSet.t; (* Set of manually unfolded ellipsis segments *)
  search_result_counts : (SlotNumber.t, int) Hashtbl.t;
      (* Track result counts per slot to detect search updates *)
  terminal_width : int; (* Terminal width for determining value truncation *)
}

and visible_item = {
  content : visible_item_content;
  indent_level : int;
  is_expandable : bool;
  is_expanded : bool;
}

(** Command type - abstracts keyboard events for both TUI and MCP *)
type command =
  | Navigate of
      [ `Up | `Down | `PageUp | `PageDown | `QuarterUp | `QuarterDown | `Home | `End ]
  | ToggleExpansion
  | Fold
  | SearchNext
  | SearchPrev
  | GotoNextHighlight (* Go to next highlight and expand *)
  | GotoPrevHighlight (* Go to previous highlight and expand *)
  | BeginSearch of string option (* None = enter input mode, Some = execute search *)
  | BeginQuietPath of string option
  | BeginGoto of int option
  | ToggleTimes
  | ToggleValues
  | ToggleSearchOrder
  | Quit
  | InputChar of char
  | InputBackspace
  | InputEscape
  | InputEnter

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
  SlotMap.exists (fun _ slot -> Hashtbl.mem slot.results (scope_id, seq_id)) search_slots

(** Compute ellipsis segments for a list of child entries. Returns a list mixing real
    entries and ellipsis placeholders.

    Algorithm: 1. Treat first and last child as "always highlighted" for context 2.
    Identify which entries are highlighted (from search matches) 3. Find contiguous
    non-highlighted sections between highlighted siblings 4. If section has >3 entries AND
    not manually unfolded → create ellipsis 5. Otherwise include all entries in that
    section *)
let compute_ellipsis_segments ~parent_scope_id ~children ~search_slots ~unfolded_ellipsis
    =
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

(** Wrap text into multiple lines based on width, respecting UTF-8 characters *)
let wrap_text text width =
  if width <= 0 then [ text ]
  else
    let text_chars = Utf8.char_count text in
    if text_chars <= width then [ text ]
    else
      let lines = ref [] in
      let pos = ref 0 in
      while !pos < text_chars do
        let remaining = text_chars - !pos in
        let line_len = min width remaining in
        let line = Utf8.sub text !pos line_len in
        lines := line :: !lines;
        pos := !pos + line_len
      done;
      List.rev !lines

(** Build visible items list from database using lazy loading *)
let build_visible_items (module Q : Query.S) expanded expanded_values values_first
    ~search_slots ~current_slot ~unfolded_ellipsis ~terminal_width =
  (* Calculate available width for content (after margin and indent) *)
  let margin_width = max 3 (String.length (string_of_int (Q.get_max_scope_id ()))) + 3 in

  let rec flatten_entry ~depth entry =
    (* Check if this entry actually has children (is a scope header) *)
    let is_scope =
      match entry.Query.child_scope_id with Some _ -> true | None -> false
    in
    let is_scope_expandable =
      match entry.Query.child_scope_id with
      | Some hid -> Q.has_children ~parent_scope_id:hid
      | None -> false
    in

    (* Check if this is a value that's expanded in expanded_values *)
    let is_value_expanded =
      (not is_scope)
      && Hashtbl.mem expanded_values (entry.Query.scope_id, entry.Query.seq_id)
    in

    (* Calculate if this value would be truncated (for is_expandable) *)
    let content_width = terminal_width - margin_width - (depth * 2) - 2 in
    (* -2 for "  " *)
    let full_value_text =
      if is_scope then ""
      else
        let message = entry.message in
        let data = Option.value ~default:"" entry.data in
        let is_result = entry.is_result in
        (if message <> "" then message ^ " " else "")
        ^ (if is_result then "=> "
           else if message <> "" && data <> "" then "= "
           else "")
        ^ data
    in
    let value_char_count = Utf8.char_count full_value_text in
    let is_value_expandable = (not is_scope) && value_char_count > content_width in

    (* Combined expandability and expansion state *)
    let is_expandable = is_scope_expandable || is_value_expandable in
    let is_expanded =
      (match entry.child_scope_id with
      | Some hid -> Hashtbl.mem expanded hid
      | None -> false)
      || is_value_expanded
    in

    (* Handle value expansion (create multiple ExpandedValueLine items) *)
    if is_value_expanded && (not is_scope) then
      (* Wrap the full value text into multiple lines *)
      let wrapped_lines = wrap_text full_value_text content_width in
      let total_lines = List.length wrapped_lines in
      (* First line shows as RealEntry (with the entry header info), rest as
         ExpandedValueLine *)
      let first_visible =
        {
          content = RealEntry entry;
          indent_level = depth;
          is_expandable = true;
          is_expanded = true;
        }
      in
      let continuation_lines =
        List.mapi
          (fun i line_text ->
            {
              content =
                ExpandedValueLine
                  { entry; line_text; line_num = i + 1; total_lines = total_lines + 1 };
              indent_level = depth;
              is_expandable = false;
              is_expanded = false;
            })
          (List.tl wrapped_lines)
        (* Skip first line, it's shown by RealEntry *)
      in
      first_visible :: continuation_lines
    else
      let visible =
        { content = RealEntry entry; indent_level = depth; is_expandable; is_expanded }
      in

      (* Add children if this scope is expanded *)
      if is_expanded && is_scope then
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

(** MCP-compatible TUI core - uses TextRenderer *)
module type TUI_CORE = sig
  type state = view_state

  val init_state : (module Query.S) -> db_path:string -> state
  val execute_command : state -> command -> state option
  val wait_for_searches : state -> timeout_sec:float -> state
end
[@@warning "-32"]
(* Suppress unused value warnings - will be implemented for MCP *)

(** Toggle expansion of current item (or unfold ellipsis, or expand/collapse value) *)
let toggle_expansion state =
  if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
    let item = state.visible_items.(state.cursor) in
    if item.is_expandable then
      match item.content with
      | ExpandedValueLine { entry; _ } ->
          (* Collapse the expanded value by removing it from expanded_values *)
          let key = (entry.scope_id, entry.seq_id) in
          Hashtbl.remove state.expanded_values key;
          let new_visible =
            build_visible_items state.query state.expanded state.expanded_values
              state.values_first ~search_slots:state.search_slots
              ~current_slot:state.current_slot
              ~unfolded_ellipsis:state.unfolded_ellipsis
              ~terminal_width:state.terminal_width
          in
          { state with visible_items = new_visible }
      | Ellipsis { parent_scope_id; start_seq_id; end_seq_id; _ } ->
          (* Unfold ellipsis: add to unfolded set and rebuild *)
          let key = (parent_scope_id, start_seq_id, end_seq_id) in
          let new_unfolded = EllipsisSet.add key state.unfolded_ellipsis in
          let new_visible =
            build_visible_items state.query state.expanded state.expanded_values
              state.values_first ~search_slots:state.search_slots
              ~current_slot:state.current_slot ~unfolded_ellipsis:new_unfolded
              ~terminal_width:state.terminal_width
          in
          { state with visible_items = new_visible; unfolded_ellipsis = new_unfolded }
      | RealEntry entry -> (
          match entry.child_scope_id with
          | Some hid ->
              (* Scope: use child_scope_id as the unique key for this scope *)
              if Hashtbl.mem state.expanded hid then Hashtbl.remove state.expanded hid
              else Hashtbl.add state.expanded hid ();

              (* Rebuild visible items *)
              let new_visible =
                build_visible_items state.query state.expanded state.expanded_values
                  state.values_first ~search_slots:state.search_slots
                  ~current_slot:state.current_slot
                  ~unfolded_ellipsis:state.unfolded_ellipsis
                  ~terminal_width:state.terminal_width
              in
              { state with visible_items = new_visible }
          | None ->
              (* Value: toggle expansion of the value itself *)
              let key = (entry.scope_id, entry.seq_id) in
              if Hashtbl.mem state.expanded_values key then
                Hashtbl.remove state.expanded_values key
              else Hashtbl.add state.expanded_values key ();

              (* Rebuild visible items *)
              let new_visible =
                build_visible_items state.query state.expanded state.expanded_values
                  state.values_first ~search_slots:state.search_slots
                  ~current_slot:state.current_slot
                  ~unfolded_ellipsis:state.unfolded_ellipsis
                  ~terminal_width:state.terminal_width
              in
              { state with visible_items = new_visible })
    else state
  else state

(** Fold current selection: re-fold an unfolded ellipsis if possible, otherwise fold
    parent scope. After folding, position cursor on the ellipsis or scope header entry. *)
let fold_selection state =
  if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
    let item = state.visible_items.(state.cursor) in
    match item.content with
    | Ellipsis _ ->
        (* Already folded - no-op *)
        state
    | ExpandedValueLine { entry; _ } ->
        (* Collapse the expanded value by removing it from expanded_values *)
        let key = (entry.scope_id, entry.seq_id) in
        Hashtbl.remove state.expanded_values key;
        let new_visible =
          build_visible_items state.query state.expanded state.expanded_values
            state.values_first ~search_slots:state.search_slots
            ~current_slot:state.current_slot ~unfolded_ellipsis:state.unfolded_ellipsis
            ~terminal_width:state.terminal_width
        in
        { state with visible_items = new_visible }
    | RealEntry entry -> (
        let module Q = (val state.query) in
        (* Try to find if this entry was part of an ellipsis segment. This entry belongs
           to scope_id, so we check siblings within that scope. *)
        let containing_scope_id = entry.Query.scope_id in

        (* Check if this entry is within an unfolded ellipsis segment *)
        let maybe_ellipsis_key =
          (* Get all siblings (children of the same scope) *)
          let siblings = Q.get_scope_children ~parent_scope_id:containing_scope_id in
          (* Find highlighted positions (first, last, search matches) *)
          let num_children = List.length siblings in
          if num_children <= 4 then None
          else
            let highlighted_indices =
              let search_matches =
                List.mapi
                  (fun i child ->
                    if
                      is_entry_highlighted ~search_slots:state.search_slots
                        ~scope_id:child.Query.scope_id ~seq_id:child.Query.seq_id
                    then Some i
                    else None)
                  siblings
                |> List.filter_map (fun x -> x)
              in
              let with_boundaries = 0 :: (num_children - 1) :: search_matches in
              List.sort_uniq compare with_boundaries
            in

            (* Find which ellipsis segment this entry belongs to *)
            let rec find_ellipsis_segment current_entry_idx remaining_highlights =
              match remaining_highlights with
              | [] -> None
              | [ _ ] -> None (* Last highlight, no more segments *)
              | prev_idx :: next_idx :: rest ->
                  (* Section between prev_idx and next_idx *)
                  let section_start = prev_idx + 1 in
                  let section_end = next_idx in
                  let count = section_end - section_start in
                  if
                    count > 3
                    && current_entry_idx >= section_start
                    && current_entry_idx < section_end
                  then
                    (* This entry is in an ellipsis segment *)
                    let start_entry = List.nth siblings section_start in
                    let end_entry = List.nth siblings (section_end - 1) in
                    Some
                      ( containing_scope_id,
                        start_entry.Query.seq_id,
                        end_entry.Query.seq_id )
                  else find_ellipsis_segment current_entry_idx (next_idx :: rest)
            in
            (* Find current entry's index in siblings list. All siblings have the same
               scope_id (the parent), so we match on seq_id. *)
            let current_idx =
              List.mapi (fun i e -> (i, e)) siblings
              |> List.find_opt (fun (_, e) -> e.Query.seq_id = entry.Query.seq_id)
              |> Option.map fst
            in
            match current_idx with
            | None -> None
            | Some idx -> find_ellipsis_segment idx highlighted_indices
        in

        match maybe_ellipsis_key with
        | Some (scope_id, start_seq, end_seq) ->
            (* Re-fold this ellipsis by removing it from unfolded set *)
            let key = (scope_id, start_seq, end_seq) in
            if EllipsisSet.mem key state.unfolded_ellipsis then
              let new_unfolded = EllipsisSet.remove key state.unfolded_ellipsis in
              let new_visible =
                build_visible_items state.query state.expanded state.expanded_values
                  state.values_first ~search_slots:state.search_slots
                  ~current_slot:state.current_slot ~unfolded_ellipsis:new_unfolded
                  ~terminal_width:state.terminal_width
              in
              (* Find the ellipsis entry in new visible items *)
              let new_cursor =
                let rec find_ellipsis idx =
                  if idx >= Array.length new_visible then state.cursor
                  else
                    match new_visible.(idx).content with
                    | Ellipsis
                        { parent_scope_id = p; start_seq_id = s; end_seq_id = e; _ }
                      when p = scope_id && s = start_seq && e = end_seq ->
                        idx
                    | _ -> find_ellipsis (idx + 1)
                in
                find_ellipsis 0
              in
              (* Adjust scroll to ensure cursor is visible *)
              let new_scroll =
                if new_cursor < state.scroll_offset then new_cursor
                else state.scroll_offset
              in
              {
                state with
                visible_items = new_visible;
                unfolded_ellipsis = new_unfolded;
                cursor = new_cursor;
                scroll_offset = new_scroll;
              }
            else state (* Ellipsis not unfolded, no-op *)
        | None ->
            (* Not in an ellipsis - fold the scope containing this entry. The expanded
               hashtable uses child_scope_id as keys. To fold the scope containing this
               entry, we remove this entry's scope_id from expanded. *)
            if Hashtbl.mem state.expanded containing_scope_id then (
              Hashtbl.remove state.expanded containing_scope_id;
              let new_visible =
                build_visible_items state.query state.expanded state.expanded_values
                  state.values_first ~search_slots:state.search_slots
                  ~current_slot:state.current_slot
                  ~unfolded_ellipsis:state.unfolded_ellipsis
                  ~terminal_width:state.terminal_width
              in
              (* Find the header entry of the folded scope in new visible items *)
              let new_cursor =
                let rec find_header idx =
                  if idx >= Array.length new_visible then state.cursor
                  else
                    match new_visible.(idx).content with
                    | RealEntry e when e.Query.child_scope_id = Some containing_scope_id
                      ->
                        idx
                    | _ -> find_header (idx + 1)
                in
                find_header 0
              in
              (* Adjust scroll to ensure cursor is visible *)
              let new_scroll =
                if new_cursor < state.scroll_offset then new_cursor
                else state.scroll_offset
              in
              {
                state with
                visible_items = new_visible;
                cursor = new_cursor;
                scroll_offset = new_scroll;
              })
            else state)
  else state

(** Find next/previous search result (searches hash tables, not just visible items).
    Returns updated state with cursor moved to the match and path auto-expanded, or None
    if no match. *)
let find_and_jump_to_search_result state ~forward ~height =
  (* Get current entry's (scope_id, seq_id) *)
  let current_scope_id, current_seq_id =
    if state.cursor >= 0 && state.cursor < Array.length state.visible_items then
      match state.visible_items.(state.cursor).content with
      | Ellipsis { parent_scope_id; start_seq_id; _ } -> (parent_scope_id, start_seq_id)
      | ExpandedValueLine { entry; _ } -> (entry.scope_id, entry.seq_id)
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
      let module
        (* Expand all ancestors of the target entry. get_ancestors returns
           [target_scope_id; parent; grandparent; ...]. Since target entry lives inside
           target_scope_id, we must expand target_scope_id and all its ancestors to make
           the path visible. *)
        Q =
        (val state.query)
      in
      let ancestors = Q.get_ancestors ~scope_id:target_scope_id in
      List.iter
        (fun ancestor_id -> Hashtbl.replace state.expanded ancestor_id ())
        ancestors;

      (* Rebuild visible items with expanded path *)
      let new_visible =
        build_visible_items state.query state.expanded state.expanded_values
          state.values_first ~search_slots:state.search_slots
          ~current_slot:state.current_slot ~unfolded_ellipsis:state.unfolded_ellipsis
          ~terminal_width:state.terminal_width
      in

      (* Find the target entry in the new visible items *)
      let rec find_in_visible idx =
        if idx >= Array.length new_visible then None
          (* Entry not found after expansion - may be filtered or invalid *)
        else
          let item = new_visible.(idx) in
          match item.content with
          | Ellipsis _ -> find_in_visible (idx + 1)
          | ExpandedValueLine { entry; _ } ->
              if entry.scope_id = target_scope_id && entry.seq_id = target_seq_id then
                Some idx
              else find_in_visible (idx + 1)
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
          let content_height = height - 4 in
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

(** Jump to scope with given ID (find header entry with child_scope_id = target_id).
    Returns updated state with cursor positioned at scope header if visible, or at the
    closest visible ancestor (which may be an ellipsis containing it). Does not unfold. *)
let goto_scope state target_scope_id ~height =
  let module Q = (val state.query) in
  (* Find the header entry with child_scope_id = target_scope_id *)
  match Q.find_scope_header ~scope_id:target_scope_id with
  | None -> None (* Scope not found *)
  | Some header_entry -> (
      (* Expand all ancestors of the header entry to make parent scope visible *)
      let ancestors = Q.get_ancestors ~scope_id:header_entry.scope_id in
      List.iter
        (fun ancestor_id -> Hashtbl.replace state.expanded ancestor_id ())
        ancestors;

      (* Rebuild visible items with expanded ancestors *)
      let new_visible =
        build_visible_items state.query state.expanded state.expanded_values
          state.values_first ~search_slots:state.search_slots
          ~current_slot:state.current_slot ~unfolded_ellipsis:state.unfolded_ellipsis
          ~terminal_width:state.terminal_width
      in

      (* Try to find the target entry in visible items *)
      let rec find_entry_by_ids ~scope_id ~seq_id idx =
        if idx >= Array.length new_visible then None
        else
          let item = new_visible.(idx) in
          match item.content with
          | RealEntry entry ->
              if entry.scope_id = scope_id && entry.seq_id = seq_id then Some idx
              else find_entry_by_ids ~scope_id ~seq_id (idx + 1)
          | ExpandedValueLine { entry; _ } ->
              if entry.scope_id = scope_id && entry.seq_id = seq_id then Some idx
              else find_entry_by_ids ~scope_id ~seq_id (idx + 1)
          | Ellipsis _ -> find_entry_by_ids ~scope_id ~seq_id (idx + 1)
      in

      (* Try to find ellipsis covering a given entry *)
      let rec find_covering_ellipsis ~parent_scope_id ~seq_id idx =
        if idx >= Array.length new_visible then None
        else
          let item = new_visible.(idx) in
          match item.content with
          | Ellipsis { parent_scope_id = ell_parent; start_seq_id; end_seq_id; _ }
            when ell_parent = parent_scope_id && start_seq_id <= seq_id
                 && seq_id <= end_seq_id ->
              Some idx
          | _ -> find_covering_ellipsis ~parent_scope_id ~seq_id (idx + 1)
      in

      (* Search strategy: try target first, then walk up ancestor chain *)
      let rec find_closest_visible targets =
        match targets with
        | [] -> None (* Shouldn't happen - root should always be visible *)
        | (scope_id, seq_id, _parent_scope_id) :: rest -> (
            (* Try to find the entry itself *)
            match find_entry_by_ids ~scope_id ~seq_id 0 with
            | Some idx -> Some idx
            | None -> (
                (* Entry not visible - try to find ellipsis covering it. The ellipsis that
                   hides an entry at (scope_id, seq_id) has parent_scope_id=scope_id (the
                   scope the entry belongs to). *)
                match find_covering_ellipsis ~parent_scope_id:scope_id ~seq_id 0 with
                | Some idx -> Some idx
                | None ->
                    (* Not in any ellipsis either - try parent *)
                    find_closest_visible rest))
      in

      (* Build target list: header_entry, then its ancestors. Each element is (scope_id,
         seq_id, parent_scope_id). Ancestors list is [target_scope; parent; grandparent;
         ...] *)
      let target_chain =
        (* First, add the target header entry itself *)
        let target_parent_scope_id =
          match ancestors with
          | _ :: parent :: _ -> parent (* Target's parent is second in list *)
          | _ -> header_entry.scope_id (* Fallback if no parent *)
        in
        let initial_chain =
          [ (header_entry.scope_id, header_entry.seq_id, target_parent_scope_id) ]
        in

        (* Then add ancestor entries, walking from target upward *)
        let rec build_ancestor_chain acc remaining_ancestors =
          match remaining_ancestors with
          | [] | [ _ ] -> acc (* Done - no more ancestors or just root left *)
          | child_scope_id :: (parent_scope_id :: _ as rest) -> (
              (* Find header entry for this ancestor scope *)
              match Q.find_scope_header ~scope_id:child_scope_id with
              | Some anc_entry ->
                  build_ancestor_chain
                    ((anc_entry.scope_id, anc_entry.seq_id, parent_scope_id) :: acc)
                    rest
              | None ->
                  (* Skip this ancestor if we can't find its header *)
                  build_ancestor_chain acc rest)
        in

        (* Start from the second element (first ancestor after target) *)
        match ancestors with
        | [] | [ _ ] -> initial_chain (* No ancestors to add *)
        | _ :: ancestor_tail -> initial_chain @ build_ancestor_chain [] ancestor_tail
      in

      match find_closest_visible target_chain with
      | Some cursor_idx ->
          (* Found closest visible item - position cursor there *)
          let content_height = height - 4 in
          let new_scroll =
            if cursor_idx < state.scroll_offset then cursor_idx
            else if cursor_idx >= state.scroll_offset + content_height then
              max 0 (cursor_idx - (content_height / 2))
            else state.scroll_offset
          in
          Some
            {
              state with
              cursor = cursor_idx;
              scroll_offset = new_scroll;
              visible_items = new_visible;
            }
      | None ->
          (* Couldn't find anything - return state with expanded ancestors anyway *)
          Some { state with visible_items = new_visible })

(** Check if a visible_item is highlighted in any search slot *)
let is_item_highlighted ~search_slots item =
  match item.content with
  | Ellipsis _ -> false
  | ExpandedValueLine { entry; _ } ->
      (* Expanded value lines inherit highlighting from their parent entry *)
      is_entry_highlighted ~search_slots ~scope_id:entry.Query.scope_id
        ~seq_id:entry.Query.seq_id
  | RealEntry entry ->
      is_entry_highlighted ~search_slots ~scope_id:entry.Query.scope_id
        ~seq_id:entry.Query.seq_id

(** Go to next/previous highlight and expand. Searches through potentially visible items,
    expands highlighted scopes, and searches within for nested highlights.
    Returns updated state with cursor at highlight, or None if no highlight found. *)
let goto_highlight_and_expand state ~forward ~height =
  let num_items = Array.length state.visible_items in
  if num_items = 0 then Some state
  else
    let content_height = height - 4 in

    (* Helper to adjust scroll offset for a given cursor position *)
    let adjust_scroll cursor =
      if cursor < state.scroll_offset then cursor
      else if cursor >= state.scroll_offset + content_height then
        max 0 (cursor - (content_height / 2))
      else state.scroll_offset
    in

    (* Find next/prev highlighted item starting from position (inclusive).
       Returns index or None. *)
    let find_highlight_from start_idx =
      if forward then
        let rec loop idx =
          if idx >= num_items then None
          else if is_item_highlighted ~search_slots:state.search_slots state.visible_items.(idx)
          then Some idx
          else loop (idx + 1)
        in
        loop start_idx
      else
        let rec loop idx =
          if idx < 0 then None
          else if is_item_highlighted ~search_slots:state.search_slots state.visible_items.(idx)
          then Some idx
          else loop (idx - 1)
        in
        loop start_idx
    in

    (* Find first highlighted item at or after/before cursor.
       For backward search: if cursor is on a highlight, first move to the nearest
       non-highlighted position before searching. This ensures M repeatedly moves
       backward through highlights rather than getting stuck on the current one. *)
    let start_search_idx =
      if forward then state.cursor
      else
        (* For backward: skip past current highlight if we're on one *)
        let rec skip_current_highlight idx =
          if idx < 0 then 0
          else if is_item_highlighted ~search_slots:state.search_slots state.visible_items.(idx)
          then skip_current_highlight (idx - 1)
          else idx
        in
        skip_current_highlight state.cursor
    in
    match find_highlight_from start_search_idx with
    | None ->
        (* No highlight found in search direction *)
        Some state
    | Some highlight_idx ->
        let item = state.visible_items.(highlight_idx) in
        if not item.is_expandable then
          (* Not expandable - just position cursor there *)
          let new_scroll = adjust_scroll highlight_idx in
          Some { state with cursor = highlight_idx; scroll_offset = new_scroll }
        else
          (* Expandable - expand if needed, then search within *)
          let item_indent = item.indent_level in
          match item.content with
          | ExpandedValueLine _ ->
              (* Continuation lines aren't really expandable - just position cursor *)
              let new_scroll = adjust_scroll highlight_idx in
              Some { state with cursor = highlight_idx; scroll_offset = new_scroll }
          | Ellipsis { parent_scope_id; start_seq_id; end_seq_id; _ } ->
              (* Unfold ellipsis if not already unfolded *)
              let key = (parent_scope_id, start_seq_id, end_seq_id) in
              let was_folded = not (EllipsisSet.mem key state.unfolded_ellipsis) in
              let new_unfolded =
                if was_folded then EllipsisSet.add key state.unfolded_ellipsis
                else state.unfolded_ellipsis
              in
              let new_visible =
                if was_folded then
                  build_visible_items state.query state.expanded state.expanded_values
                    state.values_first ~search_slots:state.search_slots
                    ~current_slot:state.current_slot ~unfolded_ellipsis:new_unfolded
                    ~terminal_width:state.terminal_width
                else state.visible_items
              in
              let state_after_expand =
                if was_folded then
                  { state with visible_items = new_visible; unfolded_ellipsis = new_unfolded }
                else state
              in
              (* Search for highlight within expanded region *)
              let curr_visible = state_after_expand.visible_items in
              let curr_num_items = Array.length curr_visible in
              (* Find highlight within expanded scope (same or greater indent), starting after
                 the header *)
              let search_start = if forward then highlight_idx + 1 else highlight_idx - 1 in
              let rec find_in_scope idx =
                let out_of_bounds =
                  if forward then idx >= curr_num_items else idx < 0
                in
                if out_of_bounds then None
                else
                  let curr_item = curr_visible.(idx) in
                  if curr_item.indent_level < item_indent then None
                  else if
                    is_item_highlighted ~search_slots:state_after_expand.search_slots curr_item
                  then Some idx
                  else find_in_scope (if forward then idx + 1 else idx - 1)
              in
              (match find_in_scope search_start with
              | Some nested_idx ->
                  let new_scroll = adjust_scroll nested_idx in
                  Some
                    { state_after_expand with cursor = nested_idx; scroll_offset = new_scroll }
              | None ->
                  (* No highlight in expanded region - position at the expanded item *)
                  let new_scroll = adjust_scroll highlight_idx in
                  Some
                    {
                      state_after_expand with
                      cursor = highlight_idx;
                      scroll_offset = new_scroll;
                    })
          | RealEntry entry -> (
              match entry.child_scope_id with
              | None ->
                  (* Not actually expandable - just position cursor *)
                  let new_scroll = adjust_scroll highlight_idx in
                  Some { state with cursor = highlight_idx; scroll_offset = new_scroll }
              | Some hid ->
                  (* Expand the scope if not already expanded *)
                  let was_collapsed = not (Hashtbl.mem state.expanded hid) in
                  if was_collapsed then Hashtbl.add state.expanded hid ();
                  let new_visible =
                    if was_collapsed then
                      build_visible_items state.query state.expanded state.expanded_values
                        state.values_first ~search_slots:state.search_slots
                        ~current_slot:state.current_slot
                        ~unfolded_ellipsis:state.unfolded_ellipsis
                        ~terminal_width:state.terminal_width
                    else state.visible_items
                  in
                  let state_after_expand =
                    if was_collapsed then { state with visible_items = new_visible } else state
                  in
                  let new_num_items = Array.length new_visible in

                  (* Find highlight within expanded scope (children have greater indent) *)
                  let search_start =
                    if forward then highlight_idx + 1
                    else min (highlight_idx + 1) (new_num_items - 1)
                  in
                  let rec find_in_expanded_scope idx =
                    let out_of_bounds =
                      if forward then idx >= new_num_items else idx < 0
                    in
                    if out_of_bounds then None
                    else
                      let curr_item = new_visible.(idx) in
                      (* Stop when we leave the expanded scope (back to same or lesser indent) *)
                      if curr_item.indent_level <= item_indent then None
                      else if
                        is_item_highlighted ~search_slots:state_after_expand.search_slots
                          curr_item
                      then Some idx
                      else find_in_expanded_scope (if forward then idx + 1 else idx - 1)
                  in

                  (* First, search in the direct children area *)
                  (match find_in_expanded_scope search_start with
                  | Some nested_idx ->
                      let new_scroll = adjust_scroll nested_idx in
                      Some
                        {
                          state_after_expand with
                          cursor = nested_idx;
                          scroll_offset = new_scroll;
                        }
                  | None ->
                      (* No highlight found in immediate expansion. Now iterate over scope's
                         entries at child level (indent_level = item_indent + 1), unfolding
                         each to search for highlights. *)
                      let child_indent = item_indent + 1 in

                      (* Collect indices of direct children (at child_indent level) *)
                      let rec collect_children idx acc =
                        if idx >= new_num_items then List.rev acc
                        else
                          let curr_item = new_visible.(idx) in
                          if curr_item.indent_level < child_indent then List.rev acc
                          else if curr_item.indent_level = child_indent then
                            collect_children (idx + 1) (idx :: acc)
                          else collect_children (idx + 1) acc
                      in
                      let children_indices =
                        let collected = collect_children (highlight_idx + 1) [] in
                        if forward then collected else List.rev collected
                      in

                      (* Try unfolding each child and searching within *)
                      let rec try_children indices current_state =
                        match indices with
                        | [] ->
                            (* No highlights found in any child - position at expanded item *)
                            let new_scroll = adjust_scroll highlight_idx in
                            Some
                              {
                                current_state with
                                cursor = highlight_idx;
                                scroll_offset = new_scroll;
                              }
                        | child_idx :: rest ->
                            (* Re-fetch the item since visible_items may have changed *)
                            let curr_visible = current_state.visible_items in
                            if child_idx >= Array.length curr_visible then
                              try_children rest current_state
                            else
                              let child_item = curr_visible.(child_idx) in
                              if not child_item.is_expandable then
                                try_children rest current_state
                              else if child_item.is_expanded then
                                (* Already expanded - skip to next *)
                                try_children rest current_state
                              else (
                                (* Unfold/expand this child *)
                                let state_after_unfold, was_unfolded =
                                  match child_item.content with
                                  | ExpandedValueLine _ ->
                                      (* Skip continuation lines *)
                                      (current_state, false)
                                  | Ellipsis
                                      { parent_scope_id; start_seq_id; end_seq_id; _ } ->
                                      let key =
                                        (parent_scope_id, start_seq_id, end_seq_id)
                                      in
                                      let new_unfolded =
                                        EllipsisSet.add key current_state.unfolded_ellipsis
                                      in
                                      let new_vis =
                                        build_visible_items current_state.query
                                          current_state.expanded current_state.expanded_values
                                          current_state.values_first
                                          ~search_slots:current_state.search_slots
                                          ~current_slot:current_state.current_slot
                                          ~unfolded_ellipsis:new_unfolded
                                          ~terminal_width:current_state.terminal_width
                                      in
                                      ( {
                                          current_state with
                                          visible_items = new_vis;
                                          unfolded_ellipsis = new_unfolded;
                                        },
                                        true )
                                  | RealEntry child_entry -> (
                                      match child_entry.child_scope_id with
                                      | Some child_hid ->
                                          Hashtbl.add current_state.expanded child_hid ();
                                          let new_vis =
                                            build_visible_items current_state.query
                                              current_state.expanded
                                              current_state.expanded_values
                                              current_state.values_first
                                              ~search_slots:current_state.search_slots
                                              ~current_slot:current_state.current_slot
                                              ~unfolded_ellipsis:current_state.unfolded_ellipsis
                                              ~terminal_width:current_state.terminal_width
                                          in
                                          ( { current_state with visible_items = new_vis },
                                            true )
                                      | None -> (current_state, false))
                                in
                                if not was_unfolded then try_children rest current_state
                                else
                                  let unfolded_visible = state_after_unfold.visible_items in
                                  let unfolded_num = Array.length unfolded_visible in

                                  (* Search for highlight in the unfolded content *)
                                  let rec find_in_unfolded idx =
                                    let out_of_bounds =
                                      if forward then idx >= unfolded_num else idx < 0
                                    in
                                    if out_of_bounds then None
                                    else
                                      let curr = unfolded_visible.(idx) in
                                      (* Stop when we leave the child scope *)
                                      if curr.indent_level <= child_indent then None
                                      else if
                                        is_item_highlighted
                                          ~search_slots:state_after_unfold.search_slots curr
                                      then Some idx
                                      else
                                        find_in_unfolded (if forward then idx + 1 else idx - 1)
                                  in

                                  (* Find where the unfolded child starts in new visible *)
                                  let rec find_child_in_new idx =
                                    if idx >= unfolded_num then None
                                    else
                                      let curr = unfolded_visible.(idx) in
                                      match (curr.content, child_item.content) with
                                      | RealEntry e1, RealEntry e2
                                        when e1.scope_id = e2.scope_id
                                             && e1.seq_id = e2.seq_id ->
                                          Some idx
                                      | _ -> find_child_in_new (idx + 1)
                                  in

                                  let search_from =
                                    match find_child_in_new 0 with
                                    | Some idx -> if forward then idx + 1 else idx + 1
                                    | None -> if forward then 0 else unfolded_num - 1
                                  in

                                  (match find_in_unfolded search_from with
                                  | Some found_idx ->
                                      let new_scroll = adjust_scroll found_idx in
                                      Some
                                        {
                                          state_after_unfold with
                                          cursor = found_idx;
                                          scroll_offset = new_scroll;
                                        }
                                  | None ->
                                      (* No highlight - fold back and try next child *)
                                      let state_refolded =
                                        match child_item.content with
                                        | ExpandedValueLine _ ->
                                            (* Skip continuation lines *)
                                            state_after_unfold
                                        | Ellipsis
                                            { parent_scope_id; start_seq_id; end_seq_id; _ }
                                          ->
                                            let key =
                                              (parent_scope_id, start_seq_id, end_seq_id)
                                            in
                                            let restored_unfolded =
                                              EllipsisSet.remove key
                                                state_after_unfold.unfolded_ellipsis
                                            in
                                            let new_vis =
                                              build_visible_items state_after_unfold.query
                                                state_after_unfold.expanded
                                                state_after_unfold.expanded_values
                                                state_after_unfold.values_first
                                                ~search_slots:state_after_unfold.search_slots
                                                ~current_slot:state_after_unfold.current_slot
                                                ~unfolded_ellipsis:restored_unfolded
                                                ~terminal_width:
                                                  state_after_unfold.terminal_width
                                            in
                                            {
                                              state_after_unfold with
                                              visible_items = new_vis;
                                              unfolded_ellipsis = restored_unfolded;
                                            }
                                        | RealEntry child_entry -> (
                                            match child_entry.child_scope_id with
                                            | Some child_hid ->
                                                Hashtbl.remove state_after_unfold.expanded
                                                  child_hid;
                                                let new_vis =
                                                  build_visible_items state_after_unfold.query
                                                    state_after_unfold.expanded
                                                    state_after_unfold.expanded_values
                                                    state_after_unfold.values_first
                                                    ~search_slots:
                                                      state_after_unfold.search_slots
                                                    ~current_slot:
                                                      state_after_unfold.current_slot
                                                    ~unfolded_ellipsis:
                                                      state_after_unfold.unfolded_ellipsis
                                                    ~terminal_width:
                                                      state_after_unfold.terminal_width
                                                in
                                                {
                                                  state_after_unfold with
                                                  visible_items = new_vis;
                                                }
                                            | None -> state_after_unfold)
                                      in
                                      try_children rest state_refolded))
                      in
                      try_children children_indices state_after_expand))

(** Handle commands - core command processing logic *)
let rec handle_command state command ~height =
  let content_height = height - 4 in

  match command with
  | Quit -> None
  | Navigate direction -> (
      match direction with
      | `Up ->
          let new_cursor = max 0 (state.cursor - 1) in
          let new_scroll =
            if new_cursor < state.scroll_offset then new_cursor else state.scroll_offset
          in
          Some { state with cursor = new_cursor; scroll_offset = new_scroll }
      | `Down ->
          let max_cursor = Array.length state.visible_items - 1 in
          let new_cursor = min max_cursor (state.cursor + 1) in
          let new_scroll =
            if new_cursor >= state.scroll_offset + content_height then
              new_cursor - content_height + 1
            else state.scroll_offset
          in
          Some { state with cursor = new_cursor; scroll_offset = new_scroll }
      | `Home -> Some { state with cursor = 0; scroll_offset = 0 }
      | `End ->
          let max_cursor = Array.length state.visible_items - 1 in
          let new_scroll = max 0 (max_cursor - content_height + 1) in
          Some { state with cursor = max_cursor; scroll_offset = new_scroll }
      | `PageUp ->
          if state.cursor = state.scroll_offset then
            let new_scroll = max 0 (state.scroll_offset - (content_height - 1)) in
            let new_cursor = new_scroll in
            Some { state with cursor = new_cursor; scroll_offset = new_scroll }
          else Some { state with cursor = state.scroll_offset }
      | `PageDown ->
          let max_cursor = Array.length state.visible_items - 1 in
          let bottom_of_screen =
            min max_cursor (state.scroll_offset + content_height - 1)
          in
          if state.cursor = bottom_of_screen then
            let new_scroll =
              min
                (max 0 (max_cursor - content_height + 1))
                (state.scroll_offset + (content_height - 1))
            in
            let new_cursor = min max_cursor (new_scroll + content_height - 1) in
            Some { state with cursor = new_cursor; scroll_offset = new_scroll }
          else Some { state with cursor = bottom_of_screen }
      | `QuarterUp ->
          let quarter_page = max 1 (content_height / 4) in
          let new_cursor = max 0 (state.cursor - quarter_page) in
          let new_scroll = max 0 (min state.scroll_offset new_cursor) in
          Some { state with cursor = new_cursor; scroll_offset = new_scroll }
      | `QuarterDown ->
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
          Some { state with cursor = new_cursor; scroll_offset = new_scroll })
  | ToggleExpansion -> Some (toggle_expansion state)
  | Fold -> Some (fold_selection state)
  | SearchNext -> (
      match find_and_jump_to_search_result state ~forward:true ~height with
      | Some new_state -> Some new_state
      | None -> Some state)
  | SearchPrev -> (
      match find_and_jump_to_search_result state ~forward:false ~height with
      | Some new_state -> Some new_state
      | None -> Some state)
  | GotoNextHighlight -> goto_highlight_and_expand state ~forward:true ~height
  | GotoPrevHighlight -> goto_highlight_and_expand state ~forward:false ~height
  | BeginSearch None -> Some { state with search_input = Some "" }
  | BeginSearch (Some search_term) ->
      if String.length search_term > 0 then
        let slot = state.current_slot in
        (* Check if this is an extract search (contains '>') *)
        let search_type, is_valid =
          match String.index_opt search_term '>' with
          | None -> (RegularSearch search_term, true)
          | Some sep_idx ->
              let search_part = String.sub search_term 0 sep_idx in
              let extract_part =
                String.sub search_term (sep_idx + 1)
                  (String.length search_term - sep_idx - 1)
              in
              let search_path = String.split_on_char ',' search_part in
              let extraction_path = String.split_on_char ',' extract_part in
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
                let search_path = List.map String.trim search_path in
                let extraction_path = List.map String.trim extraction_path in
                let display_text =
                  match extraction_path with
                  | _ :: tail when tail <> [] ->
                      Printf.sprintf "%s>%s"
                        (String.concat "," search_path)
                        (String.concat "," tail)
                  | _ ->
                      Printf.sprintf "%s>%s"
                        (String.concat "," search_path)
                        (String.concat "," extraction_path)
                in
                (ExtractSearch { search_path; extraction_path; display_text }, true)
              else (RegularSearch search_term, false)
        in
        if is_valid then (
          let completed_ref = ref false in
          let results_table = Hashtbl.create 1024 in
          let domain_handle =
            Domain.spawn (fun () ->
                let module DomainQ = Query.Make (struct
                  let db_path = state.db_path
                end) in
                match search_type with
                | RegularSearch term ->
                    DomainQ.populate_search_results ~search_term:term
                      ~quiet_path:state.quiet_path ~search_order:state.search_order
                      ~completed_ref ~results_table
                | ExtractSearch { search_path; extraction_path; _ } ->
                    DomainQ.populate_extract_search_results ~search_path ~extraction_path
                      ~quiet_path:state.quiet_path ~completed_ref ~results_table)
          in
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
          let filtered_history =
            List.filter
              (fun event ->
                match event with
                | SearchEvent (old_slot, _) -> old_slot <> slot
                | QuietPathEvent _ -> true)
              state.status_history
          in
          let rec deduplicate_consecutive acc = function
            | [] -> List.rev acc
            | (QuietPathEvent _ as qp) :: QuietPathEvent _ :: rest ->
                deduplicate_consecutive (qp :: acc) rest
            | event :: rest -> deduplicate_consecutive (event :: acc) rest
          in
          let deduped_history = deduplicate_consecutive [] filtered_history in
          let new_history = SearchEvent (slot, search_type) :: deduped_history in
          let new_count = Hashtbl.length results_table in
          let old_count =
            match Hashtbl.find_opt state.search_result_counts slot with
            | Some c -> c
            | None -> -1
          in
          let search_changed = new_count <> old_count in
          let new_result_counts = Hashtbl.copy state.search_result_counts in
          Hashtbl.replace new_result_counts slot new_count;
          let new_unfolded =
            if search_changed then EllipsisSet.empty else state.unfolded_ellipsis
          in
          let new_visible =
            if search_changed then
              build_visible_items state.query state.expanded state.expanded_values
                state.values_first ~search_slots:new_slots
                ~current_slot:state.current_slot ~unfolded_ellipsis:new_unfolded
                ~terminal_width:state.terminal_width
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
        else Some { state with search_input = None }
      else Some { state with search_input = None }
  | BeginQuietPath None ->
      Some
        { state with quiet_path_input = Some (Option.value ~default:"" state.quiet_path) }
  | BeginQuietPath (Some quiet_path_value) ->
      let new_quiet_path =
        if String.length quiet_path_value > 0 then Some quiet_path_value else None
      in
      let filtered_history =
        match state.status_history with
        | QuietPathEvent _ :: rest -> rest
        | _ -> state.status_history
      in
      let new_history = QuietPathEvent new_quiet_path :: filtered_history in
      Some
        {
          state with
          quiet_path_input = None;
          quiet_path = new_quiet_path;
          status_history = new_history;
        }
  | BeginGoto None -> Some { state with goto_input = Some "" }
  | BeginGoto (Some scope_id) -> (
      match goto_scope state scope_id ~height with
      | Some new_state -> Some { new_state with goto_input = None }
      | None -> Some { state with goto_input = None })
  | ToggleTimes -> Some { state with show_times = not state.show_times }
  | ToggleValues ->
      let new_values_first = not state.values_first in
      let new_visible =
        build_visible_items state.query state.expanded state.expanded_values
          new_values_first ~search_slots:state.search_slots
          ~current_slot:state.current_slot ~unfolded_ellipsis:state.unfolded_ellipsis
          ~terminal_width:state.terminal_width
      in
      Some { state with values_first = new_values_first; visible_items = new_visible }
  | ToggleSearchOrder ->
      let new_order =
        match state.search_order with
        | Query.AscendingIds -> Query.DescendingIds
        | Query.DescendingIds -> Query.AscendingIds
      in
      Some { state with search_order = new_order }
  | InputChar c -> (
      (* Handle input based on current input mode *)
      match state.goto_input with
      | Some input when c >= '0' && c <= '9' ->
          Some { state with goto_input = Some (input ^ String.make 1 c) }
      | Some _ -> Some state
      | None -> (
          match state.quiet_path_input with
          | Some input when c >= ' ' && c <= '~' ->
              Some { state with quiet_path_input = Some (input ^ String.make 1 c) }
          | Some _ -> Some state
          | None -> (
              match state.search_input with
              | Some input when c >= ' ' && c <= '~' ->
                  Some { state with search_input = Some (input ^ String.make 1 c) }
              | Some _ -> Some state
              | None -> Some state)))
  | InputBackspace -> (
      match state.goto_input with
      | Some input ->
          let new_input =
            if String.length input > 0 then String.sub input 0 (String.length input - 1)
            else input
          in
          Some { state with goto_input = Some new_input }
      | None -> (
          match state.quiet_path_input with
          | Some input ->
              let new_input =
                if String.length input > 0 then
                  String.sub input 0 (String.length input - 1)
                else input
              in
              Some { state with quiet_path_input = Some new_input }
          | None -> (
              match state.search_input with
              | Some input ->
                  let new_input =
                    if String.length input > 0 then
                      String.sub input 0 (String.length input - 1)
                    else input
                  in
                  Some { state with search_input = Some new_input }
              | None -> Some state)))
  | InputEscape -> (
      match state.goto_input with
      | Some _ -> Some { state with goto_input = None }
      | None -> (
          match state.quiet_path_input with
          | Some _ -> Some { state with quiet_path_input = None }
          | None -> (
              match state.search_input with
              | Some _ -> Some { state with search_input = None }
              | None -> None (* Escape in normal mode = quit *))))
  | InputEnter -> (
      match state.goto_input with
      | Some input ->
          if String.length input > 0 then
            try
              let target_scope_id = int_of_string (String.trim input) in
              match goto_scope state target_scope_id ~height with
              | Some new_state -> Some { new_state with goto_input = None }
              | None -> Some { state with goto_input = None }
            with Failure _ -> Some { state with goto_input = None }
          else Some { state with goto_input = None }
      | None -> (
          match state.quiet_path_input with
          | Some input ->
              let new_quiet_path = if String.length input > 0 then Some input else None in
              let filtered_history =
                match state.status_history with
                | QuietPathEvent _ :: rest -> rest
                | _ -> state.status_history
              in
              let new_history = QuietPathEvent new_quiet_path :: filtered_history in
              Some
                {
                  state with
                  quiet_path_input = None;
                  quiet_path = new_quiet_path;
                  status_history = new_history;
                }
          | None -> (
              match state.search_input with
              | Some input -> handle_command state (BeginSearch (Some input)) ~height
              | None ->
                  (* Enter in normal mode = toggle expansion *)
                  Some (toggle_expansion state))))

let initial_state (module Q : Query.S) ~terminal_width =
  let expanded = Hashtbl.create 64 in
  let expanded_values = Hashtbl.create 64 in
  let values_first = true in
  (* Initialize with empty search slots for initial build *)
  let empty_search_slots = SlotMap.empty in
  let unfolded_ellipsis = EllipsisSet.empty in
  let visible_items =
    build_visible_items
      (module Q)
      expanded expanded_values values_first ~search_slots:empty_search_slots
      ~current_slot:S1 ~unfolded_ellipsis ~terminal_width
  in
  let max_scope_id = Q.get_max_scope_id () in

  {
    query = (module Q : Query.S);
    db_path = Q.db_path;
    cursor = 0;
    scroll_offset = 0;
    expanded;
    expanded_values;
    visible_items;
    show_times = true;
    values_first;
    max_scope_id;
    search_slots = SlotMap.empty;
    current_slot = S1;
    search_input = None;
    quiet_path_input = None;
    goto_input = None;
    quiet_path = None;
    search_order = Query.AscendingIds;
    (* Default: uses index efficiently *)
    unfolded_ellipsis;
    search_result_counts = Hashtbl.create 4;
    status_history = [];
    terminal_width;
  }

(** Main interactive loop *)
let run (module Q : Query.S) ~initial_state ~command_stream ~render_screen ~output_size
    ~finalize =
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
          build_visible_items state.query state.expanded state.expanded_values
            state.values_first ~search_slots:state.search_slots
            ~current_slot:state.current_slot ~unfolded_ellipsis:new_unfolded
            ~terminal_width:state.terminal_width
        in
        {
          state with
          search_result_counts = new_result_counts;
          unfolded_ellipsis = new_unfolded;
          visible_items = new_visible;
        }
      else state
    in

    let width, height = output_size () in
    render_screen state_with_updated_searches ~width ~height;

    match command_stream state_with_updated_searches with
    | Some command ->
        Option.iter loop (handle_command state_with_updated_searches command ~height)
    | None ->
        (* Timeout - just redraw to update search status *)
        loop state_with_updated_searches
  in

  loop initial_state;
  finalize ()

(** Parse a command string from CLI/DB into a command type *)
let parse_command_string str =
  let str = String.trim str in
  match str with
  | "q" | "quit" -> Some Quit
  | "j" | "down" -> Some (Navigate `Down)
  | "k" | "up" -> Some (Navigate `Up)
  | "home" -> Some (Navigate `Home)
  | "end" -> Some (Navigate `End)
  | "pgup" | "pageup" -> Some (Navigate `PageUp)
  | "pgdn" | "pagedown" -> Some (Navigate `PageDown)
  | "u" -> Some (Navigate `QuarterUp)
  | "d" -> Some (Navigate `QuarterDown)
  | "enter" | "space" -> Some ToggleExpansion
  | "f" | "fold" -> Some Fold
  | "t" -> Some ToggleTimes
  | "v" -> Some ToggleValues
  | "o" -> Some ToggleSearchOrder
  | "n" -> Some SearchNext
  | "N" -> Some SearchPrev
  | "m" -> Some GotoNextHighlight
  | "M" -> Some GotoPrevHighlight
  | "esc" | "escape" -> Some InputEscape
  | "backspace" -> Some InputBackspace
  | _ when String.length str > 0 && str.[0] = '/' ->
      (* Search command: /term *)
      let term = String.sub str 1 (String.length str - 1) in
      if term = "" then Some (BeginSearch None)
      else Some (BeginSearch (Some term))
  | _ when String.length str > 0 && str.[0] = 'g' ->
      (* Goto command: g<scope_id> *)
      let rest = String.sub str 1 (String.length str - 1) in
      if rest = "" then Some (BeginGoto None)
      else (
        try Some (BeginGoto (Some (int_of_string rest)))
        with Failure _ -> None)
  | _ when String.length str > 0 && str.[0] = 'Q' ->
      (* Quiet path command: Q<pattern> *)
      let rest = String.sub str 1 (String.length str - 1) in
      if rest = "" then Some (BeginQuietPath None)
      else Some (BeginQuietPath (Some rest))
  | _ when String.length str = 1 ->
      (* Single printable character - treat as input char *)
      let c = str.[0] in
      if c >= ' ' && c <= '~' then Some (InputChar c) else None
  | _ -> None

(** Pending command record for DB-backed mode *)
type pending_command = {
  cmd_id : int;
  client_id : string;
  batch_id : string option;
  command : string;
}

(** Callbacks for DB persistence in TUI server mode *)
type db_callbacks = {
  persist_state : view_state -> unit;
  poll_commands : unit -> pending_command list;
  mark_processing : int -> unit;
  mark_done : int -> unit;
  mark_error : int -> string -> unit;
}

(** Main interactive loop with DB persistence for TUI server mode. Persists state to DB
    after each change and polls for commands from tui_commands table. *)
let run_with_db (module Q : Query.S) ~initial_state ~command_stream ~render_screen
    ~output_size ~finalize ~db_callbacks =
  let persist_state state =
    db_callbacks.persist_state state
  in

  let process_db_command state pending_cmd ~height =
    db_callbacks.mark_processing pending_cmd.cmd_id;
    match parse_command_string pending_cmd.command with
    | None ->
        db_callbacks.mark_error pending_cmd.cmd_id ("Unknown command: " ^ pending_cmd.command);
        Some state
    | Some cmd -> (
        (* Catch all exceptions and convert to mark_error to prevent stuck 'processing' *)
        try
          match handle_command state cmd ~height with
          | None ->
              db_callbacks.mark_done pending_cmd.cmd_id;
              None (* Quit command *)
          | Some new_state ->
              db_callbacks.mark_done pending_cmd.cmd_id;
              Some new_state
        with e ->
          let error_msg = Printexc.to_string e in
          db_callbacks.mark_error pending_cmd.cmd_id
            (Printf.sprintf "Exception: %s" error_msg);
          Some state)
  in

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

      if !search_changed then (
        (* Search results changed - invalidate ellipsis and rebuild *)
        let new_unfolded = EllipsisSet.empty in
        let new_visible =
          build_visible_items state.query state.expanded state.expanded_values
            state.values_first ~search_slots:state.search_slots
            ~current_slot:state.current_slot ~unfolded_ellipsis:new_unfolded
            ~terminal_width:state.terminal_width
        in
        let updated =
          {
            state with
            search_result_counts = new_result_counts;
            unfolded_ellipsis = new_unfolded;
            visible_items = new_visible;
          }
        in
        persist_state updated;
        updated)
      else state
    in

    let width, height = output_size () in

    (* First, process any pending commands from DB.
       Track last good state to persist on quit. *)
    let state_after_db_cmds, last_good_state =
      let pending = db_callbacks.poll_commands () in
      List.fold_left
        (fun (acc_state_opt, last_good) pending_cmd ->
          match acc_state_opt with
          | None -> (None, last_good) (* Already got quit - keep last good state *)
          | Some s ->
              match process_db_command s pending_cmd ~height with
              | None -> (None, s) (* Quit - remember state before quit *)
              | Some new_s -> (Some new_s, new_s))
        (Some state_with_updated_searches, state_with_updated_searches)
        pending
    in

    match state_after_db_cmds with
    | None ->
        (* Quit was requested via DB command - persist last good state *)
        persist_state last_good_state;
        finalize ()
    | Some state_after_db ->
        (* Persist after DB commands if any were processed *)
        if state_after_db != state_with_updated_searches then persist_state state_after_db;

        render_screen state_after_db ~width ~height;

        (* Then check for keyboard input *)
        (match command_stream state_after_db with
        | Some command -> (
            match handle_command state_after_db command ~height with
            | None ->
                persist_state state_after_db;
                finalize ()
            | Some new_state ->
                persist_state new_state;
                loop new_state)
        | None ->
            (* Timeout - just redraw to update search status *)
            loop state_after_db)
  in

  (* Persist initial state *)
  persist_state initial_state;
  loop initial_state
