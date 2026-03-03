# Follow-up: Solution for gh-ppx_minidebug-84

This is a follow-up task based on feedback from PR #99.
PR: https://github.com/lukstafi/ppx_minidebug/pull/99

## Original PR Description

Solution from coder for feature: gh-ppx_minidebug-84

## PR Comments and Reviews

The comments below (most recent last) describe what needs to be done.
Focus especially on the last comment(s) for the actionable task.

### Comment by lukstafi (2026-03-02T13:16:47Z)

## Refactoring Suggestions

*Post-merge retrospective: what would we do differently if starting from scratch?*

# Refactoring Suggestions

## If starting from scratch, I would...

- Factor duplicated entry decoding into a single helper in `client/query.ml` (e.g., `entry_of_stmt`) used by `search_entries`, `find_entry`, `find_scope_header`, streaming search, and extract-search paths. This would remove repeated `Sqlite3.column` mapping blocks and reduce regression risk when entry schema handling changes.
- Introduce a shared DAG-aware propagation helper in `client/query.ml` used by both `populate_search_results` and `populate_extract_search_results` (including direct-parent insertion + ancestor traversal + quiet-path stop semantics). The two code paths currently duplicate subtle propagation behavior and can drift.
- Add a public query API for "all headers for child scope" in `client/query.mli`/`client/query.ml` (`find_scope_headers`), and migrate internal callers from ad-hoc SQL fragments. This would make DAG semantics explicit instead of relying on hidden local helpers.
- Split `populate_extract_search_results` in `client/query.ml` into smaller units: candidate enumeration, dedup bookkeeping, highlight insertion, and propagation. The current monolithic function mixes concerns, making edge-case reasoning difficult.
- Add a deterministic regression test fixture utility in `test/` for resolving latest run DB via metadata (`*_meta.db`), so tests do not hardcode `_1.db` and do not depend on filesystem cleanup state.
- Add one focused test that validates quiet-path stopping behavior in DAG propagation for both search and extract modes, to lock down the intended semantics when a duplicated ancestor matches quiet-path.

