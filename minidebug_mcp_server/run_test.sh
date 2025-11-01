#!/bin/bash
# Quick test script for MCP server

set -e

echo "Building MCP server..."
cd ..
dune build bin/minidebug_mcp.exe

echo ""
echo "Running test requests..."
echo "========================"
echo ""

# Check if test database exists
if [ ! -f "test/debugger_sexp_1.db" ]; then
    echo "Test database not found. Generating..."
    cd test
    dune exec test/test_debug_sexp.exe
    cd ..
fi

echo "Sending test requests to MCP server..."
echo "(Look for 'Using cached search results' in logs for request #6)"
echo ""

# Run server with debug logging and pipe test requests
cat minidebug_mcp_server/test_requests.jsonl | \
  ./_build/default/bin/minidebug_mcp.exe test/debugger_sexp_1.db 2>&1 | \
  head -100

echo ""
echo "Test complete!"
echo ""
echo "For more examples, see: minidebug_mcp_server/TEST_EXAMPLES.md"
