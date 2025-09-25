# Migration Guide

This guide helps teams move from other popular testing frameworks to GhostSpec. It focuses on the most common patterns from Zig's built-in testing, GoogleTest, Catch2, and Criterion.

## From Zig's Built-in Testing

| Built-in Zig | GhostSpec |
| --- | --- |
| `test "foo" { ... }` | `test "foo" { try ghostspec.expect(...); }` or keep existing assertions |
| Manual property loops | `try ghostspec.property(T, propertyFn);` |
| Benchmark via manual timers | `try ghostspec.benchmark("name", benchFn);` |

Steps:
1. Import GhostSpec: `const ghostspec = @import("ghostspec");`
2. Replace ad-hoc random loops with `ghostspec.property`.
3. Use `ghostspec.benchmark` for timed measurements.
4. Replace manual mock structs with `ghostspec.mocking.Mock`.

## From GoogleTest / Catch2 / Criterion (C/C++)

| Concept | GhostSpec Equivalent |
| --- | --- |
| `TEST_F`, `TEST_CASE` | `test "name"` blocks inside Zig files |
| Assertions (`EXPECT_EQ`) | `try std.testing.expect(...)` or helper wrappers |
| Property-based plugins (RapidCheck) | `ghostspec.property` |
| Benchmarks (`BENCHMARK`, Criterion macros) | `ghostspec.benchmark` |
| Fixtures | Setup/teardown via Zig `defer` or wrapper functions |
| Mocks (gMock) | `ghostspec.mocking.Mock(Type)` |

Migration tips:
- Port fixtures as helper functions returning structs with `defer` cleanup.
- Translate matcher macros into Zig functions returning `bool` and wrap with `try std.testing.expect`.
- Replace `EXPECT_THROW` with `try std.testing.expectError(...)`.

## Checklist

1. **Dependencies**: Remove legacy testing libraries from build system and add GhostSpec via `zig fetch --save`.
2. **Test Entrypoint**: Use `zig build test` to run suite; configure `build.zig` accordingly.
3. **Randomness**: Ensure deterministic seeding when migrating from frameworks with global RNGs.
4. **Parallelism**: GhostSpec runner supports concurrency; set `RunnerConfig` to match previous behavior.
5. **CI Pipelines**: Update workflows to call `zig build test` and optionally `tools/run-coverage.sh`.

## Example Translation

```cpp
// Catch2
TEST_CASE("vector push_back") {
    std::vector<int> v;
    v.push_back(1);
    REQUIRE(v.size() == 1);
}
```

```zig
// GhostSpec
const std = @import("std");

test "vector push_back" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();

    try list.append(1);
    try std.testing.expect(list.items.len == 1);
}
```

For more advanced conversions, see `docs/examples/` for idiomatic GhostSpec patterns.
