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

#### `search-extract <search_path> <extraction_path>` ✅
**DAG path search with extraction** - Searches for patterns along a path in the trace DAG, then extracts related data with change tracking.

```bash
minidebug_view trace.db search-extract "Node,key,(id 79)" "Node,value" [options]
```

**Options:**
- `--format=json`: Output as JSON
- `--times`: Include elapsed times
- `--max-depth=<n>`: Limit extracted tree depth

**How it works:**
1. **Search path**: Finds all paths matching a sequence of patterns (comma-separated)
   - Example: `"Node,key,(id 79)"` finds `Node` → `key` → `(id 79)`
   - Uses reversed search: finds leaf pattern first, climbs up verifying ancestors
   - Works anywhere in trace (not limited to root entries)
   - **Supports value entries** at end of path (e.g., `(id 79)` can be a value, not just a scope)
2. **Extraction path**: From each matching "shared node", extracts along a different path
   - Example: `"Node,value"` extracts the `value` child of the matched `Node`
   - Must share first element with search path (the "shared node")
3. **Change tracking**: Skips consecutive duplicate extractions (same scope_id)
   - Leverages content-addressed caching - same scope_id = identical subtree
   - Shows only when extracted data actually changes

**Arguments:**
- `<search_path>`: Comma-separated patterns (e.g., `"fn,param,value"`)
- `<extraction_path>`: Comma-separated patterns starting with same element as search path
- Both paths use substring matching on entry `message` or `data` fields

**Example - Track parameter evolution:**
```bash
# Find all Node entries whose key child contains "(id 79)",
# and show their value child (skipping duplicates)
minidebug_view trace.db search-extract "Node,key,(id 79)" "Node,value"
```

**Output (text mode):**
```
=== Match #1 at shared scope #-98529 ==>
#-98530 [value] Bounds_dim
  #-98531 [value] is_in_param
    #-408 false
  ...

=== Match #2 at shared scope #-3513 ==>
#-3427 [value] Bounds_dim
  #-3428 [value] is_in_param
    #-408 false
  ...

Search-extract complete: 3 total matches, 2 unique extractions (skipped 1 consecutive duplicates)
```

**Output (JSON mode):** Each match as object with `match_number`, `shared_scope_id`, `extracted_scope_id`, and `tree`.

**Use Cases:**
- **Parameter tracking**: "Show me how parameter X evolves through function F"
  - Search: `"F,param,X"`, Extract: `"F,result"`
- **State changes**: "Where does variable V change in context C?"
  - Search: `"C,update,V"`, Extract: `"C,V"`
- **Error analysis**: "What values led to errors in module M?"
  - Search: `"M,compute,Error"`, Extract: `"M,input"`
- **DAG traversal**: Works with complex parent-child relationships from content-addressed caching

**Key Features:**
- **Efficient DAG search**: Uses `populate_search_results` + ancestor climbing (handles multiple parents)
- **Value entry support**: Last search pattern can match values (not just scopes)
- **Smart deduplication**: Skips showing same subtree multiple times (based on scope_id)
- **Disambiguation**: Shows shared scope ID to clarify which match point was used

**Algorithm Details:**
1. Reverse search path: `["Node", "key", "(id 79)"]` → `["(id 79)", "key", "Node"]`
2. Find all candidates matching `"(id 79)"` (last/leaf pattern)
3. For each candidate, climb up DAG checking ancestors match `"key"`, then `"Node"`
4. From successful matches (shared nodes), extract along `"Node" → "value"`
5. Skip consecutive extractions with same scope_id

**Comparison with other commands:**
- `search-tree`: Shows all occurrences with context (no extraction or dedup)
- `search-intersection`: Finds co-occurrence of patterns (no path structure)
- `search-extract`: Follows specific paths, extracts related data, tracks changes

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

#### `show-subtree <id>`
Shows the full subtree rooted at a specific scope, with ancestor path.

```bash
minidebug_view trace.db show-subtree 42 [options]
```

**Options:**
- `--format=json`: JSON output
- `--times`: Include elapsed times
- `--max-depth=<n>`: **INCREMENTAL** depth from target scope (not absolute depth)
- `--ancestors`: Include ancestor path from root (default: true)

**Important:** The `--max-depth` parameter is interpreted as **incremental depth** relative to the target scope:
- If target scope is at depth 5 and you specify `--max-depth=3`, shows up to depth 8
- This allows you to focus on "what happens inside this scope" without worrying about absolute depth

**Example - Show scope with limited subtree:**
```bash
minidebug_view trace.db show-subtree 2093 --max-depth=3 --times
# Shows scope 2093 + its ancestors + descendants up to 3 levels deep
```

**Example - Show scope without ancestors:**
```bash
minidebug_view trace.db show-subtree 42 --ancestors=false --max-depth=2
# Shows only scope 42 and 2 levels of descendants
```

**Output:** Full tree rendering with scope IDs, messages, locations, values, and nested structure.

**Use Case:**
- **After `search-intersection`**: Explore the full context of an LCA scope
- **Focused investigation**: See what happens inside a specific scope without being overwhelmed by the entire trace
- **Progressive exploration**: Start with compact LCA list, then drill into interesting scopes

**Workflow Example:**
```bash
# Step 1: Find interaction points
minidebug_view trace.db search-intersection "(id 79)" "(id 1802)"
# Output: Scope 2093: binop [tensor/tensor.ml:444:22-454:14]

# Step 2: Explore the subtree
minidebug_view trace.db show-subtree 2093 --max-depth=3 --times
# Shows full context where both IDs interact
```

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
- **Purpose:** Database access layer (optimized for large databases)
- **Architecture:** Functor-based design for connection management
  - `Query.Make(db_path)` creates isolated Query module instances
  - Each instance maintains its own database connections (main DB + metadata DB)
  - Domain-safe: Background search Domains instantiate separate Query modules
  - Enables future prepared statement caching within module instances
- **Key Functions:**
  - `find_entry()`: Find specific entry by (scope_id, seq_id)
  - `find_scope_header()`: Find header entry that creates a scope
  - `get_entries_for_scopes()`: Batch query for specific scope_ids
  - `get_entries_from_results()`: Get entries from search results hashtable
  - `get_root_entries()`: Efficient root-only query
  - `get_scope_children()`: Get immediate children of a scope
  - `get_parent_id()`: Get parent scope
  - `get_ancestors()`: Recursive ancestor collection
  - `search_entries()`: GLOB pattern search (uses SQLite GLOB operator)
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
- **Design Pattern:** Client holds first-class Query module instance `(module Query.S)`
  - Each Client instance contains isolated database connections via Query functor
  - Thread-safe: Each Domain can instantiate its own Query module
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

  (* 2. Extract entries efficiently from results hashtable *)
  let filtered_entries = Query.get_entries_from_results t.db ~results_table in

  (* 3. Build and render tree *)
  let trees = Renderer.build_tree_from_entries filtered_entries in
  match format with
  | `Text -> Renderer.render_tree trees
  | `Json -> Renderer.render_tree_json trees
```

**Key Insight:** Reuses `Query.populate_search_results()` from TUI, which:
1. Streams through all entries
2. Finds matches using GLOB pattern
3. Propagates to ancestors (stops at quiet_path)
4. Writes results to shared hash table

Then `get_entries_from_results()` efficiently queries only the scope_ids in the results table, avoiding loading all entries into memory. This scales to large databases.

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
     (* Use efficient queries - avoid loading all entries *)
     let root_entries = Query.get_root_entries t.db ~with_values:false in
     let trees = Renderer.build_tree t.db root_entries in
     (* ... process trees ... *)
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

#### Database Query Efficiency

**Optimized Query Patterns (v3.1+):**
- Removed `get_entries()` - no longer loads all entries into memory
- **Targeted queries:** All commands use specific SQL queries:
  - `find_entry()` - single entry by primary key
  - `find_scope_header()` - header by child_scope_id
  - `get_entries_for_scopes()` - batch query for specific scopes
  - `get_entries_from_results()` - query only scopes in search results
- **Tree building:** `Renderer.build_tree()` queries DB on-demand (lazy)
- **Search:** `get_entries_from_results()` filters at SQL level before loading

**Key Optimizations:**
1. ✅ **WHERE clauses:** All queries filter at SQL level
2. ✅ **Batch queries:** `get_entries_for_scopes()` uses `IN (?,?,?)` for efficiency
3. ✅ **Lazy tree building:** `Renderer.build_tree()` queries children on-demand
4. ✅ **Index usage:** Primary key `(scope_id, seq_id)` and index on `child_scope_id`

**Result:** Commands scale to large databases without loading everything into memory.

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

#### MCP Server ✅ **IMPLEMENTED**

**Status:** A basic MCP server has been implemented! See the [minidebug_mcp section](#minidebug_mcp---mcp-server--new) at the end of this document for full details.

**Current Implementation (v3.1.0+):**
- ✅ 7 MCP tools: list-runs, stats, show-trace, search-tree, search-subtree, show-scope, get-ancestors
- ✅ Stateless architecture (each tool opens/closes DB)
- ✅ Natural language interface via Claude Desktop or other MCP clients
- ✅ Built on Anil Madhavapeddy's lightweight ocaml-mcp library (vendored)

**Quick Start:**
```json
// Add to Claude Desktop config:
{
  "mcpServers": {
    "ppx_minidebug": {
      "command": "minidebug_mcp",
      "args": ["/path/to/trace.db"]
    }
  }
}
```

**Future: Stateful Session-Based Server**

The current implementation is stateless (reloads DB per query). Future enhancement will add session caching for massive performance gains:

**Vision - Session Caching:**
```ocaml
type server_state = {
  db: Sqlite3.db;
  entries_cache: Query.entry array;  (* Load once *)
  search_slots: (int, Hashtbl.t) Hashtbl.t;  (* 4 active searches *)
  scope_cache: (int, tree_node) Hashtbl.t;  (* LRU cache *)
}
```

**Expected Performance (1M-entry DB):**
- Current stateless: Each query ~5s (reloads DB)
- Future cached: First query 5s, subsequent <0.1s
- Speedup: 50x for multi-step workflows!

**Planned Advanced Features:**
- Search slot caching (reuse previous search results)
- `search-intersection` across cached slots (instant)
- Background async searches with progress updates
- Session persistence (save/resume debugging state)
- Incremental depth exploration without re-scanning

**Why Session State Matters:**

LLM agents often ask follow-up questions in the same debugging session:
```
1. "Find id 79" → loads 1M entries (5s)
2. "Show scope 2093" → reloads 1M entries (5s)  ← wasteful!
3. "Find id 1802" → reloads again (5s)          ← wasteful!
```

With session caching:
```
1. "Find id 79" → loads 1M entries (5s), caches
2. "Show scope 2093" → uses cache (<0.1s)       ← instant!
3. "Find id 1802" → rescans cache (0.5s)        ← reuses loaded data!
```

See the full MCP server documentation below for current usage and implementation details.

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

---

# minidebug_mcp - MCP Server ✨ NEW

**Model Context Protocol server for AI-powered debugging.**

## Overview

The `minidebug_mcp` server exposes ppx_minidebug database query capabilities via the Model Context Protocol (MCP), enabling AI assistants like Claude Desktop to directly query and analyze debug traces.

**Key Benefits:**
- **AI-native interface**: Natural language queries instead of command-line syntax
- **Contextual understanding**: AI can follow multi-step debugging workflows
- **Session-based**: Faster than CLI for iterative exploration (future: caching)
- **Integration-ready**: Works with any MCP-compatible AI assistant

## Installation

Built alongside minidebug_view:

```bash
dune build bin/minidebug_mcp.exe
# Or after opam install:
which minidebug_mcp
```

## Quick Start

### Configuration for Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "ppx_minidebug": {
      "command": "/path/to/minidebug_mcp",
      "args": ["/absolute/path/to/your/trace.db"]
    }
  }
}
```

Then restart Claude Desktop.

### Usage

Once configured, Claude can directly query your traces:

```
You: "Show me all the runs in my debug trace"
Claude: [calls minidebug/list-runs tool]
        "There are 3 runs in the database..."

You: "Find where id 79 appears"
Claude: [calls minidebug/search-tree tool with pattern "(id 79)"]
        "I found 87 scopes containing id 79..."

You: "Show me scope 2093 in detail"
Claude: [calls minidebug/show-scope tool]
        "This scope is a binop function at tensor.ml:444..."
```

## MCP Tools Provided

### Database Information
- **minidebug/list-runs** - List all trace runs with timestamps and metadata
- **minidebug/stats** - Database statistics (size, deduplication metrics)

### Trace Viewing
- **minidebug/show-trace** - Full trace tree (with depth/time options)

### Search & Analysis
- **minidebug/search-tree** 🌟 - Search with full ancestor context (best for AI)
  - Returns all matches with their complete call paths
  - Supports quiet-path filtering and pagination
- **minidebug/search-subtree** - Pruned subtree search (minimal context)
- **minidebug/search-at-depth** - Summary at specific depth (TUI-like overview)
- **minidebug/search-intersection** - Find scopes matching ALL patterns (2-4 patterns)
- **minidebug/search-extract** - Search DAG path then extract values with change tracking

### Navigation
- **minidebug/show-scope** - Show specific scope and descendants
- **minidebug/show-subtree** - Show subtree rooted at scope with ancestor path
- **minidebug/get-ancestors** - Get ancestor chain for navigation
- **minidebug/get-children** - Get child scope IDs for navigation

## Implementation Status

### ✅ Implemented
- All 13 MCP tools covering all CLI functionality relevant for AI analysis
- Database path management
- Error handling and logging
- JSON parameter validation
- Type-safe argument extraction
- **Output capture**: All tools use buffer-backed formatters for clean JSON-RPC responses

### 🚧 Planned Features
1. **Resource endpoints**: Expose runs as MCP resources
2. **Prompt templates**: Pre-defined prompts for common analysis patterns
3. **Streaming results**: Handle large result sets efficiently
4. **Session caching**: Cache entries in memory for faster multi-query workflows

## Architecture

```
AI Assistant (Claude)
         |
         | JSON-RPC over stdio
         ↓
   minidebug_mcp server
         |
         | Opens database connection
         ↓
   minidebug_client library
         |
         | SQL queries
         ↓
   trace.db (SQLite)
```

**Design:**
- Uses Anil Madhavapeddy's lightweight MCP implementation (vendored)
- Built on existing `minidebug_client` library (same code as CLI)
- Stdio-based transport (standard for MCP servers)
- Each tool call opens/closes database connection (stateless for now)

## Comparison: MCP Server vs CLI

| Feature | minidebug_view (CLI) | minidebug_mcp (MCP) |
|---------|---------------------|---------------------|
| **Interface** | Command-line args | Natural language → AI → tools |
| **Learning curve** | Must learn syntax | Conversational |
| **Multi-step** | Manual scripting | AI handles workflow |
| **Output** | Text/JSON to stdout | JSON-RPC responses |
| **Session state** | Stateless (reloads DB) | Stateless (future: caching) |
| **Speed** | ~5s per query (1M DB) | Same (future: 5-10x faster) |
| **Best for** | Scripting, automation | Interactive debugging, exploration |

## Example Workflows

### Error Root Cause Analysis

```
You: "Find all errors in the trace and explain what caused them"

Claude:
1. Calls minidebug/search-tree with pattern "Error\|Exception"
2. Analyzes the returned tree structure
3. Identifies common ancestors and parameter values
4. Calls minidebug/get-ancestors for key scopes
5. Explains: "The errors occur in validation.ml:42 when the input
   parameter is None. This happens in 3 different code paths..."
```

### Performance Investigation

```
You: "Where is my code spending the most time?"

Claude:
1. Calls minidebug/stats to understand database scale
2. Calls minidebug/show-trace with --times flag
3. Analyzes elapsed times to find hotspots
4. Calls minidebug/show-scope on slow operations
5. Reports: "The bottleneck is in scope 60452 (run_once function)
   which took 49.93s. It's called 3 times, each taking 15-20s..."
```

### Multi-Pattern Intersection

```
You: "Show me where both id 79 and id 1802 interact"

Claude:
1. Calls minidebug/search-tree for "(id 79)"
2. Calls minidebug/search-tree for "(id 1802)"
3. Analyzes overlap in returned scope IDs
4. Calls minidebug/show-scope on intersection points
5. Explains the interaction context
```

## Development

### Adding New Tools

Create new tools in `minidebug_mcp_server/minidebug_mcp_server.ml`:

```ocaml
let _ =
  add_tool server ~name:"minidebug/my-tool"
    ~description:"What this tool does"
    ~schema_properties:[
      ("param_name", "string", "Parameter description")
    ]
    ~schema_required:["param_name"]
    (fun args ->
       try
         let param = get_string_param args "param_name" in
         let client = Minidebug_client.Client.open_db (get_db_path ()) in
         (* ... perform query ... *)
         Tool.create_tool_result [Mcp.make_text_content result] ~is_error:false
       with e -> Tool.create_error_result (Printexc.to_string e))
in
```

### Testing

```bash
# Start server manually (for testing)
minidebug_mcp trace.db

# Server listens on stdin, outputs to stdout
# Send JSON-RPC request (see MCP spec)

# Or test with Claude Desktop configuration
```

### Debugging

```bash
# Enable logging
MINIDEBUG_MCP_LOG=info minidebug_mcp trace.db

# Server logs go to stderr (so stdout stays clean for JSON-RPC)
```

## Future: Session-Based Server

**Vision:** Transform into a stateful server for massive performance gains on large traces.

**Planned Architecture:**
```ocaml
type server_state = {
  db: Sqlite3.db;
  entries_cache: Query.entry array;  (* Load once *)
  search_slots: (int, Hashtbl.t) Hashtbl.t;  (* 4 active searches *)
  scope_cache: (int, tree_node) Hashtbl.t;  (* LRU cache *)
}
```

**Expected Performance (1M-entry DB):**
- Current: Each query reloads 1M entries (~5s per query)
- Future: Load once, cache searches (queries become <0.1s after first)
- Speedup: 50x for multi-step workflows!

**New Capabilities:**
- `search-intersection` across cached slots (instant)
- `search_at_depth` reusing previous search (no re-scan)
- Background search with progress updates
- Session persistence (save/resume debugging state)

See "MCP Server for Stateful Debugging" section above for detailed plan.

## Protocol Details

- **MCP Version**: 2025-03-26 (Anil's implementation)
- **Transport**: stdio (JSON-RPC over stdin/stdout)
- **Message Format**: JSON-RPC 2.0
- **Tool Schema**: JSON Schema for parameter validation

## Dependencies

### Vendored
- `vendor/ocaml-mcp` - Anil Madhavapeddy's MCP implementation
  - Lightweight, stdio-focused
  - Libraries: mcp, mcp.sdk, mcp.rpc, mcp.server

### Project
- `minidebug_client` - Query and rendering library (shared with CLI)
- `eio_main` - Effect-based I/O
- `cohttp-eio` - HTTP support for MCP
- `jsonrpc` - JSON-RPC protocol

## References

- [MCP Specification](https://modelcontextprotocol.io)
- [Anil's ocaml-mcp](https://github.com/avsm/ocaml-mcp)
- [minidebug_mcp_server/README.md](minidebug_mcp_server/README.md) - Implementation details

## Contact

For issues or feature requests, see project repository.
