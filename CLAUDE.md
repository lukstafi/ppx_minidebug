# PPX_MINIDEBUG Development Guide

## Project Overview
ppx_minidebug is an OCaml PPX extension for debug logging. It has two main components:
- **ppx_minidebug.ml**: The preprocessor that transforms annotated code (e.g., `let%debug_sexp foo`) into instrumented versions with logging calls
- **minidebug_runtime.ml**: The legacy runtime library providing Flushing and PrintBox backends (deprecated in 3.0.0)
- **minidebug_db.ml**: The database backend (3.0+ default) using SQLite with content-addressed value storage

The preprocessor generates calls to `Debug_runtime.log_value_{sexp,pp,show}` which are provided by functors in the runtime.

### 3.0.0 Architecture Shift
Version 3.0.0 transitions from static file generation (PrintBox/Flushing) to database-backed tracing:
- **Database storage**: SQLite with content-addressed deduplication (hash-based O(1) value lookup)
- **Query layer**: `minidebug_client.ml` provides in-process queries and tree rendering
- **CLI tool**: `bin/minidebug_view.exe` for stats, show, search, export operations
- **No file I/O in production**: With `[%%global_debug_log_level 0]`, PPX generates no runtime calls at all

## Build & Test Commands
- Build project: `dune build`
- Install development version: `opam install .`
- Run all tests: `dune runtest`
- Promote new test expectations: `dune promote`
  - For promotion to work, tests need to run, here this means the diffing rules need to run
  - So this requires e.g. `dune runtest` before, or can be combined into `dune test --auto-promote`
- Run a specific `executable` stanza: to run `test_debug_sexp.ml`, do: `dune exec test/test_debug_sexp.exe`
- Run a specific `test` stanza: to run the test `test_path_filter.ml`, do: `dune build @runtest-test_path_filter`
- Run an inline test suite, use `@runtest-<library name>`: to run `test_expect_test.ml`, do: `dune build @runtest-test_inline_tests`
  - In `test/dune`, the inline test library name `test_inline_tests` is different than the file / module name

## Key Architecture Insights

### Database Backend Design (3.0+)
- **Lazy initialization**: Database only created when first log occurs - crucial for production code
- **Content-addressed storage**: `value_atoms` table uses MD5 hash for O(1) deduplication
- **Composite key schema**: `(run_id, entry_id, seq_num)` primary key allows multiple rows per logical entry
  - `seq_num = 0`: Scope entry (function call) created by `open_log`
  - `seq_num > 0`: Parameter values (1, 2, 3...) created by `log_value_*`
  - `seq_num = -1`: Result value created by `log_value_*` with `is_result=true`
- **Entries vs Values design**: Entries are non-leaf nodes (scopes), Values are leaf nodes (parameters/results)
- **Functor architecture**: `DatabaseBackend` is a functor - each instantiation has isolated state (db, run_id, intern refs)
- **No contamination**: Multiple runtime instances writing to same file are safe (SQLite handles concurrency)
- **`finish_and_cleanup()` optional**: For short-lived processes, OS cleanup is sufficient; database remains valid
- **Path filtering**: `should_log` in `open_log` prevents entries from being created (not just hidden)
- **Lazy value forcing**: `log_value_*` functions ALWAYS force lazy values with `Lazy.force` to get actual content

### Critical Gotchas
1. **Database creation is lazy**: If `should_log` always returns false (e.g., log_level=0, aggressive filtering), no database file is created
2. **PPX generates local bindings**: Extension points generate `let module Debug_runtime = (val _get_local_debug_runtime ()) in` at each entry (except for `_o_` extensions)
3. **User provides `_get_local_debug_runtime` ONLY** in typical use cases
4. **`_o_` extensions are different**: `debug_o_`, `track_o_`, `diagn_o_` use pre-existing module, e.g. a manual `module Debug_runtime =` binding
5. **Runtime instance reuse**: Pattern `let rt = ... in fun () -> rt` ensures single instance shared across all calls

### Legacy Runtime Structure (minidebug_runtime.ml - deprecated)
- **Two backends share code**: Flushing and PrintBox both use `Shared_config` module type
- **Entry tracking**: Both backends maintain `hidden_entries` list for log levels
- **PrevRun diffs**: Removed in 3.0.0 - replaced by database queries

### Testing Strategy (3.0+)
- **Database backend tests**: Use dune rules to generate `.db` files, then pipe through `minidebug_view` to `.log` for comparison
- **PPX-only tests**: only verify code generation, not the backend behavior
- **Promote workflow**: Run test, generate output via `minidebug_view`, `dune promote` to capture expected output

## Common Patterns

### Modern Runtime Setup (3.0+)
```ocaml
(* Single runtime instance shared across all calls *)
let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "my_debug" in
  fun () -> rt

(* With options *)
let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file
    ~elapsed_times:Microseconds
    ~log_level:2
    ~path_filter:(`Whitelist (Re.compile (Re.str "my_module")))
    "my_debug"
  in
  fun () -> rt
```

### Testing Pattern
```ocaml
(* In test/dune *)
(executable
 (name test_my_feature)
 (libraries minidebug_db)
 (preprocess (pps ppx_minidebug ppx_deriving.show)))

(rule
 (targets debugger_my_feature.db debugger_my_feature.log)
 (deps ../bin/minidebug_view.exe)
 (action
  (progn
   (run %{dep:test_my_feature.exe})
   (with-stdout-to debugger_my_feature.log
    (run %{dep:../bin/minidebug_view.exe} debugger_my_feature.db show)))))
```

## Coding Conventions
- **Formatting**: Use OCamlformat with profile=default, margin=90
- **Naming**:
  - Modules: Mixed_snake_case (first word capitalized snake case, e.g., `Minidebug_runtime`)
  - Functions/variables: snake_case (e.g., `local_runtime`, `time_elapsed`)
  - Type names: snake_case (e.g., `time_tagged`, `log_level`)
  - Extensions: Prefixed with `debug_`, `track_`, `diagn_`
- **Error handling**: Use pattern matching or try/with for errors
- **Imports**: Group related imports together
- **Documentation**: Include docstrings for public functions

## Migration Notes (2.x → 3.0)
- **Removed features**: PrintBox, Flushing, HTML/MD output, PrevRun diffs, file splitting, multifile output
- **Deprecated modules**: `Minidebug_runtime.{PrintBox,Flushing,PrevRun}` - will be removed in the final 3.0 release
- **Migration path**: Most code needs only runtime change: `Minidebug_runtime.debug_file` → `Minidebug_db.debug_db_file`
- **Behavioral changes**: No static output files; use `minidebug_view` CLI to inspect databases
- **Thread safety**: Each thread needs its own runtime instance OR use SQLite's built-in concurrency (to be validated)