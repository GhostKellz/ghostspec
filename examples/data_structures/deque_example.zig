const std = @import("std");
const ghostspec = @import("ghostspec");

const Capacity = 32;

const BoundedDeque = struct {
    buffer: [Capacity]i32 = undefined,
    head: usize = 0,
    tail: usize = 0,
    len: usize = 0,

    pub fn pushBack(self: *BoundedDeque, value: i32) !void {
        if (self.len == Capacity) return error.Full;
        self.buffer[self.tail] = value;
        self.tail = (self.tail + 1) % Capacity;
        self.len += 1;
    }

    pub fn popFront(self: *BoundedDeque) !i32 {
        if (self.len == 0) return error.Empty;
        const value = self.buffer[self.head];
        self.head = (self.head + 1) % Capacity;
        self.len -= 1;
        return value;
    }

    pub fn peekFront(self: *BoundedDeque) !i32 {
        if (self.len == 0) return error.Empty;
        return self.buffer[self.head];
    }

    pub fn peekBack(self: *BoundedDeque) !i32 {
        if (self.len == 0) return error.Empty;
        const idx = if (self.tail == 0) Capacity - 1 else self.tail - 1;
        return self.buffer[idx];
    }
};

fn propertyDeque(values: struct { sequence: []const i32 }) !void {
    var deque = BoundedDeque{};
    var count: usize = 0;

    for (values.sequence) |item| {
        if (deque.len < Capacity) {
            try deque.pushBack(item);
            count += 1;
            try std.testing.expect(deque.len == count);
            try std.testing.expect(deque.peekBack() catch unreachable == item);
        } else {
            // FIFO: when full, popping should make space
            _ = deque.popFront() catch unreachable;
            count -= 1;
        }
    }
}

test "property: bounded deque invariants" {
    try ghostspec.property(struct { sequence: []const i32 }, propertyDeque);
}

test "fuzz: alternating push/pop" {
    const fuzz_config = ghostspec.fuzzing.FuzzConfig{
        .max_iterations = 200,
        .max_input_size = 16,
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var fuzzer = try ghostspec.fuzzing.Fuzzer.init(arena.allocator(), fuzz_config);
    defer fuzzer.deinit();

    const target = struct {
        fn run(input: []const u8) !void {
            var deque = BoundedDeque{};
            for (input) |byte| {
                if (byte % 2 == 0) {
                    _ = deque.pushBack(@intCast(byte));
                } else {
                    _ = deque.popFront();
                }
                if (deque.len > Capacity) return error.Overflow;
            }
        }
    };

    var result = try fuzzer.run(target.run, 200);
    defer result.deinit(arena.allocator());
    try std.testing.expect(result.crashes_found == 0);
}

test "benchmark: bulk operations" {
    const BenchFn = struct {
        fn run() void {
            var deque = BoundedDeque{};
            for (0..Capacity) |i| {
                _ = deque.pushBack(@intCast(i));
            }
            for (0..Capacity) |_| {
                _ = deque.popFront();
            }
        }
    };

    var bench = ghostspec.benchmarking.Benchmark.init(std.testing.allocator, .{
        .iterations = 500,
        .warmup_iterations = 50,
        .min_time_ns = 100_000,
    });

    const result = try bench.runBenchmark("deque_bulk", BenchFn.run);
    try std.testing.expect(result.iterations_run > 0);
}
