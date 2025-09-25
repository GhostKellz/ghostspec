const std = @import("std");
const ghostspec = @import("ghostspec");

const CliCommand = struct {
    pub fn run(allocator: std.mem.Allocator, args: []const []const u8) ![]const u8 {
        if (args.len == 0) return error.NoCommand;
        if (std.mem.eql(u8, args[0], "hello")) {
            const name = if (args.len > 1) args[1] else "world";
            return try std.fmt.allocPrint(allocator, "Hello, {s}!", .{name});
        }
        return error.UnknownCommand;
    }
};

fn propertyHello(values: struct { name: []const u8 }) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = if (values.name.len == 0)
        [_][]const u8{"hello"}
    else
        [_][]const u8{ "hello", values.name };

    const output = CliCommand.run(allocator, &args) catch |err| switch (err) {
        error.NoCommand, error.UnknownCommand => return,
        else => return err,
    };
    defer allocator.free(output);

    if (values.name.len == 0) {
        try std.testing.expect(std.mem.eql(u8, output, "Hello, world!"));
    } else {
        try std.testing.expect(std.mem.indexOf(u8, output, values.name) != null);
    }
}

test "property: hello greets name" {
    try ghostspec.property(struct { name: []const u8 }, propertyHello);
}

test "mock stdout for greetings" {
    const MockStdout = struct {
        buffer: *std.ArrayList(u8),
        pub fn write(self: *@This(), bytes: []const u8) !usize {
            try self.buffer.appendSlice(bytes);
            return bytes.len;
        }
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();
    var stdout = MockStdout{ .buffer = &output };

    const greeting = try CliCommand.run(allocator, &[_][]const u8{ "hello", "zig" });
    defer allocator.free(greeting);

    _ = try stdout.write(greeting);
    try std.testing.expect(std.mem.eql(u8, output.items, "Hello, zig!"));
}

test "benchmark cli command" {
    const BenchFn = struct {
        fn run(allocator: std.mem.Allocator) void {
            const result = CliCommand.run(allocator, &[_][]const u8{ "hello", "bench" }) catch unreachable;
            allocator.free(result);
        }
    };

    var bench = ghostspec.benchmarking.Benchmark.init(std.testing.allocator, .{
        .iterations = 200,
        .warmup_iterations = 20,
        .min_time_ns = 100_000,
    });

    const result = try bench.runBenchmark("hello", BenchFn.run);
    try std.testing.expect(result.iterations_run > 0);
}
