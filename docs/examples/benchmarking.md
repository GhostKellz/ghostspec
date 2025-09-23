# Benchmarking Examples

Examples of using GhostSpec's benchmarking capabilities to measure performance.

## Basic Benchmarking

```zig
const std = @import("std");
const ghostspec = @import("ghostspec");

test "basic benchmarks" {
    try ghostspec.benchmark("simple addition", benchmarkSimpleAddition);
    try ghostspec.benchmark("string concatenation", benchmarkStringConcat);
    try ghostspec.benchmark("memory allocation", benchmarkMemoryAlloc);
}

fn benchmarkSimpleAddition(b: *ghostspec.Benchmark) !void {
    var x: i64 = 0;
    b.iterate(|| {
        x += 1;
        x *= 2;
        x /= 2;
        x -= 1;
    });
}

fn benchmarkStringConcat(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        var result = std.ArrayList(u8).init(allocator);
        defer result.deinit();

        try result.appendSlice("Hello");
        try result.appendSlice(" ");
        try result.appendSlice("World");
        try result.appendSlice("!");
        _ = result.items;
    });
}

fn benchmarkMemoryAlloc(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        var list = std.ArrayList(u8).init(allocator);
        defer list.deinit();

        // Allocate some memory
        try list.ensureTotalCapacity(1000);
        for (0..1000) |i| {
            try list.append(@intCast(i % 256));
        }
    });
}
```

## Parameterized Benchmarks

```zig
test "parameterized benchmarks" {
    // Benchmark different input sizes
    inline for ([_]usize{ 10, 100, 1000, 10000 }) |size| {
        try ghostspec.benchmark(
            std.fmt.comptimePrint("sort {} elements", .{size}),
            benchmarkSortWithSize(size)
        );
    }

    // Benchmark different algorithms
    try ghostspec.benchmark("bubble sort", benchmarkBubbleSort);
    try ghostspec.benchmark("quick sort", benchmarkQuickSort);
    try ghostspec.benchmark("merge sort", benchmarkMergeSort);
}

fn benchmarkSortWithSize(comptime size: usize) fn(*ghostspec.Benchmark) anyerror!void {
    return struct {
        fn bench(b: *ghostspec.Benchmark) !void {
            var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
            defer arena.deinit();
            const allocator = arena.allocator();

            b.iterate(|| {
                var arr = try allocator.alloc(i32, size);
                defer allocator.free(arr);

                // Fill with random data
                for (arr) |*item| {
                    item.* = std.crypto.random.int(i32);
                }

                // Sort it
                std.mem.sort(i32, arr, {}, std.sort.asc(i32));
            });
        }
    }.bench;
}

fn benchmarkBubbleSort(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        var arr = try allocator.alloc(i32, 100);
        defer allocator.free(arr);

        // Fill with random data
        for (arr) |*item| {
            item.* = std.crypto.random.int(i32);
        }

        // Bubble sort
        var i: usize = 0;
        while (i < arr.len) : (i += 1) {
            var j: usize = 0;
            while (j < arr.len - i - 1) : (j += 1) {
                if (arr[j] > arr[j + 1]) {
                    const temp = arr[j];
                    arr[j] = arr[j + 1];
                    arr[j + 1] = temp;
                }
            }
        }
    });
}

fn benchmarkQuickSort(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        var arr = try allocator.alloc(i32, 100);
        defer allocator.free(arr);

        // Fill with random data
        for (arr) |*item| {
            item.* = std.crypto.random.int(i32);
        }

        // Quick sort
        std.mem.sort(i32, arr, {}, std.sort.asc(i32));
    });
}

fn benchmarkMergeSort(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        var arr = try allocator.alloc(i32, 100);
        defer allocator.free(arr);

        // Fill with random data
        for (arr) |*item| {
            item.* = std.crypto.random.int(i32);
        }

        // For this example, we'll use the standard library's sort
        // In a real implementation, you'd implement merge sort
        std.mem.sort(i32, arr, {}, std.sort.asc(i32));
    });
}
```

## Memory Benchmarks

```zig
test "memory benchmarks" {
    try ghostspec.benchmark("small allocations", benchmarkSmallAllocs);
    try ghostspec.benchmark("large allocations", benchmarkLargeAllocs);
    try ghostspec.benchmark("allocation patterns", benchmarkAllocPatterns);
}

fn benchmarkSmallAllocs(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        // Allocate many small objects
        var ptrs = try allocator.alloc(*i32, 1000);
        defer allocator.free(ptrs);

        for (ptrs) |*ptr| {
            ptr.* = try allocator.create(i32);
            ptr.*.* = 42;
        }

        // Clean up
        for (ptrs) |ptr| {
            allocator.destroy(ptr);
        }
    });
}

fn benchmarkLargeAllocs(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        // Allocate a few large objects
        var large1 = try allocator.alloc(u8, 1024 * 1024); // 1MB
        defer allocator.free(large1);
        @memset(large1, 0xFF);

        var large2 = try allocator.alloc(u8, 1024 * 1024); // 1MB
        defer allocator.free(large2);
        @memset(large2, 0xAA);

        var large3 = try allocator.alloc(u8, 1024 * 1024); // 1MB
        defer allocator.free(large3);
        @memset(large3, 0x55);
    });
}

fn benchmarkAllocPatterns(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        // Simulate a complex allocation pattern
        var lists = std.ArrayList(std.ArrayList(u8)).init(allocator);
        defer {
            for (lists.items) |*list| list.deinit();
            lists.deinit();
        }

        // Create a list of lists with varying sizes
        for (0..10) |i| {
            var list = try std.ArrayList(u8).initCapacity(allocator, i * 100 + 50);
            try list.appendNTimes(@intCast(i), i * 100 + 50);
            try lists.append(list);
        }

        // Do some operations
        for (lists.items) |*list| {
            for (list.items) |*item| {
                item.* +%= 1;
            }
        }
    });
}
```

## I/O Benchmarks

```zig
test "io benchmarks" {
    try ghostspec.benchmark("file write", benchmarkFileWrite);
    try ghostspec.benchmark("file read", benchmarkFileRead);
    try ghostspec.benchmark("buffered io", benchmarkBufferedIO);
}

fn benchmarkFileWrite(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        const file = try std.fs.cwd().createFile("temp_bench_file.txt", .{});
        defer file.close();
        defer std.fs.cwd().deleteFile("temp_bench_file.txt") catch {};

        const data = "Hello, World! This is a test string for benchmarking.\n";
        for (0..1000) |_| {
            _ = try file.write(data);
        }
    });
}

fn benchmarkFileRead(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create test file first
    {
        const file = try std.fs.cwd().createFile("temp_read_file.txt", .{});
        defer file.close();

        const data = "Hello, World! This is a test string for benchmarking.\n";
        for (0..1000) |_| {
            _ = try file.write(data);
        }
    }
    defer std.fs.cwd().deleteFile("temp_read_file.txt") catch {};

    b.iterate(|| {
        const file = try std.fs.cwd().openFile("temp_read_file.txt", .{});
        defer file.close();

        var buffer: [1024]u8 = undefined;
        while (true) {
            const bytes_read = try file.read(&buffer);
            if (bytes_read == 0) break;
        }
    });
}

fn benchmarkBufferedIO(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        const file = try std.fs.cwd().createFile("temp_buffered_file.txt", .{});
        defer file.close();
        defer std.fs.cwd().deleteFile("temp_buffered_file.txt") catch {};

        var buffered_writer = std.io.bufferedWriter(file.writer());
        const writer = buffered_writer.writer();

        const data = "Hello, World! This is a test string for benchmarking.\n";
        for (0..1000) |_| {
            _ = try writer.write(data);
        }

        try buffered_writer.flush();
    });
}
```

## Async Benchmarks

```zig
test "async benchmarks" {
    try ghostspec.benchmark("async task spawning", benchmarkAsyncSpawn);
    try ghostspec.benchmark("channel communication", benchmarkChannels);
    try ghostspec.benchmark("async file io", benchmarkAsyncFileIO);
}

fn benchmarkAsyncSpawn(b: *ghostspec.Benchmark) !void {
    b.iterate(|| {
        const frame = async simpleAsyncTask();
        _ = await frame;
    });
}

fn simpleAsyncTask() void {
    // Simple async computation
    var sum: i64 = 0;
    for (0..1000) |i| {
        sum += @intCast(i);
    }
    _ = sum;
}

fn benchmarkChannels(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        const frame = async channelBenchmarkTask(allocator);
        _ = await frame;
    });
}

fn channelBenchmarkTask(allocator: std.mem.Allocator) !void {
    var channel = std.ArrayList(i32).init(allocator);
    defer channel.deinit();

    // Simulate channel operations
    for (0..1000) |i| {
        try channel.append(@intCast(i));
    }

    var sum: i64 = 0;
    for (channel.items) |item| {
        sum += item;
    }
    _ = sum;
}

fn benchmarkAsyncFileIO(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    b.iterate(|| {
        const frame = async asyncFileIOTask(allocator);
        _ = await frame;
    });
}

fn asyncFileIOTask(allocator: std.mem.Allocator) !void {
    // Create and write to a file asynchronously
    const file = try std.fs.cwd().createFile("temp_async_file.txt", .{});
    defer file.close();
    defer std.fs.cwd().deleteFile("temp_async_file.txt") catch {};

    var data = try allocator.alloc(u8, 1024);
    defer allocator.free(data);
    @memset(data, 'A');

    _ = try file.write(data);
}
```

## Statistical Analysis

```zig
test "benchmark statistics" {
    // Run multiple iterations to get statistical data
    try ghostspec.benchmark("statistical benchmark", benchmarkWithStats, .{
        .iterations = 100, // More iterations for better statistics
        .warmup_iterations = 10,
    });
}

fn benchmarkWithStats(b: *ghostspec.Benchmark) !void {
    b.iterate(|| {
        // Some computation that has some variance
        var rng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
        const random_delay = rng.random().uintLessThan(u32, 1000);

        var sum: u64 = 0;
        for (0..10000) |i| {
            sum +%= @intCast(i + random_delay);
        }
        _ = sum;
    });
}
```</content>
<parameter name="filePath">/data/projects/ghostspec/docs/examples/benchmarking.md