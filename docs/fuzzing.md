# Fuzzing Guide

Fuzzing stresses code with random and mutated inputs to uncover crashes and unexpected states. GhostSpec integrates fuzzing alongside property tests and benchmarks.

## Basic Usage

```zig
const ghostspec = @import("ghostspec");

test "fuzz json parser" {
    const fuzz_config = ghostspec.fuzzing.FuzzConfig{
        .max_iterations = 1_000,
        .max_input_size = 1 << 10,
        .timeout_ms = 1_000,
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var fuzzer = try ghostspec.fuzzing.Fuzzer.init(arena.allocator(), fuzz_config);
    defer fuzzer.deinit();

    var result = try fuzzer.run(parseJson, fuzz_config.max_iterations);
    defer result.deinit(arena.allocator());

    std.debug.print("Crashes found: {}\n", .{result.crashes_found});
}
```

## Corpus Management

- `Fuzzer.addCorpus([]const u8)` seeds known interesting inputs.
- `Fuzzer.persistCorpus(path)` saves findings; re-load using `Fuzzer.loadCorpus`.
- GhostSpec automatically minimizes crashing inputs before saving.

## Configuration Options

| Field | Description |
| --- | --- |
| `max_iterations` | Hard ceiling on iterations per run |
| `max_input_size` | Upper bound for generated payload length |
| `timeout_ms` | Cancels fuzz campaign if exceeded |
| `mutation_depth` | Controls aggressiveness of mutations |
| `parallel` | (Planned) run mutations concurrently |

## Reporting

`FuzzResult` contains:

- `total_iterations`
- `crashes_found`
- `unique_crashes`
- `corpus_size`
- `duration_ns`

Use `result.exportCrashArtifacts(dir)` to write failing inputs and stack traces.

## Best Practices

- Start with fast, deterministic target functions (parsers, validators).
- Add oracles: return errors for invalid states rather than panicking silently.
- Seed with structured inputs to guide the fuzzer toward valid formats.
- Pair with property tests for invariants after processing fuzzed data.
- Capture logs and stack traces to reproduce crashes locally.

## Integrating into CI

- Run fuzz jobs with modest iteration counts (e.g., 2,000) for smoke detection.
- Schedule longer “fuzz farms” nightly using the same harness and persistent corpus.
- Publish artifacts for triage when crashes occur.

For real-world use cases, visit `docs/examples/fuzzing.md`.
