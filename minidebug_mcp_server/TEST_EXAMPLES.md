# MCP Server Manual Testing Examples

This file contains example JSON-RPC requests you can send to the MCP server to test it manually.

## Setup

Start the server with a test database:
```bash
cd /Users/lukstafi/ppx_minidebug
dune build
./_build/default/bin/minidebug_mcp.exe test/debugger_sexp_1.db
```

The server will wait for JSON-RPC requests on stdin. Each request should be a single line of JSON.

## Testing with echo and pipes

You can test individual requests using echo:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | ./_build/default/bin/minidebug_mcp.exe test/debugger_sexp_1.db
```

Or create a file with multiple requests and pipe it:
```bash
cat test_requests.jsonl | ./_build/default/bin/minidebug_mcp.exe test/debugger_sexp_1.db
```

## Example Requests

### 1. Initialize Connection
```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
```

### 2. List Available Tools
```json
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
```

### 3. Initialize Database (if started without DB path)
```json
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"minidebug/init-db","arguments":{"db_path":"test/debugger_sexp_1.db"}}}
```

### 4. List All Runs
```json
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"minidebug/list-runs","arguments":{}}}
```

### 5. Show Database Statistics
```json
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"minidebug/stats","arguments":{}}}
```

### 6. Show Full Trace
```json
{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"minidebug/show-trace","arguments":{}}}
```

With options:
```json
{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"minidebug/show-trace","arguments":{"show_scope_ids":true,"show_times":true,"max_depth":3}}}
```

### 7. Search with Tree Context (Best for Analysis)
```json
{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"minidebug/search-tree","arguments":{"pattern":"fib"}}}
```

With pagination:
```json
{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"minidebug/search-tree","arguments":{"pattern":"fib","limit":5,"offset":0,"show_times":true}}}
```

With quiet_path (stops ancestor propagation):
```json
{"jsonrpc":"2.0","id":10,"method":"tools/call","params":{"name":"minidebug/search-tree","arguments":{"pattern":"result","quiet_path":"fib"}}}
```

### 8. Search Subtree (Pruned View)
```json
{"jsonrpc":"2.0","id":11,"method":"tools/call","params":{"name":"minidebug/search-subtree","arguments":{"pattern":"fib","max_depth":2,"limit":3}}}
```

### 9. Show Specific Scope
```json
{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"minidebug/show-scope","arguments":{"scope_id":1}}}
```

With options:
```json
{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"minidebug/show-scope","arguments":{"scope_id":1,"show_ancestors":true,"show_times":true,"max_depth":5}}}
```

### 10. Get Ancestors
```json
{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"minidebug/get-ancestors","arguments":{"scope_id":5}}}
```

### 11. Get Children
```json
{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"minidebug/get-children","arguments":{"scope_id":1}}}
```

### 12. Show Subtree
```json
{"jsonrpc":"2.0","id":16,"method":"tools/call","params":{"name":"minidebug/show-subtree","arguments":{"scope_id":2,"max_depth":3,"show_ancestors":true,"show_times":false}}}
```

### 13. Search at Specific Depth
```json
{"jsonrpc":"2.0","id":17,"method":"tools/call","params":{"name":"minidebug/search-at-depth","arguments":{"pattern":"fib","depth":2}}}
```

With quiet_path:
```json
{"jsonrpc":"2.0","id":18,"method":"tools/call","params":{"name":"minidebug/search-at-depth","arguments":{"pattern":"result","depth":1,"quiet_path":"main","show_times":true}}}
```

### 14. Search Intersection (Multiple Patterns)
```json
{"jsonrpc":"2.0","id":19,"method":"tools/call","params":{"name":"minidebug/search-intersection","arguments":{"patterns":["fib","result"]}}}
```

With 3 patterns:
```json
{"jsonrpc":"2.0","id":20,"method":"tools/call","params":{"name":"minidebug/search-intersection","arguments":{"patterns":["fib","n","result"],"show_times":true,"limit":5}}}
```

### 15. Search and Extract (DAG Path)
```json
{"jsonrpc":"2.0","id":21,"method":"tools/call","params":{"name":"minidebug/search-extract","arguments":{"search_path":"fib,n","extraction_path":"fib,result"}}}
```

## Testing Cache Behavior

To test search caching, send the same search request twice and check the logs for "Using cached search results":

Request 1 (cache miss):
```json
{"jsonrpc":"2.0","id":100,"method":"tools/call","params":{"name":"minidebug/search-tree","arguments":{"pattern":"fib"}}}
```

Request 2 (cache hit - should be instant):
```json
{"jsonrpc":"2.0","id":101,"method":"tools/call","params":{"name":"minidebug/search-tree","arguments":{"pattern":"fib"}}}
```

Request 3 (different pattern - cache miss):
```json
{"jsonrpc":"2.0","id":102,"method":"tools/call","params":{"name":"minidebug/search-tree","arguments":{"pattern":"result"}}}
```

Request 4 (same as #3 - cache hit):
```json
{"jsonrpc":"2.0","id":103,"method":"tools/call","params":{"name":"minidebug/search-tree","arguments":{"pattern":"result"}}}
```

## Interactive Testing Script

Create a file `test_session.jsonl` with multiple requests:

```jsonl
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"minidebug/stats","arguments":{}}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"minidebug/list-runs","arguments":{}}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"minidebug/search-tree","arguments":{"pattern":"fib"}}}
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"minidebug/search-tree","arguments":{"pattern":"fib"}}}
{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"minidebug/show-scope","arguments":{"scope_id":1}}}
```

Then run:
```bash
cat test_session.jsonl | ./_build/default/bin/minidebug_mcp.exe test/debugger_sexp_1.db
```

## Expected Response Format

All successful responses will have this structure:
```json
{
  "jsonrpc": "2.0",
  "id": <request_id>,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "<tool output here>"
      }
    ],
    "isError": false
  }
}
```

Errors will have:
```json
{
  "jsonrpc": "2.0",
  "id": <request_id>,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "<error message>"
      }
    ],
    "isError": true
  }
}
```

## Debugging Tips

1. **Enable debug logging**: Set `LOGS` environment variable:
   ```bash
   LOGS='*:debug' ./_build/default/bin/minidebug_mcp.exe test/debugger_sexp_1.db
   ```

2. **Check stderr**: The server writes logs to stderr, so you can redirect:
   ```bash
   cat requests.jsonl | ./_build/default/bin/minidebug_mcp.exe test/debugger_sexp_1.db 2>debug.log
   ```

3. **Pretty-print responses**: Pipe through `jq`:
   ```bash
   echo '<json>' | ./_build/default/bin/minidebug_mcp.exe test/debugger_sexp_1.db | jq .
   ```

4. **Test without database** (lazy initialization):
   ```bash
   ./_build/default/bin/minidebug_mcp.exe  # No DB path
   # Then send init-db request
   ```

## Testing Database Switching

Start without a database and use init-db to switch:

```bash
# Start with no DB
./_build/default/bin/minidebug_mcp.exe

# Send these requests:
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"minidebug/init-db","arguments":{"db_path":"test/debugger_sexp_1.db"}}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"minidebug/stats","arguments":{}}}
# Switch to different DB
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"minidebug/init-db","arguments":{"db_path":"test/another.db"}}}
{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"minidebug/stats","arguments":{}}}
```
