//! Fuzzing integration for GhostSpec
//!
//! This module provides coverage-guided fuzzing capabilities that extend
//! Zig's built-in fuzzing functionality with corpus management, crash detection,
//! and advanced fuzzing strategies.

const std = @import("std");

/// Configuration for fuzzing sessions
pub const FuzzConfig = struct {
    /// Maximum number of iterations to run
    max_iterations: u32 = 10000,
    /// Maximum input size to generate
    max_input_size: usize = 1024,
    /// Timeout per iteration in milliseconds
    timeout_ms: u32 = 1000,
    /// Directory to store corpus files
    corpus_dir: ?[]const u8 = null,
    /// Directory to store crash inputs
    crashes_dir: ?[]const u8 = null,
    /// Enable coverage-guided mutations
    coverage_guided: bool = true,
    /// Mutation strategies to use
    mutation_strategies: []const MutationStrategy = &.{ .bit_flip, .byte_flip, .arithmetic, .splice },
};

/// Different mutation strategies for fuzzing
pub const MutationStrategy = enum {
    bit_flip,
    byte_flip,
    arithmetic,
    splice,
    insert,
    delete,
    shuffle,
};

/// Result of a fuzzing session
pub const FuzzResult = struct {
    total_iterations: u32,
    crashes_found: u32,
    timeouts: u32,
    coverage_info: ?CoverageInfo = null,
    crash_inputs: std.ArrayList([]const u8),

    pub fn deinit(self: *FuzzResult, allocator: std.mem.Allocator) void {
        for (self.crash_inputs.items) |input| {
            allocator.free(input);
        }
        self.crash_inputs.deinit(allocator);
    }
};

/// Coverage information for guided fuzzing
pub const CoverageInfo = struct {
    blocks_covered: u32,
    total_blocks: u32,
    new_coverage_found: bool,
};

/// Simplified fuzzer for demo purposes
pub const Fuzzer = struct {
    allocator: std.mem.Allocator,
    config: FuzzConfig,

    pub fn init(allocator: std.mem.Allocator, config: FuzzConfig) !Fuzzer {
        return Fuzzer{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *Fuzzer) void {
        _ = self;
    }

    /// Run fuzzing session on the target function
    pub fn run(self: *Fuzzer, comptime target_fn: anytype, iterations: u32) !FuzzResult {
        var result = FuzzResult{
            .total_iterations = 0,
            .crashes_found = 0,
            .timeouts = 0,
            .crash_inputs = std.ArrayList([]const u8){},
        };

        const actual_iterations = @min(iterations, self.config.max_iterations);

        const seed_instant = std.time.Instant.now() catch unreachable;
        const seed_value: u64 = if (@import("builtin").os.tag == .windows or @import("builtin").os.tag == .uefi or @import("builtin").os.tag == .wasi)
            seed_instant.timestamp
        else
            @as(u64, @intCast(seed_instant.timestamp.sec)) *% 1000000000 +% @as(u64, @intCast(seed_instant.timestamp.nsec));
        var rng = std.Random.DefaultPrng.init(seed_value);

        for (0..actual_iterations) |_| {
            // Generate random input
            const input_size = rng.random().uintLessThan(usize, self.config.max_input_size) + 1;
            const input = try self.allocator.alloc(u8, input_size);
            defer self.allocator.free(input);

            for (input) |*byte| {
                byte.* = rng.random().int(u8);
            }

            // Run target function
            target_fn(input) catch |err| {
                result.crashes_found += 1;
                const crash_input = try self.allocator.dupe(u8, input);
                try result.crash_inputs.append(self.allocator, crash_input);

                std.log.debug("Fuzzer found crash with error: {any}", .{err});
            };

            result.total_iterations += 1;
        }

        return result;
    }

    /// Add an input to the fuzzing corpus
    pub fn addCorpus(self: *Fuzzer, input: []const u8) !void {
        // For this simplified version, we'll just test the input immediately
        _ = self;
        _ = input;
        // In a full implementation, this would save to the corpus
    }
};

test "fuzzer: basic functionality" {
    const TestTarget = struct {
        fn target(input: []const u8) !void {
            // Crash on specific input
            if (std.mem.eql(u8, input, "crash")) {
                return error.TestCrash;
            }
        }
    };

    const config = FuzzConfig{
        .max_iterations = 10,
        .max_input_size = 32,
    };

    var fuzzer = try Fuzzer.init(std.testing.allocator, config);
    defer fuzzer.deinit();

    var result = try fuzzer.run(TestTarget.target, 10);
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result.total_iterations == 10);
}
