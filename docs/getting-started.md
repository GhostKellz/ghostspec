# Getting Started with GhostSpec

This guide will get you up and running with GhostSpec in minutes!

## 📦 Installation

### Option 1: Zig Fetch (Recommended)

```bash
zig fetch --save https://github.com/ghostkellz/ghostspec/archive/refs/heads/main.tar.gz
```

Then add to your `build.zig.zon`:

```zig
.dependencies = .{
    .ghostspec = .{
        .url = "https://github.com/ghostkellz/ghostspec/archive/refs/heads/main.tar.gz",
        .hash = "UPDATE_WITH_ACTUAL_HASH",
    },
},
```

### Option 2: Git Submodule

```bash
git submodule add https://github.com/ghostkellz/ghostspec libs/ghostspec
```

### Option 3: Manual Download

Download the latest release from [GitHub](https://github.com/ghostkellz/ghostspec/releases) and extract to your project.

## 🚀 Quick Start

### 1. Add GhostSpec to your build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    // ... your existing build configuration ...

    const ghostspec = b.dependency("ghostspec", .{});
    const ghostspec_mod = ghostspec.module("ghostspec");

    // Add to your test executable
    const test_exe = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_exe.root_module.addImport("ghostspec", ghostspec_mod);

    // ... rest of your build configuration ...
}
```

### 2. Write Your First Test

Create a test file (e.g., `src/main.zig`):

```zig
const std = @import("std");
const ghostspec = @import("ghostspec");

test "basic functionality" {
    // Your regular Zig tests
    try std.testing.expect(1 + 1 == 2);
}

test "property: addition is commutative" {
    // Property-based testing
    try ghostspec.property(struct{ a: i32, b: i32 }, testAdditionCommutative);
}

fn testAdditionCommutative(values: struct{ a: i32, b: i32 }) !void {
    try std.testing.expect(values.a + values.b == values.b + values.a);
}

test "benchmark: string concatenation" {
    // Performance benchmarking
    try ghostspec.benchmark("string_concat", benchmarkStringConcat);
}

fn benchmarkStringConcat() !void {
    var buffer = std.ArrayList(u8).initCapacity(std.heap.page_allocator, 1000);
    defer buffer.deinit();

    for (0..100) |_| {
        try buffer.appendSlice("hello");
    }

    std.mem.doNotOptimizeAway(&buffer);
}
```

### 3. Run Your Tests

```bash
zig build test
```

You should see output like:
```
Property test passed! (100 tests)
Benchmark: string_concat
  Iterations: 1000
  Total time: 1.23ms
  Average: 1.23µs/iter
All tests passed.
```

## 🎯 Core Concepts

### Property-Based Testing

Instead of writing individual test cases, you write properties that should always hold:

```zig
test "sort maintains length" {
    try ghostspec.property([]i32, testSortMaintainsLength);
}

fn testSortMaintainsLength(arr: []i32) !void {
    const original_len = arr.len;
    std.mem.sort(i32, arr, {}, std.sort.asc(i32));
    try std.testing.expect(arr.len == original_len);
}
```

GhostSpec will automatically generate thousands of test cases!

### Benchmarking

Measure performance with statistical analysis:

```zig
test "benchmark my algorithm" {
    try ghostspec.benchmark("my_algorithm", benchmarkMyAlgorithm);
}

fn benchmarkMyAlgorithm() !void {
    // Setup
    var data = try createTestData();
    defer data.deinit();

    // Benchmark this code
    var result = myAlgorithm(data.items);
    std.mem.doNotOptimizeAway(result);
}
```

### Mocking

Create test doubles for dependencies:

```zig
const DatabaseInterface = struct {
    pub fn save(self: *const @This(), data: []const u8) !void { /* ... */ }
    pub fn load(self: *const @This(), id: u32) ![]const u8 { /* ... */ }
};

test "user service saves data" {
    var mock_db = ghostspec.mocking.Mock(DatabaseInterface).init();
    defer mock_db.deinit();

    // Setup expectations
    mock_db.when("save").returnValue(void, {});

    var service = UserService.init(&mock_db);

    // Exercise
    try service.saveUser("John Doe");

    // Verify
    try mock_db.verify("save").called();
}
```

## 🛠️ Configuration

### Property Testing Configuration

```zig
const config = ghostspec.property_testing.Config{
    .num_tests = 1000,           // Number of test cases to generate
    .max_size = 100,             // Maximum size for generated values
    .max_shrinking_attempts = 100, // How hard to try to shrink failing cases
};

var prop_test = ghostspec.property_testing.PropertyTest.init(allocator, config);
```

### Benchmark Configuration

```zig
const config = ghostspec.benchmarking.BenchConfig{
    .warmup_iterations = 100,    // Iterations to run before measuring
    .min_iterations = 1000,      // Minimum iterations to run
    .max_time_ms = 1000,         // Maximum time to spend benchmarking
    .target_precision = 0.01,    // Desired coefficient of variation
};

var bench = ghostspec.benchmarking.Benchmark.init(allocator, config);
```

## 📊 Understanding Results

### Property Test Output
```
Property test passed! (100 tests)
```
- ✅ All generated test cases passed
- 🔄 Test case generation and shrinking worked correctly

### Benchmark Output
```
Benchmark: my_function
  Iterations: 10000
  Total time: 45.67ms
  Average: 4.57µs/iter
  Stats:
    Mean: 4.57µs
    Median: 4.52µs
    Std Dev: 0.23µs
    Min: 4.12µs
    Max: 5.89µs
    P95: 4.89µs
    P99: 5.12µs
```
- 📈 Statistical analysis of performance
- 🎯 Measures central tendency and variability
- 🚨 Helps detect performance regressions

## 🐛 Troubleshooting

### Common Issues

**"Module 'ghostspec' not found"**
- Make sure you've added the dependency to `build.zig.zon`
- Verify the module is imported in your `build.zig`

**"Property test failed"**
- Check your property logic - it might not hold for all inputs
- Use the shrinking information to understand the minimal failing case

**"Benchmark results are inconsistent"**
- Add warmup iterations to stabilize performance
- Run benchmarks multiple times and take the median
- Isolate benchmarks from other system activity

### Getting Help

- 📖 [Full Documentation](../docs/)
- 💬 [GitHub Discussions](https://github.com/ghostkellz/ghostspec/discussions)
- 🐛 [Issue Tracker](https://github.com/ghostkellz/ghostspec/issues)

## 🎉 Next Steps

Now that you're set up, explore:

1. **[Property Testing Guide](./property-testing.md)** - Advanced property testing techniques
2. **[Benchmarking Guide](./benchmarking.md)** - Performance analysis best practices
3. **[Examples Directory](./examples/)** - Real-world usage patterns
4. **[API Reference](./api-reference.md)** - Complete function documentation

Happy testing with GhostSpec! 🚀</content>
<parameter name="filePath">/data/projects/ghostspec/docs/getting-started.md