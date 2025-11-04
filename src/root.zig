//! GhostSpec - Advanced Testing Framework for Zig
//!
//! GhostSpec provides property-based testing, fuzzing, benchmarking, and mocking
//! capabilities to replace C testing libraries like Google Test, Catch2, and Criterion.
//!
//! Core Features:
//! - Property-based testing with automatic test case generation
//! - Coverage-guided fuzzing with corpus management
//! - Performance testing with benchmarking and regression detection
//! - Dynamic mocking and behavior verification
//! - Parallel test execution with proper isolation
//!
//! Example Usage:
//! ```zig
//! const ghostspec = @import("ghostspec");
//!
//! test "property: addition is commutative" {
//!     try ghostspec.property(i32, testCommutativeAdd);
//! }
//!
//! fn testCommutativeAdd(a: i32, b: i32) !void {
//!     try std.testing.expect(a + b == b + a);
//! }
//! ```

const std = @import("std");

// Re-export all public modules
pub const property_testing = @import("property.zig");
pub const fuzzing = @import("fuzzer.zig");
pub const benchmarking = @import("benchmark.zig");
pub const mocking = @import("mock.zig");
pub const test_runner = @import("runner.zig");
pub const data_generator = @import("generator.zig");
pub const test_reporter = @import("reporter.zig");
pub const colors = @import("colors.zig");
pub const filter = @import("filter.zig");
pub const zion = @import("integration/zion.zig");

// Core API functions matching TODO.md requirements

/// Run property-based tests with automatic test case generation
pub fn property(comptime Generator: type, comptime property_fn: anytype) !void {
    return property_testing.run(Generator, property_fn);
}

/// Run performance benchmarks with timing and memory tracking
pub fn benchmark(comptime name: []const u8, comptime bench_fn: anytype) !void {
    return benchmarking.run(name, bench_fn);
}

/// Create a dynamic mock for the given interface type
pub fn mock(comptime Interface: type) mocking.Mock(Interface) {
    return mocking.Mock(Interface).init();
}

/// Fuzzer for coverage-guided fuzzing with corpus management
pub const Fuzzer = fuzzing.Fuzzer;

/// Test runner for parallel execution and isolation
pub const Runner = test_runner.Runner;

/// Built-in generators for common data types
pub const generators = data_generator.builtin;

/// Test result reporting and analysis
pub const TestResult = test_reporter.TestResult;
pub const BenchmarkResult = benchmarking.BenchmarkResult;

// Version information
pub const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };

test "ghostspec: basic functionality" {
    // Basic smoke test to ensure the framework loads
    const allocator = std.testing.allocator;

    // Test that our core types can be instantiated
    var test_fuzzer = try fuzzing.Fuzzer.init(allocator, fuzzing.FuzzConfig{
        .max_iterations = 1000,
        .timeout_ms = 1000,
        .corpus_dir = null,
    });
    defer test_fuzzer.deinit();
}
