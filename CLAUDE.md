# PPX_MINIDEBUG Development Guide

## Project Overview
ppx_minidebug is an OCaml PPX extension for debug logging. It has two main components -- the preprocessor and the runtime / backend:
- **ppx_minidebug.ml**: The preprocessor that transforms annotated code (e.g., `let%debug_sexp foo`) into instrumented versions with logging calls
- **minidebug_runtime.ml**: The runtime library providing the types and the legacy Flushing and PrintBox backends (deprecated in 3.0.0)
- **minidebug_db.ml**: The database backend (3.0+ default) using SQLite with content-addressed value storage

The preprocessor generates calls to `Debug_runtime.log_value_{sexp,pp,show}` and `Debug_runtime.log_exception` which are provided by functors in the runtime.

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

### PPX Preprocessor (Frontend)
The preprocessor transforms annotated bindings into instrumented code with logging calls:

- **Extension points**: `%debug_sexp`, `%debug_pp`, `%debug_show`, `%track_sexp`, etc.
- **Type annotations required**: The PPX needs type information to generate logging calls
  - For function parameters and return values: `let%debug_sexp foo (x : int) (y : string) : t = ...`
  - For local bindings: `let z : int = x + y in ...`
  - Without type annotations, the PPX cannot determine how to serialize the value
  - Adding and removing type annotations controls how much gets logged
- **Sexp conversion**: `%debug_sexp` requires `[@@deriving sexp]` or `ppx_sexp_conv` for custom types
- **Code generation**: Each annotated binding gets:
  - `let module Debug_runtime = (val _get_local_debug_runtime ()) in` - fetches runtime instance
  - `Debug_runtime.open_log` - creates scope entry
  - `Debug_runtime.log_value_{sexp,pp,show}` - logs parameters/results
  - `Debug_runtime.log_exception` - logs exceptions (in exception handlers: `| exception e -> log_exception e; close_log; raise e`)
  - `Debug_runtime.close_log` - finalizes scope
- **Lazy evaluation**: All logged values wrapped in `lazy` to defer serialization until log level check passes
- **Exception logging**: Exceptions are logged once at the point closest to where they're raised, using physical equality to prevent duplicate logging as they unwind the stack

### Database Backend Design (3.0+)
- **Lazy initialization**: Database only created when first log occurs - crucial for production code
- **Content-addressed storage**: `value_atoms` table uses MD5 hash for O(1) deduplication
- **Composite key schema**: `(scope_id, seq_num)` primary key allows multiple rows per logical entry
  - `seq_num >= 0`: Values (1, 2, 3...) created by `log_value_*`, headers created by `open_log`
  - `seq_num < 0`: "Synthetic" scopes and values created by `boxify` during decomposition of sexp values
- **Entries vs Values design**: Entries are non-leaf nodes (scopes), Values are leaf nodes (parameters/results)
- **Functor architecture**: `DatabaseBackend` is a functor - each instantiation has isolated state (db, intern refs)
- **No contamination**: Multiple runtime instances writing to same file are safe (SQLite handles concurrency)
- **`finish_and_cleanup()` optional**: For short-lived processes, OS cleanup is sufficient; database remains valid
- **Path filtering**: `should_log` in `open_log` prevents entries from being created (not just hidden)
- **Lazy value forcing**: `log_value_*` functions ALWAYS force lazy values with `Lazy.force` to get actual content
- **Boxify caching**: Recursive sexp structures are cached in memory during decomposition
  - `SexpCache` module uses hashtable to map sexp hash → scope_id
  - On cache hit, creates a reference entry instead of reprocessing the sexp
  - Dramatically reduces database size for repeated substructures (trees, lists, maps)
  - Works at all recursion levels in `boxify`, not just top-level values

### Critical Gotchas
1. **Database creation is lazy**: If `should_log` always returns false (e.g., log_level=0, aggressive filtering), no database file is created
2. **PPX generates local bindings**: Extension points generate `let module Debug_runtime = (val _get_local_debug_runtime ()) in` at each entry (except for `_o_` extensions)
3. **User provides `_get_local_debug_runtime` ONLY** in typical use cases
4. **`_o_` extensions are different**: `debug_o_`, `track_o_`, `diagn_o_` use pre-existing module, e.g. a manual `module Debug_runtime =` binding
5. **Runtime instance reuse**: Pattern `let rt = ... in fun () -> rt` ensures single instance shared across all calls
6. **Adding new runtime functions**: When adding functions to `Debug_runtime` signature:
   - Add to `minidebug_runtime.mli` (interface)
   - Add to `module type Debug_runtime` in `minidebug_runtime.ml` (implementation constraint)
   - Implement in all three backends: `DatabaseBackend` (minidebug_db.ml), `Flushing`, and `PrintBox` (both in minidebug_runtime.ml)
   - Update PPX code generation if the function is meant to be called by generated code
   - Run `dune test --auto-promote` to update all test expectations when PPX output changes

### Legacy Runtime Structure (minidebug_runtime.ml - deprecated)
- **Two backends share code**: Flushing and PrintBox both use `Shared_config` module type
- **Entry tracking**: Both backends maintain `hidden_entries` list for log levels
- **PrevRun diffs**: Removed in 3.0.0 - replaced by database queries

### Testing Strategy (3.0+)
- **Database backend tests**: Use dune rules to generate `.db` files, then pipe through `minidebug_view` to `.log` for comparison
- **PPX-only tests**: only verify code generation, not the backend behavior
- **Promote workflow**: Run test, generate output via `minidebug_view`, `dune promote` to capture expected output
- **Exception tracking state**: `logged_exceptions` ref is cleared when exiting root scope (stack empty), ensuring proper cleanup between top-level calls

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
 (modules test_my_feature)
 (libraries minidebug_db)
 (modes exe)
 (preprocess (pps ppx_minidebug ppx_deriving.show)))

(rule
 (targets debugger_my_feature.db debugger_my_feature.log)
 (deps ../bin/minidebug_view.exe ../bin/filter_test_output.exe)
 (action
  (progn
   (run %{dep:test_my_feature.exe})
   (with-stdout-to
    debugger_my_feature.log
    (pipe-stdout
     (run %{dep:../bin/minidebug_view.exe} debugger_my_feature.db show)
     (run %{dep:../bin/filter_test_output.exe}))))))

(rule
 (alias runtest)
 (action
  (diff debugger_my_feature.expected.log debugger_my_feature.log)))
```

**Testing workflow**:
1. Create test file `test/test_my_feature.ml` with runtime setup and test code
2. Add executable and rule stanzas to `test/dune` (as above)
3. Run `dune exec test/test_my_feature.exe` to generate initial `.db` file
4. View output: `dune exec bin/minidebug_view.exe debugger_my_feature.db show`
5. Create expected output: `dune exec bin/minidebug_view.exe debugger_my_feature.db show | _build/default/bin/filter_test_output.exe > test/debugger_my_feature.expected.log`
6. Run tests: `dune test --auto-promote` to generate and promote all test outputs
7. Verify: `dune runtest` should pass with no diffs

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