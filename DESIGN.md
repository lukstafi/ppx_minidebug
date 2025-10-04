# Database-Backed Tracing System - Design Document

## Overview

This document describes the migration from static HTML/Markdown artifact generation to a database-backed tracing system with a separate GUI client. The goals are:

1. **Streaming writes** instead of buffering entire trees (crash-safe, memory-efficient)
2. **GUI client** with lazy loading and interactive exploration
3. **On-the-fly search** and highlighting (client-side regex, no regeneration needed)
4. **Cross-run state persistence** (remember which nodes are expanded even across different trace runs)
5. **Space efficiency** through deduplication of repeated values

## Current Architecture

### PPX Preprocessor (`ppx_minidebug.ml`)

- Transforms annotated code (e.g., `let%debug_sexp foo`) into instrumented versions
- Generates calls to `Debug_runtime.{open_log, log_value_*, close_log}`
- Provides `entry_id` from global counter at each instrumentation point
- Captures source location information (fname, line/column ranges)

### Runtime Backends (`minidebug_runtime.ml`)

Two backends share `Shared_config` module type:

**Flushing Backend:**
- Writes line-by-line to output channel immediately
- Simple indentation-based tree representation
- No buffering - crash-safe but limited formatting
- Maintains `stack : entry list ref` for parent tracking

**PrintBox Backend:**
- Builds tree in memory (`entry` records with `body: subentry list`)
- Outputs only when toplevel scope closes
- Rich formatting via PrintBox library (HTML/Markdown/Text)
- Features: highlighting, diffing, sexp decomposition, hyperlinks

**Key Types:**
```ocaml
(* PrintBox backend *)
type entry = {
  entry_id : int;
  parent_id : int option;  (* implicit via stack *)
  depth : int;
  message : string;
  body : subentry list;    (* children *)
  elapsed : Mtime.span;
  (* ... metadata ... *)
}

type subentry = {
  result_id : int;
  is_result : bool;
  subtree : PrintBox.t;    (* rendered value *)
  (* ... *)
}
```

### Critical Features

1. **Sexp Decomposition** (`boxify_sexp`, [minidebug_runtime.ml:1975](minidebug_runtime.ml:1975))
   - Large sexps (≥ `boxify_sexp_from_size` atoms) split into sub-trees
   - Prevents massive single-line values in logs
   - Example: `((first 7) (second 42) (third ((nested 1) (nested 2))))` becomes expandable tree

2. **Regex Highlighting** ([minidebug_runtime.ml:1830](minidebug_runtime.ml:1830))
   - `highlight_terms` regex matches values
   - Highlight propagates up parent chain to root
   - `exclude_on_path` stops propagation at certain nodes
   - `prune_upto` only shows highlighted subtrees below depth N

3. **Diff Highlighting** (`PrevRun` module, [minidebug_runtime.ml:588](minidebug_runtime.ml:588))
   - Loads previous run's log file (`.raw` marshaled format)
   - Edit distance algorithm finds matching entries between runs
   - Highlights insertions/deletions/changes
   - Tracks `entry_id` pairs for forced matching

4. **Entry ID System** ([minidebug_runtime.ml:467](minidebug_runtime.ml:467))
   - Global counter provides unique ID per instrumentation point
   - Stable across runs (same source location → same entry_id)
   - Used for anchors, ToC links, and diff matching

### Current Duplication Problem

**Analysis of `test/debugger_sexp_html.expected.html`:**
- Recursive `loop` function logs `depth = N` 19 times
- Each occurrence duplicates:
  - Variable name: `"depth"` (5 bytes × 19 = 95 bytes)
  - Source location: `"test/test_debug_html.ml":38:24` (~30 bytes × ~25 occurrences)
  - Sexp structure shape: `((first X) (second Y))` repeated with different values

**Static artifacts explode in size** because entire environments are serialized at each recursion level. Example from real traces:
- Small recursive trace: 13KB HTML
- Larger diffs: 28KB log file
- Environment threading multiplies data structures

## New Architecture: Database-Backed Tracing

### Design Philosophy

**Unify the best of both backends:**
- ✅ Instant writes (Flushing's crash-safety)
- ✅ No buffering (Flushing's memory efficiency)
- ✅ Rich structure (PrintBox's tree representation)
- ✅ Flexible presentation (move formatting to GUI client)
- ✅ Deduplication (new: content-addressed storage)

**No more Flushing vs PrintBox split** - single `DatabaseBackend` module.

### Database Schema

#### Core Tables

```sql
-- Trace run metadata
CREATE TABLE trace_runs (
  run_id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  executable TEXT,
  git_commit TEXT,
  command_line TEXT
);

-- Content-addressed value storage (DEDUPLICATION)
CREATE TABLE value_atoms (
  value_id INTEGER PRIMARY KEY AUTOINCREMENT,
  value_hash TEXT UNIQUE NOT NULL,  -- SHA256 of content
  value_content TEXT NOT NULL,       -- Actual string/sexp/json
  value_type TEXT,                   -- 'string', 'sexp', 'json', 'location'
  size_bytes INTEGER,
  first_seen_run INTEGER REFERENCES trace_runs(run_id)
);
CREATE INDEX idx_value_hash ON value_atoms(value_hash);
CREATE INDEX idx_value_type ON value_atoms(value_type);

-- Main trace entries (references values via IDs)
CREATE TABLE entries (
  run_id INTEGER NOT NULL,
  entry_id INTEGER NOT NULL,
  seq_num INTEGER NOT NULL DEFAULT 0,  -- Discriminates scope vs value rows
  parent_id INTEGER,             -- NULL for top-level entries
  depth INTEGER NOT NULL,

  -- References to interned values (deduplication)
  message_value_id INTEGER REFERENCES value_atoms(value_id),
  location_value_id INTEGER REFERENCES value_atoms(value_id),
  data_value_id INTEGER REFERENCES value_atoms(value_id),

  -- Structure for decomposed sexps
  structure_value_id INTEGER REFERENCES value_atoms(value_id),

  -- Timing
  elapsed_start_ns INTEGER NOT NULL,
  elapsed_end_ns INTEGER,        -- NULL until close_log (only for seq_num=0)

  -- Metadata
  is_result BOOLEAN DEFAULT FALSE,
  track_or_explicit TEXT,        -- 'Diagn', 'Debug', 'Track'

  PRIMARY KEY (run_id, entry_id, seq_num),
  FOREIGN KEY (run_id) REFERENCES runs(run_id)
);
CREATE INDEX idx_parent ON entries(run_id, parent_id);
CREATE INDEX idx_depth ON entries(run_id, depth);
CREATE INDEX idx_message ON entries(message_value_id);
```

**Key Design: `seq_num` Discriminates Row Types**

The composite primary key `(run_id, entry_id, seq_num)` allows multiple rows per logical entry:

- **`seq_num = 0`**: Scope entry (function call, let binding) created by `open_log`
  - Contains: message (function name), location, timing (start/end)
  - Represents non-leaf tree nodes

- **`seq_num > 0`**: Parameter/intermediate values created by `log_value_*`
  - Contains: message (parameter name like "x"), data (parameter value)
  - `seq_num` increments: 1, 2, 3... for multiple parameters
  - Represents leaf tree nodes

- **`seq_num = -1`**: Result value created by `log_value_*` with `is_result=true`
  - Contains: data (function return value)
  - Represents the final result leaf node

Example for `let%debug_sexp foo (x : int) (y : int) : int list`:
```
(run_id=1, entry_id=42, seq_num=0)  → scope: "foo" @ location
(run_id=1, entry_id=42, seq_num=1)  → param: "x" = 7
(run_id=1, entry_id=42, seq_num=2)  → param: "y" = 8
(run_id=1, entry_id=42, seq_num=-1) → result: => (7 8 16)
```

This matches the original design philosophy:
- **Entries** = non-leaf tree nodes (scopes/spans opened by `open_log`)
- **Values** = leaf nodes (parameters/results logged by `log_value_*`)

#### Cross-Run Diff Tables

```sql
-- Results of running PrevRun diff algorithm between consecutive runs
CREATE TABLE entry_id_mappings (
  prev_run_id INTEGER NOT NULL,
  curr_run_id INTEGER NOT NULL,
  prev_entry_id INTEGER NOT NULL,
  curr_entry_id INTEGER NOT NULL,
  match_type TEXT,  -- 'exact', 'fuzzy', 'forced'
  edit_distance INTEGER,
  PRIMARY KEY (prev_run_id, curr_run_id, prev_entry_id),
  FOREIGN KEY (prev_run_id, prev_entry_id) REFERENCES entries(run_id, entry_id),
  FOREIGN KEY (curr_run_id, curr_entry_id) REFERENCES entries(run_id, entry_id)
);
CREATE INDEX idx_curr_mapping ON entry_id_mappings(curr_run_id, curr_entry_id);
```

#### GUI State Persistence

```sql
-- User's expansion state for each run
CREATE TABLE expansion_states (
  state_id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id INTEGER NOT NULL REFERENCES trace_runs(run_id),
  user_id TEXT,  -- Optional: multi-user support

  -- Serialized state
  expanded_entries TEXT NOT NULL,  -- JSON array of entry_ids
  scroll_position INTEGER DEFAULT 0,
  active_search TEXT,              -- Current regex pattern

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_state_run ON expansion_states(run_id, user_id);
```

### Deduplication Implementation

#### Value Interning Module

**Goal:** O(1) insert complexity with automatic deduplication.

```ocaml
module ValueIntern : sig
  val intern : value_type:string -> string -> int
  (** Returns value_id, inserting if new. Uses in-memory cache + DB. *)
end = struct
  (* In-memory cache: content -> value_id *)
  let cache : (string, int) Hashtbl.t = Hashtbl.create 4096

  let hash_content content =
    Digest.string content |> Digest.to_hex

  let intern ~value_type content =
    match Hashtbl.find_opt cache content with
    | Some id -> id  (* Cache hit: O(1) *)
    | None ->
        let value_hash = hash_content content in
        let size_bytes = String.length content in

        (* Try INSERT, handle UNIQUE constraint violation *)
        let id =
          try
            db_exec "INSERT INTO value_atoms
                     (value_hash, value_content, value_type, size_bytes)
                     VALUES (?, ?, ?, ?)"
              [value_hash; content; value_type; string_of_int size_bytes];
            db_last_insert_id ()
          with Sqlite3.Error _ ->
            (* Hash collision or concurrent insert - fetch existing *)
            db_query_single "SELECT value_id FROM value_atoms WHERE value_hash = ?"
              [value_hash]
        in
        Hashtbl.add cache content id;
        id
end
```

#### Selective Interning Strategy

**Always intern** (high duplication, low overhead):
- Variable/function names: `"depth"`, `"loop"`, `"x"`, `"foo"`
- File paths: `"test/test_debug_html.ml"`
- Source locations: `"test/test_debug_html.ml":38:24`

**Conditionally intern** (size > 50 bytes):
- Sexp values: `((first 7) (second 42))`
- Pretty-printed structures
- JSON decomposition trees

**Never intern** (size < 20 bytes, overhead not worth it):
- Small integers: `"42"`, `"0"`, `"1"`
- Short strings: `"foo"`, `"bar"`

**Space Savings Example:**
```
Without interning (19 recursive loop calls):
  "depth" × 19 = 95 bytes
  Location strings × 25 = 750 bytes
  Total: ~845 bytes

With interning:
  "depth" once = 5 bytes
  19 × int reference (4 bytes) = 76 bytes
  Location once = 30 bytes
  25 × int reference = 100 bytes
  Total: ~211 bytes

Savings: 75% reduction
```

### Runtime Implementation

#### Database Module (Low-Level Primitives)

```ocaml
module Database : sig
  type entry_record = {
    entry_id : int;
    run_id : int;
    parent_id : int option;
    depth : int;
    message : string;
    location : string;
    data_content : string option;
    data_structure : string option;  (* JSON for decomposed sexps *)
    is_result : bool;
    track_or_explicit : [ `Diagn | `Debug | `Track ];
    elapsed_start_ns : int64;
    elapsed_end_ns : int64 option;
  }

  val init_db : string -> unit
  (** Initialize database file with schema *)

  val create_run : executable:string -> ?git_commit:string ->
                   ?command_line:string -> unit -> int
  (** Create new trace run, return run_id *)

  val insert_entry : entry_record -> unit
  (** Insert entry with automatic value interning *)

  val update_entry_end : run_id:int -> entry_id:int ->
                          elapsed_end_ns:int64 -> unit
  (** Update elapsed_end_ns when scope closes *)

  val get_children : run_id:int -> parent_id:int option ->
                     limit:int -> offset:int -> entry_record list
  (** Paginated child retrieval for GUI *)
end
```

#### DatabaseBackend Module (Implements Debug_runtime)

```ocaml
module type Database_config = sig
  val db_path : string
  val run_id : int
  val init_log_level : int
  val path_filter : [ `Whitelist of Re.re | `Blacklist of Re.re ] option
  val boxify_sexp_from_size : int      (* Threshold for sexp decomposition *)
  val max_inline_sexp_size : int
  val max_inline_sexp_length : int
end

module DatabaseBackend (Config : Database_config) : Debug_runtime = struct
  open Config

  let log_level = ref init_log_level
  let max_nesting_depth = ref None
  let max_num_children = ref None

  (* Minimal stack - only parent tracking, no tree building *)
  type stack_entry = {
    entry_id : int;
    depth : int;
    message : string;  (* For path filtering *)
  }
  let stack : stack_entry list ref = ref []

  let get_entry_id =
    let global_id = ref 0 in
    fun () -> incr global_id; !global_id

  let should_log ~log_level:level ~fname ~message =
    level <= !log_level &&
    match path_filter with
    | None -> true
    | Some (`Whitelist re) -> Re.execp re (fname ^ "/" ^ message)
    | Some (`Blacklist re) -> not (Re.execp re (fname ^ "/" ^ message))

  let open_log ~fname ~start_lnum ~start_colnum ~end_lnum ~end_colnum
      ~message ~entry_id ~log_level track_or_explicit =
    if should_log ~log_level ~fname ~message then (
      let parent_id = match !stack with [] -> None | h::_ -> Some h.entry_id in
      let depth = List.length !stack in
      let location =
        Printf.sprintf "%s:%d:%d-%d:%d" fname start_lnum start_colnum
                       end_lnum end_colnum
      in
      Database.insert_entry {
        entry_id; run_id; parent_id; depth;
        message;
        location;
        data_content = None;
        data_structure = None;
        is_result = false;
        track_or_explicit;
        elapsed_start_ns = Mtime_clock.elapsed () |> Mtime.Span.to_uint64_ns;
        elapsed_end_ns = None;
      };
      stack := { entry_id; depth; message } :: !stack
    )

  let close_log ~fname:_ ~start_lnum:_ ~entry_id =
    match !stack with
    | [] -> failwith "close_log without open_log"
    | h :: tl when h.entry_id <> entry_id ->
        failwith "close_log entry_id mismatch"
    | _ :: tl ->
        let elapsed_end_ns =
          Mtime_clock.elapsed () |> Mtime.Span.to_uint64_ns
        in
        Database.update_entry_end ~run_id ~entry_id ~elapsed_end_ns;
        stack := tl

  (* Sexp decomposition - see next section *)
  let log_value_sexp ?descr ~entry_id ~log_level ~is_result lazy_sexp =
    (* ... *)
end
```

### Sexp Decomposition Preservation

**Critical:** Must preserve ability to split large sexps into navigable sub-trees.

#### Strategy: JSON Structure Column

Instead of building PrintBox trees, serialize decomposition as JSON:

```ocaml
(* In DatabaseBackend module *)

type sexp_structure =
  | Inline of string                    (* Small sexp: serialize as-is *)
  | Node of string * sexp_structure list  (* (label child1 child2 ...) *)
  | List of sexp_structure list           (* Unlabeled list *)

let rec sexp_to_structure ~depth sexp =
  let open Sexplib0.Sexp in
  if sexp_size sexp < Config.boxify_sexp_from_size then
    Inline (Sexp.to_string_hum sexp)
  else
    match sexp with
    | Atom s -> Inline s
    | List [] -> Inline "()"
    | List [s] -> sexp_to_structure ~depth:(depth+1) s
    | List (Atom label :: body) ->
        Node (label, List.map (sexp_to_structure ~depth:(depth+1)) body)
    | List l ->
        List (List.map (sexp_to_structure ~depth:(depth+1)) l)

(* Serialize to JSON for database storage *)
let rec structure_to_json = function
  | Inline s -> `Assoc ["type", `String "inline"; "value", `String s]
  | Node (label, children) ->
      `Assoc [
        "type", `String "node";
        "label", `String label;
        "children", `List (List.map structure_to_json children)
      ]
  | List children ->
      `Assoc [
        "type", `String "list";
        "children", `List (List.map structure_to_json children)
      ]

let log_value_sexp ?descr ~entry_id ~log_level ~is_result lazy_sexp =
  if log_level <= !log_level then (
    let sexp = Lazy.force lazy_sexp in
    let parent_id = match !stack with [] -> None | h::_ -> Some h.entry_id in
    let depth = List.length !stack in

    (* Full sexp for search *)
    let data_content = Sexp.to_string_hum sexp in

    (* Decomposed structure for GUI rendering *)
    let structure = sexp_to_structure ~depth sexp in
    let data_structure =
      structure_to_json structure |> Yojson.Basic.to_string
    in

    let message = match descr with Some d -> d | None -> "<value>" in

    Database.insert_entry {
      entry_id; run_id; parent_id; depth;
      message;
      location = "";  (* Values don't have source locations *)
      data_content = Some data_content;
      data_structure = Some data_structure;
      is_result;
      track_or_explicit = `Debug;
      elapsed_start_ns = Mtime_clock.elapsed () |> Mtime.Span.to_uint64_ns;
      elapsed_end_ns = Some (Mtime_clock.elapsed () |> Mtime.Span.to_uint64_ns);
    }
  )
```

**GUI Client Rendering:**

```typescript
interface SexpStructure {
  type: 'inline' | 'node' | 'list';
  value?: string;        // For inline
  label?: string;        // For node
  children?: SexpStructure[];  // For node/list
}

class SexpRenderer {
  render(structure: SexpStructure, expanded: Set<string>): ReactNode {
    if (structure.type === 'inline') {
      return <pre>{structure.value}</pre>;
    }

    if (structure.type === 'node') {
      const isExpanded = expanded.has(this.nodeId);
      return (
        <details open={isExpanded}>
          <summary>{structure.label}</summary>
          <ul>
            {structure.children.map(child =>
              <li>{this.render(child, expanded)}</li>
            )}
          </ul>
        </details>
      );
    }

    // Similar for 'list'...
  }
}
```

### GUI Architecture

#### Directory Structure

```
ppx_minidebug/
├── ppx_minidebug.ml           # PPX rewriter (unchanged location)
├── minidebug_runtime.ml/mli   # Runtime library (modified)
├── gui/                        # NEW: Database tracing system
│   ├── server/                 # OCaml backend API
│   │   ├── dune
│   │   ├── db_interface.ml     # Database module
│   │   ├── api_server.ml       # Dream-based REST server
│   │   ├── diff_service.ml     # PrevRun diff adapted for DB
│   │   └── main.ml             # Server entry point
│   ├── client/                 # React/TypeScript frontend
│   │   ├── package.json
│   │   ├── src/
│   │   │   ├── api/
│   │   │   │   └── client.ts   # API client layer
│   │   │   ├── components/
│   │   │   │   ├── TreeView.tsx       # Virtual scrolling tree
│   │   │   │   ├── SearchPanel.tsx    # Regex search UI
│   │   │   │   ├── DiffViewer.tsx     # Cross-run diff display
│   │   │   │   └── SexpRenderer.tsx   # Decomposed sexp display
│   │   │   ├── state/
│   │   │   │   ├── expansionState.ts  # Manage expanded nodes
│   │   │   │   └── crossRunMapping.ts # Entry ID translation
│   │   │   └── App.tsx
│   │   └── vite.config.ts
│   └── README.md               # GUI setup/usage docs
├── test/
├── doc/
└── DESIGN.md                   # This file
```

#### API Endpoints (REST + WebSocket)

**REST API:**

```
GET  /api/runs
  → List all trace runs with metadata
  Response: [{ run_id, timestamp, executable, git_commit }]

GET  /api/runs/:run_id/entries?parent_id={id}&limit={n}&offset={m}
  → Paginated children of a node
  Response: [{ entry_id, message, location, is_result, elapsed_*, ... }]

GET  /api/runs/:run_id/entry/:entry_id
  → Single entry details (including decomposed sexp structure)
  Response: { entry_id, data_content, data_structure, ... }

GET  /api/runs/:run_id/search?pattern={regex}&limit={n}
  → Search values matching regex, return matching entry_ids
  Response: [{ entry_id, match_context, parent_chain }]

GET  /api/runs/:run_id/path/:entry_id
  → Get full parent chain from entry to root
  Response: [entry_id, parent_id, parent_parent_id, ...]

POST /api/runs/:run_id/expansion-state
  Body: { expanded_entries: [id1, id2, ...], scroll_position, search }
  → Save UI state

GET  /api/runs/:run_id/expansion-state
  → Restore saved UI state
  Response: { expanded_entries, scroll_position, search }

POST /api/diffs/compute
  Body: { prev_run_id, curr_run_id }
  → Run PrevRun diff algorithm, populate entry_id_mappings table
  Response: { total_entries, matched, inserted, deleted }

GET  /api/diffs/:prev_run_id/:curr_run_id/mapping/:entry_id
  → Get mapped entry_id from previous run to current run
  Response: { prev_entry_id, curr_entry_id, match_type }
```

**WebSocket (Optional - for live updates during long-running traces):**

```
WS   /api/runs/:run_id/live
  → Stream new entries as they're written to DB
  Message: { entry_id, parent_id, message, ... }
```

#### Client Features

**1. Tree Navigation with Virtual Scrolling**

```typescript
interface TreeNode {
  entry_id: number;
  parent_id: number | null;
  message: string;
  children: TreeNode[] | null;  // null = not loaded yet
  total_children: number;        // For "load more" UI
}

class LazyTreeLoader {
  async expandNode(node: TreeNode) {
    if (node.children !== null) return;  // Already loaded

    const response = await api.getChildren(
      node.entry_id,
      { limit: 10, offset: 0 }
    );

    node.children = response.entries.map(e => ({
      entry_id: e.entry_id,
      parent_id: e.parent_id,
      message: e.message,
      children: null,  // Lazy load on expand
      total_children: e.child_count
    }));
  }

  async loadMoreChildren(node: TreeNode) {
    const currentCount = node.children.length;
    const response = await api.getChildren(
      node.entry_id,
      { limit: 10, offset: currentCount }
    );

    node.children.push(...response.entries.map(/* ... */));
  }
}
```

**2. Client-Side Regex Search with Path Highlighting**

```typescript
class SearchHighlighter {
  private matchedEntries: Set<number> = new Set();
  private highlightedPaths: Set<number> = new Set();

  async search(pattern: string) {
    // Search on server (full-text search on value_content)
    const results = await api.searchEntries(pattern);

    this.matchedEntries = new Set(results.map(r => r.entry_id));

    // Build highlighted paths (walk up to root)
    this.highlightedPaths.clear();
    for (const result of results) {
      const path = await api.getPath(result.entry_id);
      path.forEach(id => this.highlightedPaths.add(id));
    }

    this.renderTree();
  }

  shouldHighlight(entry_id: number): boolean {
    return this.highlightedPaths.has(entry_id);
  }

  isMatch(entry_id: number): boolean {
    return this.matchedEntries.has(entry_id);
  }
}
```

**3. Cross-Run State Persistence**

```typescript
interface ExpansionState {
  run_id: number;
  expanded_entries: number[];
  scroll_position: number;
  active_search?: string;
}

class StateManager {
  async saveState(state: ExpansionState) {
    await api.saveExpansionState(state);
  }

  async restoreState(run_id: number): Promise<ExpansionState> {
    return await api.getExpansionState(run_id);
  }

  // Map state from previous run to current run
  async translateState(
    oldState: ExpansionState,
    newRunId: number
  ): Promise<ExpansionState> {
    // Get entry_id mappings from diff table
    const mappings = await api.getDiffMappings(
      oldState.run_id,
      newRunId
    );

    // Translate each expanded entry_id
    const newExpandedEntries = oldState.expanded_entries
      .map(oldId => mappings[oldId]?.curr_entry_id)
      .filter(id => id !== undefined);

    return {
      run_id: newRunId,
      expanded_entries: newExpandedEntries,
      scroll_position: oldState.scroll_position,
      active_search: oldState.active_search
    };
  }
}
```

### Configuration Migration

**Configs Preserved in Database Backend:**

| Config | Location | Notes |
|--------|----------|-------|
| `log_level` | Runtime | Controls what gets written to DB |
| `path_filter` | Runtime | Filter at write-time (don't store filtered entries) |
| `time_tagged`, `elapsed_times` | Runtime | Metadata stored in DB columns |
| `location_format` | Runtime | Determines location string format |
| `boxify_sexp_from_size` | Runtime | Controls sexp decomposition threshold |
| `max_inline_sexp_size/length` | Runtime | Decomposition parameters |
| `print_entry_ids` | Runtime | Store entry_id in messages or not |

**Configs Moved to Client:**

| Config | Client Location | Notes |
|--------|-----------------|-------|
| `highlight_terms` | Search UI | Client-side regex search |
| `highlight_diffs` | Diff Viewer | Visual diff display mode |
| `exclude_on_path` | Search Logic | Client-side highlight propagation |
| `prune_upto` | Tree Filter | Client filters depth < N |
| `truncate_children` | Pagination | Replaced by limit/offset |
| `values_first_mode` | Display Prefs | Client rendering option |
| `hyperlink` | Link Generator | Client builds links |
| `with_toc_listing`, `toc_flame_graph` | View Modes | Client view selection |

**Configs Obsolete:**

- `backend` (`Text`/`Html`/`Markdown`) - Client always renders HTML
- `snapshot_every_sec` - DB writes are immediate, no snapshotting
- `for_append` - DB handles this natively (INSERT not overwrite)

### Implementation Phases

#### Phase 1: Database Backend (Runtime Changes)

**Goal:** Replace PrintBox backend with DatabaseBackend in minidebug_runtime.ml

**Tasks:**
1. Add SQLite dependency to `dune` file
2. Implement `Database` module with schema creation and CRUD operations
3. Implement `ValueIntern` module for deduplication
4. Implement `DatabaseBackend` functor
5. Add `database_runtime` helper function (like `debug_file`)
6. Preserve `sexp_to_structure` logic from `boxify_sexp`
7. Write tests: instrument test functions, verify DB writes

**Deliverables:**
- `minidebug_runtime.ml` with new `Database` and `DatabaseBackend` modules
- Updated `minidebug_runtime.mli` with new API
- Test case demonstrating DB tracing
- Example `.db` file with trace data

**Dependencies:**
- `sqlite3` OCaml library
- `yojson` for JSON serialization

#### Phase 2: GUI Server (New Package)

**Goal:** REST API for querying trace database

**Tasks:**
1. Create `gui/server/` directory structure
2. Implement `db_interface.ml` with query functions
3. Implement `api_server.ml` using Dream framework
4. Port `PrevRun` diff logic to `diff_service.ml`
5. Add endpoints for pagination, search, state persistence
6. Write API tests

**Deliverables:**
- Runnable server: `dune exec -- gui/server/main.exe --db trace.db --port 8080`
- OpenAPI/Swagger spec documenting endpoints
- Integration tests for API

**Dependencies:**
- `dream` web framework
- `lwt` for async I/O
- `yojson` for JSON responses

#### Phase 3: GUI Client (Web Frontend)

**Goal:** Interactive tree viewer with lazy loading

**Tasks:**
1. Create `gui/client/` with Vite + React + TypeScript
2. Implement API client layer (`api/client.ts`)
3. Build virtual scrolling tree component (`TreeView.tsx`)
4. Implement search UI with highlighting (`SearchPanel.tsx`)
5. Add decomposed sexp renderer (`SexpRenderer.tsx`)
6. Build expansion state manager (`state/expansionState.ts`)

**Deliverables:**
- `npm run dev` launches development server
- `npm run build` produces production bundle
- UI supports: expand/collapse, load-more, search, highlighting

**Dependencies:**
- React 18+
- `react-window` or `react-virtualized` for virtual scrolling
- `react-query` for API state management

#### Phase 4: Cross-Run State Mapping

**Goal:** Preserve UI state across different trace runs

**Tasks:**
1. Add diff computation endpoint to server
2. Implement `entry_id_mappings` table population
3. Build state translation logic in client (`crossRunMapping.ts`)
4. Add UI for "compare with previous run"
5. Persist expansion state to DB

**Deliverables:**
- Diff button triggers `PrevRun` algorithm between selected runs
- Switching runs preserves expansion state via mapping
- UI shows diff highlights (insertions/deletions/changes)

**Dependencies:**
- Phase 2 & 3 complete
- `PrevRun` module adapted for database queries

## No Backward Compatibility Planned: 2.x Branch for Old Behavior

For users preferring static backends and / or mature functionality,
we maintain a 2.x versions branch for bug fixes and potentially backporting
new features.

## Open Questions / Future Work

1. **Multi-threaded tracing:** How to handle concurrent writes to SQLite?
   - Option A: Use WAL mode (Write-Ahead Logging) for better concurrency
   - Option B: Thread-local DBs (one per thread) + merge step
   - Option C: Message queue + single writer thread

2. **Very large traces:** What if database grows to GBs?
   - Implement DB vacuum/cleanup for old runs
   - Add archival mechanism (export to compressed format)
   - Consider partitioning by run_id

3. **Remote tracing:** Should we support streaming traces over network?
   - Client could write to remote DB server (PostgreSQL instead of SQLite)
   - Would enable distributed debugging scenarios

4. **Performance:** Is SQLite fast enough for high-frequency logging?
   - Benchmark: inserts/sec with interning
   - Consider batching writes in transactions
   - May need to tune PRAGMA settings (journal_mode, synchronous, etc.)

5. **Schema evolution:** How to handle DB schema changes across versions?
   - Store schema version in DB metadata table
   - There is no need to worry because it is very unlikely for debugging logs
     to be retained over a long term or not reproducible with a new version.

## References

- Current codebase: `/Users/lukstafi/ppx_minidebug/`
- PrintBox backend: [minidebug_runtime.ml:1143](minidebug_runtime.ml:1143)
- Flushing backend: [minidebug_runtime.ml:266](minidebug_runtime.ml:266)
- PrevRun diff module: [minidebug_runtime.ml:588](minidebug_runtime.ml:588)
- Sexp decomposition: [minidebug_runtime.ml:1975](minidebug_runtime.ml:1975)
- Entry ID generation: [minidebug_runtime.ml:467](minidebug_runtime.ml:467)
- Test examples: `/Users/lukstafi/ppx_minidebug/test/`

## Summary

This migration brings ppx_minidebug into the **interactive debugging era**:

- **From static artifacts → live database**: Crash-safe, memory-efficient, queryable
- **From fixed presentation → flexible UI**: Search, filter, navigate on-the-fly
- **From regenerate-to-highlight → client-side search**: No preprocessing needed
- **From disposable state → persistent state**: Remember your debugging context
- **From duplication → deduplication**: 75%+ space savings via content-addressing

The architecture preserves all critical features (sexp decomposition, diffing, filtering) while moving presentation concerns to where they belong: the client.
