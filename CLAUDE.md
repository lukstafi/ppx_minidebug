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