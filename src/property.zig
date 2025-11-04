//! Property-based testing implementation for GhostSpec
//!
//! Property-based testing allows you to specify properties that should hold
//! for all inputs of a certain type, rather than testing specific examples.
//! The framework generates random test cases and tries to find inputs that
//! violate the property.

const std = @import("std");
const generator = @import("generator.zig");

/// Configuration for property-based testing
pub const Config = struct {
    /// Number of test cases to generate
    num_tests: u32 = 100,
    /// Maximum size of generated values
    max_size: u32 = 100,
    /// Random seed for reproducible tests
    seed: ?u64 = null,
    /// Enable shrinking when test fails
    enable_shrinking: bool = true,
    /// Maximum shrinking attempts
    max_shrinking_attempts: u32 = 100,
};

/// Result of a property test
pub const PropertyResult = struct {
    passed: bool,
    num_tests_run: u32,
    counterexample: ?[]const u8 = null,
    shrunk_counterexample: ?[]const u8 = null,
    error_message: ?[]const u8 = null,

    pub fn deinit(self: *PropertyResult, allocator: std.mem.Allocator) void {
        if (self.counterexample) |ce| allocator.free(ce);
        if (self.shrunk_counterexample) |sce| allocator.free(sce);
        if (self.error_message) |em| allocator.free(em);
    }
};

/// Property-based test runner
pub const PropertyTest = struct {
    allocator: std.mem.Allocator,
    config: Config,
    rng: std.Random.DefaultPrng,

    pub fn init(allocator: std.mem.Allocator, config: Config) PropertyTest {
        const seed: u64 = config.seed orelse blk: {
            const instant = std.time.Instant.now() catch unreachable;
            const seed_value: u64 = if (@import("builtin").os.tag == .windows or @import("builtin").os.tag == .uefi or @import("builtin").os.tag == .wasi)
                instant.timestamp
            else
                @as(u64, @intCast(instant.timestamp.sec)) *% 1000000000 +% @as(u64, @intCast(instant.timestamp.nsec));
            break :blk seed_value;
        };
        return PropertyTest{
            .allocator = allocator,
            .config = config,
            .rng = std.Random.DefaultPrng.init(seed),
        };
    }

    /// Run a property test with the given generator and property function
    pub fn runProperty(
        self: *PropertyTest,
        comptime T: type,
        comptime property_fn: fn (T) anyerror!void,
    ) !PropertyResult {
        var result = PropertyResult{
            .passed = true,
            .num_tests_run = 0,
        };

        // Generate and test cases
        for (0..self.config.num_tests) |i| {
            const test_value = try generator.generate(T, self.allocator, self.rng.random(), self.config.max_size);
            defer generator.deinit(T, test_value, self.allocator);

            property_fn(test_value) catch |err| {
                result.passed = false;
                result.num_tests_run = @intCast(i + 1);

                // Convert the failing value to string for reporting
                result.counterexample = try self.valueToString(T, test_value);

                // Try to shrink the counterexample if enabled
                if (self.config.enable_shrinking) {
                    if (try self.shrink(T, test_value, property_fn)) |shrunk| {
                        result.shrunk_counterexample = try self.valueToString(T, shrunk);
                        generator.deinit(T, shrunk, self.allocator);
                    }
                }

                result.error_message = try std.fmt.allocPrint(self.allocator, "Property failed with error: {any}", .{err});
                return result;
            };
        }

        result.num_tests_run = self.config.num_tests;
        return result;
    }

    /// Attempt to shrink a failing test case to a simpler counterexample
    fn shrink(
        self: *PropertyTest,
        comptime T: type,
        original_value: T,
        comptime property_fn: fn (T) anyerror!void,
    ) !?T {
        // For now, implement basic shrinking for integers
        return switch (@typeInfo(T)) {
            .int => |int_info| blk: {
                if (int_info.signedness == .signed) {
                    // For signed integers, try shrinking towards 0
                    var current = original_value;
                    var attempts: u32 = 0;

                    while (attempts < self.config.max_shrinking_attempts) {
                        const candidate = if (current > 0) current - 1 else current + 1;

                        // Test if the shrunk value still fails
                        if (property_fn(candidate)) |_| {
                            // Property passed, can't shrink further
                            break;
                        } else |_| {
                            // Property still fails, continue shrinking
                            current = candidate;
                        }

                        if (current == 0) break;
                        attempts += 1;
                    }

                    break :blk if (current != original_value) current else null;
                } else {
                    // For unsigned integers, shrink towards 0
                    var current = original_value;
                    var attempts: u32 = 0;

                    while (current > 0 and attempts < self.config.max_shrinking_attempts) {
                        const candidate = current - 1;

                        if (property_fn(candidate)) |_| {
                            break;
                        } else |_| {
                            current = candidate;
                        }

                        attempts += 1;
                    }

                    break :blk if (current != original_value) current else null;
                }
            },
            else => null, // TODO: Implement shrinking for other types
        };
    }

    /// Convert a value to string for error reporting
    fn valueToString(self: *PropertyTest, comptime T: type, value: T) ![]const u8 {
        return switch (@typeInfo(T)) {
            .int => std.fmt.allocPrint(self.allocator, "{any}", .{value}),
            .float => std.fmt.allocPrint(self.allocator, "{any}", .{value}),
            .bool => std.fmt.allocPrint(self.allocator, "{any}", .{value}),
            .pointer => |ptr_info| {
                if (ptr_info.child == u8) {
                    // String case
                    return std.fmt.allocPrint(self.allocator, "\"{s}\"", .{value});
                } else {
                    return std.fmt.allocPrint(self.allocator, "ptr@{*}", .{value});
                }
            },
            else => std.fmt.allocPrint(self.allocator, "value of type {s}", .{@typeName(T)}),
        };
    }
};

/// Convenient function to run property tests (matching TODO.md API)
pub fn run(comptime _: type, comptime property_fn: anytype) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = Config{};
    var property_test = PropertyTest.init(allocator, config);

    // Extract the parameter type from the property function
    const prop_fn_info = @typeInfo(@TypeOf(property_fn));
    if (prop_fn_info != .@"fn") {
        @compileError("property_fn must be a function");
    }

    if (prop_fn_info.@"fn".params.len != 1) {
        @compileError("property_fn must take exactly one parameter");
    }

    const ParamType = prop_fn_info.@"fn".params[0].type.?;

    const result = try property_test.runProperty(ParamType, property_fn);
    defer {
        var mut_result = result;
        mut_result.deinit(allocator);
    }

    if (!result.passed) {
        std.debug.print("Property test failed!\n", .{});
        if (result.counterexample) |ce| {
            std.debug.print("Counterexample: {s}\n", .{ce});
        }
        if (result.shrunk_counterexample) |sce| {
            std.debug.print("Shrunk counterexample: {s}\n", .{sce});
        }
        if (result.error_message) |em| {
            std.debug.print("Error: {s}\n", .{em});
        }
        return error.PropertyTestFailed;
    }

    std.debug.print("Property test passed! ({any} tests)\n", .{result.num_tests_run});
}

test "property: integer addition is commutative" {
    const TestFn = struct {
        fn testCommutative(values: struct { a: i32, b: i32 }) !void {
            try std.testing.expect(values.a + values.b == values.b + values.a);
        }
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = Config{ .num_tests = 10 }; // Small number for testing
    var property_test = PropertyTest.init(allocator, config);

    const TupleType = struct { a: i32, b: i32 };
    const result = try property_test.runProperty(TupleType, TestFn.testCommutative);
    defer {
        var mut_result = result;
        mut_result.deinit(allocator);
    }

    try std.testing.expect(result.passed);
    try std.testing.expect(result.num_tests_run == 10);
}

test "property: shrinking works for failing tests" {
    const TestFn = struct {
        fn testAlwaysFails(value: u32) !void {
            if (value > 0) return error.TestFailed;
        }
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = Config{ .num_tests = 10, .enable_shrinking = true };
    var property_test = PropertyTest.init(allocator, config);

    const result = try property_test.runProperty(u32, TestFn.testAlwaysFails);
    defer {
        var mut_result = result;
        mut_result.deinit(allocator);
    }

    try std.testing.expect(!result.passed);
    try std.testing.expect(result.counterexample != null);
}
