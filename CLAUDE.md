# PPX_MINIDEBUG Development Guide

## Project Overview
ppx_minidebug is an OCaml PPX extension for debug logging. It has two main components:
- **ppx_minidebug.ml**: The preprocessor that transforms annotated code (e.g., `let%debug_sexp foo`) into instrumented versions with logging calls
- **minidebug_runtime.ml**: The runtime library providing two backends (Flushing and PrintBox) with `log_value_*` functions

The preprocessor generates calls to `Debug_runtime.log_value_{sexp,pp,show}` which are provided by functors in the runtime.

## Build & Test Commands
- Build project: `dune build`
- Install development version: `opam install .`
- Run all tests: `dune runtest`
- Promote new test expectations: `dune promote`
- Run a specific test executable: `dune exec test/test_debug_sexp.exe`

## Key Architecture Insights

### Runtime Structure
- **Two backends share code**: Flushing (simple text output) and PrintBox (structured output) both use `Shared_config` module type
- **open_log gets full context**: The `open_log` function receives both `fname` (file path) and `message` (function/binding name) - useful for filtering/routing
- **Entry tracking**: Both backends maintain `hidden_entries` list (for log levels) - when adding filtering, use a hashtable for O(1) lookups
- **Unified filtering**: Combine multiple filter checks (log level, path, etc.) in a single `should_log` function to avoid redundant checks

### Adding Runtime Features
1. **Add to Shared_config**: New config options go in the module type signature (`.mli` and `.ml`)
2. **Update shared_config function**: Add the parameter with a sensible default
3. **Implement in both backends**: Changes to filtering/logging must be done in both Flushing and PrintBox modules
4. **Track filtered entries**: If filtering affects both `open_log` and `log_value_*`, use a hashtable to prevent orphaned logs
5. **Update all runtime factories**: `debug`, `debug_file`, `debug_flushing`, `local_runtime`, `prefixed_runtime` all need the new parameter

### Testing Strategy
- **Use the `test` stanza**: New trend - use `(test ...)` with `debug()` logging to stdout, cleaner than `executable` + manual diffing
- **PPX requires _get_local_debug_runtime**: Define as `let rt = Minidebug_runtime.debug ... in fun () -> rt` at module top-level
- **Promote workflow**: Create empty `.expected` file, run test, `dune promote` to capture output

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