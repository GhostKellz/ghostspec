# GhostSpec Architecture Overview

GhostSpec is structured as a collection of focused Zig modules that cooperate through a small set of shared abstractions. This document explains the major components, how data flows between them, and the key extension points for contributors.

## High-Level Layout

```
src/
├── root.zig          # Public entry point that re-exports the framework surface
├── property.zig      # Property-based testing engine and generators
├── benchmark.zig     # Benchmark harness and statistics utilities
├── fuzzer.zig        # Coverage-guided fuzzing primitives
├── mock.zig          # Dynamic mocking utilities
├── runner.zig        # Test discovery, scheduling, and execution
├── reporter.zig      # Structured result reporting (stdout, JSON-ready)
├── generator.zig     # Shared random data generators used across modules
├── main.zig          # Standalone CLI entry point (if built as executable)
└── ...               # Support modules (async utilities, helpers)
```

At the boundary we expose a single import:

```zig
const ghostspec = @import("ghostspec");
```

Consumers interact with type-safe APIs (`ghostspec.property`, `ghostspec.benchmark`, `ghostspec.mock`, etc.) while the runtime handles execution orchestration and reporting.

## Module Responsibilities

### `root.zig`
- Re-exports public APIs from submodules.
- Houses shared configuration structs (e.g., property testing config).
- Central place to evolve surface area without leaking internal details.

### `property.zig`
- Implements combinators for property-based testing.
- Owns shrinking, generator composition, and failure minimization.
- Depends on `generator.zig` for reusable data generation.

### `benchmark.zig`
- Provides benchmarking harness that records iterations, timing, and memory stats.
- Exposes hooks to integrate with reporters.
- Coordinates warm-up, steady-state, and statistical aggregation.

### `fuzzer.zig`
- Implements coverage-guided fuzz loops that reuse property generators.
- Abstracts corpus management so users can plug their own storage.

### `mock.zig`
- Creates dynamic mocks using Zig's comptime reflection.
- Tracks expectations, call verification, and argument matchers.

### `runner.zig`
- Discovers tests compiled into the module.
- Schedules execution across available threads (async-friendly).
- Notifies reporters and aggregates final status.

### `reporter.zig`
- Formats structured events (start, success, failure, benchmark sample).
- Provides default CLI reporter; extensible for JSON/HTML in future.

### `generator.zig`
- Shared library of primitive generators (numbers, strings, collections).
- Provides combinators for custom generator construction.

## Execution Flow

1. **Discovery**: Zig collects `test` declarations; GhostSpec registers additional metadata for property/benchmark/fuzz cases.
2. **Scheduling**: `runner.zig` builds a queue of units of work and drives them asynchronously.
3. **Execution**:
   - Property tests call into `property.zig` to generate inputs, execute user callbacks, and shrink on failure.
   - Benchmarks run under `benchmark.zig`, which emits statistical samples.
   - Fuzzers in `fuzzer.zig` leverage the same runner loop with corpus feedback.
4. **Reporting**: `reporter.zig` receives structured events and prints progress plus summaries.
5. **Exit**: Runner aggregates pass/fail counts and returns diagnostics to Zig's test harness.

## Configuration Surfaces

- **Property Testing**: `PropertyConfig` (num tests, max shrink attempts, max size).
- **Benchmarking**: `BenchConfig` (warmup iterations, max time, precision targets).
- **Fuzzing**: `FuzzConfig` (mutation depth, corpus paths, timeout).
- **Mocks**: Expectation builder DSL with argument matchers and call counts.

Configurations live in `root.zig` so that users only import a single module.

## Data Flow Diagram

```
 User Test Code
       │
       ▼
`ghostspec.property` ──▶ Property Engine ──▶ Runner ──▶ Reporter ──▶ Console/CI
`ghostspec.benchmark` ─▶ Benchmark Harness ─┘         └─▶ Metrics (future)
`ghostspec.mock` ─────▶ Mock Registry ───────────────▶ Property/Bench Execution
```

## Extension Points

- **Custom Generators**: Compose via `generator.zig` primitives.
- **Custom Reporters**: Implement reporter interface (WIP) and register with runner.
- **Custom Corpus Storage**: Plug into fuzz harness via callbacks.
- **Mock Matchers**: Provide user-defined matcher functions.

## Future Directions

- Modular reporters (JSON, HTML dashboards).
- Distributed property test execution.
- Incremental test impact analysis.

Use this guide when orienting new contributors or evaluating architectural changes.
