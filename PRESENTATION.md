# ppx_minidebug 3.0: Database-Backed Tracing with Interactive TUI {#title}

<style>
  #slipshow-content {
    font-size: 1.2em;
  }
</style>

{pause}

## What is ppx_minidebug? {#what-is}

{.definition title="ppx_minidebug"}
OCaml PPX extension for **automatic debug logging** with **zero manual instrumentation**.

{pause}

```ocaml
let%debug_sexp rec fib (n : int) : int =
  if n <= 1 then n else fib (n - 1) + fib (n - 2)
```

{pause up=what-is}

> Automatically logs:
> - Function arguments
> - Let-binding values
> - Return values
> - Execution flow

***

{pause center=new-in-3}

## What's New in 3.0 🚀 {#new-in-3}

{.block title="Database-Backed Tracing + Interactive TUI"}
> **SQLite storage** with content-addressed deduplication
>
> **Terminal UI** for interactive trace exploration
>
> **CLI tool** for querying and analysis

{pause up}
### Architecture Highlights

> **Schema Design**:
> ```sql
> -- Content-addressed value storage (deduplication)
> CREATE TABLE value_atoms (
>   value_id INTEGER PRIMARY KEY,
>   value_hash TEXT UNIQUE,        -- MD5 for O(1) dedup
>   value_content TEXT,
>   value_type TEXT
> );
> ```

{pause up}
```sql
-- Tree structure: scope parent relationships
CREATE TABLE entry_parents (
  run_id INTEGER NOT NULL,
  -- Scope ID:
  entry_id INTEGER NOT NULL,
  -- Parent scope (NULL for roots)
  parent_id INTEGER,
  PRIMARY KEY (run_id, entry_id)
);
```

{pause up}
```sql
-- Trace entries:
-- composite key (run_id, entry_id, seq_id)
CREATE TABLE entries (
  run_id INTEGER NOT NULL,
  -- Groups all rows for this scope
  entry_id INTEGER NOT NULL,
  -- Position in parent (0, 1, 2...)
  seq_id INTEGER NOT NULL,
  -- NULL for values; child scope for headers
  header_entry_id INTEGER,
  depth INTEGER,
  message_value_id INTEGER,  -- FK to value_atoms
  data_value_id INTEGER,     -- FK to value_atoms
  elapsed_start_ns INTEGER,
  elapsed_end_ns INTEGER,
  PRIMARY KEY (run_id, entry_id, seq_id)
);
```

***

{pause up}
## Usage (Simple!) {#usage}

```ocaml
open Sexplib0.Sexp_conv

(* Setup once *)
let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "trace" in
  fun () -> rt

(* Use anywhere *)
let%debug_sexp process (data : t) : R.t =
  (* your code here *)

let () =
  let result = process my_data in
  (* optional *)
  Debug_runtime.finish_and_cleanup ()
```

{pause}

**Output**: `trace.db` SQLite database

***

{pause center=tui}

## Interactive Exploration {#tui}

### Launch TUI
```bash
minidebug_view trace.db tui
```

{pause down}
> **Features**:
>
> `↑/↓` or `k/j`: Navigate tree
>
> `Enter`: Expand/collapse nodes
>
> `t`: Toggle timing display
>
> `v`: Toggle values-first mode
>
> `q`: Quit

{pause center}
> **Why TUI?**
>
> Works over SSH (no X forwarding)
>
> Zero dependencies (no Node.js, browsers)
>
> Instant startup (< 50ms)
>
> Keyboard-optimized workflow
>
> Single binary

{pause up}
### CLI Commands {#cli}
```bash
# List all runs
minidebug_view trace.db list

# Show full trace
minidebug_view trace.db show --times

# Fast summary (large DBs)
minidebug_view trace.db roots --with-values

# Regex search
minidebug_view trace.db search "fib"

# Database stats
minidebug_view trace.db stats
```

***

{pause up}
## Roadmap {#roadmap}

{.block title="Version 3.0 (Current Release)" #v3-0}
> ✅ Database backend with deduplication
>
> ✅ SQLite storage with indexes
>
> ✅ All PPX extensions supported
>
> ✅ Path filtering, log levels
>
> ✅ CLI tool with multiple commands
>
> ✅ **Interactive TUI** for trace exploration
>
> ✅ **Sexp decomposition** (large sexps broken into navigable subtrees)
>
> 🔜 Regex search in TUI with highlighting (TODO)

{pause down .block title="Version 3.1 (Next - ~6 weeks)"}
> 📅 Cross-run diff visualization (available in 2.x)
>
> 📅 State persistence (remember expanded nodes)
>
> 📅 Bookmarks and navigation history
>
> 📅 Export filtered views to files

{pause down .block title="Version 3.2 (Future - ~12 weeks)"}
> 📅 Advanced deduplication (structural templates)
>
> 📅 Flame graphs (static single-page available in 2.x)

***

{pause down .remark title="OCaml 4 -> 2.2.x"}
**For users needing OCaml 4**: Use 2.2.x branch (maintained for bug fixes)

***

{pause up}
## Why OCamlers Should Try This

### Compared to Printf Debugging
```ocaml
(* Before: Manual prints everywhere *)
let process data =
  Printf.eprintf "process: data=%s\n%!" (show_data data);
  let result = compute data in
  Printf.eprintf "process: result=%s\n%!" (show_result result);
  result
```

{pause}

```ocaml
(* After: Add %debug_sexp and type annotations *)
let%debug_sexp process (data : data) : result =
  let not_logged = prepare data in
  let x : intermediate = compute not_logged in
  postprocess x
```

{pause}

**Advantage**: Less manual work, automatic tree structure, no cleanup needed

{pause down=vs-ocamldebug}

### Compared to ocamldebug

{.block #vs-ocamldebug}
> **No recompilation**: Works with existing bytecode/native
>
> **Production-safe**: Enable/disable at runtime via log levels
>
> **Asynchronous code**: Traces work even with Lwt/Async (no stepping)
>
> **Complex data**: Automatic sexp serialization of any type

{pause down=vs-landmarks}

### Compared to Landmarks/Statmemprof

{.block #vs-landmarks}
> **Full execution trace**: Not just hotspots, but complete flow
>
> **Data values**: See actual data, not just function names
>
> **Interactive exploration**: TUI for drilling down into specific calls
>
> **Zero configuration**: No need to annotate call sites

{pause down=for-dev}

### For Development

{.block #for-dev}
> **Fast debugging**: See complete execution flow without manual prints
>
> **Type-safe**: Uses ppx_sexp_conv, show, or pp - picks the right one
>
> **Minimal overhead**: Lazy evaluation, optional compilation (`[%%global_debug_log_level 0]`)
>
> **Interactive exploration**: TUI beats scrolling through text files

{pause down=for-prod}

### For Production

{.block #for-prod}
> **Crash-safe**: WAL mode, instant writes (no buffering)
>
> **Space efficient**: 60-80% deduplication on real workloads
>
> **Queryable**: SQL analysis of execution patterns
>
> **Conditional**: Path filters and log levels for targeted tracing
>
> **Thread-safe**: Multiple threads can write to same database

{pause down=analys}

### For Analysis

{.block #analys}
> **SQL queries**: Find hot paths, analyze value distributions
>
> **Performance profiling**: Elapsed time per entry with nanosecond precision
>
> **Regression detection**: Compare runs with diffs (coming in 3.1)
>
> **Post-mortem**: Trace persists after crash, query with standard tools

***

{pause up}
## Quick Start (60 seconds) {#quick-start}

```bash
# 1. Install (one command) -- for 3.0
opam pin ppx_minidebug https://github.com/lukstafi/ppx_minidebug.git
```

{pause}

```bash
# 2. Add to dune file
(executable
 (name my_program)
 (preprocess (pps ppx_minidebug ppx_sexp_conv))
 (libraries ppx_minidebug.db sexplib0))
```

{pause}

```ocaml
# 3. Add to your code
let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "trace" in
  fun () -> rt

let%debug_sexp my_function (x : t) : R.t =
  (* your code *)
```

{pause down}
```bash
# 4. Run and explore
./my_program.exe
minidebug_view trace.db tui
```

{pause down}
That's it! No configuration files, no build system changes, just works.

***

{pause center}
## Installation {#install}

```bash
# Current stable (static generation - 2.x)
opam install ppx_minidebug

# Latest with database backend + TUI (3.0)
opam pin ppx_minidebug https://github.com/lukstafi/ppx_minidebug.git
```

{pause}

**Dependencies**: `sqlite3`, `notty` (automatically installed)

***

{pause up}
## Key Takeaways {#takeaways}

{.block title="Key Takeaways"}
> ✓ **Zero-effort debugging**: PPX handles all instrumentation
>
> ✓ **Space efficient**: 60-80% deduplication on real traces
>
> ✓ **Interactive TUI**: Terminal-native exploration (works over SSH!)
>
> ✓ **Modern architecture**: Database + TUI > static files
>
> ✓ **Production ready**: 3.0 stable, tested, documented
>
> ✓ **Simple design**: TUI in ~200 lines, not 3000+ for web GUI

***

{pause down=resources}

## Links

{.block title="Resources" #resources}
> **Repo**: https://github.com/lukstafi/ppx_minidebug
>
> **Docs**: https://lukstafi.github.io/ppx_minidebug/ppx_minidebug
>
> **Design Doc**: [DESIGN.md](./DESIGN.md) - TUI architecture explained
>
> **Migration Guide**: [MIGRATION_3.0.md](./MIGRATION_3.0.md)

{pause down=quest}

## Questions?

{.block title="Discussion Topics" #quest}
> - Use cases in your codebase?
> - Specific query patterns needed?
> - TUI workflow feedback?
> - Integration with existing tools?
