# Landmarks vs ppx_minidebug: Comparison and Inspiration

This document compares [Landmarks](https://github.com/LexiFi/landmarks) (a runtime profiling library by LexiFi) with ppx_minidebug (a debug logging/tracing PPX). It identifies overlap, differences, and concrete improvements to ppx_minidebug inspired by Landmarks' design.

## Overview

Both tools use PPX preprocessing to instrument OCaml code with enter/exit calls around function bodies. However, they serve fundamentally different purposes:

- **Landmarks**: Performance profiling through aggregation. Multiple calls to the same function are merged into a single node with accumulated metrics (total CPU cycles, call count, average time).
- **ppx_minidebug**: Debug tracing with per-call logging. Each function call is recorded individually with argument values, return values, and hierarchical scope context.

## Detailed Comparison

| Aspect | Landmarks | ppx_minidebug |
|--------|-----------|---------------|
| **Purpose** | Performance profiling | Debug logging and tracing |
| **Per-call vs aggregate** | Aggregates: total time, call count, avg per landmark | Logs each call separately with full context |
| **What's recorded** | CPU cycles, allocation, call counts | Argument values, return values, branch paths |
| **Value logging** | No | Yes (type-driven via sexp/show/pp) |
| **Call graph** | Hierarchical with aggregation across call sites | Hierarchical tree/DAG of individual calls |
| **Timing precision** | CPU cycles via `rdtsc` (x86-64) / `cntvct_el0` (ARM64) | Elapsed time via `mtime` (nanosecond monotonic clock) |
| **Memory tracking** | Yes (`Gc.allocated_bytes`, major heap) | No |
| **Auto mode** | `[@@@landmark "auto"]` -- all top-level functions | Scoped -- instruments within `%debug_sexp`/`%track_show` etc. |
| **Output** | Text tree, JSON, web viewer | SQLite database + TUI, MCP server |
| **Zero-cost disable** | `--remove` PPX flag strips annotations | `[%%global_debug_log_level 0]` eliminates generated code |
| **Recursive handling** | Deduplicates by default (only times outermost call) | Logs every call including recursive ones |
| **Thread safety** | `Landmark_threads` module (mutex-based) | Per-runtime instances with thread-local storage |
| **Multi-process** | `export`/`merge` for worker aggregation | Multiple DB files |
| **Additional primitives** | Counters (call counts), Samplers (arbitrary floats) | None beyond value logging |

## Overlap Areas

### 1. PPX Instrumentation of Function Calls

Both PPXs wrap function bodies with enter/exit logic:
- Landmarks: `Landmark.enter lm; try let r = expr in Landmark.exit lm; r with e -> Landmark.exit lm; raise e`
- ppx_minidebug: `Debug_runtime.open_log ...; try ... Debug_runtime.close_log ... with e -> Debug_runtime.log_exception ...; Debug_runtime.close_log ...; raise e`

Both handle exception safety in the generated code.

### 2. Call Graph Hierarchy

Both maintain parent-child scope relationships:
- Landmarks: `SparseArray`-based call graph with cached `last_parent`/`last_son` links for O(1) fast-path on repeated call patterns.
- ppx_minidebug: `entry_parents` table in SQLite with a runtime stack of `entry_info` records.

### 3. Timing

Both measure elapsed time per scope, but with different precision and overhead:
- Landmarks uses hardware cycle counters (`rdtsc` on x86-64, `cntvct_el0` on ARM64), which have minimal overhead (~10 cycles) and very high resolution.
- ppx_minidebug uses `Mtime_clock.elapsed()` (monotonic nanosecond clock). The documentation notes: "times include printing out logs, therefore might not be reliable for profiling."

### 4. Configuration and Zero-Cost Disable

Both support compile-time elimination:
- Landmarks: `--remove` flag in the PPX strips all `[@landmark]` annotations.
- ppx_minidebug: `[%%global_debug_log_level 0]` causes the PPX to generate no runtime calls.

Both also support environment-variable-based runtime configuration.

## Inspiration Points from Landmarks

### 1. Aggregated Profiling View (Implemented)

**Landmarks feature**: `aggregate_landmarks` merges all nodes with the same landmark ID, giving a "flat profile" showing total time per function across all call sites.

**ppx_minidebug improvement**: Added a `profile` command to `minidebug_view` that aggregates timing data from the SQLite database using SQL queries. This provides a Landmarks-style profiling summary (total time, call count, average, min, max per function) without any runtime changes or external dependencies.

Example output:
```
Profiling Summary
=================
Calls  Total       Avg         Min         Max         Function
────────────────────────────────────────────────────────────────
  100  4.52s       45.20ms     12.30ms     98.70ms     foo @ src/main.ml:23
  500  3.01s       6.02ms      1.20ms      15.40ms     bar @ src/util.ml:7
   42  245.00ms    5.83ms      2.10ms      18.90ms     baz @ src/lib.ml:45
```

### 2. Threshold-Based Filtering

**Landmarks feature**: Text output skips nodes below a configurable percentage of their parent's time, keeping output manageable for large profiles.

**Potential ppx_minidebug improvement**: Could add `--min-time` or `--time-threshold` options to `show` and `search-tree` commands to hide entries below a configurable time threshold. This would help focus on performance-relevant scopes.

### 3. Memory Allocation Tracking

**Landmarks feature**: Per-scope `Gc.allocated_bytes` measurement with non-allocating C stubs that access GC internals directly.

**Potential ppx_minidebug improvement**: Could add optional `Gc.allocated_bytes` capture in `open_log`/`close_log`, stored alongside elapsed times. This would complement timing data for memory-sensitive debugging. Note: Landmarks' C stubs are optimized to avoid measurement overhead; a pure OCaml implementation using `Gc.allocated_bytes()` would add some overhead due to float allocation.

### 4. Recursive Call Deduplication

**Landmarks feature**: When `profile_recursive` is false (default), only the outermost call to a recursive function is timed. The `last_self` field tracks whether we are already inside this landmark, and inner recursive calls just increment a counter.

**Potential ppx_minidebug improvement**: Could add a PPX option (e.g., `%debug_sexp_outer`) that only logs the outermost call of recursive functions, significantly reducing log volume for deeply recursive code.

### 5. PPX Code Structure

**Landmarks' PPX** (`mapper.ml`, ~496 lines) is structurally simpler than ppx_minidebug's (~2000 lines), but this reflects different scope rather than code quality issues.

Notable patterns from Landmarks worth studying:

- **Eta-expansion for multi-argument functions**: Landmarks computes function arity and generates eta-expanded wrappers, which preserves tail-call optimization. ppx_minidebug wraps the entire function body, which is necessary for argument logging but prevents TCO.
- **Digest-based module IDs**: Landmarks hashes module content for globally unique landmark IDs. ppx_minidebug uses an incrementing counter, which is simpler and adequate since IDs are only used within a single trace run.
- **Cached parent-child links**: Landmarks' `SparseArray` with `last_parent`/`last_son` caching gives O(1) fast-path for repeated call patterns. This is relevant for ppx_minidebug's runtime performance in high-frequency logging scenarios.

### 6. Counters and Samplers

**Landmarks feature**: Lightweight primitives -- `Landmark.counter` for call counts without timing, and `Landmark.sampler` for recording arbitrary float measurements.

**Potential ppx_minidebug improvement**: Could add lightweight counter/sampler primitives for cases where full value logging is too expensive but some instrumentation is desired.

## Assessment: Using Landmarks as a Library

**Recommendation: Do NOT add Landmarks as a dependency.**

Reasons:

1. **Semantic mismatch**: Landmarks aggregates, ppx_minidebug traces individually. Running both systems on the same code doubles instrumentation overhead without clear benefit.

2. **Cycle counter limitations**: `rdtsc` returns CPU cycles, not wall-clock time. Converting to nanoseconds requires knowing the CPU frequency, which varies with dynamic frequency scaling. ppx_minidebug's `mtime` (monotonic nanoseconds) is more appropriate for absolute timestamps. Cycles are only useful for relative comparisons.

3. **Architecture-specific**: The `rdtsc` C stub only works on x86-64 and ARM64. On other platforms it returns 0. Adding a C dependency complicates the build for all ppx_minidebug users.

4. **Timing accuracy caveat is inherent**: The note that "times include printing out logs" reflects a fundamental property of debug tracing -- value serialization takes time. Switching to `rdtsc` would not fix this; it would just measure the same overhead with higher precision.

5. **Aggregation via SQL is simpler**: The most valuable Landmarks feature (aggregated profiling) can be implemented purely with SQL queries on ppx_minidebug's existing database, with no runtime changes or external dependencies.

## Follow-up Opportunities

These Landmarks-inspired improvements could be filed as separate issues:

1. **GC allocation tracking per scope** (medium effort): Add optional `Gc.allocated_bytes` capture in `open_log`/`close_log`.
2. **Threshold filtering in TUI/CLI** (low effort): Add `--min-time` option to hide entries below a time threshold.
3. **Recursive call deduplication** (medium effort): Add `%debug_sexp_outer` extension that only logs outermost recursive calls.
4. **Self-time/intensity computation** (low effort): Extend the `profile` command to compute self-time (entry time minus children time), inspired by Landmarks' `intensity` function.
5. **Counters/samplers** (medium effort): Add lightweight instrumentation primitives.

## References

- Landmarks repository: https://github.com/LexiFi/landmarks
- Landmarks PPX mapper: `ppx/mapper.ml` (~496 lines)
- Landmarks runtime: `src/landmark.ml` (~894 lines)
- Landmarks graph analysis: `src/graph.ml` (~464 lines)
- Landmarks C stubs: `src/utils.c` (cycle counter, GC allocation)
