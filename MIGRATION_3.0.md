# Migration Guide: 2.4.x → 3.0.0

This guide helps you migrate from ppx_minidebug 2.4.x (static artifacts) to 3.0.0 (database-backed tracing).

## Overview of Changes

### What's New in 3.0.0
- ✅ **Database-backed tracing**: SQLite storage with content-addressed deduplication
- ✅ **Space efficiency**: 87-92% size reduction vs static HTML/Markdown
- ✅ **Interactive GUI** (coming in 3.1.0): Lazy loading, regex search, cross-run state
- ✅ **Better performance**: O(1) value deduplication, indexed queries
- ✅ **Crash-safe logging**: WAL mode for concurrent access

### What's Removed in 3.0.0
- ❌ **Flushing module**: Line-at-a-time text output
- ❌ **PrintBox module**: Static HTML/Markdown/Text generation
- ❌ **PrevRun module**: Static diff highlighting (reimplemented in GUI)
- ❌ **Factory functions**: `debug_file`, `debug_flushing`, `local_runtime` (PrintBox variants)
- ❌ **Static config**: `printbox_config`, flame graphs, ToC generation

### Migration Path
- **Option 1**: Migrate to database backend (recommended for new features)
- **Option 2**: Stay on 2.4.x branch (for static HTML/Markdown)

## Quick Migration Examples

### Before (2.4.x - PrintBox)

```ocaml
open Sexplib0.Sexp_conv

let () = Debug_runtime.config.values_first_mode <- false

let%debug_sexp rec fib (n : int) : int =
  if n <= 1 then n else fib (n - 1) + fib (n - 2)

let () =
  Printf.printf "fib(5) = %d\n" (fib 5)
```

### After (3.0.0 - Database)

```ocaml
open Sexplib0.Sexp_conv

(* Setup database runtime *)
let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file ~print_entry_ids:true "debug" in
  fun () -> rt

let%debug_sexp rec fib (n : int) : int =
  if n <= 1 then n else fib (n - 1) + fib (n - 2)

let () =
  Printf.printf "fib(5) = %d\n" (fib 5);
  Debug_runtime.finish_and_cleanup ()
```

**Output**: Creates `debug.db` SQLite database instead of `debug.log` file

## Detailed Migration Steps

### Step 1: Update Runtime Creation

#### 2.4.x PrintBox with HTML output
```ocaml
let module Debug_runtime = Minidebug_runtime.PrintBox (
  (val Minidebug_runtime.debug_file
    ~backend:(`Html Minidebug_runtime.default_html_config)
    "trace")
)
```

#### 3.0.0 Database equivalent
```ocaml
module Debug_runtime =
  (val Minidebug_db.debug_db_file "trace")
(* Creates trace.db *)
```

### Step 2: Update Local Runtime (for recursive functions)

#### 2.4.x
```ocaml
let _get_local_debug_runtime () =
  (module Minidebug_runtime.PrintBox (
    (val Minidebug_runtime.shared_config "trace.log")
  ) : Minidebug_runtime.Debug_runtime)
```

#### 3.0.0
```ocaml
let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "trace" in
  fun () -> rt
```

### Step 3: Update Thread-Local Runtimes

#### 2.4.x
```ocaml
let _get_local_debug_runtime =
  Minidebug_runtime.local_runtime
    ~backend:(`Html Minidebug_runtime.default_html_config)
    "thread_trace"
```

#### 3.0.0
```ocaml
(* Each thread needs its own database file *)
let _get_local_debug_runtime =
  let thread_id = Thread.id (Thread.self ()) in
  let filename = Printf.sprintf "thread_%d" thread_id in
  let rt = Minidebug_db.debug_db_file filename in
  fun () -> rt
```

### Step 4: Replace Configuration Options

| 2.4.x Option | 3.0.0 Equivalent | Notes |
|--------------|------------------|-------|
| `~backend:(`Html _)` | N/A | Database only |
| `~values_first_mode:true` | N/A | Controlled by GUI |
| `~highlight_terms:re` | N/A | GUI client feature |
| `~prev_run_file:"old.raw"` | N/A | GUI handles diffs |
| `~boxify_sexp_from_size:50` | N/A | Future: structure_value_id |
| `~print_entry_ids:true` | `~print_entry_ids:true` | ✅ Supported |
| `~log_level:5` | `~log_level:5` | ✅ Supported |
| `~path_filter:(`Whitelist re)` | `~path_filter:(`Whitelist re)` | ✅ Supported |
| `~elapsed_times:Milliseconds` | `~elapsed_times:Milliseconds` | ✅ Supported |

### Step 5: Update Cleanup Code

#### 2.4.x (PrintBox)
```ocaml
(* Automatic cleanup on program exit, or: *)
Debug_runtime.finish_and_cleanup ()
```

#### 3.0.0 (Database)
```ocaml
(* REQUIRED: Close database connection *)
Debug_runtime.finish_and_cleanup ()
```

**Important**: Database backend requires explicit cleanup to close the SQLite connection.

## Viewing Traces

### 2.4.x - Static Files
```bash
# Open HTML in browser
firefox debug.html

# View markdown
cat debug.md
```

### 3.0.0 - Database Queries

#### View all runs
```bash
sqlite3 debug.db "SELECT run_id, timestamp, command_line FROM runs;"
```

#### View top-level entries
```bash
sqlite3 debug.db "
SELECT
  e.entry_id,
  m.value_content as function_name,
  l.value_content as location
FROM entries e
JOIN value_atoms m ON e.message_value_id = m.value_id
JOIN value_atoms l ON e.location_value_id = l.value_id
WHERE e.run_id = 1 AND e.depth = 0
ORDER BY e.entry_id;"
```

#### View entry tree with values
```bash
sqlite3 debug.db -column "
SELECT
  e.entry_id,
  e.depth,
  m.value_content as message,
  COALESCE(d.value_content, '') as data
FROM entries e
JOIN value_atoms m ON e.message_value_id = m.value_id
LEFT JOIN value_atoms d ON e.data_value_id = d.value_id
WHERE e.run_id = 1
ORDER BY e.entry_id;"
```

#### Check deduplication stats
```bash
sqlite3 debug.db "
SELECT
  COUNT(*) as total_entries,
  (SELECT COUNT(*) FROM value_atoms) as total_value_storage,
  (SELECT COUNT(DISTINCT value_hash) FROM value_atoms) as unique_values
FROM entries;"
```

### 3.1.0+ - GUI Client (Coming Soon)
```bash
# Start GUI server
ppx_minidebug_gui debug.db

# Opens web browser with interactive trace viewer:
# - Lazy-loaded tree navigation
# - On-the-fly regex search
# - Cross-run state persistence
# - Diff highlighting
```

## Feature Mapping

### Static HTML Features → 3.0.0+ Equivalents

| 2.4.x Feature | 3.0.0 Status | Alternative |
|---------------|--------------|-------------|
| Collapsible HTML trees | ❌ Removed | ✅ GUI client (3.1.0+) |
| Flame graphs | ❌ Removed | ✅ GUI client (3.1.0+) |
| Table of Contents | ❌ Removed | ✅ GUI client (3.1.0+) |
| Diff highlighting | ❌ Removed | ✅ GUI client (3.1.0+) |
| Hyperlinks to code | ❌ Removed | ✅ GUI client (3.1.0+) |
| Search in browser | ❌ Removed | ✅ GUI client (3.1.0+) |
| Sexp decomposition | ⏳ Planned | Structure column (3.2.0) |
| Multi-file splitting | ❌ Removed | Multiple databases |
| Time-tagged logs | ✅ Kept | Stored in database |
| Entry IDs | ✅ Kept | Primary key in DB |
| Log levels | ✅ Kept | Stored per entry |
| Path filtering | ✅ Kept | Runtime filtering |

## Dependency Changes

### 2.4.x Dependencies
```ocaml
(libraries
  minidebug_runtime
  printbox
  printbox-html
  printbox-md
  sexplib0)
```

### 3.0.0 Dependencies
```ocaml
(libraries
  minidebug_db  (* New: includes sqlite3 *)
  sexplib0)     (* Only if using %debug_sexp *)
```

## Common Migration Issues

### Issue 1: "Unbound module Minidebug_runtime.PrintBox"

**Cause**: PrintBox module removed in 3.0.0

**Solution**: Replace with database backend
```ocaml
(* Old *)
module Debug_runtime = Minidebug_runtime.PrintBox ((val config))

(* New *)
module Debug_runtime = (val Minidebug_db.debug_db_file "debug")
```

### Issue 2: "values_first_mode not found"

**Cause**: PrintBox config removed

**Solution**: Remove configuration, will be in GUI
```ocaml
(* Old *)
Debug_runtime.config.values_first_mode <- true

(* New - remove this line, GUI will control display *)
```

### Issue 3: HTML files not generated

**Cause**: Database backend doesn't generate HTML

**Solution**:
- **Option A**: Use GUI client (3.1.0+)
- **Option B**: Stay on 2.4.x branch for HTML output

### Issue 4: Need static artifacts for CI/archival

**Recommendation**: Stay on 2.4.x-static-artifacts branch
```bash
git checkout 2.4.x-static-artifacts
```

The 2.4.x branch will receive:
- Bug fixes
- Security updates
- Potential feature backports (as 2.5.0, 2.6.0, etc.)

## Testing Your Migration

### Create a test file
```ocaml
(* test_migration.ml *)
open Sexplib0.Sexp_conv

module Debug_runtime =
  (val Minidebug_db.debug_db_file "test_migration")

let _get_local_debug_runtime =
  let rt = Minidebug_db.debug_db_file "test_migration" in
  fun () -> rt

let%debug_o_sexp test (x : int) : int = x * 2

let () =
  let result = test 21 in
  Printf.printf "Result: %d\n" result;
  Debug_runtime.finish_and_cleanup ()
```

### Build and run
```bash
dune build test_migration.exe
dune exec ./test_migration.exe
```

### Verify database
```bash
sqlite3 test_migration.db ".tables"
# Should show: entries, runs, schema_version, value_atoms

sqlite3 test_migration.db "SELECT COUNT(*) FROM entries;"
# Should show entry count
```

## Rollback Instructions

If migration causes issues:

### Temporary: Use 2.4.x branch
```bash
git checkout 2.4.x-static-artifacts
opam install .
```

### Permanent: Pin to 2.4.x
```bash
opam pin ppx_minidebug https://github.com/lukstafi/ppx_minidebug.git#2.4.x-static-artifacts
```

## Getting Help

- **Documentation**: See [DATABASE_BACKEND.md](./DATABASE_BACKEND.md)
- **Issues**: https://github.com/lukstafi/ppx_minidebug/issues
- **Examples**: See `test/test_db_backend.ml`

## Roadmap

- **3.0.0** (Current): Database backend, CLI tools
- **3.1.0**: GUI client with lazy loading, search
- **3.2.0**: Sexp structure decomposition, advanced deduplication
- **3.3.0**: Cross-run state persistence, diff visualization
- **2.5.0+** (Branch): Backport features to static artifacts branch
