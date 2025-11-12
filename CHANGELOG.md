# [3.1.0] -- 2025-11-12

### Added

- **MCP Server for AI-Powered Debugging**: Full MCP (Model Context Protocol) server implementation enabling AI agents to explore traces
  - `minidebug/init-db`: Initialize session with a trace database
  - `minidebug/tui-execute`: Stateful TUI-style navigation with command sequences (j/k, /, expand, goto, etc.)
  - `minidebug/tui-reset`: Reset TUI state to initial view
  - `minidebug/search-tree`, `search-subtree`, `search-at-depth`, `search-intersection`, `search-extract`: Advanced search operations
  - `minidebug/show-trace`, `show-scope`, `show-subtree`: Tree rendering with configurable depth
  - `minidebug/get-ancestors`, `get-children`: Scope hierarchy navigation
  - `minidebug/list-runs`, `minidebug/stats`: Database inspection
  - Session state management with search caching and prepared statement optimization
  - Text-based renderer with color-coded highlights ([G] [C] [M] [Y]) for AI consumption
  - GLOB pattern syntax (SQL GLOB, auto-wrapped: `error` → `*error*`) documented across all surfaces
- **Enhanced CLI Commands**: Expanded `minidebug_view` with comprehensive search and navigation
  - `search-tree <pattern>`: Search with full ancestor context (shows complete call paths to matches)
  - `search-subtree <pattern>`: Search with pruned trees (shows only matching branches)
  - `search-at-depth <pattern> <depth>`: TUI-like summary view at specific depth
  - `search-intersection <p1> <p2> [p3] [p4]`: Find scopes matching ALL patterns (2-4 patterns)
  - `search-extract <search_path> <extraction_path>`: DAG path search with value extraction and change tracking
  - `show-scope <id>`: Display specific scope and descendants, or ancestor path with `--ancestors`
  - `show-subtree <id>`: Focused scope exploration with depth limiting
  - `get-ancestors <id>`: Show ancestor chain with messages and locations
  - `get-children <id>`: List child scope IDs
  - `--format=json`: Machine-readable JSON output for programmatic access
  - `--quiet-path=<pattern>`: Control ancestor propagation boundaries in search
  - `--limit`, `--offset`: Pagination for large result sets
- **Enhanced TUI Navigation**:
  - `g<scope_id>`: Goto command for direct scope navigation with smart ancestor expansion
  - `f`: Fold command to re-fold unfolded ellipsis or collapse containing scope
  - Highlight-aware ellipsis with unfolding capability
  - Chronological status history with LRU deduplication
  - Character-aware UTF-8 operations using uutf (fixes crashes on Unicode)
  - Exception string sanitization (removes control characters)
- **Architecture Improvements**:
  - Refactored `Interactive` module: separated command processing from keyboard event parsing
  - Split `minidebug_client.ml` into modular `client/` directory structure
  - Shared command type abstraction for TUI and MCP frontends
  - Pluggable RENDERER module signature (Notty terminal vs. plain text)
  - Query module refactored to functor with prepared statement caching
  - Migrated from `get_entries` to targeted SQL queries for efficiency
  - Output budget limiting for MCP responses
  - DAG parent support: scopes can have multiple parents (fixes search ambiguity)
- **Dependency Updates**:
  - Migrated from `notty` to `notty-community` for OCaml 5.4+ and Windows support
  - Removed unnecessary `nottui-unix` dependency
  - Vendored `mcp` library (Anil Madhavapeddy's ocaml-mcp)
  - Added `pin_depends` for `notty-community` fork
- **Exception Logging**: PPX now logs exceptions with `Debug_runtime.log_exception`
  - Physical equality tracking prevents duplicate logs during stack unwinding
  - Exceptions logged once at raise point, close to their origin
- **Documentation**:
  - Comprehensive `CLI.md` covering CLI commands, MCP server, and TUI implementation
  - MCP Server section in README.md with configuration examples for Claude Desktop
  - GLOB pattern syntax reference across all user-facing surfaces
  - Updated test expectations after metadata-based DB retrieval refactoring

### Changed

- **Test Suite Refactoring**: Tests now use metadata-based database retrieval instead of hardcoded paths
- **Client API Enhancement**: `open_by_run_name` upstreamed from test code to public API
- **Scope ID Notation**: Simplified from `{#N}` to `#N` in CLI output for readability

### Fixed

- **OCaml 5.4 Compatibility**: Tiny compatibility fixes for OCaml 5.4
- **MCP Vendoring**: Fixed missing dependencies in vendored mcp library
- **TUI Crashes**:
  - Fixed UTF-8 crashes with character-aware operations using uutf
  - Fixed crash on exception strings containing control characters
- **DAG Parent Ambiguity**: Scopes now support multiple parents (resolves search path issues)
- **Not_found Exceptions**: Fixed in `show-subtree` and other CLI commands
- **Scope Retrieval**: `show-subtree` now works correctly with non-root scopes
- **Client Refactoring**: Fixed MCP stdio transport after parametric output channel changes



# [3.0.0] -- 2025-10-24

### Added

- **Database backend** with SQLite storage (`minidebug_db.ml`)
  - Content-addressed value deduplication via MD5 hashing (O(1) lookup)
  - Recursive sexp caching during boxify decomposition for structural deduplication
  - Large value decomposition (boxify) with indentation-based parsing into nested scopes
  - Schema versioning with automatic migration support (currently v3)
  - Separate metadata database for tracking runs across versioned files
- **Fast mode performance optimization** (~100x speedup)
  - Top-level transaction scoping (BEGIN when stack empty, COMMIT when stack clears)
  - DELETE journal with synchronous=OFF (trades durability for speed)
  - Signal handlers (SIGINT, SIGTERM) and at_exit for safe commits
- **File versioning** to prevent runtime conflicts
  - Global atomic counter assigns unique run numbers (debug_1.db, debug_2.db, etc.)
  - Symlink from base name to latest versioned file
  - Multiple runtime instances in same process write to separate files
- **Interactive TUI** (`minidebug_view db.db tui`)
  - Navigation: arrow keys/j/k, PageUp/PageDown, Home/End
  - Search: `/` for multi-slot concurrent search (4 slots: S1-S4) with background Domain
  - Search result navigation: `n`/`N` jump to next/previous match with auto-expand
  - Quiet path filtering: `Q` stops highlight propagation at matching ancestors
  - Configurable search ordering: `o` toggles Ascending/Descending scope_id
  - Expand/collapse: Space toggles selected entry
  - Real-time incremental search results with ancestor path highlighting
- **CLI tool** (`minidebug_view`) for database inspection
  - `stats`: Database statistics and deduplication metrics
  - `show`: Render trace tree with configurable depth/format
  - `compact`: Function names only view with timing
  - `search`: CLI-based pattern search
  - `export`: Export to markdown format
  - `roots`: Efficient top-level entry queries for large databases

### Changed

- **Breaking**: Database backend is now the default and recommended approach
- **Breaking**: Static file generation (PrintBox/Flushing) marked as deprecated
- **Breaking**: Removed HTML/Markdown output, PrevRun diffs, file splitting, multifile output
- **Breaking**: Database schema field renames in v2:
  - `entry_id` → `scope_id` (identifies parent scope)
  - `header_entry_id` → `child_scope_id` (points to child scope)
  - `show_entry_ids` → `show_scope_ids`
- **Breaking**: Removed `run_id` from composite keys (file versioning guarantees one run per file)
- Migration from static backends: change `Minidebug_runtime.debug_file` to `Minidebug_db.debug_db_file`
- `global_prefix` parameter renamed to `run_name` and stored in metadata database
- `finish_and_cleanup()` now optional (automatic at_exit handlers in Fast mode)
- Database created lazily (no file if log_level=0 or all logs filtered)
- `values_first_mode` default changed to `true` for better rendering

### Fixed

- TUI crash on EINTR from Unix.select (terminal resize signals)
- Search highlight propagation to ancestors in TUI (retroactive highlighting for boxified values)
- Quiet path filter propagation (proper boundary marking)
- Multiple runtime instances writing to same database (file versioning eliminates conflicts)
- Memory issues with large databases (streaming instead of loading all entries)
- Boxify hash collisions (MD5 content hash instead of Hashtbl.hash)
- Boxify cross-recursion scope_id reference bug
- Database path resolution for versioned files in metadata queries
- Chronological ordering of trace output (unified seq_id ordering)
- Parameter/result value ordering (parameters before results)
- Retroactive `no_debug_if` implementation for database backend
- `%log_entry` dynamic scoping with database backend
- Orphaned logs support (query database for next available seq_id)
- Multiple tests migrated to database backend with proper expectations

## [2.4.0] -- 2025-10-03

### Added

- Runtime path filtering: filter logs by file path and/or function/binding name (#63)
  - `path_filter` parameter accepts `Whitelist` or `Blacklist` with a regex
  - Filter applied to `fname/message` pattern for fine-grained control
  - Examples: filter by file, by function prefix, or exclude test utilities
  - Zero overhead when filtering is disabled

### Fixed

- Make string and sexp conversions lazy to reduce overhead (#57)
- Prevent polluting LSP type reports by using ghost locations (#67)
- Fix runtime argument passing for proper type inference (#62)

## [2.3.0] -- 2025-06-21

### Changed

- Switched over to the new OCaml AST and ppxlib 0.36.

### Fixed

- Fixed stale README.md mentions of the retired `_l_` infix.

## [2.2.0] -- 2025-03-28

### Added

- Added some missing configurations for runtime providers `debug`, `debug_flushing`.
- New runtime providers that can directly be used for `_get_local_debug_runtime`: `local_runtime`, `local_runtime_flushing`, `prefixed_runtime`, `prefixed_runtime_flushing`.
- Added `PPX_MINIDEBUG_DEFAULT_COMPILE_LOG_LEVEL` environment variable to avoid forcing everyone to use `[%%global_debug_log_level_from_env_var "..."]` in every file.
- Ability to prefix individual logs in the flushing backend. For `prefixed_runtime_flushing`, we prefix all logs, not only headers.

### Changed

- Major, breaking change: the `_l_` variant entry points become default, and the default variants become `_o_`, e.g. `%debug_l_sexp` becomes `%debug_sexp`, `%debug_sexp` becomes `%debug_o_sexp`.
- Overhaul of `README.md` / `index.mld` to use MDX: all code samples are automatically lifted from tests (or `sync_to_md.ml`) thus guaranteed correct.

## [2.1.0] -- 2025-03-19

### Added

- New feature: highlight differences between runs. Allow ignoring expected change patterns in the logs.
- `finish_and_cleanup` to finish or interrupt logging in a safe way (closes the files).

### Fixed

- Close files when finalizing a runtime.
- Manual cleanup of the `README.md` -> `index.mld` translation.
- Automate/standardize documentation deployment.

## [2.0.3] -- 2025-01-02

### Changed

- `%log_level` unregistered extension is now setting the dynamic log level in addition to the lexical log level.

### Fixed

- Bump printbox compatibility and dependency to 0.12.

## [2.0.2] -- 2024-10-18

### Changed

- `Shared_config` now has an `init_log_level` field, populated from the runtime creation functions' `~log_level` argument.
- A header `BEGIN DEBUG SESSION` is only output when the (initial) log level is greater than 0.
- A debug file is opened (created) lazily, in particular not at initialization if the initial log level is 0.
- We give up on only splitting the flushing backend files at toplevel log boundaries: now a log open and log close can be in different files.

### Fixed

- Outdated README comment: local debug runtimes are not restricted to functions.

## [2.0.1] -- 2024-09-08

### Changed

- `values_first_mode` is now the default: `?(values_first_mode = true)`.

### Fixed

- Write the whole incomplete log tree on the error "lexical scope of close_log not matching its dynamic scope" by snapshotting, so the entries from the error message can be looked up.
- Don't use `str_formatter`, it's only meant to be used from the main domain. (It affected timestamps, and `_pp` entry points for the flushing backend.)

## [2.0.0] -- 2024-08-26

### Added

- Compile-time explicit log levels `%debug1_sexp`, `%debug2_sexp`, `%log1`, `%log2`, `%log2_result`, `%log2_entry` etc. that participate in compile-time log level filtering.
- Runtime log levels `%at_log_level`, `%logN`, `%logN_result`, `%logN_printbox` that take the level at which to log as argument. Note: not supported for extension entry points `%debug_sexp` etc.
- New unregistered extension point `%log_block` (similar to `%log_entry`) that assumes its body is logging code only, and does both compile-time and runtime pruning of the body according to the log level. Limited to unit-type bodies.

### Changed

- Moved `no_debug_if` to the generic interface (the last remaining non-config functionality missing from it). It's ignored (no-op) for the flushing backend.
- Moved to linear log levels per-entry and per-log, where an unspecified log level inherits from the entry it's in, determined statically.
- Removed `_this_` infix and make all extension points behave as `_this_` (not extend to bodies of toplevel bindings).
- Removed `_rtb_` and `_lb_` -- all debugging should use the generic interface as it now offers all the functionality except configuration.
- Removed a heuristic to not print extra debug information at log level 1 -- replaced by checking for `%diagn`.

## [1.6.1] -- 2024-08-21

### Fixed

- Write the log tree on the error "lexical scope of close_log not matching its dynamic scope", so the entries from the error message can be looked up.
- Uncaught exception in the `[%%global_debug_log_level_from_env_var "..."]` consistency check when the environment variable is not defined.

## [1.6.0] -- 2024-08-08

### Added

- Runtime `description`: where the logs are directed to.
- A new family of entry points `_l_` resp. `_lb_` that retrieve debug runtimes via a call `_get_local_debug_runtime ()` resp. `_get_local_printbox_debug_runtime ()`: these functions are correspondingly expected in the scope. The entry points facilitate using thread-local (and domain-local) debug runtimes.
- Compile-time vs. runtime consistency check for `%%global_debug_log_level_from_env_var`, and  `%%global_debug_log_level_from_env_var_unsafe` that bypasses the check.

### Changed

- Runtime builders take a `description` optional argument.
- We now check for the compile-time vs. runtime consistency of log level specifications (#45).

### Fixed

- `_this_` infix on non-let-binding expressions throws a syntax error instead of being a no-op.
  - As a design decision aligned with [#51](https://github.com/lukstafi/ppx_minidebug/issues/51), we output the error instead of processing the expression, i.e. we don't ignore the `_this_` infix.
- `_rt_` / `_rtb_` entry points now work correctly on non-function expressions, making them functions of the debug runtime.
- Not outputting `%log_entry` when `log_level=Nothing`.
- Highlighting of `<returns>` and `<values>`.

## [1.5.1] -- 2024-07-07

### Changed

- Outputs entry ids on the stack when reporting static vs. dynamic scope mismatch failure.
- Promotes `val snapshot : unit -> unit` to the generic interface, implemented as no-op in the flushing backend.
- Does not try to debug module bindings.

## [1.5.0] -- 2024-03-20

### Added

- An API function `Debug_runtime.open_log_no_source` for log entries without associated source code locations, and a corresponding `[%log_entry]` extension point.
- A simple, minimalistic version of a Flame Graph output in ToC files (PrintBox backend only).
- A new ToC criterion: elapsed time threshold.
- And-or gates for ToC criteria.

## [1.4.0] -- 2024-03-08

### Added

- A setting `verbose_entry_ids` that prefixes logged values with entry id tags.
- Log entries now generate anchors, HTML syntax: `<a id=ENTRY_ID></a>`
- Table of Contents, initial version (in the future this might be optionally a flame graph).

### Changed

- Fixes [#32](https://github.com/lukstafi/ppx_minidebug/issues/32): optionally output time spans instead of clock times.
- Breaking: renames `Debug_ch` to `Shared_config`.
- Breaking: replaces the `open_log_preamble_brief` and `open_log_preamble_full` with `open_log` and a setting `location_format`.
- Breaking: Adds `fname`, `start_lnum`, `entry_id` parameters to `close_log` to debug lexical-vs-dynamic scope mismatches and spurious closes.
- Adds `global_prefix` to the error message on `close_log` failure.
- Entry ids output with `~print_entry_ids:true` now link to the entry anchors.

## [1.3.0] -- 2024-02-28

### Added

- A new entry extension point prefix: `%diagn_` restricts the compile-time log level to `Prefixed [||]`, does not change tighter settings (`Nothing`, `Prefixed [|prefixes...|]`).
- `forget_printbox`
- `snapshot` in the PrintBox backend as in [#21](https://github.com/lukstafi/ppx_minidebug/issues/21).
- Optionally, `snapshot ()` at the end of a `log_value` call if elapsed time since last snapshot is greater than given threshold.
- A replacement `Minidebug_runtime.sexp_of_lazy_t` that does not force the thunk (but prints content if available).
- A new extension point `[%log_result]` to convey information in a header.
- A new extension point `[%log_printbox]` that directly embeds a `PrintBox.t` in the logs, instead of a representation of it. A corresponding `log_value_printbox` entry in `Minidebug_runtime.Debug_runtime`.
- A new registered extension point `[%%global_debug_log_level_from_env_var "env_var_name"]`.

### Changed

- Re-interpret `Prefixed [||]` and `Prefixed_or_result [||]` to mean "explicit logs only" -- originally (as logic indicates) it was equivalent to `Nothing`.
- Change runtime `Prefixed_or_result` to only output results if an entry would be non-empty without them.
- Breaking change: removed the `Pp_format` backend.
- More informative headers for tracking: e.g. anonymous functions logged with `fun:file_name:LNUM` instead of `__fun`.
- When printing sexps, don't escape strings for box-level atoms, print them directly. This can be disabled by setting `sexp_unescape_strings` to false.
- A more configurable `debug_flushing` builder.
- `max_inline_sexp_length` is now configurable via a `debug_file` call, and the default is bumped to 80.

### Fixed

- Be more defensive about not allowing multiline descriptions and messages.
- Don't output line breaks in time-tagged headers.
- Be more consistent about when entries are opened: open toplevel (extension-point) entries even if not binding anything; don't open nested entries when restricted to explicit logs.
- Nested structure items are not toplevel extension points (fix over-generating log entries e.g. for other ppx extensions).

## [1.2.1] -- 2024-02-15

### Added

- Optionally print `entry_id`s for log headers (and escaping logs).

### Fixed

- Do not crash when logging value with an empty entry stack; while unusual, "logs escaping lexical scope" are fine.

## [1.2.0] -- 2024-02-14

### Added

- Runtime log levels for the PrintBox backend.
- Compile-time log levels.

### Changed

- `%debug_` entry points log un-annotated functions but only the function the entry point is attached to.
- Added a default type `string` to `%log` expression decomposition, reducing the need for annotations.

### Fixed

- `_rt_` & `_rtb_` should work even when nested inside another debug scope.
  - Nested entry extension point is still considered toplevel.
- Tighter error locations for `%log` missing types or type errors.

## [1.1.0] -- 2024-02-11

### Added

- A shared runtime-wide setting `global_prefix` for prefixing log headers (and closing tags in the flushing backend), to disambiguate (or debug) interactions of different runtime instances.
- `_rt_` resp. `_rtb_` (e.g. `%track_rtb_sexp`) entry points to support runtime-passing, i.e. abstracting over a `Debug_runtime` resp. `PrintBox_runtime`.
- An extension point `%log` that is not registered -- therefore reducing interference with logger ppxs -- and does not open a new log subtree.
- Optionally indicate elapsed time in subtree headers in the PrintBox backend.

### Changed

- Removed the VS Code specific section of the README.
- Slightly breaking change: the `~descr` parameter of the logging functions in the runtimes is now optional.

### Fixed

- `log_value_pp` would raise a potentially uncaught or misleading exception, now marks a syntax error.
- Setting of the global `log_value` was not updated for nested extension points.

## [1.0.0] -- 2024-02-03

### Added

- PrintBox Markdown backend.
- Optionally, log to multiple files, opening a new file once a file size threshold is exceeded.
- Continuous Integration tests.
- Fixes #9: handle tuple and record patterns.
- Handle variants patterns, nested patterns, ... pretty much all patterns.
- Log bindings in `match` and `function` patterns, but only when in a `%track_` scope.
- Provide pattern text in addition to the branch number (counted from 0).
- Propagate type information top-down and merge different sources of type information.
- Optionally, log the type information found with extension points `%debug_type_info` and `%global_debug_type_info`.
- A PrintBox-backend option `truncate_children` to limit the amount of output.

### Changed

- Rename `debug_html` to `debug_file`, since it now supports both HTML and Markdown. Take file name/path without a suffix.
- Refactored PrintBox configuration, smaller footprint and allowing control over the backends.
- Changed `highlighted_roots` to a more general `prune_upto`: prune to only the highlighted boxes up to the given depth.
- Exported `PrintBox_runtime` configuration for better flexibility (in-flight configuration changes).
- Refactored the optional termination configuration `max_nesting_depth` and `max_num_children` into extension points `%debug_interrupts` and `%global_debug_interrupts`.

### Fixed

- In `values_first_mode`, be consistent about what counts as a returned value.
- Missing transformations for `%debug_notrace`, and generally for the root construct of a body of a non-logged binding.

## [0.9.0] -- 2024-01-18

### Added

- Optionally output source locations as hyperlinks -- requires a (potentially empty) address prefix.
- A setting `values_first_mode` for the PrintBox runtime, to put results of computation as headers, and push paths beneath headers (friendly for HTML-backed foldable output).

### Changed

- Include the variable name in the open-log line (just as function name for functions).
- Output the description of a for loop body as `<for [identifier]>` rather than just `[identifier]`.
- `Debug_runtime` functions now take an `~entry_id` parameter, set to a per-entry ID generated by `get_entry_id`.
- Small non-atomic sexp values can now be printed inline with the variable name (like sexp atoms) rather than spread out as trees.

## [0.8.0] -- 2024-01-16

### Added

- When in an active `%track_` scope:
  - Log `for` loop nesting and indices at the beginning of a loop body.
  - Log `while` loop nesting.
  - Log `function` branches (similar to `match` branches).
  - Log all functions. Doing it only for `%track_` to reduce noise.
    - This will log type-annotated arguments of anonymous functions (even when the function result type is not annotated).

## [0.7.0] -- 2023-12-31

### Added

- A new optional PrintBox-only setting `highlight_terms`, which applies a frame / border on paths to leaves matching a regular expression.
  - A corresponding setting `exclude_on_path` -- if this regular expression matches on a log, its children have no effect on its highlight status. I.e., `exclude_on_path` stops the continued propagation of highlights.
  - A flag `highlighted_roots` prevents outputting toplevel boxes that have not been highlighted.
- A set of extension points `%track_sexp`, `%track_pp` etc. that parallel `%debug_sexp`, `%debug_pp` etc. but additionally log which `if` and `match` branch got executed.
  - An extension point `%debug_notrace` that turns off logging the branch of the specific `if` or `match` expression. It is ignored by the `%debug_` extension points.

### Fixed

- Issue [#8](https://github.com/lukstafi/ppx_minidebug/issues/8): ignore nested debug scope indications (don't re-process them).

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
