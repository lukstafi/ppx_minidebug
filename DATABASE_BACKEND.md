# Database Backend for ppx_minidebug

This document describes the database-backed tracing system implemented in Phase 1 of the migration from static HTML/Markdown artifacts to a database-backed approach with interactive GUI client.

## Overview

The database backend (`minidebug_db.ml`) provides:
- SQLite-based trace storage with content-addressed deduplication
- Automatic value interning for space efficiency
- Same Debug_runtime interface as existing backends
- Schema designed for future GUI client integration

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

This creates a database file `trace.db` with all trace information.

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

**entries** - Trace entries (composite key allows multiple values per scope)
- `run_id`: Foreign key to runs table
- `entry_id`: Entry identifier (unique within run for scopes)
- `seq_num`: Sequence number discriminating row type:
  - `0` = scope entry (function/let binding created by `open_log`)
  - `1, 2, 3...` = parameter values (created by `log_value_*`)
  - `-1` = result value (created by `log_value_*` with `is_result=true`)
- `parent_id`: Parent entry ID (NULL for top-level, self for values)
- `depth`: Nesting depth (scope depth + 1 for values)
- `message_value_id`: Foreign key to value_atoms (function name or parameter name)
- `location_value_id`: Foreign key to value_atoms (source location, only for seq_num=0)
- `data_value_id`: Foreign key to value_atoms (logged value, only for seq_num!=0)
- `structure_value_id`: Foreign key to value_atoms (sexp structure, future use)
- `elapsed_start_ns`: Entry start time in nanoseconds
- `elapsed_end_ns`: Entry end time in nanoseconds (NULL until close_log, only for seq_num=0)
- `is_result`: Boolean indicating if this is a result value
- `log_level`: Log level of the entry
- `entry_type`: Entry type (diagn, debug, track for scopes; "value" for logged values)

**Primary Key:** `(run_id, entry_id, seq_num)` allows multiple rows per logical entry.

**Example:** For `let%debug_sexp foo (x : int) (y : int) : int list = [x; y; 2*y]` called as `foo 7 8`:

| run_id | entry_id | seq_num | message | location | data | is_result |
|--------|----------|---------|---------|----------|------|-----------|
| 1 | 42 | 0 | "foo" | "test.ml:10:15" | NULL | false |
| 1 | 42 | 1 | "x" | NULL | "7" | false |
| 1 | 42 | 2 | "y" | NULL | "8" | false |
| 1 | 42 | -1 | "" | NULL | "(7 8 16)" | true |

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
- `idx_entries_parent`: Index on `entries(run_id, parent_id)` for tree traversal
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

# Search for entries matching pattern
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

### Query Performance

- O(1) value lookup via hash index
- O(log n) tree traversal via parent_id index
- WAL mode enabled for concurrent access
- NORMAL synchronous mode for speed

## Next Steps (Phase 2+)

1. **Sexp Structure Decomposition**: Store JSON structure in `structure_value_id` for navigable large sexps
2. **GUI Server**: REST API for pagination, search, lazy loading
3. **GUI Client**: React/TypeScript client with tree visualization
4. **Cross-Run State**: PrevRun diff integration for state persistence
5. **Advanced Deduplication**: Template-based structural sharing for repeated record shapes

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
