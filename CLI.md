# ppx_minidebug CLI Documentation

## Overview

The `minidebug_view` CLI provides powerful tools for exploring and analyzing ppx_minidebug database traces. It supports both interactive TUI mode for human exploration and command-line mode with JSON output for programmatic access (e.g., by LLM agents or automation scripts).

**Key Features:**
- **Multiple output formats**: Human-readable text and machine-parseable JSON
- **Efficient search**: Context-aware search with ancestor propagation (inspired by TUI)
- **Multi-pattern search** ✅ (v3.1.0+): Find scopes matching ALL patterns with `search-intersection`
- **Pagination** ✅ (v3.1.0+): `--limit` and `--offset` for managing large result sets
- **Tree navigation**: Scope-based navigation for targeted exploration
- **Flexible filtering**: Quiet-path filtering to control context boundaries
- **Visual TUI enhancements** ✅ (v3.1.0+): Checkered highlighting for overlapping search matches
- **Export capabilities**: Markdown export for documentation

## Installation

The CLI is built as part of the ppx_minidebug project:

```bash
dune build
# The executable will be at: _build/default/bin/minidebug_view.exe
```

## Quick Start

```bash
# Show help
minidebug_view --help

# List all runs in a database
minidebug_view trace.db list

# Show latest trace with times
minidebug_view trace.db show --times

# Search with full context (great for LLM analysis)
minidebug_view trace.db search-tree "error" --format=json

# Multi-pattern search (NEW in v3.1.0+)
minidebug_view trace.db search-intersection "compute" "error" --format=json

# Pagination for large results (NEW in v3.1.0+)
minidebug_view trace.db search-tree "process" --limit=20 --offset=0

# Interactive TUI mode with visual search highlighting
minidebug_view trace.db interactive
```

## Command Reference

### Basic Commands

#### `list`
Lists all runs in the database with metadata.

```bash
minidebug_view trace.db list
```

**Output:**
```
Runs in trace.db:

Run #3 - 2025-10-29 07:41:33.707839 +01:00
  Command: ./my_program
  Elapsed: 8.64ms
...
```

#### `stats`
Shows database statistics including deduplication metrics.

```bash
minidebug_view trace.db stats
```

**Output:**
```
Database Statistics
===================
Total entries: 1523
Total value references: 2841
Unique values: 892
Deduplication: 68.6%
Database size: 245 KB
```

#### `show`
Displays the full trace tree for the latest run.

```bash
minidebug_view trace.db show [options]
```

**Options:**
- `--entry-ids`: Show scope IDs for each entry
- `--times`: Include elapsed times
- `--max-depth=<n>`: Limit tree depth
- `--values-first`: Show result values as headers (default mode)

**Example:**
```bash
minidebug_view trace.db show --times --max-depth=2
```

#### `compact`
Shows a compact trace with only function names (no values).

```bash
minidebug_view trace.db compact
```

#### `roots`
Efficiently shows only root-level entries (fast for large databases).

```bash
minidebug_view trace.db roots [--times] [--with-values]
```

**Options:**
- `--times`: Include elapsed times
- `--with-values`: Also show immediate children values

**Use Case:** Quickly see top-level function calls without loading entire tree.

### Search Commands

#### `search <pattern>`
Basic search matching entries by regex pattern.

```bash
minidebug_view trace.db search "error"
```

**Output:** Flat list of matching entries with their data.

**Limitation:** No tree context, just raw matches.

#### `search-tree <pattern>` 🌟
**Most powerful for debugging** - Shows matching entries with their full ancestor paths.

```bash
minidebug_view trace.db search-tree "error" [options]
```

**Options:**
- `--format=json`: Output as JSON (ideal for LLMs)
- `--times`: Include elapsed times
- `--max-depth=<n>`: Limit tree depth
- `--quiet-path=<pattern>`: Stop propagating context when this pattern matches
- `--limit=<n>`: Limit number of results (pagination)
- `--offset=<n>`: Skip first n results (pagination)

**How it works:**
1. Searches for all entries matching the pattern
2. Propagates highlights to ancestors (like TUI background search)
3. Builds tree containing all matches + their ancestor paths
4. Optionally stops propagation at "quiet path" boundaries

**Example - Find errors with context:**
```bash
minidebug_view trace.db search-tree "error" --format=json
```

**Example - Stop context at test boundaries:**
```bash
minidebug_view trace.db search-tree "error" --quiet-path="test_"
```

**Example - Pagination for large result sets:**
```bash
# Get first 10 results
minidebug_view trace.db search-tree "compute" --limit=10 --offset=0

# Get next 10 results
minidebug_view trace.db search-tree "compute" --limit=10 --offset=10
```

**Use Case:** Understanding where errors occur in the call hierarchy. LLMs can analyze the full context tree to understand root causes. Pagination helps manage large result sets.

**Output (text mode):**
```
Found 3 matching scopes for pattern 'error'

{#0} [debug] main @ src/main.ml:10:5-25:7
  {#5} [debug] process_data @ src/process.ml:42:12-48:3
    {#12} [debug] validate => Error "Invalid input" @ src/validate.ml:15:8-20:5
```

**Output (JSON mode):** Complete tree with all entry fields (scope_id, message, location, data, elapsed times, etc.)

#### `search-subtree <pattern>`
Shows only matching subtrees with non-matching branches pruned.

```bash
minidebug_view trace.db search-subtree "fib" [options]
```

**Options:** Same as `search-tree` (including `--limit` and `--offset` for pagination)

**Difference from `search-tree`:**
- `search-tree`: Shows **all ancestors** to root (full context paths)
- `search-subtree`: Shows **only matching nodes** and their descendants (minimal tree)

**Example:**
```bash
minidebug_view trace.db search-subtree "fib" --times
```

**Use Case:** Focus on matching code paths without seeing unrelated parent contexts. Good for analyzing recursive functions or deeply nested calls.

#### `search-at-depth <pattern> <depth>` 🌟
**Most useful for large traces** - Shows only unique entries at a specific depth on paths to matches.

```bash
minidebug_view trace.db search-at-depth "error" 4 [options]
```

**Options:**
- `--format=json`: Output as JSON
- `--times`: Include elapsed times
- `--quiet-path=<pattern>`: Stop propagating context when this pattern matches

**How it works:**
1. Runs search with ancestor propagation (like `search-tree`)
2. Filters results to only entries at specified depth
3. Deduplicates by scope_id to show unique entries only

**Example - Get high-level overview:**
```bash
minidebug_view trace.db search-at-depth "(id 79)" 1 --quiet-path="env" --times
# Result: 3 unique top-level operations
```

**Example - Mid-level summary:**
```bash
minidebug_view trace.db search-at-depth "(id 79)" 4 --quiet-path="env"
# Result: 3 unique scopes at depth 4
```

**Performance on large traces (1M+ entries):**
- `search-tree`: Returns 87 matching scopes (overwhelming output)
- `search-at-depth ... 4`: Returns 3 unique entries (perfect!)
- `search-at-depth ... 1`: Returns 3 top-level contexts

**Use Case:** When `search-tree` returns too many results (hundreds of matches), use `search-at-depth` to get a TUI-like hierarchical summary. Start at depth 1 for top-level overview, then drill down with `show-scope`.

**Typical Workflow:**
```bash
# 1. Get top-level contexts
minidebug_view trace.db search-at-depth "error" 1 --times

# 2. Get mid-level summary
minidebug_view trace.db search-at-depth "error" 4 --times

# 3. Drill into specific scope
minidebug_view trace.db show-scope 12345 --max-depth=2
```

**Key Insight:** Provides "progressive disclosure" - see summary first, then explore details. This is how the TUI works, now available in CLI!

#### `search-intersection <pat1> <pat2> [<pat3> ...]` ✅
**Multi-pattern search** - Finds the smallest subtrees containing ALL patterns (LCA-based AND logic).

```bash
minidebug_view trace.db search-intersection "(id 79)" "(id 1802)" [options]
```

**Options:**
- `--format=json`: Output as JSON (list of LCA scope entries)
- `--times`: Include elapsed times
- `--quiet-path=<pattern>`: Stop ancestor propagation at pattern (applies to all searches)
- `--limit=<n>`: Limit number of results
- `--offset=<n>`: Skip first n results

**How it works:**
1. Runs separate search with ancestor propagation for each pattern
2. Extracts actual matching scope IDs (not propagated ancestors) from each search
3. Computes **Lowest Common Ancestors (LCA)** for all combinations of matches (one match per pattern)
4. Returns unique LCAs as the **smallest subtrees** containing all patterns
5. For scopes in separate root-level trees, returns each root scope as a minimal subtree

**Algorithm:** Uses Cartesian product of match sets to find all combinations, then computes LCA for each. This identifies the minimal context where all patterns co-occur.

**Arguments:**
- Requires 2+ search patterns (no upper limit)
- All patterns must appear somewhere in the resulting subtrees

**Example - Find smallest contexts with multiple IDs:**
```bash
minidebug_view trace.db search-intersection "(id 79)" "(id 1802)"
# Finds minimal subtrees where both IDs interact
```

**Example - Complex filtering:**
```bash
minidebug_view trace.db search-intersection "compute" "error" "validation" --format=json
# Finds minimal contexts where all three patterns co-occur
```

**Output (text mode) - Compact display:**
```
Found 7 smallest subtrees containing all patterns ('(id 79)' AND '(id 1802)'):

Per-pattern match counts:
  '(id 79)': 87 scopes
  '(id 1802)': 129 scopes

Lowest Common Ancestor scopes (smallest subtrees):

  Scope 2093: binop [tensor/tensor.ml:444:22-454:14]
  Scope 2197: param [tensor/tensor.ml:587:22-605:48]
  Scope 56661: unop [tensor/tensor.ml:468:21-478:10]
  Scope 57280: binop [tensor/tensor.ml:444:22-454:14]
  Scope 57820: unop [tensor/tensor.ml:468:21-478:10]
  Scope 59564: binop [tensor/tensor.ml:444:22-454:14]
  Scope 60452: run_once [lib/train.ml:236:25-258:25]
```

**Output (JSON mode):** List of LCA scope entries with scope_id, message, and location.

**Use Case:**
- **Finding interactions**: "Where do these two IDs/functions/values interact?"
- **Root cause analysis**: "What's the minimal context that involves all these symptoms?"
- **Targeted debugging**: Identify precise scopes to investigate instead of searching through full trees
- **Relationship discovery**: Find common ancestors of multiple points of interest

**Comparison with other search commands:**
- `search-tree "pattern"`: Shows full trees with any match (OR logic)
- `search-intersection "pat1" "pat2"`: Shows minimal subtrees containing all patterns (LCA-based AND)
- `show-scope <id>`: Investigates a specific LCA result in detail
- Result: Much more targeted results when you know multiple things must co-occur

### Navigation Commands

#### `show-scope <id>`
Displays a specific scope and its immediate children.

```bash
minidebug_view trace.db show-scope 42 [options]
```

**Options:**
- `--format=json`: JSON output
- `--times`: Include elapsed times
- `--max-depth=<n>`: Show descendants N levels deep
- `--ancestors`: Show ancestor path instead of descendants

**Example - Show scope contents:**
```bash
minidebug_view trace.db show-scope 42 --depth=2 --format=json
```

**Example - Show path to scope:**
```bash
minidebug_view trace.db show-scope 42 --ancestors
```

**Use Case:** After finding an interesting scope ID (e.g., from search), drill down into its details or understand its context.

#### `show-entry <scope_id> <seq_id>`
Shows detailed information for a specific entry.

```bash
minidebug_view trace.db show-entry 5 1 [--format=json]
```

**Output (text):**
```
Entry (5, 1):
  Type: debug
  Message: compute
  Location: src/compute.ml:42:8-50:3
  Data: (input: 42, multiplier: 3)
  Child Scope ID: 6
  Depth: 2
  Log Level: 1
  Is Result: false
  Elapsed: 125.3μs
```

**Output (JSON):** Complete entry object with all fields.

**Use Case:** Inspect exact details of an entry identified by coordinates.

#### `get-ancestors <id>`
Returns list of scope IDs from root to target.

```bash
minidebug_view trace.db get-ancestors 100
```

**Output (text):** `Ancestors of scope 100: [ 100 -> 42 -> 5 -> 0 ]`

**Output (JSON):** `[ 100, 42, 5, 0 ]`

**Use Case:** Trace the call chain to understand how execution reached this scope.

#### `get-parent <id>`
Gets the immediate parent scope ID.

```bash
minidebug_view trace.db get-parent 100
```

**Output (text):** `Parent of scope 100: 42`

**Output (JSON):** `42`

**Use Case:** Navigate up one level in the call tree.

#### `get-children <id>`
Lists immediate child scope IDs.

```bash
minidebug_view trace.db get-children 42
```

**Output (text):** `Child scopes of 42: [ 85, 91, 100 ]`

**Output (JSON):** `[ 85, 91, 100 ]`

**Note:** May include negative scope IDs (from `boxify` decomposition of complex values).

**Use Case:** Explore what sub-calls or value decompositions exist within a scope.

### Export & Interactive

#### `export <file>`
Exports the latest trace to a Markdown file.

```bash
minidebug_view trace.db export output.md
```

**Use Case:** Generate human-readable documentation of trace execution.

#### `interactive` (alias: `tui`)
Launches the interactive TUI for exploring the trace.

```bash
minidebug_view trace.db interactive
```

**TUI Controls:**
- `↑/↓` or `k/j`: Navigate
- `Enter` or `Space`: Expand/collapse
- `/`: Search (up to 4 concurrent searches in slots)
- `Q`: Set quiet path filter
- `n/N`: Next/previous match
- `t`: Toggle times
- `v`: Toggle values-first mode
- `q` or `Esc`: Quit

**Search Highlighting (v3.1.0+):**
- **Single match**: Entry highlighted with one color (green/cyan/magenta/yellow for slots 1-4)
- **Multiple matches**: Checkered pattern with alternating color segments
  - 2 matches: Text split into 4 segments alternating between the two colors
  - 3 matches: Text split into 6 segments cycling through all three colors
  - 4 matches: Text split into 8 segments cycling through all four colors
- Makes it visually obvious when multiple search patterns match the same scope
- Useful for finding interactions between multiple concepts in the trace

**Example:** If you search for both "compute" and "validation", entries matching both will display with alternating green-cyan-green-cyan segments, immediately showing where both concepts intersect.

**Use Case:** Interactive exploration when you don't know exactly what you're looking for. The multi-pattern highlighting helps identify complex interactions visually.

## Global Options

These options work with multiple commands:

- `--format=<fmt>`: Output format (`text` or `json`)
- `--times`: Include elapsed time information
- `--max-depth=<n>`: Limit tree depth (avoids overwhelming output)
- `--entry-ids`: Show scope IDs in output
- `--values-first`: Result values become headers (cleaner output)

## LLM / Automation Use Cases

### Finding Error Root Causes

```bash
# Get full context tree of all errors
minidebug_view trace.db search-tree "Error\|Exception" --format=json > errors.json

# LLM can analyze the tree to find:
# - Which top-level functions led to errors
# - Parameter values that caused failures
# - Call chain leading to exception
```

### Performance Analysis

```bash
# Find slow operations with context
minidebug_view trace.db search-tree "timeout\|slow" --times --format=json

# LLM can identify:
# - Which code paths are slow
# - Parent contexts of slow operations
# - Cumulative times in call chains
```

### Code Understanding

```bash
# Get scope hierarchy for specific function
minidebug_view trace.db search-tree "compute" --format=json

# Then drill down with navigation:
minidebug_view trace.db show-scope 42 --format=json
minidebug_view trace.db get-children 42 --format=json
```

### Targeted Debugging

```bash
# Find matches but stop at test boundaries
minidebug_view trace.db search-tree "database_error" --quiet-path="test_"

# This shows real application errors without test framework noise
```

## Implementation Architecture

### File Structure

```
ppx_minidebug/
├── minidebug_client.ml     # Client library (query + rendering)
├── minidebug_client.mli    # Public interface
└── bin/
    ├── minidebug_view.ml   # CLI entry point
    └── dune                # Build configuration
```

### Module Organization

#### `minidebug_client.ml` - Core Library

**Module: `Query`**
- **Purpose:** Database access layer
- **Key Functions:**
  - `get_entries()`: Fetch all entries from database
  - `get_root_entries()`: Efficient root-only query
  - `get_scope_children()`: Get immediate children of a scope
  - `get_parent_id()`: Get parent scope
  - `get_ancestors()`: Recursive ancestor collection
  - `search_entries()`: Regex-based search
  - `populate_search_results()`: TUI-style search with ancestor propagation
  - `get_runs()`: Metadata about trace runs
  - `get_stats()`: Database statistics

**Module: `Renderer`**
- **Purpose:** Tree rendering in text and JSON formats
- **Key Functions:**
  - `build_tree()`: Construct tree structure from flat entry list
  - `render_tree()`: Human-readable text output
  - `render_compact()`: Function names only
  - `render_roots()`: Root entries as flat list
  - `render_tree_json()`: JSON tree output
  - `render_entries_json()`: JSON array of entries
  - `entry_to_json()`: JSON object for single entry

**Module: `Interactive`**
- **Purpose:** Notty-based TUI
- **Implementation:** See TUI section below (not covered in detail here)

**Module: `Client`**
- **Purpose:** High-level API wrapping Query and Renderer
- **Design Pattern:** Client object holds database connection and path
- **Key Functions:**
  - Basic: `show_trace()`, `show_compact_trace()`, `show_roots()`
  - Search: `search()`, `search_tree()`, `search_subtree()`
  - Navigation: `show_scope()`, `show_entry()`, `get_ancestors()`, `get_parent()`, `get_children()`
  - Export: `export_markdown()`

#### `bin/minidebug_view.ml` - CLI Entry Point

**Architecture:**
1. **Argument Parsing:**
   - `parse_args()`: Parses command and options
   - Returns `(db_path, command, options)` tuple

2. **Command Type:**
   ```ocaml
   type command =
     | List | Stats | Show | Interactive | Compact | Roots
     | Search of string
     | SearchTree of string
     | SearchSubtree of string
     | ShowScope of int
     | ShowEntry of int * int
     | GetAncestors of int | GetParent of int | GetChildren of int
     | Export of string | Help
   ```

3. **Options Type:**
   ```ocaml
   type options = {
     show_scope_ids : bool;
     show_times : bool;
     max_depth : int option;
     values_first_mode : bool;
     with_values : bool;
     format : [ `Text | `Json ];
     quiet_path : string option;
     show_ancestors : bool;
   }
   ```

4. **Main Logic:**
   - Open database connection
   - Match command and dispatch to `Client` module
   - Handle errors and cleanup

### Key Implementation Details

#### Search Tree Algorithm (`Client.search_tree`)

```ocaml
let search_tree ?(quiet_path = None) ?(format = `Text) t ~pattern =
  (* 1. Run search with ancestor propagation *)
  let results_table = Hashtbl.create 1024 in
  Query.populate_search_results t.db_path ~search_term:pattern
    ~quiet_path ~search_order:AscendingIds ~results_table;

  (* 2. Extract entries from hash table *)
  let all_entries = Query.get_entries t.db () in
  let filtered_entries =
    List.filter (fun e -> Hashtbl.mem results_table (e.scope_id, e.seq_id))
      all_entries in

  (* 3. Build and render tree *)
  let trees = Renderer.build_tree filtered_entries in
  match format with
  | `Text -> Renderer.render_tree trees
  | `Json -> Renderer.render_tree_json trees
```

**Key Insight:** Reuses `Query.populate_search_results()` from TUI, which:
1. Streams through all entries
2. Finds matches using regex
3. Propagates to ancestors (stops at quiet_path)
4. Writes results to shared hash table

This avoids duplicating complex TUI search logic in CLI.

#### Search Subtree Algorithm (`Client.search_subtree`)

```ocaml
let search_subtree t ~pattern =
  (* 1. Get search results and build full tree *)
  let results_table = ... (* same as search_tree *)
  let full_trees = Renderer.build_tree all_entries in

  (* 2. Recursively prune non-matching nodes *)
  let rec prune_tree node =
    let is_match = Hashtbl.mem results_table (node.entry.scope_id, ...) in
    let pruned_children = List.filter_map prune_tree node.children in
    (* Keep if match OR any child survived *)
    if is_match || pruned_children <> [] then
      Some { node with children = pruned_children }
    else None
  in

  List.filter_map prune_tree full_trees
```

**Key Insight:** Bottom-up pruning preserves only nodes with matches in their subtree.

#### JSON Rendering

The `Renderer` module provides JSON output by:
1. **Escaping strings:** Proper JSON escaping (quotes, newlines, control chars)
2. **Recursive tree encoding:** Each node becomes `{ entry: {...}, children: [...] }`
3. **Complete field coverage:** All entry fields included (scope_id, message, data, times, etc.)

**Design Choice:** Manual JSON construction (no external library) keeps dependencies minimal.

#### Scope Navigation

Navigation commands leverage existing database queries:
- `get_ancestors()`: Recursive `get_parent_id()` calls
- `get_children()`: Query for `scope_id = parent`, extract `child_scope_id`s
- `show_scope()`: Either `get_scope_children()` or ancestor filtering

**Design Pattern:** Simple wrappers around Query functions with format selection.

### Database Schema Dependencies

The CLI relies on the ppx_minidebug database schema v3+:

**Key Tables:**
- `entries`: Main trace data (scope_id, seq_id, message, location, data refs, times)
- `value_atoms`: Content-addressed value storage (value_id, value_hash, value_content)
- `entry_parents`: Parent relationships (scope_id, parent_id)
- `runs`: Run metadata (run_id, timestamp, command_line)

**Important Schema Details:**
- **Composite keys:** `(scope_id, seq_id)` uniquely identifies an entry
- **Content addressing:** Values deduplicated by hash in `value_atoms`
- **Negative scope IDs:** Used for synthetic scopes from `boxify` decomposition
- **Metadata database:** Separate `_meta.db` stores run information (v3+ only)

### Extension Points

#### Adding New Commands

1. **Add to command type** in `bin/minidebug_view.ml`:
   ```ocaml
   type command = ... | MyCommand of string
   ```

2. **Add parser case:**
   ```ocaml
   | "my-command" :: arg :: rest ->
       cmd_ref := MyCommand arg;
       parse_rest rest
   ```

3. **Implement in `Client` module:**
   ```ocaml
   let my_command ?(format = `Text) t ~arg =
     let entries = Query.get_entries t.db () in
     (* ... process entries ... *)
     match format with
     | `Text -> print_string result
     | `Json -> print_endline (to_json result)
   ```

4. **Add dispatch case:**
   ```ocaml
   | MyCommand arg -> Client.my_command ~format:opts.format client ~arg
   ```

5. **Update help text** in `usage_msg`

6. **Export in `.mli`** if part of public API

#### Adding New Output Formats

To add CSV, XML, or other formats:

1. **Add to options type:**
   ```ocaml
   format : [ `Text | `Json | `Csv ]
   ```

2. **Implement renderer:**
   ```ocaml
   val render_tree_csv : tree_node list -> string
   ```

3. **Update all command handlers** to support new format

**Design Consideration:** Consider using a format typeclass/module for extensibility.

#### Custom Search Algorithms

To implement different search strategies:

1. **Define search function in `Query`:**
   ```ocaml
   val my_search : Sqlite3.db -> pattern:string -> strategy:search_strategy -> entry list
   ```

2. **Add command-line option:**
   ```ocaml
   --search-strategy=<strategy>
   ```

3. **Wire through `Client` to new search function**

**Example Use Cases:**
- Fuzzy matching
- Type-based search (find all int values)
- Time-based filtering (entries in time range)
- Depth-first vs breadth-first traversal

### Performance Considerations

#### Memory Usage

**Concern:** Loading full trees for large databases

**Mitigations:**
1. **Lazy loading in TUI:** `build_visible_items()` only loads expanded nodes
2. **`--max-depth` option:** Limits tree depth
3. **`roots` command:** Efficient query without loading full tree
4. **Streaming search:** `populate_search_results()` streams entries

**Future Optimization:** Implement lazy tree building in CLI (currently loads all entries).

#### Database Query Efficiency

**Current Approach:**
- Most commands use `get_entries()` which loads all entries
- Navigation commands use targeted queries (`get_scope_children`, etc.)

**Optimization Opportunities:**
1. **Add WHERE clauses:** Filter at SQL level before loading into memory
2. **Pagination:** `LIMIT` and `OFFSET` for large result sets
3. **Prepared statements:** Cache frequently-used queries
4. **Index usage:** Ensure proper indexes on `(scope_id, seq_id)`, `child_scope_id`

**Trade-off:** Current approach is simple and correct. Optimize only if profiling shows bottlenecks.

#### Search Performance

`populate_search_results()` is already optimized:
- Streams entries (doesn't load all into memory first)
- Uses hash tables for O(1) lookups
- Regex compiled once
- Progress tracking every 100K entries

**Bottleneck:** Large databases with millions of entries. Consider:
1. **SQL LIKE clauses:** Push simple pattern matching to database
2. **Incremental results:** Return matches as found (streaming)
3. **Result caching:** Cache recent searches

### Testing Strategy

#### Unit Tests

**Location:** `test/` directory

**Test Pattern for CLI Commands:**
```ocaml
(* In test/dune *)
(executable
 (name test_my_feature)
 (libraries minidebug_db))

(rule
 (targets my_feature.db my_feature.log)
 (deps ../bin/minidebug_view.exe)
 (action
  (progn
   (run %{dep:test_my_feature.exe})  ; Generate database
   (with-stdout-to my_feature.log
    (run %{dep:../bin/minidebug_view.exe} my_feature.db show)))))

(rule
 (alias runtest)
 (action (diff my_feature.expected.log my_feature.log)))
```

**Workflow:**
1. Run test executable → generates `.db`
2. Run `minidebug_view` command → generates `.log`
3. Compare with `.expected.log`
4. Promote with `dune promote`

#### Integration Tests

Test typical workflows:

```bash
# Generate test database
./test_program > test.db

# Test commands
minidebug_view test.db search-tree "error" --format=json > output1.json
minidebug_view test.db get-ancestors 42 --format=json > output2.json
minidebug_view test.db show-scope 42 --format=json > output3.json

# Validate JSON structure
jq '.[0].entry.scope_id' output1.json
```

#### JSON Validation

Use `jq` or JSON schema validators:

```bash
# Check JSON is valid
minidebug_view trace.db search-tree "test" --format=json | jq empty

# Validate structure
echo '[
  {"type": "array"},
  {"items": {
    "type": "object",
    "required": ["entry", "children"]
  }}
]' > schema.json

minidebug_view trace.db show --format=json | ajv validate -s schema.json
```

### Common Pitfalls & Solutions

#### Problem: "option is None" error

**Cause:** No runs in metadata database (old schema or database has no run metadata)

**Solution:**
- Schema v3+ required for full functionality
- Some commands (show, roots, compact) fail without run metadata
- Use navigation commands which don't require runs

#### Problem: Negative scope IDs in output

**Cause:** `boxify` creates synthetic scopes with negative IDs for sexp decomposition

**Meaning:** These are internal nodes representing value structure, not actual code scopes

**Solution:** Filter negative IDs when inappropriate, or document as internal

#### Problem: Search finds no results

**Debugging:**
1. Check pattern is substring (not regex) for `populate_search_results()`
2. Use `show` command to see what's actually in database
3. Verify you're searching the right database file
4. Check if `quiet_path` is filtering too aggressively

#### Problem: JSON output is huge

**Cause:** Full tree with all entries can be large

**Solutions:**
1. Use `--max-depth` to limit depth
2. Use `search-subtree` instead of `search-tree` (pruned output)
3. Use navigation commands to fetch specific scopes
4. Implement pagination for large results

### Future Work

#### Lessons from Production Use (OCANNL 1M+ Entry Trace)

The CLI was tested on a real-world OCANNL trace with 1,051,297 entries and 105 MB size. This revealed both strengths and areas for improvement.

**What Worked Exceptionally Well:**

1. **`search-at-depth`** - The killer feature for large traces
   - Reduced output from 87 matching scopes → 3 unique entries at depth 4
   - Provides TUI-like hierarchical understanding without interactive session
   - Enables "progressive disclosure" workflow: overview → drill down

2. **`--quiet-path` filtering** - Effective noise reduction
   - Reduced matches from 123 → 87 scopes by stopping at "env" patterns
   - Works by halting ancestor propagation when pattern matches message field

3. **`--times` flag** - Instant performance insights
   - Immediately identified 49.93s hotspot in scope {#60452}
   - Showed id 1802 operations taking 100-270ms vs id 79 at 10-13ms

4. **Navigation commands** - Perfect for drilling down
   - `get-ancestors`, `show-scope`, `show-entry` work flawlessly
   - Enable systematic exploration of interesting scopes

**Discovered Limitations:**

1. **Quiet-path only filters message field**
   - Many interesting patterns appear in `data` field, not `message`
   - Example: Variable IDs like `(id 79)` often in data, causing filter misses
   - **Need:** `--quiet-data` or unified filtering across all fields

2. **Performance on extreme scale**
   - Some queries hang on 1M+ databases (need SQL optimization)
   - Loading all entries into memory for filtering is inefficient
   - **Need:** Query pushdown to SQL layer, streaming results

3. **Missing context for errors**
   - Actual error messages (thrown exceptions) don't appear in trace
   - Error occurs after trace ends, so can't see the failure point
   - **Need:** Better exception capture in tracing runtime

**Recommended Workflow for Large Traces:**

```bash
# Step 1: Understand scale
minidebug_view huge.db stats
# Output: 1,051,297 entries → sets expectations

# Step 2: Top-level overview
minidebug_view huge.db search-at-depth "(id 79)" 1 --quiet-path="env" --times
# Output: 3 top-level operations, identifies 49.93s hotspot

# Step 3: Mid-level summary
minidebug_view huge.db search-at-depth "(id 79)" 4 --quiet-path="env"
# Output: 3 unique scopes at depth 4

# Step 4: Find intersections manually
minidebug_view huge.db search-at-depth "(id 1802)" 4 --quiet-path="env"
# Notice scope {#60460} appears in both → likely where ids interact

# Step 5: Drill down
minidebug_view huge.db show-scope 60460 --max-depth=2
```

This workflow reduces a 1M-entry trace to 3-7 key scopes in seconds!

#### Planned Features

1. **Data-field filtering:** ✅ High Priority
   ```bash
   minidebug_view trace.db search-tree "(id 79)" --quiet-data="env\|Node\|Bounds"
   # Stop propagation when data field matches pattern
   ```

2. **Multi-pattern search:** ✅ **IMPLEMENTED** (v3.1.0+)
   ```bash
   minidebug_view trace.db search-intersection "(id 79)" "(id 1802)"
   # Find smallest subtrees (LCAs) where both patterns co-occur
   ```

   **Status:** Fully implemented with LCA-based algorithm supporting 2+ patterns (no upper limit).
   Returns the minimal contexts containing all patterns. See `search-intersection` command above.

3. **Pagination:** ✅ **IMPLEMENTED** (v3.1.0+)
   ```bash
   minidebug_view trace.db search-tree "error" --limit=10 --offset=0
   # Show only first 10 results, enable paging through large result sets
   ```

   **Status:** Fully implemented for `search-tree`, `search-subtree`, and `search-intersection` commands.
   Output shows: "Found X matching scopes, Y root trees (showing trees M-N)"

4. **Time-range queries:**
   ```bash
   minidebug_view trace.db search-tree "compute" --min-time=100ms
   # Only show scopes that took at least 100ms
   ```

5. **Scope range filtering:**
   ```bash
   minidebug_view trace.db search-tree "error" --scope-range=50000-60000
   # Only search within specific scope ID range
   ```

6. **Summary mode:**
   ```bash
   minidebug_view trace.db search-tree "error" --summary
   # Output: Found 87 scopes: [2093, 2197, 5796, ...]
   # Just IDs, no full tree
   ```

7. **Value-based search:**
   ```bash
   minidebug_view trace.db search-value "42" --type=int
   ```

8. **Comparison mode:**
   ```bash
   minidebug_view trace1.db trace2.db diff
   ```

9. **SQL-like queries:**
   ```bash
   minidebug_view trace.db query "SELECT * FROM entries WHERE elapsed_ns > 1000000"
   ```

#### API Improvements

1. **Batch operations:**
   ```bash
   minidebug_view trace.db batch commands.txt --format=json
   ```

2. **Piping support:**
   ```bash
   minidebug_view trace.db search-tree "error" --format=json \
     | minidebug_view - show-scope $(jq '.[0].entry.scope_id')
   ```

3. **Output streaming:**
   ```bash
   minidebug_view large.db search-tree "test" --stream
   ```

#### MCP Server for Stateful Debugging 🚀

**Problem:** The CLI's stateless nature means every command re-loads the entire database. For the 1M-entry OCANNL trace, each command takes ~5 seconds just to load entries, even though we're doing related queries.

**Solution:** Implement a Model Context Protocol (MCP) server using [ocaml-mcp](https://github.com/tmattio/ocaml-mcp) for stateful, session-based debugging.

**Performance Gain Example:**
```bash
# Current CLI approach (4 round-trips):
search-at-depth "(id 79)" 1    # Loads 1M entries: 5s
search-at-depth "(id 79)" 4    # Loads 1M entries: 5s
search-at-depth "(id 1802)" 4  # Loads 1M entries: 5s
show-scope 60460               # Loads 1M entries: 5s
# Total: 20 seconds, 4M entries loaded

# MCP Server approach (1 session):
mcp.open_database("trace.db")  # Loads entries once: 3s
mcp.search_at_depth("(id 79)", 1)    # Uses cache: 0.5s
mcp.search_at_depth("(id 79)", 4)    # Reuses search: 0.1s
mcp.search_at_depth("(id 1802)", 4)  # Uses cache: 0.5s
mcp.show_scope(60460)                # Instant: <0.1s
# Total: 4.2 seconds, 1M entries loaded once
# Speedup: 4.8x!
```

**Architecture:**

```ocaml
(* bin/minidebug_mcp_server.ml *)
type server_state = {
  db: Sqlite3.db;
  db_path: string;
  entries: Query.entry array;        (* Cached in memory *)
  search_slots: search_slot SlotMap.t;  (* 4 active searches like TUI *)
  expanded: (int, unit) Hashtbl.t;   (* UI state *)
}

(* MCP Tools *)
let tools = [
  {
    name = "open_database";
    description = "Open database and cache entries for session";
    inputSchema = {
      db_path: string;
      preload: bool;  (* default: true *)
    }
  };
  {
    name = "search_tree";
    description = "Search with ancestor propagation (results cached in slot)";
    inputSchema = {
      pattern: string;
      quiet_path: string option;
      slot: int;  (* 1-4, for multi-search like TUI *)
    }
  };
  {
    name = "search_at_depth";
    description = "Filter cached search to specific depth";
    inputSchema = {
      depth: int;
      slot: int option;  (* Reuse previous search result! *)
    }
  };
  {
    name = "get_intersection";
    description = "Find scopes in multiple search results";
    inputSchema = {
      slots: int list;  (* [1; 2] = scopes in both slot 1 and slot 2 *)
    }
  };
  {
    name = "show_scope";
    description = "Show scope contents (instant from cache)";
    inputSchema = {
      scope_id: int;
      max_depth: int option;
    }
  }
]
```

**Key Features Enabled by MCP:**

1. **Search Result Caching** - Like TUI's 4 search slots
   ```ocaml
   mcp.search_tree("(id 79)", slot:1)     (* Cached in slot 1 *)
   mcp.search_tree("(id 1802)", slot:2)   (* Cached in slot 2 *)
   mcp.get_intersection([1; 2])           (* Instant! *)
   ```

2. **Incremental Depth Exploration** - Reuse same search at different depths
   ```ocaml
   mcp.search_tree("error", slot:1)       (* Scan 1M entries once *)
   mcp.search_at_depth(depth:1, slot:1)   (* Filter cache: 3 results *)
   mcp.search_at_depth(depth:4, slot:1)   (* Refilter cache: 7 results *)
   ```

3. **Background Processing** - Async searches like TUI Domains
   ```ocaml
   search_id = mcp.start_search_async("(id 79)")
   (* Do other work... *)
   mcp.get_stats()
   mcp.show_scope(42)
   (* Check completion *)
   if mcp.is_search_complete(search_id) then
     results = mcp.get_search_results(search_id)
   ```

4. **Multi-Pattern Queries** - Impossible with stateless CLI
   ```ocaml
   (* Find scopes containing BOTH id 79 AND id 1802 *)
   mcp.search_intersection(["(id 79)"; "(id 1802)"])

   (* Find scopes with id 79 but NOT env *)
   mcp.search_difference("(id 79)", except:"env")
   ```

5. **Session Persistence** - Save exploration state
   ```ocaml
   (* Save current search state to resume later *)
   mcp.save_session("debug_session_1.json")

   (* Later... *)
   mcp.load_session("debug_session_1.json")
   (* All search slots and expanded state restored *)
   ```

**Implementation Plan:**

1. **Phase 1:** Basic MCP server with stateful entry cache
   - Tools: `open_database`, `search_tree`, `show_scope`
   - Library: [ocaml-mcp](https://github.com/tmattio/ocaml-mcp)
   - Reuse existing `Query` and `Renderer` modules

2. **Phase 2:** Search slot system (like TUI)
   - 4 concurrent search slots with different patterns
   - `get_intersection`, `get_union`, `get_difference`
   - Hash-based set operations on cached results

3. **Phase 3:** Background processing with Domains
   - Async search spawned in background Domain
   - Polling interface: `start_search`, `is_complete`, `get_results`
   - Non-blocking for LLM agents doing multi-step analysis

4. **Phase 4:** Advanced features
   - Session save/load
   - Query history and replay
   - Streaming results for huge result sets
   - Smart caching (LRU for scopes, keep hot paths)

**Use Case: LLM Agent Debugging Workflow**

```
Agent: "Find scopes where both id 79 and id 1802 appear"

MCP Server session:
1. open_database("ocannl.db")         # Cache 1M entries: 3s
2. search_tree("(id 79)", slot:1)     # Scan cache: 2s → 87 scopes
3. search_tree("(id 1802)", slot:2)   # Scan cache: 2s → 129 scopes
4. get_intersection([1, 2])           # Hash lookup: <1ms → 3 scopes!
5. show_scope(60460)                  # Instant from cache

Total: 7 seconds (vs 25+ seconds with CLI)

Agent: "Now show me the call paths to those scopes"
6. get_ancestors(60460)               # Instant: already in cache
7. search_at_depth(depth:1, slot:1)   # Refilter slot 1: <1ms
```

**Why This Matters for LLM Agents:**

- **Conversational debugging:** Agent can ask follow-up questions without re-loading DB
- **Complex queries:** Multi-pattern searches that would require manual shell scripting
- **Interactive exploration:** Like TUI, but programmatic
- **Efficiency:** 5-10x speedup for multi-step workflows

**Dependencies:**

```dune
(executable
 (name minidebug_mcp_server)
 (libraries mcp sqlite3 minidebug_client)
 (preprocess (pps ppx_deriving_yojson)))
```

**Status:** Planned for future release. Would provide TUI-like efficiency with CLI-like automation.

#### Performance Optimizations

1. **Lazy tree building:** Don't load full tree until needed
2. **Query pushdown:** Move filtering to SQL layer
3. **Result caching:** Cache frequently-accessed scopes (already in MCP server plan!)
4. **Parallel queries:** Use multiple database connections for concurrent reads

## Troubleshooting

### Database Issues

**Symptom:** "Database file not found"
```bash
# Check file exists
ls -la *.db

# Look for versioned databases (_1.db, _2.db, etc.)
ls -la *_*.db

# Check metadata database exists
ls -la *_meta.db
```

**Symptom:** "Invalid database"
```bash
# Check schema version
sqlite3 trace.db "SELECT * FROM sqlite_master"

# Verify entries table exists
sqlite3 trace.db "SELECT COUNT(*) FROM entries"
```

### Performance Issues

**Symptom:** Commands hang on large databases

**Diagnosis:**
```bash
# Check database size
du -h trace.db

# Check entry count
sqlite3 trace.db "SELECT COUNT(*) FROM entries"

# Profile with time command
time minidebug_view trace.db show --max-depth=1
```

**Solutions:**
- Use `--max-depth` to limit output
- Use `roots` command instead of `show`
- Use navigation commands to focus on specific scopes
- Consider database cleanup (remove old runs)

### Output Issues

**Symptom:** JSON output not parsing

**Diagnosis:**
```bash
# Validate JSON
minidebug_view trace.db show --format=json | jq empty

# Check for special characters
minidebug_view trace.db show --format=json | grep -n '[^[:print:]]'
```

**Solutions:**
- Report as bug (JSON should always be valid)
- Check for special characters in source code (might need better escaping)

## Contributing

### Code Style

- **OCaml formatting:** Use `ocamlformat` with project settings
- **Naming:** snake_case for functions, Mixed_snake_case for modules
- **Documentation:** Docstrings for all public functions
- **Error handling:** Use `Result` types or clear error messages

### Pull Request Checklist

- [ ] New commands documented in `usage_msg`
- [ ] Tests added for new functionality
- [ ] JSON output validated with `jq`
- [ ] Updated CLI.md with new features
- [ ] Updated minidebug_client.mli interface
- [ ] Ran `dune build` and `dune runtest` successfully
- [ ] Tested with real database examples

### Design Principles

1. **Minimal dependencies:** Keep dependency footprint small
2. **Consistent API:** All commands follow same option patterns
3. **Format flexibility:** Support both text and JSON
4. **Efficient queries:** Don't load more data than needed
5. **Clear errors:** Provide helpful error messages
6. **Composability:** Commands should pipe and chain well

## References

- **Database Schema:** See `DATABASE_BACKEND.md` for schema details
- **TUI Implementation:** See `Interactive` module in `minidebug_client.ml`
- **Project Overview:** See `CLAUDE.md` for general architecture
- **Examples:** See `test/` directory for usage examples

## License

Same as ppx_minidebug project.

## Contact

For issues or feature requests, see project repository.
