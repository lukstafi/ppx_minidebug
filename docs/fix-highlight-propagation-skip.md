# Fix: Highlight Propagation Sometimes Skips Over One Node

GitHub issue: https://github.com/lukstafi/ppx_minidebug/issues/84

## Motivation

In the ppx_minidebug TUI, when a search matches entries, ancestor entries in the tree should also be highlighted so the user can see the path to matches. Sometimes an ancestor entry has no highlight even though one of its children is highlighted, creating a visual "skip." The issue description notes this is "rather annoying / disorienting" and can affect multiple nodes at once.

This is a highlight *computation* bug, not a navigation (m/M key) bug.

## Root Cause

The `propagate_to_ancestors` function in `client/query.ml` (lines 1028-1121) uses `get_scope_entry` to look up the header entry for each ancestor scope. This function queries the database with:

```sql
WHERE e.child_scope_id = ?
LIMIT 1
```

Due to **SexpCache deduplication** (`minidebug_db.ml` lines 810-890), a scope can be shared across multiple parents (DAG structure). When this happens, there are multiple header entries with the same `child_scope_id` -- one in each parent scope. The `LIMIT 1` returns only ONE of these headers. `insert_entry` adds that header's `(scope_id, seq_id)` to `results_table`, but all other headers pointing to the same scope are left unhighlighted.

The result: if the user is viewing the tree through a parent path whose header was NOT the one returned by `LIMIT 1`, that parent entry appears without highlight color. Ancestors above it may still be highlighted (via `get_parent_ids` which correctly returns all parents), and descendants inside the shared scope are highlighted. The parent in between is skipped.

### Why "sometimes"

SexpCache deduplication is transparent -- identical subtrees are silently shared. The user sees a normal tree but the underlying data has DAG structure. The skip only occurs when the viewed path uses a different header than the one returned by `LIMIT 1`.

### Secondary factor: Streaming order

The local `get_scope_entry` in `populate_search_results` uses a `scope_by_id` cache populated during streaming (`Hashtbl.add scope_by_id hid entry` at line 1166). With the default ascending order, `Hashtbl.find_opt` returns the most recently added (highest parent scope_id) entry. The `retroactive_highlight` mechanism (lines 1192-1235) partially mitigates this in descending order but not in ascending order (the default).

## Current State

Key files:
- `client/query.ml` lines 961-1024 -- local `get_scope_entry` with cache fallback to DB
- `client/query.ml` lines 872-890 -- `get_scope_entry_stmt` prepared statement (`LIMIT 1`)
- `client/query.ml` lines 1028-1121 -- `propagate_to_ancestors` function
- `client/query.ml` lines 1164-1167 -- `scope_by_id` cache population during streaming
- `client/query.ml` lines 1192-1235 -- `retroactive_highlight` for headers scanned after matches
- `client/query.ml` lines 1775-1841 -- `populate_extract_search_results` (same bug)
- `client/query.ml` lines 427-466 -- `find_scope_header` public API (also `LIMIT 1`)
- `client/interactive.ml` lines 297-298 -- `is_entry_highlighted` display check
- `client/tui.ml` lines 185-243 -- rendering with highlight colors
- `minidebug_db.ml` lines 810-890 -- SexpCache hit creating DAG structure

## Proposed Change

### 1. Add `get_all_scope_entries` query

Add a new prepared statement that returns ALL header entries for a given scope (no `LIMIT 1`):

```ocaml
let get_all_scope_entries_stmt =
  let query = {|
    SELECT e.scope_id, e.seq_id, e.child_scope_id, e.depth,
           m.value_content as message, l.value_content as location,
           d.value_content as data,
           e.elapsed_start_ns, e.elapsed_end_ns, e.is_result, e.log_level, e.entry_type
    FROM entries e
    LEFT JOIN value_atoms m ON e.message_value_id = m.value_id
    LEFT JOIN value_atoms l ON e.location_value_id = l.value_id
    LEFT JOIN value_atoms d ON e.data_value_id = d.value_id
    WHERE e.child_scope_id = ?
  |} in
  let stmt = Sqlite3.prepare db query in
  fun ~scope_id ->
    Sqlite3.reset stmt |> ignore;
    Sqlite3.bind_int stmt 1 scope_id |> ignore;
    (* collect all rows *)
    ...
```

### 2. Modify propagation to insert all headers

In `propagate_to_ancestors` and `propagate_to_parent`, after calling `get_scope_entry` and `insert_entry` for one header, also fetch all other headers for the same `child_scope_id` and insert them:

```ocaml
(* After inserting the primary header, insert all alternative headers *)
let all_headers = get_all_scope_entries ~scope_id:direct_parent_id in
List.iter (fun alt_header ->
  if alt_header.scope_id <> parent_scope.scope_id
     || alt_header.seq_id <> parent_scope.seq_id then
    insert_entry ~is_match:false alt_header
) all_headers
```

The propagation to further ancestors via `get_parent_ids` is already correct (it returns all parents from `entry_parents`), so no change is needed there.

### 3. Apply the same fix to `populate_extract_search_results`

The extraction search (lines 1775-1841) has the same `get_scope_entry` + `insert_entry` pattern. Apply the same all-headers insertion.

### 4. Update `scope_by_id` cache handling

Modify the local `get_scope_entry` in `populate_search_results` to use `Hashtbl.find_all` (returns all bindings) and insert all cached headers, not just the most recent one.

### 5. Consider updating `find_scope_header` public API

The public `find_scope_header` function (lines 427-466) also uses `LIMIT 1`. Consider adding a `find_all_scope_headers` variant if other consumers need DAG-aware behavior.

## Acceptance criteria

- All header entries pointing to a scope with matching descendants are highlighted
- Ancestor propagation highlights all paths through DAG structure
- No regression with pure tree (single-parent) databases
- Works correctly with both ascending and descending search orders
- No performance regression for large databases (the additional query only fires during propagation, which is bounded by tree depth)

## Scope

**In scope:**
- Fix `propagate_to_ancestors` to insert all headers for each ancestor scope
- Fix `populate_extract_search_results` with the same approach
- Update `scope_by_id` cache handling for DAG awareness
- Test with DAG databases

**Out of scope:**
- Refactoring `propagate_to_ancestors` (keep changes minimal)
- Changes to `goto_highlight_and_expand` navigation (separate issue if any)
- Changes to `quiet_path` behavior (by-design suppression, separate concern)
- Other TUI issues (#85, #89)
