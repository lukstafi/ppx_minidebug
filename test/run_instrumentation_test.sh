#!/usr/bin/env bash
# Integration test: verify dune instrumentation backend functionality.
# Builds the fixture with --instrument-with ppx_minidebug, runs it,
# and verifies that a debug database is produced.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Clean up any previous database files
rm -f debugger_main*.db

echo "=== Building instrumentation fixture ==="
dune build test/instrumentation_fixture/main.exe --instrument-with ppx_minidebug 2>&1

echo "=== Running instrumented executable ==="
OUTPUT="$(dune exec test/instrumentation_fixture/main.exe --instrument-with ppx_minidebug 2>&1)"
echo "$OUTPUT"

# Verify the program produced correct output
if echo "$OUTPUT" | grep -q "Hello, world!"; then
  echo "PASS: Program produced expected output"
else
  echo "FAIL: Expected 'Hello, world!' in output"
  rm -f debugger_main*.db
  exit 1
fi

# Verify a database file was created
if ls debugger_main*.db >/dev/null 2>&1; then
  echo "PASS: Debug database created"
  # Verify the database has trace entries
  ENTRIES="$(dune exec bin/minidebug_view.exe -- debugger_main.db show 2>&1 | head -10)"
  if echo "$ENTRIES" | grep -q "greet"; then
    echo "PASS: Database contains 'greet' trace entry"
  else
    echo "FAIL: No 'greet' trace entry found in database"
    echo "Database content:"
    echo "$ENTRIES"
    rm -f debugger_main*.db
    exit 1
  fi
else
  echo "FAIL: No debug database file found"
  rm -f debugger_main*.db
  exit 1
fi

# Clean up
rm -f debugger_main*.db

echo "=== All integration checks passed ==="
