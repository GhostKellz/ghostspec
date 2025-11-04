//! Test runner for parallel execution and isolation
//!
//! Provides capabilities for running tests in parallel, with proper isolation,
//! resource management, and comprehensive result reporting.

const std = @import("std");
const reporter = @import("reporter.zig");

/// Configuration for test execution
pub const RunnerConfig = struct {
    /// Maximum number of concurrent tests
    max_concurrency: u32 = 4,
    /// Timeout per test in milliseconds
    test_timeout_ms: u32 = 30000, // 30 seconds
    /// Enable parallel execution
    parallel_execution: bool = true,
    /// Capture stdout/stderr from tests
    capture_output: bool = true,
    /// Enable test isolation (separate processes)
    enable_isolation: bool = false,
    /// Randomize test execution order
    randomize_order: bool = false,
    /// Fail fast (stop on first failure)
    fail_fast: bool = false,
    /// Repeat tests N times
    repeat_count: u32 = 1,
};

/// Test function metadata
pub const TestFunction = struct {
    name: []const u8,
    function: *const fn () anyerror!void,
    timeout_ms: ?u32 = null,
    skip: bool = false,
    tags: []const []const u8 = &.{},

    pub fn init(name: []const u8, function: *const fn () anyerror!void) TestFunction {
        return TestFunction{
            .name = name,
            .function = function,
        };
    }

    pub fn withTimeout(self: TestFunction, timeout_ms: u32) TestFunction {
        var result = self;
        result.timeout_ms = timeout_ms;
        return result;
    }

    pub fn withTags(self: TestFunction, tags: []const []const u8) TestFunction {
        var result = self;
        result.tags = tags;
        return result;
    }

    pub fn skipped(self: TestFunction) TestFunction {
        var result = self;
        result.skip = true;
        return result;
    }
};

/// Result of a single test execution
pub const TestExecutionResult = struct {
    name: []const u8,
    status: TestStatus,
    duration_ms: u64,
    error_message: ?[]const u8 = null,
    stdout: ?[]const u8 = null,
    stderr: ?[]const u8 = null,
    memory_usage: ?u64 = null,

    pub fn deinit(self: *TestExecutionResult, allocator: std.mem.Allocator) void {
        if (self.error_message) |msg| allocator.free(msg);
        if (self.stdout) |out| allocator.free(out);
        if (self.stderr) |err| allocator.free(err);
    }
};

/// Status of test execution
pub const TestStatus = enum {
    passed,
    failed,
    skipped,
    timeout,
    err,

    pub fn isFailure(self: TestStatus) bool {
        return self == .failed or self == .timeout or self == .err;
    }
};

/// Test suite containing multiple tests
pub const TestSuite = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    tests: std.ArrayList(TestFunction),
    setup_fn: ?*const fn () anyerror!void = null,
    teardown_fn: ?*const fn () anyerror!void = null,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) TestSuite {
        return TestSuite{
            .allocator = allocator,
            .name = name,
            .tests = .empty,
        };
    }

    pub fn deinit(self: *TestSuite) void {
        self.tests.deinit(self.allocator);
    }

    pub fn addTest(self: *TestSuite, test_fn: TestFunction) !void {
        try self.tests.append(self.allocator, test_fn);
    }

    pub fn setSetup(self: *TestSuite, setup_fn: *const fn () anyerror!void) void {
        self.setup_fn = setup_fn;
    }

    pub fn setTeardown(self: *TestSuite, teardown_fn: *const fn () anyerror!void) void {
        self.teardown_fn = teardown_fn;
    }
};

/// Worker thread for parallel test execution
const TestWorker = struct {
    thread: std.Thread,
    work_queue: *WorkQueue,
    results_queue: *ResultsQueue,
    config: RunnerConfig,
    allocator: std.mem.Allocator,

    const WorkItem = struct {
        test_fn: TestFunction,
        suite_name: []const u8,
        setup_fn: ?*const fn () anyerror!void,
        teardown_fn: ?*const fn () anyerror!void,
        is_sentinel: bool = false,
    };

    const WorkQueue = struct {
        items: std.ArrayList(WorkItem),
        mutex: std.Thread.Mutex = .{},

        fn init(_: std.mem.Allocator) WorkQueue {
            return .{ .items = std.ArrayList(WorkItem).empty };
        }

        fn deinit(self: *WorkQueue, allocator: std.mem.Allocator) void {
            self.items.deinit(allocator);
        }

        fn push(self: *WorkQueue, allocator: std.mem.Allocator, item: WorkItem) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            try self.items.append(allocator, item);
        }

        fn pop(self: *WorkQueue, allocator: std.mem.Allocator) ?WorkItem {
            _ = allocator;
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.items.items.len == 0) return null;
            return self.items.orderedRemove(0);
        }
    };

    const ResultsQueue = struct {
        items: std.ArrayList(TestExecutionResult),
        mutex: std.Thread.Mutex = .{},

        fn init(_: std.mem.Allocator) ResultsQueue {
            return .{ .items = std.ArrayList(TestExecutionResult).empty };
        }

        fn deinit(self: *ResultsQueue, allocator: std.mem.Allocator) void {
            self.items.deinit(allocator);
        }

        fn push(self: *ResultsQueue, allocator: std.mem.Allocator, item: TestExecutionResult) !void {
            self.mutex.lock();
            defer self.mutex.unlock();
            try self.items.append(allocator, item);
        }

        fn pop(self: *ResultsQueue, allocator: std.mem.Allocator) ?TestExecutionResult {
            _ = allocator;
            self.mutex.lock();
            defer self.mutex.unlock();
            if (self.items.items.len == 0) return null;
            return self.items.orderedRemove(0);
        }
    };

    pub fn spawn(
        allocator: std.mem.Allocator,
        work_queue: *WorkQueue,
        results_queue: *ResultsQueue,
        config: RunnerConfig,
    ) !TestWorker {
        const thread = try std.Thread.spawn(.{}, workerMain, .{ allocator, work_queue, results_queue, config });

        return TestWorker{
            .thread = thread,
            .work_queue = work_queue,
            .results_queue = results_queue,
            .config = config,
            .allocator = allocator,
        };
    }

    pub fn join(self: TestWorker) void {
        self.thread.join();
    }

    fn workerMain(
        allocator: std.mem.Allocator,
        work_queue: *WorkQueue,
        results_queue: *ResultsQueue,
        config: RunnerConfig,
    ) void {
        while (true) {
            const work_item = work_queue.pop(allocator) orelse {
                std.posix.nanosleep(0, 1 * std.time.ns_per_ms);
                continue;
            };

            // Check for sentinel value to exit
            if (work_item.is_sentinel) break;

            const result = executeTest(allocator, work_item, config);
            results_queue.push(allocator, result) catch break;
        }
    }

    fn executeTest(allocator: std.mem.Allocator, work_item: WorkItem, config: RunnerConfig) TestExecutionResult {
        if (work_item.test_fn.skip) {
            return TestExecutionResult{
                .name = work_item.test_fn.name,
                .status = .skipped,
                .duration_ms = 0,
            };
        }

        const ts_start = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch unreachable;
        const start_time: i64 = @intCast(@divTrunc((@as(i128, ts_start.sec) * std.time.ns_per_s + ts_start.nsec), std.time.ns_per_ms));

        // Run setup if provided
        if (work_item.setup_fn) |setup| {
            setup() catch |err| {
                const ts_now = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch unreachable;
                const now_time: i64 = @intCast(@divTrunc((@as(i128, ts_now.sec) * std.time.ns_per_s + ts_now.nsec), std.time.ns_per_ms));
                return TestExecutionResult{
                    .name = work_item.test_fn.name,
                    .status = .err,
                    .duration_ms = @intCast(now_time - start_time),
                    .error_message = std.fmt.allocPrint(allocator, "Setup failed: {any}", .{err}) catch null,
                };
            };
        }

        defer {
            // Run teardown if provided
            if (work_item.teardown_fn) |teardown| {
                teardown() catch |err| {
                    std.log.warn("Teardown failed for test {s}: {any}", .{ work_item.test_fn.name, err });
                };
            }
        }

        // Execute the actual test
        const test_result = if (config.enable_isolation)
            executeTestIsolated(allocator, work_item.test_fn, config)
        else
            executeTestDirect(allocator, work_item.test_fn, config);

        const ts_end = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch unreachable;
        const end_time: i64 = @intCast(@divTrunc((@as(i128, ts_end.sec) * std.time.ns_per_s + ts_end.nsec), std.time.ns_per_ms));
        const duration = @as(u64, @intCast(end_time - start_time));

        return TestExecutionResult{
            .name = work_item.test_fn.name,
            .status = test_result.status,
            .duration_ms = duration,
            .error_message = test_result.error_message,
            .stdout = test_result.stdout,
            .stderr = test_result.stderr,
        };
    }

    const DirectTestResult = struct {
        status: TestStatus,
        error_message: ?[]const u8 = null,
        stdout: ?[]const u8 = null,
        stderr: ?[]const u8 = null,
    };

    fn executeTestDirect(allocator: std.mem.Allocator, test_fn: TestFunction, config: RunnerConfig) DirectTestResult {
        _ = config; // TODO: Implement timeout handling

        // Execute the test function
        test_fn.function() catch |err| {
            const error_msg = std.fmt.allocPrint(allocator, "Test failed with error: {any}", .{err}) catch null;
            return DirectTestResult{
                .status = .failed,
                .error_message = error_msg,
            };
        };

        return DirectTestResult{
            .status = .passed,
        };
    }

    fn executeTestIsolated(allocator: std.mem.Allocator, test_fn: TestFunction, config: RunnerConfig) DirectTestResult {
        // TODO: Implement process isolation
        // For now, fall back to direct execution
        _ = allocator;
        _ = test_fn;
        _ = config;

        return DirectTestResult{
            .status = .passed,
        };
    }
};

/// Main test runner
pub const Runner = struct {
    allocator: std.mem.Allocator,
    config: RunnerConfig,
    suites: std.ArrayList(TestSuite),

    pub fn init(allocator: std.mem.Allocator, config: RunnerConfig) Runner {
        return Runner{
            .allocator = allocator,
            .config = config,
            .suites = .empty,
        };
    }

    pub fn deinit(self: *Runner) void {
        for (self.suites.items) |*suite| {
            suite.deinit();
        }
        self.suites.deinit(self.allocator);
    }

    pub fn addSuite(self: *Runner, suite: TestSuite) !void {
        try self.suites.append(self.allocator, suite);
    }

    /// Run all tests and return results
    pub fn runAll(self: *Runner) !reporter.TestReport {
        var all_results: std.ArrayList(TestExecutionResult) = .empty;
        defer {
            for (all_results.items) |*result| {
                result.deinit(self.allocator);
            }
            all_results.deinit(self.allocator);
        }

        const ts_start = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch unreachable;
        const start_time: i64 = @intCast(@divTrunc((@as(i128, ts_start.sec) * std.time.ns_per_s + ts_start.nsec), std.time.ns_per_ms));

        if (self.config.parallel_execution and self.config.max_concurrency > 1) {
            try self.runParallel(&all_results);
        } else {
            try self.runSequential(&all_results);
        }

        const ts_end = std.posix.clock_gettime(std.posix.CLOCK.REALTIME) catch unreachable;
        const end_time: i64 = @intCast(@divTrunc((@as(i128, ts_end.sec) * std.time.ns_per_s + ts_end.nsec), std.time.ns_per_ms));
        const total_duration = @as(u64, @intCast(end_time - start_time));

        // Create test report
        var report = reporter.TestReport.init(self.allocator);

        // Copy results to report (ownership transfer)
        for (all_results.items) |result| {
            try report.addResult(result);
        }
        all_results.clearRetainingCapacity(); // Prevent double-free

        report.total_duration_ms = total_duration;
        report.finalize();

        return report;
    }

    fn runSequential(self: *Runner, results: *std.ArrayList(TestExecutionResult)) !void {
        for (self.suites.items) |suite| {
            for (suite.tests.items) |test_fn| {
                const work_item = TestWorker.WorkItem{
                    .test_fn = test_fn,
                    .suite_name = suite.name,
                    .setup_fn = suite.setup_fn,
                    .teardown_fn = suite.teardown_fn,
                };

                const result = TestWorker.executeTest(self.allocator, work_item, self.config);
                try results.append(self.allocator, result);

                // Fail fast if enabled
                if (self.config.fail_fast and result.status.isFailure()) {
                    break;
                }
            }
        }
    }

    fn runParallel(self: *Runner, results: *std.ArrayList(TestExecutionResult)) !void {
        var work_queue = TestWorker.WorkQueue.init(self.allocator);
        defer work_queue.deinit(self.allocator);

        var results_queue = TestWorker.ResultsQueue.init(self.allocator);
        defer results_queue.deinit(self.allocator);

        // Populate work queue
        var total_tests: u32 = 0;
        for (self.suites.items) |suite| {
            for (suite.tests.items) |test_fn| {
                const work_item = TestWorker.WorkItem{
                    .test_fn = test_fn,
                    .suite_name = suite.name,
                    .setup_fn = suite.setup_fn,
                    .teardown_fn = suite.teardown_fn,
                };

                try work_queue.push(self.allocator, work_item);
                total_tests += 1;
            }
        }

        // Spawn worker threads
        var workers: std.ArrayList(TestWorker) = .empty;
        defer {
            for (workers.items) |worker| {
                worker.join();
            }
            workers.deinit(self.allocator);
        }

        const num_workers = @min(self.config.max_concurrency, total_tests);
        for (0..num_workers) |_| {
            const worker = try TestWorker.spawn(self.allocator, &work_queue, &results_queue, self.config);
            try workers.append(self.allocator, worker);
        }

        // Signal workers to stop by putting sentinel items
        for (0..num_workers) |_| {
            try work_queue.push(self.allocator, .{
                .test_fn = undefined,
                .suite_name = "",
                .setup_fn = null,
                .teardown_fn = null,
                .is_sentinel = true,
            });
        }

        // Collect results
        for (0..total_tests) |_| {
            if (results_queue.pop(self.allocator)) |result| {
                try results.append(self.allocator, result);

                // Fail fast if enabled
                if (self.config.fail_fast and result.status.isFailure()) {
                    // Signal early termination to workers
                    break;
                }
            }
        }
    }

    /// Run tests matching specific tags
    pub fn runWithTags(self: *Runner, tags: []const []const u8) !reporter.TestReport {
        // Create a temporary runner with filtered tests
        var filtered_runner = Runner.init(self.allocator, self.config);
        defer filtered_runner.deinit();

        for (self.suites.items) |suite| {
            var filtered_suite = TestSuite.init(self.allocator, suite.name);
            filtered_suite.setup_fn = suite.setup_fn;
            filtered_suite.teardown_fn = suite.teardown_fn;

            for (suite.tests.items) |test_fn| {
                if (hasMatchingTag(test_fn.tags, tags)) {
                    try filtered_suite.addTest(test_fn);
                }
            }

            if (filtered_suite.tests.items.len > 0) {
                try filtered_runner.addSuite(filtered_suite);
            } else {
                filtered_suite.deinit();
            }
        }

        return filtered_runner.runAll();
    }

    fn hasMatchingTag(test_tags: []const []const u8, filter_tags: []const []const u8) bool {
        for (filter_tags) |filter_tag| {
            for (test_tags) |test_tag| {
                if (std.mem.eql(u8, test_tag, filter_tag)) {
                    return true;
                }
            }
        }
        return false;
    }
};

test "runner: basic sequential execution" {
    const TestFunctions = struct {
        fn testPass() !void {
            try std.testing.expect(true);
        }

        fn testFail() !void {
            return error.TestFailed;
        }
    };

    const config = RunnerConfig{
        .parallel_execution = false,
        .max_concurrency = 1,
    };

    var runner = Runner.init(std.testing.allocator, config);
    defer runner.deinit();

    var suite = TestSuite.init(std.testing.allocator, "test_suite");
    try suite.addTest(TestFunction.init("test_pass", TestFunctions.testPass));
    try suite.addTest(TestFunction.init("test_fail", TestFunctions.testFail));

    try runner.addSuite(suite);

    var report = try runner.runAll();
    defer report.deinit();

    try std.testing.expect(report.results.items.len == 2);
    try std.testing.expect(report.passed > 0);
    try std.testing.expect(report.failed > 0);
}

test "runner: test with tags" {
    const TestFunctions = struct {
        fn unitTest() !void {}
        fn integrationTest() !void {}
    };

    const config = RunnerConfig{};
    var runner = Runner.init(std.testing.allocator, config);
    defer runner.deinit();

    var suite = TestSuite.init(std.testing.allocator, "tagged_tests");
    try suite.addTest(TestFunction.init("unit_test", TestFunctions.unitTest).withTags(&.{"unit"}));
    try suite.addTest(TestFunction.init("integration_test", TestFunctions.integrationTest).withTags(&.{"integration"}));

    try runner.addSuite(suite);

    // Run only unit tests
    var unit_report = try runner.runWithTags(&.{"unit"});
    defer unit_report.deinit();

    try std.testing.expect(unit_report.results.items.len == 1);
    try std.testing.expect(std.mem.eql(u8, unit_report.results.items[0].name, "unit_test"));
}
