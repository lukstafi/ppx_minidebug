# Proposal: ppx_minidebug PR #102 followups

**Task**: task-d3ede2d6
**Project**: ppx_minidebug
**PR**: https://github.com/lukstafi/ppx_minidebug/pull/102

## Goal

Clean up two follow-up items from the dune instrumentation backend PR (#102):

1. **Extract `is_auto_eligible` predicate**: The eligibility check for auto-instrumentation (is this binding a non-unit, non-runtime-setup, function expression that is not already instrumented?) is written out identically in three places. Extract it into a single named function.

2. **Document `instrumentation.backend` flags gotcha**: Dune's `(instrumentation.backend ...)` stanza in `dune-project` does not support a `flags` field. Users must pass `--auto` on the consumer side via `(instrumentation (backend ppx_minidebug --auto))` in each library/executable's `dune` file. This is non-obvious and should be documented in the README.

## Acceptance Criteria

- [ ] A top-level `is_auto_eligible : value_binding -> bool` function is defined in `ppx_minidebug.ml` that checks: `not (is_unit_pattern vb.pvb_pat) && not (is_runtime_setup_binding vb) && is_function_expr vb.pvb_expr && not (is_already_instrumented vb)`
- [ ] The local `is_eligible_binding` inside `needs_runtime_injection` (line ~810) is replaced with a call to `is_auto_eligible`
- [ ] The inline predicate in `any_eligible` (lines ~2130-2136) is replaced with a call to `is_auto_eligible`
- [ ] The inline predicate in the `List.map` filter (lines ~2143-2147) is replaced with a call to `is_auto_eligible`
- [ ] README.md includes a section (or note in an existing section) explaining how to pass `--auto` when using dune instrumentation, with a concrete `dune` file example showing `(instrumentation (backend ppx_minidebug --auto))`
- [ ] The README note clarifies that `(instrumentation.backend ...)` in `dune-project` does NOT accept a `flags` field
- [ ] All existing tests pass (`dune runtest`)

## Context

### Duplication locations in `ppx_minidebug.ml`

**Location 1** -- `needs_runtime_injection` (line ~809): defines a local `is_eligible_binding` with the same 4-conjunct check.

**Location 2** -- `transform_item` / `any_eligible` (line ~2130): inline `List.exists` with identical 4-conjunct predicate.

**Location 3** -- `transform_item` / `List.map` filter (line ~2143): inline `if` guard with identical 4-conjunct predicate.

### README gap

The README currently has no section about dune instrumentation or the `--auto` flag. The `--auto` flag and related `--auto-mode`, `--auto-log-value`, `--auto-db-base-name` options are only documented via `Driver.add_arg` doc strings in the source.

## Approach

1. Define `let is_auto_eligible vb = ...` near the existing helper functions (around line 808, just before `needs_runtime_injection`).
2. Replace all three occurrences with calls to `is_auto_eligible`.
3. Add a "Dune Instrumentation Backend" section to the README (near the end, before "Related projects") with:
   - Brief explanation of `--auto` mode
   - `dune-project` stanza example: `(instrumentation.backend (ppx ppx_minidebug))`
   - Consumer-side `dune` file example: `(instrumentation (backend ppx_minidebug --auto))`
   - Explicit note about the flags gotcha
4. Run `dune runtest` to confirm no regressions.
