//! Test filtering system for GhostSpec
//!
//! Allows selective test execution based on patterns, names, and tags.

const std = @import("std");

/// Filter configuration
pub const FilterConfig = struct {
    /// Include patterns (glob-style)
    include_patterns: []const []const u8 = &.{},
    /// Exclude patterns (glob-style)
    exclude_patterns: []const []const u8 = &.{},
    /// Exact names to include
    exact_names: []const []const u8 = &.{},
    /// Whether to run only failed tests from previous run
    failed_only: bool = false,

    /// Check if any filters are active
    pub fn hasFilters(self: FilterConfig) bool {
        return self.include_patterns.len > 0 or
            self.exclude_patterns.len > 0 or
            self.exact_names.len > 0 or
            self.failed_only;
    }
};

/// Test filter
pub const TestFilter = struct {
    config: FilterConfig,
    allocator: std.mem.Allocator,
    failed_tests: ?std.StringHashMap(void) = null,

    pub fn init(allocator: std.mem.Allocator, config: FilterConfig) TestFilter {
        return TestFilter{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *TestFilter) void {
        if (self.failed_tests) |*ft| {
            ft.deinit();
        }
    }

    /// Load failed tests from previous run
    pub fn loadFailedTests(self: *TestFilter, file_path: []const u8) !void {
        var map = std.StringHashMap(void).init(self.allocator);
        errdefer map.deinit();

        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return; // No previous failures
            }
            return err;
        };
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var reader = buf_reader.reader();

        var line_buf: [1024]u8 = undefined;
        while (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len > 0) {
                const name_copy = try self.allocator.dupe(u8, trimmed);
                try map.put(name_copy, {});
            }
        }

        self.failed_tests = map;
    }

    /// Check if a test should be run based on filter rules
    pub fn shouldRun(self: *const TestFilter, test_name: []const u8) bool {
        // If failed_only mode and we have failed tests list
        if (self.config.failed_only) {
            if (self.failed_tests) |ft| {
                return ft.contains(test_name);
            }
            // No failed tests list, run all
            return true;
        }

        // Check exact names first (highest priority)
        if (self.config.exact_names.len > 0) {
            for (self.config.exact_names) |name| {
                if (std.mem.eql(u8, test_name, name)) {
                    return !self.isExcluded(test_name);
                }
            }
            // Name not in exact list, skip
            return false;
        }

        // Check include patterns
        if (self.config.include_patterns.len > 0) {
            var matched = false;
            for (self.config.include_patterns) |pattern| {
                if (matchPattern(test_name, pattern)) {
                    matched = true;
                    break;
                }
            }
            if (!matched) return false;
        }

        // Check exclude patterns
        return !self.isExcluded(test_name);
    }

    fn isExcluded(self: *const TestFilter, test_name: []const u8) bool {
        for (self.config.exclude_patterns) |pattern| {
            if (matchPattern(test_name, pattern)) {
                return true;
            }
        }
        return false;
    }

    /// Count how many tests would run
    pub fn countMatches(self: *const TestFilter, test_names: []const []const u8) usize {
        var count: usize = 0;
        for (test_names) |name| {
            if (self.shouldRun(name)) {
                count += 1;
            }
        }
        return count;
    }

    /// Get list of tests that will run (caller owns returned slice)
    pub fn getMatchingTests(self: *const TestFilter, allocator: std.mem.Allocator, test_names: []const []const u8) ![]const []const u8 {
        var matching = std.ArrayList([]const u8).init(allocator);
        errdefer matching.deinit();

        for (test_names) |name| {
            if (self.shouldRun(name)) {
                try matching.append(name);
            }
        }

        return matching.toOwnedSlice();
    }
};

/// Simple glob-style pattern matching
/// Supports:
/// - * : matches any sequence of characters
/// - ? : matches a single character
/// - literal strings
pub fn matchPattern(text: []const u8, pattern: []const u8) bool {
    return matchPatternRecursive(text, pattern, 0, 0);
}

fn matchPatternRecursive(text: []const u8, pattern: []const u8, text_idx: usize, pattern_idx: usize) bool {
    // Both exhausted - match
    if (text_idx == text.len and pattern_idx == pattern.len) {
        return true;
    }

    // Pattern exhausted but text remains - no match
    if (pattern_idx == pattern.len) {
        return false;
    }

    // Handle wildcards
    if (pattern[pattern_idx] == '*') {
        // Try matching zero or more characters
        // First try matching zero (skip the *)
        if (matchPatternRecursive(text, pattern, text_idx, pattern_idx + 1)) {
            return true;
        }
        // Try matching one or more (consume one char from text)
        if (text_idx < text.len) {
            return matchPatternRecursive(text, pattern, text_idx + 1, pattern_idx);
        }
        return false;
    }

    // Text exhausted but pattern has non-* - no match
    if (text_idx == text.len) {
        return false;
    }

    // Handle single character wildcard
    if (pattern[pattern_idx] == '?') {
        return matchPatternRecursive(text, pattern, text_idx + 1, pattern_idx + 1);
    }

    // Literal character match
    if (text[text_idx] == pattern[pattern_idx]) {
        return matchPatternRecursive(text, pattern, text_idx + 1, pattern_idx + 1);
    }

    return false;
}

test "filter: pattern matching" {
    try std.testing.expect(matchPattern("hello", "hello"));
    try std.testing.expect(matchPattern("hello world", "hello*"));
    try std.testing.expect(matchPattern("hello world", "*world"));
    try std.testing.expect(matchPattern("hello world", "*o*"));
    try std.testing.expect(matchPattern("test", "te??"));
    try std.testing.expect(matchPattern("test123", "test*"));

    try std.testing.expect(!matchPattern("hello", "world"));
    try std.testing.expect(!matchPattern("hello", "hello world"));
    try std.testing.expect(!matchPattern("test", "te?"));
}

test "filter: basic filtering" {
    const config = FilterConfig{
        .include_patterns = &.{"test_*"},
        .exclude_patterns = &.{"*_slow"},
    };

    const filter = TestFilter.init(std.testing.allocator, config);

    try std.testing.expect(filter.shouldRun("test_fast"));
    try std.testing.expect(filter.shouldRun("test_basic"));
    try std.testing.expect(!filter.shouldRun("test_slow"));
    try std.testing.expect(!filter.shouldRun("other_test"));
}

test "filter: exact names" {
    const config = FilterConfig{
        .exact_names = &.{ "test1", "test2" },
    };

    const filter = TestFilter.init(std.testing.allocator, config);

    try std.testing.expect(filter.shouldRun("test1"));
    try std.testing.expect(filter.shouldRun("test2"));
    try std.testing.expect(!filter.shouldRun("test3"));
    try std.testing.expect(!filter.shouldRun("test1_extra"));
}

test "filter: count matches" {
    const config = FilterConfig{
        .include_patterns = &.{"test_*"},
    };

    const filter = TestFilter.init(std.testing.allocator, config);

    const tests = [_][]const u8{ "test_a", "test_b", "other", "test_c" };
    const count = filter.countMatches(&tests);

    try std.testing.expectEqual(@as(usize, 3), count);
}
