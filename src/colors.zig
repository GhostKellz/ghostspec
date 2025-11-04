//! Terminal color and formatting utilities for GhostSpec
//!
//! Provides ANSI color codes and formatting helpers for beautiful terminal output.
//! Automatically detects if colors should be enabled based on terminal capabilities.

const std = @import("std");
const builtin = @import("builtin");

/// Color configuration
pub const ColorConfig = struct {
    enabled: bool = true,
    force: bool = false,

    pub fn auto() ColorConfig {
        return ColorConfig{
            .enabled = shouldUseColors(),
            .force = false,
        };
    }

    pub fn always() ColorConfig {
        return ColorConfig{
            .enabled = true,
            .force = true,
        };
    }

    pub fn never() ColorConfig {
        return ColorConfig{
            .enabled = false,
            .force = false,
        };
    }
};

/// Detect if terminal supports colors
fn shouldUseColors() bool {
    // Check NO_COLOR environment variable
    if (std.posix.getenv("NO_COLOR")) |_| {
        return false;
    }

    // Check FORCE_COLOR environment variable
    if (std.posix.getenv("FORCE_COLOR")) |_| {
        return true;
    }

    // On Windows, always enable (modern Windows supports ANSI)
    if (builtin.os.tag == .windows) {
        return true;
    }

    // Check if TERM is set (indicates terminal environment)
    if (std.posix.getenv("TERM")) |term| {
        // Disable for "dumb" terminals
        if (std.mem.eql(u8, term, "dumb")) {
            return false;
        }
        return true;
    }

    // Default to true for Unix-like systems
    return builtin.os.tag != .windows;
}

/// ANSI color codes
pub const Color = enum {
    reset,
    bold,
    dim,
    italic,
    underline,

    // Foreground colors
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,

    // Bright foreground colors
    bright_black,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,

    pub fn code(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .bold => "\x1b[1m",
            .dim => "\x1b[2m",
            .italic => "\x1b[3m",
            .underline => "\x1b[4m",

            .black => "\x1b[30m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .white => "\x1b[37m",

            .bright_black => "\x1b[90m",
            .bright_red => "\x1b[91m",
            .bright_green => "\x1b[92m",
            .bright_yellow => "\x1b[93m",
            .bright_blue => "\x1b[94m",
            .bright_magenta => "\x1b[95m",
            .bright_cyan => "\x1b[96m",
            .bright_white => "\x1b[97m",
        };
    }
};

/// Styled text builder
pub const Style = struct {
    config: ColorConfig,

    pub fn init(config: ColorConfig) Style {
        return Style{ .config = config };
    }

    /// Format text with color
    pub fn colorize(self: Style, color: Color, text: []const u8) []const u8 {
        _ = self;
        _ = color;
        return text;
    }

    /// Print colored text to writer
    pub fn print(self: Style, writer: anytype, color: Color, comptime fmt: []const u8, args: anytype) !void {
        if (self.config.enabled) {
            try writer.writeAll(color.code());
            try writer.print(fmt, args);
            try writer.writeAll(Color.reset.code());
        } else {
            try writer.print(fmt, args);
        }
    }

    /// Print success message (green)
    pub fn success(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void {
        try self.print(writer, .bright_green, fmt, args);
    }

    /// Print error message (red)
    pub fn err(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void {
        try self.print(writer, .bright_red, fmt, args);
    }

    /// Print warning message (yellow)
    pub fn warn(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void {
        try self.print(writer, .bright_yellow, fmt, args);
    }

    /// Print info message (cyan)
    pub fn info(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void {
        try self.print(writer, .bright_cyan, fmt, args);
    }

    /// Print dim text (for less important info)
    pub fn dim(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void {
        if (self.config.enabled) {
            try writer.writeAll(Color.dim.code());
            try writer.print(fmt, args);
            try writer.writeAll(Color.reset.code());
        } else {
            try writer.print(fmt, args);
        }
    }

    /// Print bold text
    pub fn bold(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void {
        if (self.config.enabled) {
            try writer.writeAll(Color.bold.code());
            try writer.print(fmt, args);
            try writer.writeAll(Color.reset.code());
        } else {
            try writer.print(fmt, args);
        }
    }
};

/// Global color configuration (can be set once at startup)
var global_config: ColorConfig = ColorConfig.auto();

pub fn setGlobalConfig(config: ColorConfig) void {
    global_config = config;
}

pub fn getGlobalConfig() ColorConfig {
    return global_config;
}

/// Get a styled printer with global config
pub fn styled() Style {
    return Style.init(global_config);
}

test "colors: basic functionality" {
    const config = ColorConfig.never();
    const style = Style.init(config);

    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();

    try style.success(output.writer(), "test", .{});
    try std.testing.expectEqualStrings("test", output.items);
}

test "colors: with colors enabled" {
    const config = ColorConfig.always();
    const style = Style.init(config);

    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();

    try style.success(output.writer(), "test", .{});
    try std.testing.expect(std.mem.containsAtLeast(u8, output.items, 1, "\x1b["));
}
