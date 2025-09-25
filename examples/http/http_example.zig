const std = @import("std");
const ghostspec = @import("ghostspec");

const Request = struct {
    method: []const u8,
    path: []const u8,
    query: ?[]const u8 = null,
};

const Response = struct {
    status: u16,
    body: []const u8,
};

fn parseQuery(path: []const u8) struct { clean: []const u8, query: ?[]const u8 } {
    if (std.mem.indexOfScalar(u8, path, '?')) |idx| {
        return .{ .clean = path[0..idx], .query = path[idx + 1 ..] };
    }
    return .{ .clean = path, .query = null };
}

fn handleRequest(allocator: std.mem.Allocator, req: Request) !Response {
    const parsed = parseQuery(req.path);
    if (!std.mem.eql(u8, req.method, "GET")) {
        return Response{ .status = 405, .body = "Method Not Allowed" };
    }
    if (!std.mem.eql(u8, parsed.clean, "/hello")) {
        return Response{ .status = 404, .body = "Not Found" };
    }

    const name = parsed.query orelse "name=world";
    const value = if (std.mem.indexOfScalar(u8, name, '=')) |eq|
        name[eq + 1 ..]
    else
        name;

    const body = try std.fmt.allocPrint(allocator, "Hello, {s}!", .{value});
    return Response{ .status = 200, .body = body };
}

fn propertyUrl(values: struct { path: []const u8 }) !void {
    const parsed = parseQuery(values.path);
    try std.testing.expect(parsed.clean.len <= values.path.len);
    if (parsed.query) |q| try std.testing.expect(q.len + parsed.clean.len + 1 == values.path.len);
}

test "property: parseQuery" {
    try ghostspec.property(struct { path: []const u8 }, propertyUrl);
}

test "handleRequest returns greeting" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const resp = try handleRequest(allocator, .{ .method = "GET", .path = "/hello?name=zig" });
    defer allocator.free(resp.body);

    try std.testing.expectEqual(@as(u16, 200), resp.status);
    try std.testing.expect(std.mem.eql(u8, resp.body, "Hello, zig!"));
}

test "mock async channel" {
    const Network = struct {
        pub fn send(self: *@This(), data: []const u8) !void {
            _ = self;
            _ = data;
        }
    };

    var mock_net = ghostspec.mocking.Mock(Network).init();
    defer mock_net.deinit();

    mock_net.when("send").returnValue(void, {});

    // Simulate async call by invoking executeCall directly.
    try mock_net.executeCall("send", !void, .{"Hello, async!"});
    try mock_net.verifyCalled("send", .{"Hello, async!"});
}

test "benchmark handler" {
    const BenchFn = struct {
        fn run(allocator: std.mem.Allocator) void {
            const resp = handleRequest(allocator, .{ .method = "GET", .path = "/hello?name=bench" }) catch unreachable;
            allocator.free(resp.body);
        }
    };

    var bench = ghostspec.benchmarking.Benchmark.init(std.testing.allocator, .{
        .iterations = 100,
        .warmup_iterations = 10,
        .min_time_ns = 100_000,
    });

    const result = try bench.runBenchmark("http_handler", BenchFn.run);
    try std.testing.expect(result.iterations_run > 0);
}
