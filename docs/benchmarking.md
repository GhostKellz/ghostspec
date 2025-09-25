# Benchmarking Guide

GhostSpec ships an opinionated benchmarking harness that balances ease-of-use with statistically meaningful results.

## Getting Started

```zig
const ghostspec = @import("ghostspec");

test "benchmark matrix multiply" {
    try ghostspec.benchmark("matmul", benchMatMul, .{
        .iterations = 500,
        .warmup_iterations = 50,
        .track_memory = true,
    });
}

fn benchMatMul(b: *ghostspec.Benchmark) !void {
    b.iterate(|| {
        var matrix = try createMatrix();
        defer matrix.deinit();
        const result = try matrix.multiply(otherMatrix);
        std.mem.doNotOptimizeAway(result);
    });
}
```

## Configuration

`ghostspec.benchmarking.BenchConfig` options:

| Field | Purpose |
| --- | --- |
| `iterations` | Minimum steady-state iterations to execute |
| `warmup_iterations` | Iterations run before recording metrics |
| `max_time_ms` | Hard cap on total benchmark duration |
| `target_precision` | Coefficient of variation threshold for early stop |
| `track_memory` | Capture allocation/frees during benchmark |

## Metrics Captured

- **Total time** and **per-iteration average**
- **Throughput** (iterations per second)
- **Percentiles** (p50, p95, p99)
- **Standard deviation** (variability)
- **Memory stats** (allocations, bytes, peak) when enabled

Sample output:

```
Benchmark: matmul
  Iterations: 5000
  Total time: 42.13ms
  Avg: 8.42µs/iter  StdDev: 0.51µs  p95: 9.10µs  p99: 9.45µs
  Memory: +64 bytes alloc, 0 bytes leak
```

## Writing Reliable Benchmarks

- Keep work inside `b.iterate` pure; avoid i/o or allocations unless measured.
- Use `std.mem.doNotOptimizeAway` to prevent Zig from optimizing the result.
- If setup is expensive, move to an outer scope and pass handles into the closure.
- Favor fixed-size data to reduce noise; when measuring scaling, parameterize via inline loops.
- Run benchmarks under `ReleaseFast` when evaluating production code.

## Regression Guardrails

Integrate benchmarks into CI by saving baseline stats and comparing against a tolerance window. GhostSpec exposes helpers to store regression histories (planned for RC2), but today you can export JSON via `BenchmarkResult.toJson` and assert thresholds manually.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| High variance between runs | Increase warmup iterations; pin CPU frequency; reduce background tasks |
| Benchmark never reaches target precision | Set `target_precision = null` and rely on `iterations`/`max_time_ms` |
| Memory stats always zero | Ensure `track_memory = true` and allocator instrumentation enabled |

See `docs/examples/benchmarking.md` for comprehensive scenarios.
