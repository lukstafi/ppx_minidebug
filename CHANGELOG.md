## [0.7.0] -- current

### Added

- A new optional PrintBox-only setting `highlight_terms`, which applies a highlight style on paths to leaves matching a regular expression.

## [0.6.2] -- 2023-12-21

### Fixed

- Backward compatibility: `Out_channel.output_string` --> `Stdlib.output_string`.

## [0.6.1] -- 2023-12-20

Support for debugging infinite loops.

### Added

- A new optional setting `max_num_children`, which terminates a computation with a `Failure` exception when the given size of sibling logs is exceeded.

## [0.6.0] -- 2023-12-15

### Added

- Runtime entry point `debug_flushing` that returns a `Flushing` runtime which by default logs to `stdout`.
- A new optional setting `max_nesting_depth`, which terminates a computation with a `Failure` exception when the given nesting of logs is exceeded.

## [0.5.0] -- 2023-10-29

### Added

- An option to output to HTML, when in the `PrintBox` runtime.
- An option to convert the logged `sexp` values to `PrintBox` trees, when they exceed a given size in atoms.
- Runtime entry points `debug_html` that returns a `PrintBox` runtime configured to output HTML into a file with the given name, and `debug` that returns a `PrintBox` runtime which by default logs to `stdout`.

### Changed

- Exception handling that allows proper tracing/logging for raising functions and crashing (via uncaught exception) programs.

## [0.4.0] -- 2023-10-18

### Added

- The `PrintBox` logger now allows disabling (not outputting) a whole subtree of the logs.

### Fixed

- A broken link in the documentation landing page.

## [0.3.3] -- 2023-09-15

### Changed

- Breaking change: explicitly set whether logs should be time tagged.

## [0.3.2] -- 2023-04-25

### Fixed

- Missing version bounds on `ocaml` and `ppxlib` to make CI happy.

## [0.3.1] -- 2023-03-30

### Fixed

- A small tweak to have `dune-release` work.

## [0.3.0] -- 2023-03-29

### Changed

- Breaking change: renamed `Minidebug_runtime.Format` to `Minidebug_runtime.PP_format`.
- Non-optionally depending on `sexplib0` and `ppx_sexp_conv`, as optional dependency was making it hard to test. Also the `minidebug_runtime` source files duplication was ugly.
- Trying to minimize dependencies: removed the unused direct dependency on `base`, but `ppx_sexp_conv` depends on it. Removed the dependency on `stdio`.
- Added a building-related comment to the documentation.

## [0.2.0] -- 2023-03-29

### Fixed

- Added non-optional package dependencies.
- Major bug fix: missing processing of the top expression in a function body.

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