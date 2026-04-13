# Refactor snapshot_ch into with_snapshot_bookkeeping wrapper and add test output .gitignore

## Goal

Reduce the fragility of snapshot bookkeeping in `close_tree` by extracting the paired `pop_snapshot()` / `snapshot_ch()` calls into a structural wrapper. The original bug (gh-ppx_minidebug-42, PR #104) was caused by `snapshot_ch()` being positionally placed between main output and TOC output, so the TOC got a stale snapshot. A wrapper makes the save/restore boundary explicit and prevents future regressions of the same class.

Additionally, add `.gitignore` patterns for generated test output files that currently show up as untracked in worktrees.

## Acceptance Criteria

1. A `with_snapshot_bookkeeping` function (or equivalent wrapper) exists inside the `PrintBox` functor that encapsulates the `pop_snapshot()` call before the wrapped body and the conditional `snapshot_ch()` call after it.
2. The `close_tree` function in `close_log_impl` uses this wrapper instead of manually calling `pop_snapshot` and `snapshot_ch`.
3. All existing tests pass (`dune runtest`).
4. The root `.gitignore` includes patterns that ignore generated test debug output files (e.g. `debugger_*_debug*` logs, `*.raw`) without matching checked-in `.expected.log` files.

## Context

### Snapshot bookkeeping in close_tree

The `close_tree` local function is defined inside `close_log_impl` at `minidebug_runtime.ml:1622`. It currently calls:
- `pop_snapshot()` (line 1625) -- restores channel state if `needs_snapshot_reset` is true
- `snapshot_ch()` (line 1627) -- takes a new channel snapshot, guarded by `if not from_snapshot`

These two functions are defined per `Shared_config` implementation:
- `shared_config` factory (line ~147) -- file-backed channels with rotation
- `local_printbox_runtime` / `debug` (line ~2196) -- optional `debug_ch` argument
- `debug_flushing` (line ~2251) -- similar
- `minidebug_db.ml` -- no-op (database backend, no channel snapshots)

The `from_snapshot` parameter comes from `close_log_impl`, not from the config, so the wrapper lives inside `close_log_impl` (or takes `~from_snapshot` as a parameter).

Key helper state: `needs_snapshot_reset` ref (line 1568) gates `pop_snapshot`. Set by `snapshot()` (line 1615), cleared by `pop_snapshot()` (line 1573).

### .gitignore

The root `.gitignore` already covers `*.db`, `*.db-shm`, `*.db-wal`. Generated test output files like `debugger_snapshot_toc_debug.log`, `debugger_snapshot_toc_debug-toc.log`, and `debugger_snapshot_toc_debug.raw` are not covered. Checked-in expected files use `debugger_*.expected.log` naming (never contain `_debug` before the extension), so a `debugger_*_debug*` pattern is safe.

## Approach

*Suggested approach -- agents may deviate if they find a better path.*

1. Add a `with_snapshot_bookkeeping ~from_snapshot f` helper near `pop_snapshot` (around line 1574) that calls `pop_snapshot()`, runs `f ()`, then conditionally calls `snapshot_ch()`.
2. Refactor `close_tree` to wrap its body (from `let ch = debug_ch ()` through the TOC output) inside `with_snapshot_bookkeeping ~from_snapshot`.
3. Append to the root `.gitignore`: patterns for `debugger_*_debug*` and `*.raw`.

## Scope

**In scope:**
- The `with_snapshot_bookkeeping` wrapper and `close_tree` refactor in `minidebug_runtime.ml`
- Root `.gitignore` additions for test output files

**Out of scope:**
- Changes to `minidebug_db.ml` (its snapshot functions are no-ops)
- Changes to the `Shared_config` interface or individual `snapshot_ch` / `pop_snapshot` implementations
- New tests beyond confirming existing tests still pass (the refactor is behavior-preserving)
