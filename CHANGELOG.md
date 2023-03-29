# Change Log

## [0.2.0] -- 2023-03-29

### Fixed

- Added non-optional package dependencies.
- Major bug fix: missing processing of the top expression in a function body.
- Testing involving the optional dependency is now optional.

## [0.1.4] -- 2023-03-21

### Changed

- Merged the two packages `ppx_minidebug` and `minidebug_runtime` into one.

## [0.1.3] -- 2023-03-17

### Fixed

- Handles labeled function arguments.

### Added

- Documentation suggestions regarding [VOCaml](https://github.com/lukstafi/vocaml).

## [0.1.2] -- 2023-03-06

### Added

- A syntax extension to instrument type-annotated bindings and functions with logging.
- The extension supports 3 value conversion mechanisms: pp and show from deriving.show, and sexp from ppx_sexp_conv.
- The `minidebug_runtime` package provides 3 logging backends: Format based purely on formatters, Flushing that converts to strings first and flushes output after every entry, and PrintBox that pretty-prints as trees using the printbox package.
- References a VS Code extension that builds flame graphs for the `Flushing` logger out-of-the-box.
- Documentation and API docs on github.io.
- Tests, including testing the writing-to-files functionality. Uses `sed` for sanitizing.