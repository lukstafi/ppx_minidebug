# DB-Backed TUI State Migration

## Overview

Migrate the TUI state management from in-memory only to DB-backed, enabling:
1. **TUI Server** (human-facing) — renders to terminal, writes state to DB
2. **CLI Clients** (AI agent-facing) — read state from DB, render text output, write commands

Both sides see identical state. The TUI server owns background computations (search domains), but persists all renderable state to DB so CLI clients can reconstruct the view.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  CLI Client     │────▶│       DB        │◀────│   TUI Server    │
│  (AI agent)     │     │                 │     │  (human user)   │
│                 │     │  tui_state      │     │                 │
│  reads:         │     │  visible_items  │     │  writes:        │
│  - visible_items│     │  search_results │     │  - all state    │
│  - search status│     │  commands queue │     │                 │
│                 │     │                 │     │  reads:         │
│  writes:        │     │                 │     │  - commands     │
│  - commands     │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Benefits Over MCP

1. **No long-running server for AI** — CLI calls only
2. **Human and AI see identical state** — true shared view
3. **SQLite handles concurrency** — no custom IPC
4. **Simpler deployment** — no MCP protocol/transport
5. **Debuggable** — can inspect DB state directly

## DB Schema

## DB Contract (Snapshot + Concurrency)

- **Single-writer**: only the TUI server writes `tui_state`, `tui_visible_items`, and `tui_search_*`.
- **Multi-reader**: CLI clients only read those tables.
- **Command queue**: CLI clients append to `tui_commands`; the TUI server consumes.
- **Atomic snapshot**: every user-visible state change should update `tui_state` + dependent tables in **one SQLite transaction**, so CLI clients never observe a mixed revision (e.g. new cursor but old `tui_visible_items`).
- **Revisioning**: the TUI server increments a monotonically increasing `tui_state.revision` on each committed snapshot. CLI clients can poll this value to detect changes cheaply.
- **SQLite pragmas (recommended)**: enable WAL mode and a busy timeout so readers/writers cooperate under contention.

### Core State Table

```sql
CREATE TABLE tui_state (
  id INTEGER PRIMARY KEY DEFAULT 1,  -- singleton row
  revision INTEGER NOT NULL DEFAULT 0,
  cursor INTEGER NOT NULL DEFAULT 0,
  scroll_offset INTEGER NOT NULL DEFAULT 0,
  show_times BOOLEAN NOT NULL DEFAULT 1,
  values_first BOOLEAN NOT NULL DEFAULT 1,
  current_slot INTEGER NOT NULL DEFAULT 1,  -- 1-4 (S1-S4)
  search_order TEXT NOT NULL DEFAULT 'asc',  -- 'asc' | 'desc'
  quiet_path TEXT,
  search_input TEXT,  -- active input buffer (NULL if not in input mode)
  quiet_path_input TEXT,
  goto_input TEXT,
  max_scope_id INTEGER NOT NULL DEFAULT 0,
  updated_at REAL NOT NULL DEFAULT (unixepoch()),
  -- JSON-encoded complex state:
  expanded_scopes TEXT NOT NULL DEFAULT '[]',  -- JSON array of scope_ids
  unfolded_ellipsis TEXT NOT NULL DEFAULT '[]',  -- JSON array of [parent, start, end]
  status_history TEXT NOT NULL DEFAULT '[]'  -- JSON array of status events
);

-- NOTE: ensure the singleton row exists (id=1). Either INSERT it at table creation
-- time, or make all writers use INSERT ... ON CONFLICT(id) DO UPDATE.
```

### Visible Items Table

```sql
CREATE TABLE tui_visible_items (
  idx INTEGER PRIMARY KEY,  -- position in array (0-indexed)
  -- Content discrimination:
  content_type TEXT NOT NULL,  -- 'entry' | 'ellipsis'
  -- For 'entry' type (references entries table):
  scope_id INTEGER,
  seq_id INTEGER,
  -- For 'ellipsis' type:
  parent_scope_id INTEGER,
  start_seq_id INTEGER,
  end_seq_id INTEGER,
  hidden_count INTEGER,
  -- Display state:
  indent_level INTEGER NOT NULL,
  is_expandable BOOLEAN NOT NULL,
  is_expanded BOOLEAN NOT NULL
);

CREATE INDEX idx_tui_visible_items_content ON tui_visible_items(content_type, scope_id, seq_id);
```

### Search State Tables

```sql
CREATE TABLE tui_search_slots (
  slot_number INTEGER PRIMARY KEY,  -- 1-4
  search_type TEXT NOT NULL,  -- 'regular' | 'extract'
  search_term TEXT,  -- for regular search
  -- for extract search:
  search_path TEXT,  -- JSON array
  extraction_path TEXT,  -- JSON array
  display_text TEXT,
  completed BOOLEAN NOT NULL DEFAULT 0,
  started_at REAL,   -- unixepoch() when kicked off (nullable)
  updated_at REAL,   -- unixepoch() when last updated (nullable)
  error_text TEXT    -- non-NULL iff the search failed / was canceled
);

CREATE TABLE tui_search_results (
  slot_number INTEGER NOT NULL,
  scope_id INTEGER NOT NULL,
  seq_id INTEGER NOT NULL,
  is_match BOOLEAN NOT NULL,  -- true = actual match, false = propagated ancestor
  PRIMARY KEY (slot_number, scope_id, seq_id)
);

CREATE INDEX idx_tui_search_results_lookup ON tui_search_results(scope_id, seq_id);
```

### Command Queue Table

```sql
CREATE TABLE tui_commands (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  client_id TEXT NOT NULL, -- opaque (helps debugging + multi-client support)
  batch_id TEXT,           -- optional grouping for "wait until done"
  command TEXT NOT NULL,  -- e.g., "j", "/error", "g42", "m"
  status TEXT NOT NULL DEFAULT 'pending',  -- 'pending'|'processing'|'done'|'error'
  error_text TEXT,
  created_at REAL NOT NULL DEFAULT (unixepoch()),
  processed_at REAL
);

CREATE INDEX idx_tui_commands_pending ON tui_commands(status, id);
CREATE INDEX idx_tui_commands_by_batch ON tui_commands(batch_id, id);
```

## Implementation Tasks

### Phase 1: DB Schema and Serialization

1. **Add tables to trace DB schema** (`minidebug_db.ml`)
   - Add CREATE TABLE statements for tui_* tables
   - Tables created lazily on first TUI use (not during tracing)

2. **Create serialization module** (`client/tui_db.ml` or extend `interactive.ml`)
   - `write_state : view_state -> unit` — serialize full state to DB
   - `read_state : (module Query.S) -> view_state` — reconstruct state from DB
   - `write_visible_items : visible_item array -> unit`
   - `read_visible_items : unit -> visible_item array`
   - `write_search_results : slot_map -> unit`
   - `read_search_results : unit -> slot_map` (without domain handles)

3. **JSON helpers for complex fields**
   - `expanded` hashtable ↔ JSON array of ints
   - `unfolded_ellipsis` set ↔ JSON array of `[parent, start, end]`
   - `status_history` list ↔ JSON array of event objects

### Phase 2: TUI Server Modifications

4. **Modify TUI main loop** (`client/tui.ml` or `interactive.ml`)
   - After each state change, call `write_state`
   - After `build_visible_items`, call `write_visible_items`
   - After search results update, call `write_search_results`
   - Poll for pending commands from `tui_commands` table

5. **Command queue processing**
   - In render loop, check for unprocessed commands
   - Parse and execute commands from queue
   - Mark commands as `done` / `error` (store `error_text` for CLI diagnostics)
   - Continue with normal keyboard input handling

### Phase 3: CLI Client Implementation

6. **Create CLI TUI commands** (`bin/minidebug_view.ml` or new file)
   ```
   minidebug tui render              # Read state, render text
   minidebug tui cmd <commands...>   # Write commands, wait, render
   minidebug tui status              # Show search status, cursor position
   ```

7. **CLI render function**
   - Read `tui_state` and `tui_visible_items` from DB
   - Reconstruct enough state to call `render_screen`
   - Output text (reuse `minidebug_mcp.ml` text renderer)

8. **CLI command submission**
   - Parse command strings (reuse `parse_command` from `minidebug_mcp.ml`)
   - Insert into `tui_commands` table
   - Optionally poll until the submitted batch is `done`, then render

### Phase 4: Synchronization

9. **Handle concurrent access**
   - Use SQLite transactions for atomic state updates
   - CLI waits for command processing with polling + timeout
   - Consider using SQLite's `PRAGMA busy_timeout`

10. **State versioning** (optional optimization)
    - (Now required) Use `tui_state.revision`
    - CLI can poll revision to detect changes
    - Avoids re-reading unchanged state

### Phase 5: Cleanup and Deprecation

11. **Deprecate MCP server**
    - Mark MCP tools as deprecated in docs
    - Remove MCP server in future release

12. **Update documentation**
    - New CLI commands for AI agents
    - Architecture documentation

## Data Flow Examples

### Human presses 'j' (down) in TUI

1. TUI server receives keypress
2. `handle_command` updates state (cursor += 1)
3. `write_state` persists cursor to DB
4. TUI renders to terminal

### AI agent sends navigation command

1. CLI: `minidebug tui cmd j j enter`
2. CLI inserts 3 commands into `tui_commands`
3. CLI polls `tui_commands` waiting for `processed = 1`
4. TUI server (in render loop) sees pending commands
5. TUI executes commands, updates state, writes to DB
6. TUI marks commands as processed
7. CLI sees commands processed
8. CLI reads `tui_visible_items`, renders text output

### AI agent initiates search

1. CLI: `minidebug tui cmd /error`
2. Command queued, TUI picks it up
3. TUI spawns search Domain (owns the thread)
4. TUI writes `tui_search_slots` with `completed = 0`
5. As results arrive, TUI periodically writes to `tui_search_results`
6. When done, TUI sets `completed = 1`
7. CLI can poll search status and results

## Open Questions

1. **Polling interval** — How often should CLI poll for command completion?
   - Suggestion: 50ms with 5s timeout

2. **Large visible_items** — Should we paginate or always write full array?
   - Suggestion: Full array is fine, typically <10K items

3. **Search result size** — Large searches could have many results
   - Suggestion: Accept it; SQLite handles this well

4. **Multiple CLI clients** — Should we support multiple concurrent AI agents?
   - Suggestion: Yes; require `client_id` to make debugging + batching sane

5. **TUI server not running** — What happens if CLI sends command but no TUI?
   - Suggestion: CLI times out with helpful error message

6. **Unbounded history growth** — `status_history` can grow without bound.
   - Suggestion: cap to last N events in `tui_state.status_history` (e.g. 200).

## Files to Modify

- `minidebug_db.ml` — Add TUI table creation
- `client/interactive.ml` — Add DB read/write functions
- `client/tui.ml` — Integrate DB writes into render loop
- `bin/minidebug_view.ml` — Add `tui` subcommand
- `client/minidebug_mcp.ml` — Reuse text renderer, eventually deprecate

## Testing Strategy

1. **Unit tests** — Serialization roundtrips
2. **Integration tests** — TUI server + CLI client interaction
3. **Stress tests** — Rapid command submission
4. **Concurrency tests** — Multiple CLI clients
