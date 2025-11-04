//! Test result reporting and analysis for GhostSpec
//!
//! Provides comprehensive reporting capabilities including test results,
//! statistics, performance metrics, and various output formats.

const std = @import("std");
const colors = @import("colors.zig");
const runner = @import("runner.zig");

pub const TestExecutionResult = runner.TestExecutionResult;
pub const TestStatus = runner.TestStatus;

/// Overall test report containing all results and statistics
pub const TestReport = struct {
    allocator: std.mem.Allocator,
    results: std.ArrayList(TestExecutionResult),
    total_duration_ms: u64 = 0,

    // Statistics
    total: u32 = 0,
    passed: u32 = 0,
    failed: u32 = 0,
    skipped: u32 = 0,
    timeout: u32 = 0,
    errors: u32 = 0,

    // Performance metrics
    fastest_test_ms: u64 = std.math.maxInt(u64),
    slowest_test_ms: u64 = 0,
    average_test_ms: f64 = 0.0,

    pub fn init(allocator: std.mem.Allocator) TestReport {
        return TestReport{
            .allocator = allocator,
            .results = .empty,
        };
    }

    pub fn deinit(self: *TestReport) void {
        for (self.results.items) |*result| {
            result.deinit(self.allocator);
        }
        self.results.deinit(self.allocator);
    }

    pub fn addResult(self: *TestReport, result: TestExecutionResult) !void {
        try self.results.append(self.allocator, result);
    }

    /// Calculate final statistics after all results are added
    pub fn finalize(self: *TestReport) void {
        self.total = @intCast(self.results.items.len);
        self.passed = 0;
        self.failed = 0;
        self.skipped = 0;
        self.timeout = 0;
        self.errors = 0;

        var total_duration: u64 = 0;

        for (self.results.items) |result| {
            switch (result.status) {
                .passed => self.passed += 1,
                .failed => self.failed += 1,
                .skipped => self.skipped += 1,
                .timeout => self.timeout += 1,
                .err => self.errors += 1,
            }

            if (result.status != .skipped) {
                total_duration += result.duration_ms;

                if (result.duration_ms < self.fastest_test_ms) {
                    self.fastest_test_ms = result.duration_ms;
                }

                if (result.duration_ms > self.slowest_test_ms) {
                    self.slowest_test_ms = result.duration_ms;
                }
            }
        }

        const executed_tests = self.total - self.skipped;
        if (executed_tests > 0) {
            self.average_test_ms = @as(f64, @floatFromInt(total_duration)) / @as(f64, @floatFromInt(executed_tests));
        }

        if (self.fastest_test_ms == std.math.maxInt(u64)) {
            self.fastest_test_ms = 0;
        }
    }

    /// Check if all tests passed
    pub fn allPassed(self: TestReport) bool {
        return self.failed == 0 and self.timeout == 0 and self.errors == 0;
    }

    /// Get success rate as percentage
    pub fn successRate(self: TestReport) f64 {
        if (self.total == 0) return 100.0;
        return (@as(f64, @floatFromInt(self.passed)) / @as(f64, @floatFromInt(self.total))) * 100.0;
    }

    /// Get failures (failed + timeout + errors)
    pub fn totalFailures(self: TestReport) u32 {
        return self.failed + self.timeout + self.errors;
    }

    /// Print summary to stdout
    pub fn printSummary(self: TestReport) void {
        // Use std.debug.print which writes to stderr
        self.printSummarySimple();
    }

    /// Print summary with colors
    pub fn printSummaryColored(self: TestReport, writer: anytype) !void {
        const style = colors.styled();
        const status_emoji = if (self.allPassed()) "✅" else "❌";

        try writer.writeAll("\n");
        if (self.allPassed()) {
            try style.success(writer, "{s} Test Summary\n", .{status_emoji});
        } else {
            try style.err(writer, "{s} Test Summary\n", .{status_emoji});
        }
        try style.dim(writer, "══════════════════════════════════════\n", .{});

        try style.info(writer, "Total tests:     ", .{});
        try writer.print("{any}\n", .{self.total});

        try style.success(writer, "Passed:          ", .{});
        try writer.print("{any} ", .{self.passed});
        try style.dim(writer, "({d:.1}%)\n", .{self.successRate()});

        if (self.failed > 0) {
            try style.err(writer, "Failed:          ", .{});
            try writer.print("{any} ❌\n", .{self.failed});
        }

        if (self.timeout > 0) {
            try style.warn(writer, "Timeouts:        ", .{});
            try writer.print("{any} ⏰\n", .{self.timeout});
        }

        if (self.errors > 0) {
            try style.err(writer, "Errors:          ", .{});
            try writer.print("{any} 💥\n", .{self.errors});
        }

        if (self.skipped > 0) {
            try style.warn(writer, "Skipped:         ", .{});
            try writer.print("{any} ⚠️\n", .{self.skipped});
        }

        try writer.writeAll("\n");
        try style.bold(writer, "⏱️  Performance\n", .{});
        try writer.print("Total duration:  {d:.2}s\n", .{@as(f64, @floatFromInt(self.total_duration_ms)) / 1000.0});
        try writer.print("Average test:    {d:.2}ms\n", .{self.average_test_ms});

        if (self.total > self.skipped) {
            try style.success(writer, "Fastest test:    ", .{});
            try writer.print("{any}ms\n", .{self.fastest_test_ms});
            try style.warn(writer, "Slowest test:    ", .{});
            try writer.print("{any}ms\n", .{self.slowest_test_ms});
        }

        try writer.writeAll("\n");
    }

    /// Print summary without colors (fallback)
    fn printSummarySimple(self: TestReport) void {
        const status_emoji = if (self.allPassed()) "✅" else "❌";

        std.debug.print("\n{s} Test Summary\n", .{status_emoji});
        std.debug.print("══════════════════════════════════════\n", .{});
        std.debug.print("Total tests:     {any}\n", .{self.total});
        std.debug.print("Passed:          {any} ({d:.1}%)\n", .{ self.passed, self.successRate() });

        if (self.failed > 0) {
            std.debug.print("Failed:          {any} ❌\n", .{self.failed});
        }

        if (self.timeout > 0) {
            std.debug.print("Timeouts:        {any} ⏰\n", .{self.timeout});
        }

        if (self.errors > 0) {
            std.debug.print("Errors:          {any} 💥\n", .{self.errors});
        }

        if (self.skipped > 0) {
            std.debug.print("Skipped:         {any} ⚠️\n", .{self.skipped});
        }

        std.debug.print("\n⏱️  Performance\n", .{});
        std.debug.print("Total duration:  {d:.2}s\n", .{@as(f64, @floatFromInt(self.total_duration_ms)) / 1000.0});
        std.debug.print("Average test:    {d:.2}ms\n", .{self.average_test_ms});

        if (self.total > self.skipped) {
            std.debug.print("Fastest test:    {any}ms\n", .{self.fastest_test_ms});
            std.debug.print("Slowest test:    {any}ms\n", .{self.slowest_test_ms});
        }

        std.debug.print("\n", .{});
    }

    /// Print detailed results
    pub fn printDetailed(self: TestReport) void {
        self.printSummary();
        self.printDetailedColored(std.io.getStdErr().writer()) catch {
            self.printDetailedSimple();
        };
    }

    /// Print detailed results with colors
    fn printDetailedColored(self: TestReport, writer: anytype) !void {
        const style = colors.styled();

        if (self.totalFailures() > 0) {
            try writer.writeAll("\n");
            try style.err(writer, "🔍 Failed Tests\n", .{});
            try style.dim(writer, "════════════════════════════════════\n", .{});

            for (self.results.items) |result| {
                if (result.status.isFailure()) {
                    const status_icon = switch (result.status) {
                        .failed => "❌",
                        .timeout => "⏰",
                        .err => "💥",
                        else => "?",
                    };

                    try writer.print("{s} ", .{status_icon});
                    try style.bold(writer, "{s}", .{result.name});
                    try style.dim(writer, " ({d:.2}ms)\n", .{@as(f64, @floatFromInt(result.duration_ms))});

                    if (result.error_message) |msg| {
                        try style.err(writer, "   ┗━ Error: ", .{});
                        try writer.print("{s}\n", .{msg});

                        // Add helpful hints based on common errors
                        if (std.mem.indexOf(u8, msg, "OutOfMemory") != null) {
                            try style.dim(writer, "      💡 Hint: Consider checking for memory leaks or increasing available memory\n", .{});
                        } else if (std.mem.indexOf(u8, msg, "FileNotFound") != null) {
                            try style.dim(writer, "      💡 Hint: Verify the file path exists and is accessible\n", .{});
                        } else if (std.mem.indexOf(u8, msg, "AccessDenied") != null) {
                            try style.dim(writer, "      💡 Hint: Check file permissions\n", .{});
                        }
                    }

                    if (result.stderr) |stderr| {
                        try style.warn(writer, "   ┗━ Stderr: ", .{});
                        try writer.print("{s}\n", .{stderr});
                    }

                    try writer.writeAll("\n");
                }
            }
        }
    }

    /// Print detailed results without colors (fallback)
    fn printDetailedSimple(self: TestReport) void {
        if (self.totalFailures() > 0) {
            std.debug.print("🔍 Failed Tests\n", .{});
            std.debug.print("════════════════════════════════════\n", .{});

            for (self.results.items) |result| {
                if (result.status.isFailure()) {
                    const status_icon = switch (result.status) {
                        .failed => "❌",
                        .timeout => "⏰",
                        .err => "💥",
                        else => "?",
                    };

                    std.debug.print("{s} {s} ({d:.2}ms)\n", .{ status_icon, result.name, @as(f64, @floatFromInt(result.duration_ms)) });

                    if (result.error_message) |msg| {
                        std.debug.print("   Error: {s}\n", .{msg});
                    }

                    if (result.stderr) |stderr| {
                        std.debug.print("   Stderr: {s}\n", .{stderr});
                    }

                    std.debug.print("\n", .{});
                }
            }
        }

        // Show slowest tests
        if (self.results.items.len > 1) {
            std.debug.print("🐌 Slowest Tests\n", .{});
            std.debug.print("════════════════════════════════════\n", .{});

            // Create a copy for sorting
            var sorted_results = std.ArrayList(TestExecutionResult).init(std.heap.page_allocator);
            defer sorted_results.deinit();

            for (self.results.items) |result| {
                if (result.status != .skipped) {
                    sorted_results.append(result) catch continue;
                }
            }

            std.mem.sort(TestExecutionResult, sorted_results.items, {}, struct {
                fn lessThan(_: void, a: TestExecutionResult, b: TestExecutionResult) bool {
                    return a.duration_ms > b.duration_ms; // Descending order
                }
            }.lessThan);

            const num_to_show = @min(5, sorted_results.items.len);
            for (sorted_results.items[0..num_to_show]) |result| {
                std.debug.print("   {s}: {d:.2}ms\n", .{ result.name, @as(f64, @floatFromInt(result.duration_ms)) });
            }

            std.debug.print("\n", .{});
        }
    }

    /// Export results as JSON
    pub fn exportJson(self: TestReport, writer: anytype) !void {
        try writer.writeAll("{\n");
        try writer.print("  \"summary\": {{\n", .{});
        try writer.print("    \"total\": {any},\n", .{self.total});
        try writer.print("    \"passed\": {any},\n", .{self.passed});
        try writer.print("    \"failed\": {},\n", .{self.failed});
        try writer.print("    \"skipped\": {},\n", .{self.skipped});
        try writer.print("    \"timeout\": {},\n", .{self.timeout});
        try writer.print("    \"errors\": {},\n", .{self.errors});
        try writer.print("    \"success_rate\": {d:.2},\n", .{self.successRate()});
        try writer.print("    \"total_duration_ms\": {},\n", .{self.total_duration_ms});
        try writer.print("    \"average_test_ms\": {d:.2}\n", .{self.average_test_ms});
        try writer.writeAll("  },\n");

        try writer.writeAll("  \"results\": [\n");
        for (self.results.items, 0..) |result, i| {
            try writer.writeAll("    {\n");
            try writer.print("      \"name\": \"{s}\",\n", .{result.name});
            try writer.print("      \"status\": \"{s}\",\n", .{@tagName(result.status)});
            try writer.print("      \"duration_ms\": {}", .{result.duration_ms});

            if (result.error_message) |msg| {
                try writer.print(",\n      \"error_message\": \"{s}\"", .{msg});
            }

            try writer.writeAll("\n    }");
            if (i < self.results.items.len - 1) {
                try writer.writeAll(",");
            }
            try writer.writeAll("\n");
        }
        try writer.writeAll("  ]\n");
        try writer.writeAll("}\n");
    }

    /// Export results as JUnit XML
    pub fn exportJUnit(self: TestReport, writer: anytype) !void {
        try writer.writeAll("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        try writer.print("<testsuite name=\"GhostSpec\" tests=\"{}\" failures=\"{}\" errors=\"{}\" skipped=\"{}\" time=\"{d:.3}\">\n", .{
            self.total,
            self.failed + self.timeout,
            self.errors,
            self.skipped,
            @as(f64, @floatFromInt(self.total_duration_ms)) / 1000.0,
        });

        for (self.results.items) |result| {
            try writer.print("  <testcase name=\"{s}\" time=\"{d:.3}\"", .{
                result.name,
                @as(f64, @floatFromInt(result.duration_ms)) / 1000.0,
            });

            switch (result.status) {
                .passed => {
                    try writer.writeAll("/>\n");
                },
                .failed => {
                    try writer.writeAll(">\n");
                    try writer.writeAll("    <failure message=\"Test failed\">");
                    if (result.error_message) |msg| {
                        try writer.print("{s}", .{msg});
                    }
                    try writer.writeAll("</failure>\n");
                    try writer.writeAll("  </testcase>\n");
                },
                .timeout => {
                    try writer.writeAll(">\n");
                    try writer.writeAll("    <failure message=\"Test timeout\"/>\n");
                    try writer.writeAll("  </testcase>\n");
                },
                .err => {
                    try writer.writeAll(">\n");
                    try writer.writeAll("    <error message=\"Test error\">");
                    if (result.error_message) |msg| {
                        try writer.print("{s}", .{msg});
                    }
                    try writer.writeAll("</error>\n");
                    try writer.writeAll("  </testcase>\n");
                },
                .skipped => {
                    try writer.writeAll(">\n");
                    try writer.writeAll("    <skipped/>\n");
                    try writer.writeAll("  </testcase>\n");
                },
            }
        }

        try writer.writeAll("</testsuite>\n");
    }
};


test "reporter: basic functionality" {
    var report = TestReport.init(std.testing.allocator);
    defer report.deinit();

    // Add some test results
    try report.addResult(TestExecutionResult{
        .name = "test1",
        .status = .passed,
        .duration_ms = 100,
    });

    try report.addResult(TestExecutionResult{
        .name = "test2",
        .status = .failed,
        .duration_ms = 200,
        .error_message = null,
    });

    try report.addResult(TestExecutionResult{
        .name = "test3",
        .status = .skipped,
        .duration_ms = 0,
    });

    report.finalize();

    try std.testing.expect(report.total == 3);
    try std.testing.expect(report.passed == 1);
    try std.testing.expect(report.failed == 1);
    try std.testing.expect(report.skipped == 1);
    try std.testing.expect(!report.allPassed());
    try std.testing.expect(report.successRate() > 0.0 and report.successRate() < 100.0);
}

test "reporter: JSON export" {
    var report = TestReport.init(std.testing.allocator);
    defer report.deinit();

    try report.addResult(TestExecutionResult{
        .name = "test1",
        .status = .passed,
        .duration_ms = 50,
    });

    report.finalize();

    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();

    try report.exportJson(output.writer());

    const json_str = output.items;
    try std.testing.expect(std.mem.containsAtLeast(u8, json_str, 1, "\"total\": 1"));
    try std.testing.expect(std.mem.containsAtLeast(u8, json_str, 1, "\"passed\": 1"));
}

test "reporter: JUnit XML export" {
    var report = TestReport.init(std.testing.allocator);
    defer report.deinit();

    try report.addResult(TestExecutionResult{
        .name = "test1",
        .status = .passed,
        .duration_ms = 100,
    });

    report.finalize();

    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();

    try report.exportJUnit(output.writer());

    const xml_str = output.items;
    try std.testing.expect(std.mem.containsAtLeast(u8, xml_str, 1, "<testsuite"));
    try std.testing.expect(std.mem.containsAtLeast(u8, xml_str, 1, "<testcase"));
    try std.testing.expect(std.mem.containsAtLeast(u8, xml_str, 1, "tests=\"1\""));
}
