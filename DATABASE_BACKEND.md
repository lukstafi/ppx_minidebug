# Database Backend for ppx_minidebug

This document describes the database-backed tracing system implemented in Phase 1 of the migration from static HTML/Markdown artifacts to a database-backed approach with interactive GUI client.

## Overview

The database backend (`minidebug_db.ml`) provides:
- SQLite-based trace storage with content-addressed deduplication
- Automatic value interning for space efficiency
- Same Debug_runtime interface as existing backends
- Fast mode: top-level transactions for ~100x write performance improvement
- File versioning: each runtime instance gets unique database file
- Schema designed for interactive TUI and future GUI client integration

## Usage

### Basic Setup

```ocaml
open Sexplib0.Sexp_conv

(* Setup database runtime *)
let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file ~print_entry_ids:true "trace" in
  fun () -> rt

(* Instrument functions *)
let%debug_o_sexp rec fib (n : int) : int =
  if n <= 1 then n
  else fib (n - 1) + fib (n - 2)

let () =
  let result = fib 5 in
  Printf.printf "fib(5) = %d\n" result;
  Debug_runtime.finish_and_cleanup ()
```

This creates versioned database files with automatic file management:
- First runtime instance: `trace_1.db`
- Second runtime instance: `trace_2.db`
- Symlink `trace.db` → latest versioned file

This prevents conflicts when multiple runtime instances exist in the same process.

**Note on `finish_and_cleanup()`:** This call is optional in Fast mode. The database backend registers `at_exit` handlers and signal handlers (SIGINT, SIGTERM) to automatically commit any pending transaction before process termination. However, calling `finish_and_cleanup()` explicitly ensures the database is committed immediately and is recommended for long-running processes.

### Factory Functions

```ocaml
(* File-based database runtime *)
val debug_db_file :
  ?time_tagged:time_tagged ->
  ?elapsed_times:elapsed_times ->
  ?location_format:location_format ->
  ?print_entry_ids:bool ->
  ?verbose_entry_ids:bool ->
  ?global_prefix:string ->
  ?for_append:bool ->
  ?log_level:int ->
  ?path_filter:[ `Whitelist of Re.re | `Blacklist of Re.re ] ->
  string ->
  (module Debug_runtime)

(* Default database runtime (creates "debug.db") *)
val debug_db :
  ?debug_ch:out_channel ->
  ?time_tagged:time_tagged ->
  ?elapsed_times:elapsed_times ->
  ?location_format:location_format ->
  ?print_entry_ids:bool ->
  ?verbose_entry_ids:bool ->
  ?global_prefix:string ->
  ?log_level:int ->
  ?path_filter:[ `Whitelist of Re.re | `Blacklist of Re.re ] ->
  unit ->
  (module Debug_runtime)
```

## Database Schema

### Tables

**runs** - Trace run metadata
- `run_id`: Unique run identifier (primary key)
- `timestamp`: Run start timestamp
- `elapsed_ns`: Elapsed nanoseconds at run start
- `command_line`: Command line that started the run

**value_atoms** - Content-addressed value storage
- `value_id`: Unique value identifier (primary key)
- `value_hash`: MD5 hash of value content (unique index)
- `value_content`: Actual value content (TEXT)
- `value_type`: Type of value (message, location, value, result)
- `size_bytes`: Size of value in bytes

**entry_parents** - Entry parent relationships
- `run_id`: Foreign key to runs table
- `entry_id`: Entry identifier (unique within run)
- `parent_id`: Parent entry ID (NULL for top-level entries)

**Primary Key:** `(run_id, entry_id)` ensures one parent per entry.

**entries** - Trace entries (composite key allows chronological ordering of children)
- `run_id`: Foreign key to runs table
- `entry_id`: Parent scope ID (all children of a scope share the same entry_id)
- `seq_id`: Chronological position within parent's children
  - `seq_id >= 0`: Regular entries (0, 1, 2...) created by `log_value_*` and `open_log`
  - `seq_id < 0`: Synthetic entries created by `boxify` during sexp decomposition
- `header_entry_id`: Discriminates row type:
  - `NULL` = value row (parameter or result)
  - Non-NULL = header row opening a new scope (points to new scope's entry_id)
- `depth`: Nesting depth
- `message_value_id`: Foreign key to value_atoms (function name or parameter name)
- `location_value_id`: Foreign key to value_atoms (source location, only for headers)
- `data_value_id`: Foreign key to value_atoms (logged value, only for values)
- `structure_value_id`: Foreign key to value_atoms (sexp structure, future use)
- `elapsed_start_ns`: Entry start time in nanoseconds
- `elapsed_end_ns`: Entry end time in nanoseconds (NULL until close_log, only for headers)
- `is_result`: Boolean indicating if this is a result value
- `log_level`: Log level of the entry
- `entry_type`: Entry type (diagn, debug, track for headers; "value" for values)

**Primary Key:** `(run_id, entry_id, seq_id)` provides unique position for each child.

**Example:** For `let%debug_sexp foo (x : int) (y : int) : int list = [x; y; 2*y]` with entry_id=42, nested in scope 10:

entry_parents table:
| run_id | entry_id | parent_id |
|--------|----------|-----------|
| 1 | 42 | 10 |

entries table:
| run_id | entry_id | seq_id | header_entry_id | message | location | data | is_result |
|--------|----------|--------|-----------------|---------|----------|------|-----------|
| 1 | 10 | 5 | 42 | "foo" | "test.ml:10:15" | NULL | false |
| 1 | 42 | 0 | NULL | "x" | NULL | "7" | false |
| 1 | 42 | 1 | NULL | "y" | NULL | "8" | false |
| 1 | 42 | 2 | NULL | "" | NULL | "(7 8 16)" | true |

Rendered as:
```
[debug] foo @ test.ml:10:15
  x = 7
  y = 8
  => (7 8 16)
```

**schema_version** - Schema version tracking
- `version`: Current schema version

### Indexes

- `idx_value_hash`: Hash index on `value_atoms(value_hash)` for O(1) deduplication
- `idx_entries_header`: Index on `entries(run_id, header_entry_id)` for finding scope headers
- `idx_entries_depth`: Index on `entries(run_id, depth)` for depth queries

## Deduplication Strategy

The database backend uses content-addressed storage to deduplicate values:

1. **Hash-based interning**: Values are hashed (MD5) before storage
2. **Lookup before insert**: Check if hash exists before inserting new value
3. **Reference counting**: Multiple entries reference the same value_id
4. **All value types deduplicated**: Messages, locations, and logged values are all interned

### Example Deduplication

For Fibonacci sequence:
- Value `1` appears many times → stored once, referenced multiple times
- Location `test.ml:10:15-12:20` → stored once for all calls from that location
- Message `fib` → stored once for all recursive calls

## Large Value Decomposition (Boxify)

When a sexp value exceeds a threshold size (default: 10 atoms), the database backend automatically decomposes it into multiple entries for better navigation:

**Indentation-based parsing:**
- Multi-line pretty-printed sexps are parsed by indentation
- Each indented level becomes a separate scope with nested structure
- Values at the same indentation level are siblings

**Synthetic entries:**
- Boxified entries use negative `entry_id` values (e.g., -1, -2, -3, ...)
- Regular logged entries use positive `entry_id` values (1, 2, 3, ...)
- Both positive and negative entries can have positive or negative `seq_id` values
- Each decomposed scope gets a unique synthetic `entry_id` from a negative counter
- Synthetic entries properly nest to preserve structure

**Benefits:**
- Large data structures remain navigable in the TUI
- Tree structure matches visual indentation
- Each level can be expanded/collapsed independently
- Preserves all structural information from original sexp

## Viewing Traces

### Using the minidebug_view CLI Tool

ppx_minidebug 3.0.0 includes an in-process client for viewing database traces:

```bash
# Show statistics
minidebug_view trace.db stats

# Show latest trace with entry IDs and times
minidebug_view trace.db show --entry-ids --times

# Show compact view (function names only)
minidebug_view trace.db compact

# Launch interactive TUI (Text User Interface)
minidebug_view trace.db tui

# Search for entries matching pattern (CLI)
minidebug_view trace.db search "fib"

# Export to markdown
minidebug_view trace.db export output.md

# Show specific run
minidebug_view trace.db show --run=1 --max-depth=3
```

**Example output** (compact view):
```
fib <3.79ms>
  a <2.46ms>
    fib <1.64ms>
      a <1.02ms>
        fib <943.04μs>
  b <888.42μs>
    fib <810.00μs>
calculate <471.58μs>
  sum <133.58μs>
  product <139.79μs>
```

### Interactive TUI Features

The TUI mode provides an interactive terminal interface with:

**Navigation:**
- Arrow keys / j/k: Move up/down through entries
- PageUp/PageDown: Jump by screen height
- Space: Toggle expand/collapse for current entry
- Home/End: Jump to first/last entry

**Search:**
- `/`: Enter search mode (supports 4 concurrent searches: S1, S2, S3, S4)
- Type pattern and press Enter to search
- `n`: Jump to next search result
- `N`: Jump to previous search result
- `Q`: Set quiet path filter (stops highlight propagation at matching ancestors)
- `o`: Toggle search ordering (Ascending/Descending entry_id)
- Search runs concurrently in background Domain
- Matched entries highlighted with full ancestor path to root
- Auto-expand entries to show search results
- Incremental highlighting (results appear as search progresses)

**Search Features:**
- **Multi-slot search**: 4 concurrent search slots (S1-S4) with different highlight colors
- **Quiet path filtering**: Stop ancestor highlighting at paths matching regex
- **Eager scope fetching**: On-demand database queries for ancestor entries
- **Search ordering**: Choose ASC (newest-neg → oldest-neg → oldest-pos → newest-pos) or DESC
- **In-memory results**: Search results stored in memory (not persisted to database)

**Display:**
- Entry IDs shown in left margin for reference
- Elapsed times displayed when available
- Progress indicator for ongoing searches
- Search order shown in header ("Search: Asc" or "Search: Desc")

### Direct SQL Queries

You can also query the database directly with sqlite3:

#### View All Runs

```sql
SELECT run_id, timestamp, command_line FROM runs;
```

#### View Top-Level Entries

```sql
SELECT
  e.entry_id,
  v.value_content as message,
  l.value_content as location
FROM entries e
JOIN value_atoms v ON e.message_value_id = v.value_id
JOIN value_atoms l ON e.location_value_id = l.value_id
WHERE e.run_id = 1 AND e.depth = 0
ORDER BY e.entry_id;
```

### View Entry Tree

```sql
-- Get an entry with its value
SELECT
  e.entry_id,
  e.parent_id,
  e.depth,
  m.value_content as message,
  d.value_content as data,
  e.elapsed_start_ns,
  e.elapsed_end_ns
FROM entries e
JOIN value_atoms m ON e.message_value_id = m.value_id
LEFT JOIN value_atoms d ON e.data_value_id = d.value_id
WHERE e.run_id = 1
ORDER BY e.entry_id;
```

### Check Deduplication Efficiency

```sql
-- Total values vs unique values
SELECT
  COUNT(*) as total_value_references,
  (SELECT COUNT(DISTINCT value_hash) FROM value_atoms) as unique_values
FROM value_atoms;

-- Most deduplicated values
SELECT
  value_content,
  COUNT(*) as usage_count
FROM value_atoms
WHERE value_type IN ('value', 'result')
GROUP BY value_content
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 10;
```

## Performance Characteristics

### Space Efficiency

For the test case (fib 5 + calculate + process_list):
- **33 entries** total
- **15 unique values** (100% deduplication efficiency)
- **44 KB** database size (includes SQLite overhead)

For real-world OCANNL traces (471 MB HTML):
- Projected: 60-100 MB database (87-92% reduction)
- Lazy thunks: 99.6% deduplication rate (2.9M occurrences → 1 storage)
- Environment values: 99.7% deduplication rate

### Write Performance (Fast Mode)

ppx_minidebug 3.0+ uses optimized "Fast mode" for database writes:

**Configuration:**
- `journal_mode=DELETE`: Simpler than WAL, lower overhead
- `synchronous=OFF`: No fsync calls (trades durability for speed)
- `locking_mode=NORMAL`: Allows lock release on COMMIT

**Transaction Strategy:**
- `BEGIN TRANSACTION` when entering top-level scope (when stack is empty)
- `COMMIT` when leaving top-level scope (when stack becomes empty)
- Database unlocked between top-level function calls for concurrent access

**File Versioning:**
- Each runtime instance gets unique run number from global atomic counter
- Database files versioned: `debug.db` → `debug_1.db`, `debug_2.db`, etc.
- Symlink from base name to latest versioned file for convenience
- Prevents conflicts between multiple runtimes in same process

**Performance Impact:**
- ~100x faster than autocommit within each trace
- Single transaction per top-level function eliminates per-log fsync overhead
- Database accessible for reading between top-level function calls

**Safety:**
- `at_exit` handler ensures COMMIT on normal exit
- Signal handlers (SIGINT, SIGTERM) commit before process termination
- Each runtime instance writes to separate versioned file (no conflicts)

**Concurrent Access Model:**
- **During top-level trace**: Database locked (transaction in progress)
- **Between top-level traces**: Database unlocked and readable by other processes
- **TUI/query tools**: Can read database when not actively writing
- **Multiple runtimes**: Each writes to separate versioned file, no conflicts
- **Search operations**: Use in-memory hash tables (not persisted to database)
- **Eager ancestor fetching**: Search performs on-demand DB queries for ancestor scope entries

This allows the TUI to inspect traces between function calls while maintaining high write performance during tracing.

### Query Performance

- O(1) value lookup via hash index
- O(log n) tree traversal via parent_id index
- DELETE journal mode (fast, simple)
- NORMAL synchronous mode for speed

## Implemented Features (3.0+)

✅ **Database backend with content-addressed storage**
✅ **Fast mode with top-level transactions** (~100x write performance improvement)
✅ **File versioning for multi-runtime safety**
✅ **Interactive TUI** with navigation, search, expand/collapse
✅ **Multi-slot concurrent search** (4 slots) with background Domain and in-memory results
✅ **Incremental search highlighting** with eager ancestor fetching
✅ **Quiet path filtering** to stop highlight propagation at boundaries
✅ **Configurable search ordering** (Ascending/Descending entry_id)
✅ **Large value decomposition** (boxify with indentation-based parsing)
✅ **Automatic signal handling** for safe commits on interruption

## Next Steps (Phase 2+)

1. **Schema Cleanup**: Remove `run_id` from composite keys - file versioning makes it redundant
   - Currently: `(run_id, entry_id, seq_num)` primary key
   - After cleanup: `(entry_id, seq_num)` primary key
   - Rationale: Each runtime instance gets its own versioned database file, so all entries in a file belong to the same logical run. The `run_id` column is vestigial from the pre-versioning design.
2. **Enhanced Structure Storage**: Use `structure_value_id` for JSON-based structure metadata
3. **Advanced Deduplication**: Template-based structural sharing for repeated record shapes
4. **Cross-Run State**: PrevRun diff integration for state persistence
5. **Performance Metrics**: Query timing, cache hit rates, deduplication statistics
6. Optional **GUI Server and Client**: REST API for pagination, search, lazy loading; Web-based client with rich tree visualization

## Testing

Run the database backend test:

```bash
dune build test/test_db_backend.exe
dune exec test/test_db_backend.exe
```

Examine the database:

```bash
sqlite3 test_db.db
.tables
.schema entries
SELECT * FROM entries LIMIT 10;
```

## Migration from Existing Backends

To migrate from PrintBox or Flushing backend to database:

```diff
- module Debug_runtime = Minidebug_runtime.PrintBox ((val config))
+ module Debug_runtime = (val Minidebug_db.debug_db_file "trace")

- let _get_local_debug_runtime = fun () ->
-   (module Minidebug_runtime.PrintBox ((val config)) : Minidebug_runtime.Debug_runtime)
+ let _get_local_debug_runtime =
+   let rt = Minidebug_db.debug_db_file "trace" in
+   fun () -> rt
```

All PPX extensions (`%debug_sexp`, `%debug_show`, etc.) work unchanged.
