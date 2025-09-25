# GhostSpec Documentation

Welcome to the official documentation for **GhostSpec**, the advanced testing framework for Zig!

## 📚 Documentation Overview

- **[Getting Started](./getting-started.md)** - Quick start guide and installation
- **[Property Testing](./property-testing.md)** - Automatic test case generation
- **[Benchmarking](./benchmarking.md)** - Performance testing and regression detection
- **[Fuzzing](./fuzzing.md)** - Coverage-guided fuzz testing
- **[Mocking](./mocking.md)** - Dynamic mock objects and behavior verification
- **[Architecture Overview](./architecture.md)** - Internal module map and data flow
- **[API Reference](./api-reference.md)** - Complete API documentation
- **[Examples](./examples/)** - Real-world usage examples
- **[Migration Guide](./migration-guide.md)** - Migrating from other testing frameworks
- **[Best Practices](./best-practices.md)** - Patterns for maintainable suites
- **[Troubleshooting](./troubleshooting.md)** - Fix common issues quickly
- **[Contributor Guide](../CONTRIBUTING.md)** - Onboarding for new contributors
- **[Issue Triage Process](./process/triage.md)** - Keep the tracker healthy

## 🚀 Quick Links

- [GitHub Repository](https://github.com/ghostkellz/ghostspec)
- [Issue Tracker](https://github.com/ghostkellz/ghostspec/issues)
- [Discussions](https://github.com/ghostkellz/ghostspec/discussions)

## 📖 What is GhostSpec?

GhostSpec is a comprehensive testing framework for Zig that provides:

- **Property-based testing** with automatic test case generation
- **Performance benchmarking** with memory tracking and statistics
- **Coverage-guided fuzzing** for finding edge cases
- **Dynamic mocking** using Zig's comptime features
- **Parallel test execution** with proper isolation
- **Rich reporting** in multiple formats

Built with performance and developer experience in mind, GhostSpec aims to be the gold standard for testing in Zig.

## 🎯 Key Features

### Property-Based Testing
```zig
const ghostspec = @import("ghostspec");

test "addition is commutative" {
    try ghostspec.property(struct{ a: i32, b: i32 }, testAdditionCommutative);
}

fn testAdditionCommutative(values: struct{ a: i32, b: i32 }) !void {
    try std.testing.expect(values.a + values.b == values.b + values.a);
}
```

### Performance Benchmarking
```zig
test "benchmark my function" {
    try ghostspec.benchmark("my_function", benchmarkMyFunction);
}

fn benchmarkMyFunction() !void {
    // Your code to benchmark
    var result = myExpensiveFunction();
    std.mem.doNotOptimizeAway(result);
}
```

### Dynamic Mocking
```zig
const MockInterface = struct {
    pub fn getValue(self: *const @This()) i32 { return 42; }
};

test "mock behavior" {
    var mock = ghostspec.mocking.Mock(MockInterface).init();
    defer mock.deinit();

    mock.when("getValue").returnValue(i32, 100);
    const result = try mock.executeCall("getValue", i32, .{});
    try std.testing.expect(result == 100);
}
```

## 🏗️ Architecture

GhostSpec is built with a modular architecture:

- **`property.zig`** - Property-based testing implementation
- **`benchmark.zig`** - Performance benchmarking with memory tracking
- **`fuzzer.zig`** - Coverage-guided fuzzing infrastructure
- **`mock.zig`** - Dynamic mocking system
- **`runner.zig`** - Parallel test execution engine
- **`reporter.zig`** - Test result reporting and formatting
- **`root.zig`** - Main API and module exports

## 📋 Requirements

- **Zig**: 0.13.0 or later
- **Platform**: Linux, macOS, Windows, WebAssembly
- **Dependencies**: None (pure Zig implementation)

## 📄 License

GhostSpec is licensed under the MIT License. See [LICENSE](../LICENSE) for details.

---

*Built with ❤️ for the Zig community*</content>
<parameter name="filePath">/data/projects/ghostspec/docs/README.md