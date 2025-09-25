# Property Testing Guide

GhostSpec's property-testing engine lets you describe invariants and automatically explores thousands of generated inputs to validate them. This guide covers configuration, generators, shrinking, and practical usage patterns.

## Quick Start

```zig
const ghostspec = @import("ghostspec");

fn commutative(values: struct { a: i32, b: i32 }) !void {
    try std.testing.expect(values.a + values.b == values.b + values.a);
}

test "addition is commutative" {
    try ghostspec.property(struct { a: i32, b: i32 }, commutative);
}
```

## Configuration

`ghostspec.property_testing.Config` controls generation and shrinking:

- `num_tests`: how many test cases to attempt (default 100)
- `max_size`: upper bound on collection sizes and integer magnitudes
- `max_shrinking_attempts`: effort spent reducing failing cases
- `timeout_ms`: optional safety valve for long-running tests

```zig
const config = ghostspec.property_testing.Config{
    .num_tests = 500,
    .max_size = 256,
    .max_shrinking_attempts = 200,
};

var prop = ghostspec.property_testing.PropertyTest.init(allocator, config);
try prop.runProperty(MyType, myPropertyFn);
```

## Generators

GhostSpec ships reusable generators in `ghostspec.generators`:

- Primitive numbers (`i32`, `u64`, `f32`, etc.)
- Booleans, characters, strings, byte slices
- Containers (`[]T`, `std.ArrayList`, `std.AutoHashMap`)
- Composite structs and enums (filled using field types)

Compose generators using combinators:

```zig
const generators = ghostspec.generators;
const Pair = struct { lhs: i32, rhs: i32 };

const pair_gen = generators.struct(Pair, .{
    .lhs = generators.intRange(i32, -1000, 1000),
    .rhs = generators.intRange(i32, -1000, 1000),
});

test "custom generator" {
    try ghostspec.propertyWithGenerator(pair_gen, testPair);
}
```

## Shrinking

When a property fails, GhostSpec attempts to shrink the counterexample to a minimal form. You can inspect the shrink trace by enabling verbose output:

```zig
var cfg = ghostspec.property_testing.Config{ .num_tests = 200, .shrink_trace = true };
var prop = ghostspec.property_testing.PropertyTest.init(allocator, cfg);
const result = try prop.runProperty(MyType, failingProperty);
std.debug.print("Counterexample: {any}\n", .{result.counter_example.?});
```

Provide custom shrinkers when the default heuristic is insufficient:

```zig
const Shrinkable = struct {
    value: MyType,
    fn shrink(self: *@This(), allocator: std.mem.Allocator) !?MyType {
        // produce a simpler value or return null when minimal
    }
};
```

## Tips

- Keep property bodies small; delegate heavy logic to helpers.
- Assert high-level invariants (idempotence, roundtrip, ordering) instead of specific outputs.
- Combine with mocks to probe failure modes of dependencies.
- Use tags to group expensive properties and run them selectively.

## When to Reach for Property Tests

Use property-based testing when:

- Functions should satisfy algebraic laws (associativity, identity, ordering).
- Parsers or serializers must round-trip across a large input space.
- You want confidence across wide numeric ranges without hand-written cases.

Avoid when:

- Behavior relies on complex external systems (e.g., networks) without fast mocks.
- Properties are hard to state precisely; invest in clarifying invariants first.

For end-to-end examples see `docs/examples/property-testing.md`.
