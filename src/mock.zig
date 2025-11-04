//! Mocking and stubbing system for GhostSpec
//!
//! Provides dynamic mocks, behavior verification, and stubbing capabilities
//! using Zig's powerful comptime features for type-safe mocking.

const std = @import("std");

/// Call verification mode
pub const VerifyMode = enum {
    never,
    once,
    exactly,
    at_least,
    at_most,
    times,
};

/// Verification specification
pub const Verification = struct {
    mode: VerifyMode,
    count: u32 = 0,

    pub fn never() Verification {
        return Verification{ .mode = .never };
    }

    pub fn once() Verification {
        return Verification{ .mode = .once };
    }

    pub fn exactly(count: u32) Verification {
        return Verification{ .mode = .exactly, .count = count };
    }

    pub fn atLeast(count: u32) Verification {
        return Verification{ .mode = .at_least, .count = count };
    }

    pub fn atMost(count: u32) Verification {
        return Verification{ .mode = .at_most, .count = count };
    }

    pub fn times(count: u32) Verification {
        return Verification{ .mode = .times, .count = count };
    }
};

/// Represents a function call with arguments
pub const Call = struct {
    function_name: []const u8,
    args_hash: u64,
    timestamp: i64,

    pub fn matches(self: Call, name: []const u8, args_hash: u64) bool {
        return std.mem.eql(u8, self.function_name, name) and self.args_hash == args_hash;
    }
};

/// Mock behavior configuration
pub const MockBehavior = struct {
    return_value: ?*anyopaque = null,
    should_panic: bool = false,
    should_error: bool = false,
    error_value: anyerror = error.MockError,
    call_count: u32 = 0,
    max_calls: ?u32 = null,

    pub fn returnValue(self: *MockBehavior, comptime T: type, value: T) void {
        const boxed_value = std.heap.page_allocator.create(T) catch unreachable;
        boxed_value.* = value;
        self.return_value = boxed_value;
    }

    pub fn panic() MockBehavior {
        return MockBehavior{
            .should_panic = true,
        };
    }

    pub fn err(error_value: anyerror) MockBehavior {
        return MockBehavior{
            .should_error = true,
            .error_value = error_value,
        };
    }

    pub fn times(max: u32) MockBehavior {
        return MockBehavior{
            .max_calls = max,
        };
    }
};

/// Hash function for arguments
fn hashArgs(args: anytype) u64 {
    var hasher = std.hash.Fnv1a_64.init();

    const ArgsType = @TypeOf(args);
    if (@typeInfo(ArgsType) == .@"struct") {
        inline for (@typeInfo(ArgsType).@"struct".fields) |field| {
            const value = @field(args, field.name);
            hashValue(&hasher, value);
        }
    } else {
        hashValue(&hasher, args);
    }

    return hasher.final();
}

fn hashValue(hasher: *std.hash.Fnv1a_64, value: anytype) void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .int, .float => {
            const bytes = std.mem.asBytes(&value);
            hasher.update(bytes);
        },
        .bool => {
            hasher.update(&[_]u8{if (value) 1 else 0});
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .Slice and ptr_info.child == u8) {
                hasher.update(value);
            } else {
                // Hash the pointer address
                const addr = @intFromPtr(value);
                const bytes = std.mem.asBytes(&addr);
                hasher.update(bytes);
            }
        },
        .@"struct" => {
            inline for (@typeInfo(T).@"struct".fields) |field| {
                hashValue(hasher, @field(value, field.name));
            }
        },
        .array => {
            for (value) |item| {
                hashValue(hasher, item);
            }
        },
        else => {
            // For unsupported types, hash the type name
            hasher.update(@typeName(T));
        },
    }
}

/// Generic mock implementation
pub fn Mock(comptime Interface: type) type {
    const interface_info = @typeInfo(Interface);
    if (interface_info != .@"struct") {
        @compileError("Mock can only be created for struct types");
    }

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        calls: std.ArrayList(Call),
        behaviors: std.StringHashMap(MockBehavior),

        pub fn init() Self {
            return Self{
                .allocator = std.heap.page_allocator,
                .calls = std.ArrayList(Call){},
                .behaviors = std.StringHashMap(MockBehavior).init(std.heap.page_allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.calls.deinit(self.allocator);

            // Clean up stored return values
            var iterator = self.behaviors.iterator();
            while (iterator.next()) |entry| {
                if (entry.value_ptr.return_value) |ret_val| {
                    std.heap.page_allocator.destroy(@as(*u8, @ptrCast(ret_val)));
                }
            }
            self.behaviors.deinit();
        }

        /// Set up behavior for a specific function
        pub fn when(self: *Self, comptime function_name: []const u8) *MockBehavior {
            const behavior = MockBehavior{};
            self.behaviors.put(function_name, behavior) catch unreachable;
            return self.behaviors.getPtr(function_name).?;
        }

        /// Record a function call
        pub fn recordCall(self: *Self, function_name: []const u8, args: anytype) void {
            const args_hash = hashArgs(args);
            const instant = std.time.Instant.now() catch unreachable;
            const timestamp: i64 = if (@import("builtin").os.tag == .windows or @import("builtin").os.tag == .uefi or @import("builtin").os.tag == .wasi)
                @intCast(instant.timestamp)
            else
                instant.timestamp.sec;
            const call = Call{
                .function_name = function_name,
                .args_hash = args_hash,
                .timestamp = timestamp,
            };
            self.calls.append(self.allocator, call) catch unreachable;
        }

        /// Execute a mocked function call
        pub fn executeCall(
            self: *Self,
            comptime function_name: []const u8,
            comptime ReturnType: type,
            args: anytype,
        ) !ReturnType {
            self.recordCall(function_name, args);

            if (self.behaviors.getPtr(function_name)) |behavior| {
                behavior.call_count += 1;

                // Check call limits
                if (behavior.max_calls) |max| {
                    if (behavior.call_count > max) {
                        return error.TooManyCalls;
                    }
                }

                // Handle different behaviors
                if (behavior.should_panic) {
                    @panic("Mock function panicked");
                }

                if (behavior.should_error) {
                    return behavior.error_value;
                }

                if (behavior.return_value) |ret_val| {
                    const typed_ptr: *ReturnType = @ptrCast(@alignCast(ret_val));
                    return typed_ptr.*;
                }
            }

            // Default behavior: return default value for the type
            return switch (@typeInfo(ReturnType)) {
                .void => {},
                .bool => false,
                .int => 0,
                .float => 0.0,
                .optional => null,
                .error_union => |eu| switch (@typeInfo(eu.payload)) {
                    .void => {},
                    else => @as(eu.payload, undefined),
                },
                else => undefined,
            };
        }

        /// Verify that a function was called with specific arguments
        pub fn verify(self: *Self, function_name: []const u8, args: anytype, verification: Verification) !void {
            const args_hash = hashArgs(args);
            var matching_calls: u32 = 0;

            for (self.calls.items) |call| {
                if (call.matches(function_name, args_hash)) {
                    matching_calls += 1;
                }
            }

            const verification_passed = switch (verification.mode) {
                .never => matching_calls == 0,
                .once => matching_calls == 1,
                .exactly => matching_calls == verification.count,
                .at_least => matching_calls >= verification.count,
                .at_most => matching_calls <= verification.count,
                .times => matching_calls == verification.count,
            };

            if (!verification_passed) {
                std.debug.print("Verification failed for {s}: expected {s} {any} calls, got {any}\n", .{
                    function_name,
                    @tagName(verification.mode),
                    verification.count,
                    matching_calls,
                });
                return error.VerificationFailed;
            }
        }

        /// Verify that a function was called at least once
        pub fn verifyCalled(self: *Self, function_name: []const u8, args: anytype) !void {
            try self.verify(function_name, args, Verification.atLeast(1));
        }

        /// Verify that a function was never called
        pub fn verifyNeverCalled(self: *Self, function_name: []const u8, args: anytype) !void {
            try self.verify(function_name, args, Verification.never());
        }

        /// Get the number of times a function was called
        pub fn getCallCount(self: *Self, function_name: []const u8, args: anytype) u32 {
            const args_hash = hashArgs(args);
            var count: u32 = 0;

            for (self.calls.items) |call| {
                if (call.matches(function_name, args_hash)) {
                    count += 1;
                }
            }

            return count;
        }

        /// Reset all recorded calls
        pub fn reset(self: *Self) void {
            self.calls.clearRetainingCapacity();

            // Reset call counts in behaviors
            var iterator = self.behaviors.iterator();
            while (iterator.next()) |entry| {
                entry.value_ptr.call_count = 0;
            }
        }

        /// Get all calls made to this mock
        pub fn getCalls(self: *Self) []const Call {
            return self.calls.items;
        }
    };
}

/// Create a spy that wraps a real implementation
pub fn Spy(comptime Interface: type, comptime _: Interface) type {
    return struct {
        const Self = @This();

        mock: Mock(Interface),
        real: Interface,

        pub fn init(real_implementation: Interface) Self {
            return Self{
                .mock = Mock(Interface).init(),
                .real = real_implementation,
            };
        }

        pub fn deinit(self: *Self) void {
            self.mock.deinit();
        }

        // Spy methods delegate to both mock (for recording) and real implementation
        pub fn recordAndDelegate(
            self: *Self,
            comptime function_name: []const u8,
            comptime ReturnType: type,
            args: anytype,
            comptime real_fn: anytype,
        ) ReturnType {
            self.mock.recordCall(function_name, args);
            return @call(.auto, real_fn, .{self.real} ++ args);
        }

        // Verification methods delegate to mock
        pub fn verify(self: *Self, function_name: []const u8, args: anytype, verification: Verification) !void {
            return self.mock.verify(function_name, args, verification);
        }

        pub fn getCallCount(self: *Self, function_name: []const u8, args: anytype) u32 {
            return self.mock.getCallCount(function_name, args);
        }

        pub fn reset(self: *Self) void {
            self.mock.reset();
        }
    };
}

test "mock: basic functionality" {
    const Calculator = struct {
        pub fn add(a: i32, b: i32) i32 {
            return a + b;
        }

        pub fn multiply(a: i32, b: i32) i32 {
            return a * b;
        }
    };

    var mock_calc = Mock(Calculator).init();
    defer mock_calc.deinit();

    // Set up behavior
    _ = mock_calc.when("add").returnValue(i32, 42);

    // Execute mocked call
    const result = try mock_calc.executeCall("add", i32, .{ 1, 2 });
    try std.testing.expect(result == 42);

    // Verify the call was made
    try mock_calc.verifyCalled("add", .{ 1, 2 });

    // Verify call count
    try std.testing.expect(mock_calc.getCallCount("add", .{ 1, 2 }) == 1);
}

test "mock: verification modes" {
    const Service = struct {
        pub fn process(data: []const u8) void {
            _ = data;
        }
    };

    var mock_service = Mock(Service).init();
    defer mock_service.deinit();

    // Call the function multiple times
    _ = try mock_service.executeCall("process", void, .{"test1"});
    _ = try mock_service.executeCall("process", void, .{"test2"});
    _ = try mock_service.executeCall("process", void, .{"test1"});

    // Verify different modes
    try mock_service.verify("process", .{"test1"}, Verification.exactly(2));
    try mock_service.verify("process", .{"test2"}, Verification.once());
    try mock_service.verify("process", .{"nonexistent"}, Verification.never());
}

test "mock: error behavior" {
    const FileService = struct {
        pub fn readFile(path: []const u8) ![]const u8 {
            _ = path;
            return "content";
        }
    };

    var mock_file = Mock(FileService).init();
    defer mock_file.deinit();

    // Set up error behavior
    _ = mock_file.when("readFile").err(error.FileNotFound);

    // Execute and expect error
    const result = mock_file.executeCall("readFile", ![]const u8, .{"test.txt"});
    try std.testing.expectError(error.FileNotFound, result);
}

test "hash: arguments" {
    // Test that different arguments produce different hashes
    const hash1 = hashArgs(.{ 1, 2 });
    const hash2 = hashArgs(.{ 1, 3 });
    const hash3 = hashArgs(.{ 2, 1 });

    try std.testing.expect(hash1 != hash2);
    try std.testing.expect(hash1 != hash3);
    try std.testing.expect(hash2 != hash3);

    // Test that same arguments produce same hash
    const hash4 = hashArgs(.{ 1, 2 });
    try std.testing.expect(hash1 == hash4);
}
