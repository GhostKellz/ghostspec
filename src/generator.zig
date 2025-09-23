//! Data generators for property-based testing
//!
//! This module provides generators for common data types used in property tests.
//! Generators create random values of specified types with configurable size limits.

const std = @import("std");

/// Generate a random value of the specified type
pub fn generate(comptime T: type, allocator: std.mem.Allocator, rng: std.Random, max_size: u32) !T {
    return switch (@typeInfo(T)) {
        .int => |int_info| {
            if (int_info.signedness == .signed) {
                const max_val = @min(@as(i64, max_size), std.math.maxInt(T));
                const min_val = @max(-@as(i64, max_size), std.math.minInt(T));
                return @intCast(rng.intRangeLessThan(i64, min_val, max_val + 1));
            } else {
                const max_val = @min(@as(u64, max_size), std.math.maxInt(T));
                return @intCast(rng.uintLessThan(u64, max_val + 1));
            }
        },
        .float => |float_info| {
            return switch (float_info.bits) {
                32 => @as(T, rng.float(f32)) * @as(f32, @floatFromInt(max_size)),
                64 => @as(T, rng.float(f64)) * @as(f64, @floatFromInt(max_size)),
                else => @compileError("Unsupported float type"),
            };
        },
        .bool => rng.boolean(),
        .@"enum" => |enum_info| {
            const fields = enum_info.fields;
            const index = rng.uintLessThan(usize, fields.len);
            return @enumFromInt(fields[index].value);
        },
        .@"struct" => |struct_info| {
            if (struct_info.is_tuple) {
                var result: T = undefined;
                inline for (struct_info.fields, 0..) |field, i| {
                    result[i] = try generate(field.type, allocator, rng, max_size);
                }
                return result;
            } else {
                var result: T = undefined;
                inline for (struct_info.fields) |field| {
                    @field(result, field.name) = try generate(field.type, allocator, rng, max_size);
                }
                return result;
            }
        },
        .array => |array_info| {
            var result: T = undefined;
            for (&result) |*elem| {
                elem.* = try generate(array_info.child, allocator, rng, max_size);
            }
            return result;
        },
        .pointer => |ptr_info| {
            if (ptr_info.size == .Slice) {
                if (ptr_info.child == u8) {
                    // Generate random string
                    const len = rng.uintLessThan(usize, @min(max_size, 100)) + 1;
                    const str = try allocator.alloc(u8, len);
                    for (str) |*char| {
                        char.* = rng.intRangeAtMost(u8, 32, 126); // Printable ASCII
                    }
                    return str;
                } else {
                    // Generate slice of other types
                    const len = rng.uintLessThan(usize, @min(max_size, 20)) + 1;
                    const slice = try allocator.alloc(ptr_info.child, len);
                    for (slice) |*elem| {
                        elem.* = try generate(ptr_info.child, allocator, rng, max_size);
                    }
                    return slice;
                }
            } else {
                @compileError("Only slices are supported for pointer generation");
            }
        },
        .optional => |opt_info| {
            if (rng.boolean()) {
                return try generate(opt_info.child, allocator, rng, max_size);
            } else {
                return null;
            }
        },
        else => @compileError("Unsupported type for generation: " ++ @typeName(T)),
    };
}

/// Clean up generated values that require deallocation
pub fn deinit(comptime T: type, value: T, allocator: std.mem.Allocator) void {
    switch (@typeInfo(T)) {
        .pointer => |ptr_info| {
            if (ptr_info.size == .Slice) {
                if (ptr_info.child == u8 or @typeInfo(ptr_info.child) == .Int or @typeInfo(ptr_info.child) == .Float or @typeInfo(ptr_info.child) == .Bool) {
                    allocator.free(value);
                } else {
                    // Clean up slice elements first
                    for (value) |elem| {
                        deinit(ptr_info.child, elem, allocator);
                    }
                    allocator.free(value);
                }
            }
        },
        .@"struct" => |struct_info| {
            if (struct_info.is_tuple) {
                inline for (struct_info.fields, 0..) |field, i| {
                    deinit(field.type, value[i], allocator);
                }
            } else {
                inline for (struct_info.fields) |field| {
                    deinit(field.type, @field(value, field.name), allocator);
                }
            }
        },
        .array => |array_info| {
            for (value) |elem| {
                deinit(array_info.child, elem, allocator);
            }
        },
        .optional => |opt_info| {
            if (value) |unwrapped| {
                deinit(opt_info.child, unwrapped, allocator);
            }
        },
        else => {
            // Types that don't need cleanup
        },
    }
}

/// Built-in generators for common scenarios
pub const builtin = struct {
    /// Generate a positive integer
    pub fn positiveInt(comptime T: type) fn (std.mem.Allocator, std.Random, u32) anyerror!T {
        return struct {
            fn gen(allocator: std.mem.Allocator, rng: std.Random, max_size: u32) !T {
                _ = allocator;
                const max_val = @min(@as(u64, max_size), std.math.maxInt(T));
                return @intCast(rng.uintLessThan(u64, max_val) + 1);
            }
        }.gen;
    }

    /// Generate a non-empty string
    pub fn nonEmptyString(allocator: std.mem.Allocator, rng: std.Random, max_size: u32) ![]const u8 {
        const len = rng.uintLessThan(usize, @min(max_size, 100)) + 1;
        const str = try allocator.alloc(u8, len);
        for (str) |*char| {
            char.* = rng.intRangeAtMost(u8, 32, 126); // Printable ASCII
        }
        return str;
    }

    /// Generate an alphanumeric string
    pub fn alphanumericString(allocator: std.mem.Allocator, rng: std.Random, max_size: u32) ![]const u8 {
        const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        const len = rng.uintLessThan(usize, @min(max_size, 100)) + 1;
        const str = try allocator.alloc(u8, len);
        for (str) |*char| {
            char.* = chars[rng.uintLessThan(usize, chars.len)];
        }
        return str;
    }

    /// Generate a small positive integer (1-10)
    pub fn smallInt(allocator: std.mem.Allocator, rng: std.Random, max_size: u32) !u32 {
        _ = allocator;
        _ = max_size;
        return rng.uintLessThan(u32, 10) + 1;
    }
};

test "generate integers" {
    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();

    const int_val = try generate(i32, std.testing.allocator, random, 100);
    try std.testing.expect(int_val >= -100 and int_val <= 100);

    const uint_val = try generate(u32, std.testing.allocator, random, 50);
    try std.testing.expect(uint_val <= 50);
}

test "generate strings" {
    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();

    const str = try generate([]const u8, std.testing.allocator, random, 20);
    defer deinit([]const u8, str, std.testing.allocator);

    try std.testing.expect(str.len > 0);
    try std.testing.expect(str.len <= 20);
}

test "generate structs" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();

    const point = try generate(Point, std.testing.allocator, random, 100);
    deinit(Point, point, std.testing.allocator);

    try std.testing.expect(point.x >= -100 and point.x <= 100);
    try std.testing.expect(point.y >= -100 and point.y <= 100);
}

test "generate arrays" {
    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();

    const arr = try generate([5]u8, std.testing.allocator, random, 255);
    deinit([5]u8, arr, std.testing.allocator);

    for (arr) |val| {
        try std.testing.expect(val <= 255);
    }
}

test "builtin generators" {
    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();

    const pos_int = try builtin.positiveInt(u32)(std.testing.allocator, random, 100);
    try std.testing.expect(pos_int > 0);
    try std.testing.expect(pos_int <= 100);

    const non_empty_str = try builtin.nonEmptyString(std.testing.allocator, random, 50);
    defer std.testing.allocator.free(non_empty_str);
    try std.testing.expect(non_empty_str.len > 0);

    const alpha_str = try builtin.alphanumericString(std.testing.allocator, random, 30);
    defer std.testing.allocator.free(alpha_str);
    try std.testing.expect(alpha_str.len > 0);

    const small_int = try builtin.smallInt(std.testing.allocator, random, 100);
    try std.testing.expect(small_int >= 1 and small_int <= 10);
}
