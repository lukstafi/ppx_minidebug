# PPX_MINIDEBUG Development Guide

## Build & Test Commands
- Build project: `dune build`
- Install development version: `opam install .`
- Run all tests: `dune runtest`
- Run specific test: `dune runtest test/test_debug_sexp.ml`
- Run expect test: `dune runtest test/test_expect_test.ml`

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