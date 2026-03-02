# Round 1 Review

## Delta since last round

First round — no prior review. This commit implements all six refactoring suggestions from the post-merge retrospective on PR #99:

1. **Centralized `entry_of_stmt`** — eliminates duplicated `Sqlite3.column` mapping (53 → 12 occurrences)
2. **Shared `propagate_highlight_to_ancestors`** — unifies propagation logic between `populate_search_results` and `populate_extract_search_results`
3. **Public `find_scope_headers` API** — replaces the internal `get_all_scope_entries` and ad-hoc SQL fragments
4. **Split extract-search into focused helpers** — `enumerate_candidates`, `apply_dedup_and_highlight`, `remove_highlights_for_shared`, `highlight_shared_and_ancestors`
5. **Deterministic test fixture utility** (`test_db_fixture_utils.ml`) — metadata-based latest run DB resolution
6. **Focused regression test** (`test_dag_quiet_path_stop.ml`) — covers quiet-path stop in both search and extract modes

Net effect: -443 lines (1911 → 1468 in `query.ml`), cleaner separation of concerns.

## Findings (prioritized)

### Minor observations (non-blocking)

1. **`find_scope_header` now does full multi-row fetch**: The old `find_scope_header` used `LIMIT 1` in its query. The new version calls `find_scope_headers` (no LIMIT) then takes the head. For correctness this is fine (semantically identical), but it fetches all headers when only one is needed. The performance difference is negligible since scopes rarely have more than a handful of headers. Not blocking.

2. **`_scope_entry_matches_pattern` also does full fetch**: Same pattern — delegates to `find_scope_headers` then takes head. The `find_matching_paths` function (which uses this heavily via `local_scope_entry_matches_pattern`) still has its own `LIMIT 1` prepared statement, so the hot path is unaffected.

3. **`Hashtbl.add` → `Hashtbl.replace` in propagated tracking**: The original used `Hashtbl.add`; the new shared helper uses `Hashtbl.replace`. Functionally equivalent for `Hashtbl.mem` checks, and `replace` is slightly more correct since it avoids duplicate bindings. Fine.

4. **`get_entries_for_scopes` still uses dynamic SQL**: This function constructs SQL with dynamic placeholders and cannot reuse `entry_of_stmt`'s prepared statement pattern. This is unchanged from the original — not a regression.

### Verification

- `dune build` — clean
- `dune exec test/test_dag_quiet_path_stop.exe` — passes
- `dune exec test/test_dag_highlight_propagation.exe` — passes
- `dune exec test/test_highlight_propagation.exe` — passes
- `dune runtest` — full suite passes cleanly (no diffs)

### Behavioral equivalence confirmed

I carefully compared the propagation logic in `propagate_highlight_to_ancestors` against both original call sites:
- Search path: direct parent check → quiet-path stop → insert all entries → recursive propagation — matches original
- Extract path: shared entry highlight (is_match:true) → ancestor propagation via callback — matches original
- The `on_highlight_scope` callback pattern correctly captures the different insertion behavior (search: plain insert + count; extract: insert + track highlighted keys for dedup removal)

## Verdict

APPROVE

The refactoring is clean, behaviorally equivalent to the original, well-tested, and achieves all six stated goals. The code is significantly more maintainable — the shared propagation helper eliminates the most dangerous source of drift between the two search modes. No regressions detected.
