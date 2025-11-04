//! GhostSpec Demo Application
//!
//! This showcases all the features of the GhostSpec testing framework including:
//! - Property-based testing
//! - Fuzzing
//! - Benchmarking
//! - Mocking
//! - Parallel test execution

const std = @import("std");
const ghostspec = @import("ghostspec");

// Example functions to test and benchmark
fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

fn fibonacci(n: u32) u64 {
    if (n <= 1) return n;
    var a: u64 = 0;
    var b: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        const temp = a + b;
        a = b;
        b = temp;
    }
    return b;
}

// Example interface for mocking
const Calculator = struct {
    const Self = @This();

    pub fn add(self: Self, a: i32, b: i32) i32 {
        _ = self;
        return a + b;
    }

    pub fn divide(self: Self, a: i32, b: i32) !f32 {
        _ = self;
        if (b == 0) return error.DivisionByZero;
        return @as(f32, @floatFromInt(a)) / @as(f32, @floatFromInt(b));
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("🚀 GhostSpec Demo - Advanced Testing Framework for Zig\n", .{});
    std.debug.print("=====================================================\n\n", .{});

    // Demo 1: Property-based testing
    std.debug.print("📊 Property-Based Testing Demo\n", .{});
    std.debug.print("────────────────────────────────\n", .{});

    const PropertyTests = struct {
        fn testAdditionCommutative(values: anytype) !void {
            try std.testing.expect(add(values.a, values.b) == add(values.b, values.a));
        }

        fn testAdditionAssociative(values: anytype) !void {
            const left = add(add(values.a, values.b), values.c);
            const right = add(values.a, add(values.b, values.c));
            try std.testing.expect(left == right);
        }
    };

    // Run property tests
    var property_test = ghostspec.property_testing.PropertyTest.init(allocator, ghostspec.property_testing.Config{ .num_tests = 50 });

    std.debug.print("Testing addition commutativity...\n", .{});
    const comm_result = try property_test.runProperty(struct { a: i32, b: i32 }, PropertyTests.testAdditionCommutative);
    defer {
        var mut_result = comm_result;
        mut_result.deinit(allocator);
    }
    std.debug.print("✅ Passed {} tests\n", .{comm_result.num_tests_run});

    std.debug.print("Testing addition associativity...\n", .{});
    const assoc_result = try property_test.runProperty(struct { a: i32, b: i32, c: i32 }, PropertyTests.testAdditionAssociative);
    defer {
        var mut_result = assoc_result;
        mut_result.deinit(allocator);
    }
    std.debug.print("✅ Passed {} tests\n\n", .{assoc_result.num_tests_run});

    // Demo 2: Fuzzing
    std.debug.print("🔍 Fuzzing Demo\n", .{});
    std.debug.print("───────────────\n", .{});

    const FuzzTargets = struct {
        fn parseInteger(input: []const u8) !void {
            // This function should handle any input gracefully
            _ = std.fmt.parseInt(i32, input, 10) catch return;
        }

        fn processString(input: []const u8) !void {
            // Test string processing - should not crash on any input
            if (std.mem.eql(u8, input, "crash_me")) {
                return error.FuzzTestError; // Intentional crash for demo
            }

            // Do some string processing
            for (input) |c| {
                if (c > 127) {
                    // Handle non-ASCII
                    continue;
                }
            }
        }
    };

    const fuzz_config = ghostspec.fuzzing.FuzzConfig{
        .max_iterations = 100,
        .max_input_size = 64,
    };

    var fuzzer = try ghostspec.fuzzing.Fuzzer.init(allocator, fuzz_config);
    defer fuzzer.deinit();

    std.debug.print("Fuzzing integer parser...\n", .{});
    var parse_result = try fuzzer.run(FuzzTargets.parseInteger, 100);
    defer parse_result.deinit(allocator);
    std.debug.print("✅ Ran {} iterations, found {} crashes\n", .{ parse_result.total_iterations, parse_result.crashes_found });

    // Add a problematic input to test crash detection
    try fuzzer.addCorpus("crash_me");

    std.debug.print("Fuzzing string processor (with known crash)...\n", .{});
    var string_result = try fuzzer.run(FuzzTargets.processString, 50);
    defer string_result.deinit(allocator);
    std.debug.print("🔍 Ran {} iterations, found {} crashes\n\n", .{ string_result.total_iterations, string_result.crashes_found });

    // Demo 3: Benchmarking
    std.debug.print("⚡ Benchmarking Demo\n", .{});
    std.debug.print("───────────────────\n", .{});

    const BenchFunctions = struct {
        fn benchFibonacci() void {
            const result = fibonacci(20);
            std.mem.doNotOptimizeAway(result);
        }

        fn benchStringConcatenation(bench_allocator: std.mem.Allocator) void {
            var str: std.ArrayList(u8) = .empty;
            defer str.deinit(bench_allocator);

            var buf: [20]u8 = undefined;
            for (0..100) |i| {
                const formatted = std.fmt.bufPrint(&buf, "item{}", .{i}) catch return;
                str.appendSlice(bench_allocator, formatted) catch return;
            }

            std.mem.doNotOptimizeAway(str.items);
        }

        fn benchArraySum() void {
            var arr: [1000]i32 = undefined;
            for (&arr, 0..) |*item, i| {
                item.* = @intCast(i);
            }

            var sum: i64 = 0;
            for (arr) |item| {
                sum += item;
            }

            std.mem.doNotOptimizeAway(sum);
        }
    };

    const bench_config = ghostspec.benchmarking.BenchConfig{
        .iterations = 100,
        .warmup_iterations = 10,
        .track_memory = true,
    };

    var benchmark = ghostspec.benchmarking.Benchmark.init(allocator, bench_config);

    std.debug.print("Benchmarking Fibonacci(20)...\n", .{});
    const fib_result = try benchmark.runBenchmark("fibonacci", BenchFunctions.benchFibonacci);
    std.debug.print("📈 Avg: {d:.2}ns/iter, Throughput: {d:.2} iter/sec\n", .{ fib_result.averageTimePerIteration(), fib_result.throughputPerSecond() });

    std.debug.print("Benchmarking string concatenation...\n", .{});
    const str_result = try benchmark.runBenchmark("string_concat", BenchFunctions.benchStringConcatenation);
    std.debug.print("📈 Avg: {d:.2}ns/iter", .{str_result.averageTimePerIteration()});
    if (str_result.memory_info) |mem| {
        std.debug.print(", Memory: {} bytes peak\n", .{mem.peak_memory});
    } else {
        std.debug.print("\n", .{});
    }

    std.debug.print("Benchmarking array sum...\n", .{});
    const sum_result = try benchmark.runBenchmark("array_sum", BenchFunctions.benchArraySum);
    std.debug.print("📈 Avg: {d:.2}ns/iter, Throughput: {d:.2} iter/sec\n\n", .{ sum_result.averageTimePerIteration(), sum_result.throughputPerSecond() });

    // Demo 4: Mocking
    std.debug.print("🎭 Mocking Demo\n", .{});
    std.debug.print("──────────────\n", .{});

    var mock_calc = ghostspec.mocking.Mock(Calculator).init();
    defer mock_calc.deinit();

    // Set up mock behavior
    _ = mock_calc.when("add").returnValue(i32, 42);
    mock_calc.when("divide").* = ghostspec.mocking.MockBehavior.err(error.DivisionByZero);

    // Test mock behavior
    std.debug.print("Testing mocked calculator...\n", .{});
    const add_result = try mock_calc.executeCall("add", i32, .{ 10, 20 });
    std.debug.print("✅ Mock add(10, 20) = {} (expected: 42)\n", .{add_result});

    const divide_result = mock_calc.executeCall("divide", f32, .{ 10, 0 });
    if (divide_result) |_| {
        std.debug.print("❌ Expected error but got result\n", .{});
    } else |err| {
        std.debug.print("✅ Mock divide(10, 0) threw error: {}\n", .{err});
    }

    // Verify calls
    try mock_calc.verifyCalled("add", .{ 10, 20 });
    try mock_calc.verifyCalled("divide", .{ 10, 0 });
    std.debug.print("✅ All mock verifications passed\n\n", .{});

    // Demo 5: Test Runner
    std.debug.print("🏃 Test Runner Demo\n", .{});
    std.debug.print("──────────────────\n", .{});

    const TestFunctions = struct {
        fn testAlwaysPass() !void {
            try std.testing.expect(true);
        }

        fn testMath() !void {
            try std.testing.expect(add(2, 3) == 5);
            try std.testing.expect(multiply(4, 5) == 20);
        }

        fn testFibonacci() !void {
            try std.testing.expect(fibonacci(0) == 0);
            try std.testing.expect(fibonacci(1) == 1);
            try std.testing.expect(fibonacci(10) == 55);
        }

        fn testSlowOperation() !void {
            // Simulate a slower test
            std.posix.nanosleep(0, 10 * std.time.ns_per_ms);
            try std.testing.expect(true);
        }
    };

    const runner_config = ghostspec.test_runner.RunnerConfig{
        .max_concurrency = 2,
        .parallel_execution = true,
    };

    var runner = ghostspec.test_runner.Runner.init(allocator, runner_config);
    defer runner.deinit();

    // Create a test suite
    var suite = ghostspec.test_runner.TestSuite.init(allocator, "demo_suite");
    try suite.addTest(ghostspec.test_runner.TestFunction.init("always_pass", TestFunctions.testAlwaysPass));
    try suite.addTest(ghostspec.test_runner.TestFunction.init("math_test", TestFunctions.testMath).withTags(&.{"unit"}));
    try suite.addTest(ghostspec.test_runner.TestFunction.init("fibonacci_test", TestFunctions.testFibonacci).withTags(&.{ "unit", "math" }));
    try suite.addTest(ghostspec.test_runner.TestFunction.init("slow_test", TestFunctions.testSlowOperation).withTags(&.{"slow"}));

    try runner.addSuite(suite);

    std.debug.print("Running test suite with {} tests...\n", .{suite.tests.items.len});
    var test_report = try runner.runAll();
    defer test_report.deinit();

    test_report.printSummary();

    std.debug.print("🎉 GhostSpec Demo Complete!\n", .{});
    std.debug.print("All major features demonstrated successfully.\n", .{});
}

// Some basic tests to verify the framework is working
test "ghostspec: framework integration" {
    // Test that all modules can be imported and basic functionality works
    const allocator = std.testing.allocator;

    // Test property-based testing
    const TestProperty = struct {
        fn testSimple(value: i32) !void {
            try std.testing.expect(value + 0 == value);
        }
    };

    var property_test = ghostspec.property_testing.PropertyTest.init(allocator, ghostspec.property_testing.Config{ .num_tests = 5 });
    const prop_result = try property_test.runProperty(i32, TestProperty.testSimple);
    defer {
        var mut_result = prop_result;
        mut_result.deinit(allocator);
    }
    try std.testing.expect(prop_result.passed);

    // Test mocking
    const MockInterface = struct {
        pub fn getValue() i32 {
            return 42;
        }
    };

    var mock = ghostspec.mocking.Mock(MockInterface).init();
    defer mock.deinit();

    _ = mock.when("getValue").returnValue(i32, 100);
    const mock_result = try mock.executeCall("getValue", i32, .{});
    try std.testing.expect(mock_result == 100);
}

test "ghostspec: basic arithmetic properties" {
    const PropertyFns = struct {
        fn additionIdentity(value: i32) !void {
            try std.testing.expect(add(value, 0) == value);
        }

        fn multiplicationIdentity(value: i32) !void {
            try std.testing.expect(multiply(value, 1) == value);
        }
    };

    try ghostspec.property(i32, PropertyFns.additionIdentity);
    try ghostspec.property(i32, PropertyFns.multiplicationIdentity);
}

test "ghostspec: benchmark math functions" {
    const BenchFns = struct {
        fn benchAdd() void {
            const result = add(123, 456);
            std.mem.doNotOptimizeAway(result);
        }
    };

    try ghostspec.benchmark("addition", BenchFns.benchAdd);
}
