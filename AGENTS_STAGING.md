# Agent Learnings (Staging)

This file collects agent-discovered learnings for later curation into CLAUDE.md / AGENTS.md.

<!-- Entry: gh-ppx_minidebug-84-coder | 2026-03-02T13:39:52+0100 -->
### Prefer metadata DB for latest run file in tests

When using `Minidebug_db.debug_db_file "name"` in tests, run output is versioned (e.g. `name_3.db`) and earlier `name_1.db` files may remain from previous invocations. For deterministic assertions, resolve the latest `db_file` from `name_meta.db` (e.g., `SELECT db_file FROM runs ORDER BY run_id DESC LIMIT 1`) instead of hardcoding `_1.db`.

<!-- End entry -->

<!-- Entry: gh-ppx_minidebug-84-followup-coder | 2026-03-02T23:20:21+0100 -->
### Share helper test code via a small test library in `test/dune`

If multiple `(test ...)` stanzas need the same helper module, define a small `(library ...)` for that helper and depend on it from each test. Listing the same helper module in multiple test stanzas creates conflicting generated rules in dune.

<!-- End entry -->
