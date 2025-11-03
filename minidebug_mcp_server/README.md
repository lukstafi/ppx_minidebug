# ppx_minidebug MCP Server

Model Context Protocol server for querying and analyzing ppx_minidebug database traces.

## Overview

This MCP server exposes ppx_minidebug's debug trace database capabilities to AI assistants like Claude Desktop, enabling them to directly query and analyze code execution traces.

## Architecture

- **Library**: `minidebug_mcp_server` - Core MCP server implementation
- **Executable**: `minidebug_mcp` - CLI tool that starts the MCP server
- **Protocol**: Uses Anil Madhavapeddy's lightweight MCP implementation (vendored)
- **Transport**: stdio-based JSON-RPC communication (newline-delimited JSON over stdin/stdout)

## Tools Provided

### Database Management
- **minidebug/list-runs** - List all trace runs with metadata (timestamps, command lines, etc.)
- **minidebug/stats** - Show database statistics including size and deduplication metrics

### Trace Viewing
- **minidebug/show-trace** - Show full trace tree with optional depth limiting
  - Supports `max_depth` parameter (recommended: `max_depth=20` for large traces)

### Search & Analysis
- **minidebug/search-tree** - Search with full ancestor context (best for AI analysis)
  - Supports `limit`/`offset` for pagination, `max_depth` for tree depth limiting
- **minidebug/search-subtree** - Search showing only matching subtrees (pruned view)
  - Supports `limit` and `max_depth` parameters
- **minidebug/search-at-depth** - Search summary at specific depth (TUI-like view for large traces)
- **minidebug/search-intersection** - Find scopes matching ALL provided patterns (2-4 patterns)
  - Supports `limit`/`offset` for pagination
- **minidebug/search-extract** - Search DAG path then extract values with change tracking/deduplication
  - Supports `max_depth` parameter

### Navigation
- **minidebug/show-scope** - Show specific scope by ID with descendants
- **minidebug/show-subtree** - Show subtree rooted at scope with ancestor path
- **minidebug/get-ancestors** - Get ancestor chain for a scope
- **minidebug/get-children** - Get child scope IDs for a scope

## Usage

### Command Line
```bash
# Start MCP server for a specific database
minidebug_mcp /path/to/your/trace.db

# Auto-discover database in current directory
minidebug_mcp .
```

### Claude Desktop Configuration

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "ppx_minidebug": {
      "command": "minidebug_mcp",
      "args": ["/absolute/path/to/your/trace.db"]
    }
  }
}
```

Then restart Claude Desktop. The tools will appear in Claude's tool list.

## Output Budget Limiting

To prevent the MCP server from becoming unresponsive due to excessive output, all tools enforce a **4KB output budget** (configurable via `default_output_budget` constant).

### How It Works
- All tools use a bounded formatter that tracks cumulative output bytes
- When the budget is exceeded, output is gracefully truncated
- A helpful message is appended suggesting pagination parameters

### Example Truncation Message
```
[... truncated: output exceeded 1048576 byte limit (wrote 2045231 bytes).
Use limit/offset/max_depth parameters to reduce output.]
```

### Recommended Parameters for Large Traces
- **Pagination**: Use `limit=50` and `offset=0` (increment offset for next page)
- **Depth limiting**: Use `max_depth=20` to limit tree rendering depth
- **Focused searches**: Use specific patterns to narrow results

### Adjusting the Budget
Edit `default_output_budget` in `minidebug_mcp_server.ml` if needed (value in bytes).

## Implementation Status

### ✅ Implemented
- All 13 MCP tools covering all CLI functionality relevant for AI analysis
- Database path management
- Error handling and logging
- Type-safe JSON parameter extraction
- **Output capture refactoring**: All tools use buffer-backed formatters (clean, no Unix pipe hacks)
- **stdio transport**: Uses `run_sdtio_server` for proper stdin/stdout JSON-RPC communication
- **Output budget limiting**: 4KB default limit prevents unresponsive server from excessive output
  - Graceful truncation with helpful error messages suggesting pagination parameters
  - Configurable per-tool if needed

### 🚧 TODO
- Add resource endpoints (expose runs as MCP resources)
- Add prompt templates for common analysis patterns
- Better error messages with context

## Development

### Building
```bash
dune build bin/minidebug_mcp.exe
```

### Testing
```bash
# Generate a test database
cd test
dune exec test/test_debug_sexp.exe

# Run MCP server on it
../_build/default/bin/minidebug_mcp.exe test/debugger_sexp.db
```

### Adding New Tools

1. Add tool registration in `minidebug_mcp_server.ml` using `Mcp_sdk.add_tool`
2. Define JSON schema for parameters
3. Implement handler function that:
   - Extracts parameters using helper functions
   - Opens database with `Minidebug_client.Client.open_db`
   - Performs query operation
   - Returns result via `Tool.create_tool_result`
   - Handles errors gracefully

Example:
```ocaml
let _ =
  add_tool server ~name:"minidebug/my-tool"
    ~description:"Description of what this tool does"
    ~schema_properties:[("param_name", "string", "Parameter description")]
    ~schema_required:["param_name"]
    (fun args ->
       try
         let param = get_string_param args "param_name" in
         let client = Minidebug_client.Client.open_db (get_db_path ()) in
         (* ... perform operation ... *)
         Tool.create_tool_result [Mcp.make_text_content result] ~is_error:false
       with e -> Tool.create_error_result (Printexc.to_string e))
in
```

## Dependencies

### Vendored
- **ocaml-mcp** (Anil Madhavapeddy's implementation) - Core MCP protocol
  - Located in `/vendor/ocaml-mcp/`
  - Lightweight, stdio-focused implementation
  - Libraries: mcp, mcp_sdk, mcp_rpc, mcp_server

### External
- `minidebug_client` - ppx_minidebug's query and rendering library
- `eio_main` - Effect-based I/O for server
- `cohttp-eio` - HTTP support for MCP transport
- `jsonrpc` - JSON-RPC protocol handling
- `logs` - Logging infrastructure

## Protocol Details

- **MCP Version**: 2025-03-26 (Anil's implementation)
- **Transport**: stdio (JSON-RPC over stdin/stdout)
- **Message Format**: JSON-RPC 2.0
- **Encoding**: UTF-8

The server runs as a long-lived process, accepting JSON-RPC requests on stdin and sending responses on stdout. This matches the MCP specification for stdio-based servers.

## Comparison: Anil's vs Thibaut's MCP

We chose Anil's lightweight MCP implementation over Thibaut's more feature-complete one because:

1. **Simpler** - Direct JSON handling, fewer abstractions
2. **Sufficient** - Provides all features needed (tools, resources, stdio transport)
3. **Lighter dependencies** - No `jsonschema`, `ppx_deriving_yojson`, `re`
4. **Easier to vendor** - Fewer files, simpler structure
5. **Good fit** - Our tools are simple query operations that don't need complex type-safe argument parsing

For future enhancements, the architecture supports upgrading to Thibaut's implementation if needed.

## References

- [MCP Specification](https://modelcontextprotocol.io)
- [ppx_minidebug Documentation](https://lukstafi.github.io/ppx_minidebug)
- [Anil's ocaml-mcp](https://github.com/avsm/ocaml-mcp)
