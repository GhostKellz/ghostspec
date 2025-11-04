//! Benchmarking module for GhostSpec
//!
//! Provides performance testing capabilities with timing, memory tracking,
//! regression detection, and statistical analysis of benchmark results.

const std = @import("std");

/// Configuration for benchmark execution
pub const BenchConfig = struct {
    /// Number of iterations to run
    iterations: u32 = 1000,
    /// Minimum time to run benchmarks (in nanoseconds)
    min_time_ns: u64 = 1_000_000_000, // 1 second
    /// Maximum time to run benchmarks (in nanoseconds)
    max_time_ns: u64 = 10_000_000_000, // 10 seconds
    /// Enable memory tracking
    track_memory: bool = true,
    /// Enable regression detection
    detect_regressions: bool = true,
    /// Regression threshold (percentage)
    regression_threshold: f64 = 10.0,
    /// Warmup iterations
    warmup_iterations: u32 = 100,
};

/// Statistical information about benchmark results
pub const BenchStats = struct {
    mean: f64,
    median: f64,
    std_dev: f64,
    min: f64,
    max: f64,
    p95: f64,
    p99: f64,

    pub fn calculate(times: []const u64) BenchStats {
        if (times.len == 0) {
            return BenchStats{
                .mean = 0,
                .median = 0,
                .std_dev = 0,
                .min = 0,
                .max = 0,
                .p95 = 0,
                .p99 = 0,
            };
        }

        // Sort times for percentile calculations
        var sorted_times = std.ArrayList(u64){};
        defer sorted_times.deinit(std.heap.page_allocator);
        sorted_times.appendSlice(std.heap.page_allocator, times) catch unreachable;
        std.mem.sort(u64, sorted_times.items, {}, std.sort.asc(u64));

        // Calculate basic stats
        const mean = calculateMean(times);
        const median = calculateMedian(sorted_times.items);
        const std_dev = calculateStdDev(times, mean);
        const min_val = sorted_times.items[0];
        const max_val = sorted_times.items[sorted_times.items.len - 1];
        const p95 = calculatePercentile(sorted_times.items, 95);
        const p99 = calculatePercentile(sorted_times.items, 99);

        return BenchStats{
            .mean = mean,
            .median = median,
            .std_dev = std_dev,
            .min = @floatFromInt(min_val),
            .max = @floatFromInt(max_val),
            .p95 = p95,
            .p99 = p99,
        };
    }

    fn calculateMean(times: []const u64) f64 {
        var sum: f64 = 0;
        for (times) |time| {
            sum += @floatFromInt(time);
        }
        return sum / @as(f64, @floatFromInt(times.len));
    }

    fn calculateMedian(sorted_times: []const u64) f64 {
        const len = sorted_times.len;
        if (len % 2 == 0) {
            const mid1 = sorted_times[len / 2 - 1];
            const mid2 = sorted_times[len / 2];
            return (@as(f64, @floatFromInt(mid1)) + @as(f64, @floatFromInt(mid2))) / 2.0;
        } else {
            return @floatFromInt(sorted_times[len / 2]);
        }
    }

    fn calculateStdDev(times: []const u64, mean: f64) f64 {
        var variance: f64 = 0;
        for (times) |time| {
            const diff = @as(f64, @floatFromInt(time)) - mean;
            variance += diff * diff;
        }
        variance /= @as(f64, @floatFromInt(times.len));
        return std.math.sqrt(variance);
    }

    fn calculatePercentile(sorted_times: []const u64, percentile: u8) f64 {
        const index = (@as(f64, @floatFromInt(percentile)) / 100.0) * @as(f64, @floatFromInt(sorted_times.len - 1));
        const lower_index = @as(usize, @intFromFloat(@floor(index)));
        const upper_index = @min(lower_index + 1, sorted_times.len - 1);
        const weight = index - @floor(index);

        const lower_val = @as(f64, @floatFromInt(sorted_times[lower_index]));
        const upper_val = @as(f64, @floatFromInt(sorted_times[upper_index]));

        return lower_val + weight * (upper_val - lower_val);
    }
};

/// Memory usage information
pub const MemoryInfo = struct {
    bytes_allocated: usize,
    bytes_freed: usize,
    peak_memory: usize,
    allocations: usize,

    pub fn netMemory(self: MemoryInfo) isize {
        return @as(isize, @intCast(self.bytes_allocated)) - @as(isize, @intCast(self.bytes_freed));
    }
};

/// Result of a benchmark run
pub const BenchmarkResult = struct {
    name: []const u8,
    iterations_run: u32,
    total_time_ns: u64,
    stats: BenchStats,
    memory_info: ?MemoryInfo = null,
    is_regression: bool = false,
    regression_percentage: f64 = 0.0,

    pub fn throughputPerSecond(self: BenchmarkResult) f64 {
        if (self.total_time_ns == 0) return 0;
        const seconds = @as(f64, @floatFromInt(self.total_time_ns)) / 1_000_000_000.0;
        return @as(f64, @floatFromInt(self.iterations_run)) / seconds;
    }

    pub fn averageTimePerIteration(self: BenchmarkResult) f64 {
        if (self.iterations_run == 0) return 0;
        return @as(f64, @floatFromInt(self.total_time_ns)) / @as(f64, @floatFromInt(self.iterations_run));
    }

    pub fn format(self: BenchmarkResult, comptime fmt: []const u8, options: anytype, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("Benchmark: {s}\n", .{self.name});
        try writer.print("  Iterations: {any}\n", .{self.iterations_run});
        try writer.print("  Total time: {d:.2}ms\n", .{@as(f64, @floatFromInt(self.total_time_ns)) / 1_000_000.0});
        try writer.print("  Average: {d:.2}ns/iter\n", .{self.averageTimePerIteration()});
        try writer.print("  Throughput: {d:.2} iter/sec\n", .{self.throughputPerSecond()});
        try writer.print("  Stats:\n");
        try writer.print("    Mean: {d:.2}ns\n", .{self.stats.mean});
        try writer.print("    Median: {d:.2}ns\n", .{self.stats.median});
        try writer.print("    Std Dev: {d:.2}ns\n", .{self.stats.std_dev});
        try writer.print("    Min: {d:.2}ns\n", .{self.stats.min});
        try writer.print("    Max: {d:.2}ns\n", .{self.stats.max});
        try writer.print("    P95: {d:.2}ns\n", .{self.stats.p95});
        try writer.print("    P99: {d:.2}ns\n", .{self.stats.p99});

        if (self.memory_info) |mem| {
            try writer.print("  Memory:\n");
            try writer.print("    Allocated: {any} bytes\n", .{mem.bytes_allocated});
            try writer.print("    Freed: {any} bytes\n", .{mem.bytes_freed});
            try writer.print("    Net: {any} bytes\n", .{mem.netMemory()});
            try writer.print("    Peak: {any} bytes\n", .{mem.peak_memory});
            try writer.print("    Allocations: {any}\n", .{mem.allocations});
        }

        if (self.is_regression) {
            try writer.print("  🔴 REGRESSION DETECTED: {d:.1}% slower\n", .{self.regression_percentage});
        }
    }
};

/// Memory tracking allocator
pub const TrackingAllocator = struct {
    child_allocator: std.mem.Allocator,
    bytes_allocated: usize = 0,
    bytes_freed: usize = 0,
    peak_memory: usize = 0,
    current_memory: usize = 0,
    allocations: usize = 0,

    pub fn init(child_allocator: std.mem.Allocator) TrackingAllocator {
        return TrackingAllocator{
            .child_allocator = child_allocator,
        };
    }

    pub fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn remap(ctx: *anyopaque, memory: []u8, log2_align: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        _ = ctx;
        _ = memory;
        _ = log2_align;
        _ = new_len;
        _ = ra;
        // For tracking purposes, we don't support remap - return null to indicate
        // the allocator should use alloc+free instead
        return null;
    }

    pub fn getMemoryInfo(self: *TrackingAllocator) MemoryInfo {
        return MemoryInfo{
            .bytes_allocated = self.bytes_allocated,
            .bytes_freed = self.bytes_freed,
            .peak_memory = self.peak_memory,
            .allocations = self.allocations,
        };
    }

    pub fn reset(self: *TrackingAllocator) void {
        self.bytes_allocated = 0;
        self.bytes_freed = 0;
        self.peak_memory = 0;
        self.current_memory = 0;
        self.allocations = 0;
    }

    fn alloc(ctx: *anyopaque, len: usize, log2_ptr_align: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));

        if (self.child_allocator.rawAlloc(len, log2_ptr_align, ra)) |result| {
            self.bytes_allocated += len;
            self.current_memory += len;
            self.allocations += 1;

            if (self.current_memory > self.peak_memory) {
                self.peak_memory = self.current_memory;
            }

            return result;
        }
        return null;
    }

    fn resize(ctx: *anyopaque, buf: []u8, log2_buf_align: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));

        if (self.child_allocator.rawResize(buf, log2_buf_align, new_len, ra)) {
            if (new_len > buf.len) {
                const additional = new_len - buf.len;
                self.bytes_allocated += additional;
                self.current_memory += additional;

                if (self.current_memory > self.peak_memory) {
                    self.peak_memory = self.current_memory;
                }
            } else {
                const freed = buf.len - new_len;
                self.bytes_freed += freed;
                self.current_memory -= freed;
            }

            return true;
        }
        return false;
    }

    fn free(ctx: *anyopaque, buf: []u8, log2_buf_align: std.mem.Alignment, ra: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));

        self.child_allocator.rawFree(buf, log2_buf_align, ra);
        self.bytes_freed += buf.len;
        self.current_memory -= buf.len;
    }
};

/// Benchmark runner
pub const Benchmark = struct {
    allocator: std.mem.Allocator,
    config: BenchConfig,

    pub fn init(allocator: std.mem.Allocator, config: BenchConfig) Benchmark {
        return Benchmark{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Run a benchmark function
    pub fn runBenchmark(
        self: *Benchmark,
        comptime name: []const u8,
        comptime bench_fn: anytype,
    ) !BenchmarkResult {
        var tracking_allocator = TrackingAllocator.init(self.allocator);
        var times = std.ArrayList(u64){};
        defer times.deinit(self.allocator);

        // Warmup phase
        for (0..self.config.warmup_iterations) |_| {
            _ = self.runSingleIteration(&tracking_allocator, bench_fn);
        }

        tracking_allocator.reset();

        var total_time: u64 = 0;
        var iterations: u32 = 0;
        const start_time = std.time.Instant.now() catch unreachable;

        // Main benchmark loop
        while (iterations < self.config.iterations) {
            const iter_time = self.runSingleIteration(&tracking_allocator, bench_fn);
            try times.append(self.allocator, iter_time);
            total_time += iter_time;
            iterations += 1;

            // Check time limits
            const current_time = std.time.Instant.now() catch unreachable;
            const elapsed = current_time.since(start_time);
            if (elapsed >= self.config.max_time_ns) break;
            if (elapsed >= self.config.min_time_ns and iterations >= self.config.iterations / 2) break;
        }

        const stats = BenchStats.calculate(times.items);
        const memory_info = if (self.config.track_memory) tracking_allocator.getMemoryInfo() else null;

        return BenchmarkResult{
            .name = name,
            .iterations_run = iterations,
            .total_time_ns = total_time,
            .stats = stats,
            .memory_info = memory_info,
        };
    }

    fn runSingleIteration(self: *Benchmark, tracking_allocator: *TrackingAllocator, comptime bench_fn: anytype) u64 {
        _ = self;

        const FnType = @TypeOf(bench_fn);
        const fn_info = @typeInfo(FnType).@"fn";

        const start = std.time.Instant.now() catch unreachable;

        // Check function signature and call appropriately
        if (fn_info.params.len == 0) {
            bench_fn();
        } else if (fn_info.params.len == 1) {
            // Assume it takes an allocator
            bench_fn(tracking_allocator.allocator());
        } else {
            @compileError("Benchmark function must take 0 or 1 parameters (allocator)");
        }

        const end = std.time.Instant.now() catch unreachable;
        return end.since(start);
    }
};

/// Convenient function to run benchmarks (matching TODO.md API)
pub fn run(comptime name: []const u8, comptime bench_fn: anytype) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const config = BenchConfig{};
    var benchmark = Benchmark.init(allocator, config);

    const result = try benchmark.runBenchmark(name, bench_fn);

    // Print results
    std.debug.print("{any}\n", .{result});
}

test "benchmark: basic functionality" {
    const TestFn = struct {
        fn simpleLoop() void {
            var sum: u64 = 0;
            for (0..1000) |i| {
                sum += i;
            }
            std.mem.doNotOptimizeAway(sum);
        }
    };

    const config = BenchConfig{
        .iterations = 10,
        .warmup_iterations = 2,
        .min_time_ns = 1_000_000, // 1ms
    };

    var benchmark = Benchmark.init(std.testing.allocator, config);
    const result = try benchmark.runBenchmark("test_loop", TestFn.simpleLoop);

    try std.testing.expect(result.iterations_run > 0);
    try std.testing.expect(result.total_time_ns > 0);
    try std.testing.expect(result.stats.mean > 0);
}

test "benchmark: memory tracking" {
    const TestFn = struct {
        fn allocateMemory(allocator: std.mem.Allocator) void {
            const data = allocator.alloc(u8, 1024) catch return;
            defer allocator.free(data);
            std.mem.doNotOptimizeAway(data);
        }
    };

    const config = BenchConfig{
        .iterations = 5,
        .track_memory = true,
        .warmup_iterations = 1,
    };

    var benchmark = Benchmark.init(std.testing.allocator, config);
    const result = try benchmark.runBenchmark("memory_test", TestFn.allocateMemory);

    try std.testing.expect(result.memory_info != null);
    if (result.memory_info) |mem| {
        try std.testing.expect(mem.bytes_allocated > 0);
        try std.testing.expect(mem.allocations > 0);
    }
}

test "stats: calculation" {
    const times = [_]u64{ 100, 200, 150, 180, 120, 300, 90, 110, 170, 160 };
    const stats = BenchStats.calculate(&times);

    try std.testing.expect(stats.mean > 0);
    try std.testing.expect(stats.median > 0);
    try std.testing.expect(stats.std_dev > 0);
    try std.testing.expect(stats.min <= stats.max);
    try std.testing.expect(stats.p95 >= stats.median);
    try std.testing.expect(stats.p99 >= stats.p95);
}
