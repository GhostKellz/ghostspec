# Fuzzing Examples

Examples of using GhostSpec's fuzzing capabilities to find edge cases and bugs.

## Basic Fuzzing

```zig
const std = @import("std");
const ghostspec = @import("ghostspec");

test "basic fuzzing" {
    try ghostspec.fuzz("parse integer", fuzzParseInteger);
    try ghostspec.fuzz("json parsing", fuzzJsonParse);
    try ghostspec.fuzz("string operations", fuzzStringOps);
}

fn fuzzParseInteger(data: []const u8) !void {
    // Try to parse the input as an integer
    _ = std.fmt.parseInt(i32, data, 10) catch {
        // Expected to fail for invalid input - this is normal
        return;
    };
}

fn fuzzJsonParse(data: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Try to parse as JSON
    std.json.parseFromSlice(std.json.Value, allocator, data, .{}) catch {
        // Expected to fail for invalid JSON - this is normal
        return;
    };
}

fn fuzzStringOps(data: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Test various string operations
    _ = std.mem.indexOf(u8, data, "test") catch {};
    _ = std.mem.indexOfAny(u8, data, "abc") catch {};
    _ = std.mem.indexOfScalar(u8, data, 'x') catch {};

    // Test string splitting
    var splits = std.mem.split(u8, data, " ");
    while (splits.next()) |_| {
        // Just iterate
    }
}
```

## Structured Fuzzing

```zig
test "structured fuzzing" {
    try ghostspec.fuzz("person data", fuzzPersonData);
    try ghostspec.fuzz("network packet", fuzzNetworkPacket);
    try ghostspec.fuzz("file path", fuzzFilePath);
}

const Person = struct {
    name: []const u8,
    age: u32,
    email: []const u8,
};

fn fuzzPersonData(data: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Try to parse as JSON and validate as Person
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, data, .{}) catch return;

    // Validate structure
    const obj = parsed.value.object;
    if (obj.get("name")) |name_val| {
        if (name_val != .string) return;
        if (name_val.string.len == 0) return; // Invalid: empty name
    } else return; // Missing name

    if (obj.get("age")) |age_val| {
        if (age_val != .integer) return;
        const age = @as(u32, @intCast(age_val.integer));
        if (age > 150) return; // Invalid: unreasonable age
    } else return; // Missing age

    if (obj.get("email")) |email_val| {
        if (email_val != .string) return;
        if (std.mem.indexOf(u8, email_val.string, "@") == null) return; // Invalid: no @ in email
    } else return; // Missing email
}

const NetworkPacket = struct {
    source_ip: []const u8,
    dest_ip: []const u8,
    port: u16,
    payload: []const u8,
};

fn fuzzNetworkPacket(data: []const u8) !void {
    if (data.len < 8) return; // Too small for a valid packet

    // Parse packet structure
    const source_ip = data[0..4];
    const dest_ip = data[4..8];
    const port_bytes = data[8..10];
    const port = std.mem.readInt(u16, port_bytes[0..2], .big);

    // Validate IP addresses (basic check)
    for (source_ip) |byte| {
        if (byte == 0) return; // Invalid: null bytes in IP
    }
    for (dest_ip) |byte| {
        if (byte == 0) return; // Invalid: null bytes in IP
    }

    // Validate port
    if (port == 0) return; // Invalid: port 0

    // Process payload if any
    if (data.len > 10) {
        const payload = data[10..];
        // Look for dangerous patterns
        if (std.mem.indexOf(u8, payload, "..")) |_| return; // Directory traversal
        if (std.mem.indexOf(u8, payload, "<script>")) |_| return; // XSS attempt
    }
}

fn fuzzFilePath(data: []const u8) !void {
    // Check for path traversal attacks
    if (std.mem.indexOf(u8, data, "..")) |_| {
        // Found potential path traversal
        // This might be an attack attempt
        return;
    }

    // Check for absolute paths
    if (data.len > 0 and data[0] == '/') return; // Unix absolute path
    if (data.len > 2 and data[1] == ':' and data[2] == '\\') return; // Windows absolute path

    // Check for null bytes
    if (std.mem.indexOfScalar(u8, data, 0)) |_| return;

    // Try to validate as a reasonable file path
    if (std.mem.indexOfAny(u8, data, "/\\:*?\"<>|")) |_| {
        // Contains invalid characters for filename
        return;
    }
}
```

## Algorithm Fuzzing

```zig
test "algorithm fuzzing" {
    try ghostspec.fuzz("sorting algorithm", fuzzSorting);
    try ghostspec.fuzz("search algorithm", fuzzSearching);
    try ghostspec.fuzz("compression", fuzzCompression);
}

fn fuzzSorting(data: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Convert bytes to array of numbers
    if (data.len % 4 != 0) return; // Must be multiple of 4 for i32
    if (data.len == 0) return;

    const num_elements = data.len / 4;
    var arr = try allocator.alloc(i32, num_elements);
    defer allocator.free(arr);

    // Convert bytes to i32 array
    for (0..num_elements) |i| {
        const bytes = data[i*4..(i+1)*4];
        arr[i] = std.mem.readInt(i32, bytes[0..4], .little);
    }

    // Make a copy for verification
    var original = try allocator.alloc(i32, num_elements);
    defer allocator.free(original);
    @memcpy(original, arr);

    // Sort the array
    std.mem.sort(i32, arr, {}, std.sort.asc(i32));

    // Verify sorting properties
    for (1..arr.len) |i| {
        if (arr[i - 1] > arr[i]) {
            // Sorting failed! This is a bug
            @panic("Sorting algorithm failed");
        }
    }

    // Verify all elements are preserved
    std.mem.sort(i32, original, {}, std.sort.asc(i32));
    if (!std.mem.eql(i32, arr, original)) {
        @panic("Sorting changed the elements");
    }
}

fn fuzzSearching(data: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    if (data.len < 5) return; // Need at least 1 target + 4 bytes for array

    // First byte is the target to search for
    const target: i32 = @intCast(data[0]);
    const array_data = data[1..];

    if (array_data.len % 4 != 0) return;

    const num_elements = array_data.len / 4;
    var arr = try allocator.alloc(i32, num_elements);
    defer allocator.free(arr);

    // Convert to i32 array
    for (0..num_elements) |i| {
        const bytes = array_data[i*4..(i+1)*4];
        arr[i] = std.mem.readInt(i32, bytes[0..4], .little);
    }

    // Search for the target
    const index = std.mem.indexOfScalar(i32, arr, target);

    // Verify the result
    if (index) |i| {
        if (arr[i] != target) {
            @panic("Search returned wrong index");
        }
    } else {
        // Verify target is not in array
        for (arr) |item| {
            if (item == target) {
                @panic("Search missed existing element");
            }
        }
    }
}

fn fuzzCompression(data: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Try to compress the data
    var compressed = std.ArrayList(u8).init(allocator);
    defer compressed.deinit();

    // Simple RLE compression for fuzzing
    var i: usize = 0;
    while (i < data.len) {
        var count: u8 = 1;
        const current = data[i];

        // Count consecutive identical bytes
        while (i + count < data.len and data[i + count] == current and count < 255) {
            count += 1;
        }

        try compressed.append(count);
        try compressed.append(current);
        i += count;
    }

    // Try to decompress
    var decompressed = std.ArrayList(u8).init(allocator);
    defer decompressed.deinit();

    var j: usize = 0;
    while (j < compressed.items.len) {
        if (j + 1 >= compressed.items.len) break;

        const count = compressed.items[j];
        const value = compressed.items[j + 1];

        for (0..count) |_| {
            try decompressed.append(value);
        }

        j += 2;
    }

    // Verify round-trip
    if (!std.mem.eql(u8, data, decompressed.items)) {
        @panic("Compression/decompression failed");
    }
}
```

## Parser Fuzzing

```zig
test "parser fuzzing" {
    try ghostspec.fuzz("expression parser", fuzzExpressionParser);
    try ghostspec.fuzz("url parser", fuzzUrlParser);
    try ghostspec.fuzz("config parser", fuzzConfigParser);
}

fn fuzzExpressionParser(data: []const u8) !void {
    // Try to parse as a mathematical expression
    const expr = parseExpression(data) catch return;

    // If parsing succeeded, evaluate it
    _ = evaluateExpression(expr) catch {
        // Evaluation might fail for valid expressions (division by zero, etc.)
        // This is expected
    };
}

fn parseExpression(input: []const u8) !Expression {
    // Very basic expression parser for fuzzing
    var tokens = std.mem.tokenize(u8, input, " \t\n");
    var stack = std.ArrayList(Expression).init(std.testing.allocator);
    defer stack.deinit();

    while (tokens.next()) |token| {
        if (std.fmt.parseInt(i32, token, 10)) |num| {
            try stack.append(.{ .number = num });
        } else if (std.mem.eql(u8, token, "+")) {
            if (stack.items.len < 2) return error.InvalidExpression;
            const b = stack.pop();
            const a = stack.pop();
            try stack.append(.{ .add = .{ a, b } });
        } else if (std.mem.eql(u8, token, "*")) {
            if (stack.items.len < 2) return error.InvalidExpression;
            const b = stack.pop();
            const a = stack.pop();
            try stack.append(.{ .mul = .{ a, b } });
        } else {
            return error.InvalidToken;
        }
    }

    if (stack.items.len != 1) return error.InvalidExpression;
    return stack.items[0];
}

const Expression = union(enum) {
    number: i32,
    add: [2]*const Expression,
    mul: [2]*const Expression,
};

fn evaluateExpression(expr: Expression) !i32 {
    return switch (expr) {
        .number => |n| n,
        .add => |ops| try evaluateExpression(ops[0].*) + try evaluateExpression(ops[1].*),
        .mul => |ops| try evaluateExpression(ops[0].*) * try evaluateExpression(ops[1].*),
    };
}

fn fuzzUrlParser(data: []const u8) !void {
    // Try to parse as a URL
    const url = parseUrl(data) catch return;

    // Validate URL components
    if (url.scheme.len == 0) return; // Must have scheme
    if (url.host.len == 0) return; // Must have host

    // Check for valid scheme
    const valid_schemes = [_][]const u8{ "http", "https", "ftp", "ftps" };
    var valid_scheme = false;
    for (valid_schemes) |scheme| {
        if (std.mem.eql(u8, url.scheme, scheme)) {
            valid_scheme = true;
            break;
        }
    }
    if (!valid_scheme) return;

    // Check for valid port if specified
    if (url.port != null) {
        if (url.port.? == 0) return; // Invalid port
    }
}

const Url = struct {
    scheme: []const u8,
    host: []const u8,
    port: ?u16,
    path: []const u8,
    query: ?[]const u8,
};

fn parseUrl(input: []const u8) !Url {
    if (std.mem.indexOf(u8, input, "://")) |scheme_end| {
        const scheme = input[0..scheme_end];
        const rest = input[scheme_end + 3..];

        if (std.mem.indexOfAny(u8, rest, "/?")) |host_end| {
            const host_part = rest[0..host_end];
            const path_start = host_end;

            // Parse host and port
            var host = host_part;
            var port: ?u16 = null;

            if (std.mem.indexOf(u8, host_part, ":")) |colon_pos| {
                host = host_part[0..colon_pos];
                const port_str = host_part[colon_pos + 1..];
                port = std.fmt.parseInt(u16, port_str, 10) catch return error.InvalidPort;
            }

            // Parse path and query
            var path = rest[path_start..];
            var query: ?[]const u8 = null;

            if (std.mem.indexOf(u8, path, "?")) |query_start| {
                query = path[query_start + 1..];
                path = path[0..query_start];
            }

            return Url{
                .scheme = scheme,
                .host = host,
                .port = port,
                .path = path,
                .query = query,
            };
        }
    }
    return error.InvalidUrl;
}

fn fuzzConfigParser(data: []const u8) !void {
    // Try to parse as a simple key=value config
    const config = parseConfig(data) catch return;

    // Validate config entries
    for (config.entries.items) |entry| {
        if (entry.key.len == 0) return; // Empty key not allowed
        if (std.mem.indexOfScalar(u8, entry.key, '=')) |_| return; // = in key not allowed
        if (std.mem.indexOfScalar(u8, entry.key, '\n')) |_| return; // newline in key not allowed
    }
}

const Config = struct {
    entries: std.ArrayList(ConfigEntry),
};

const ConfigEntry = struct {
    key: []const u8,
    value: []const u8,
};

fn parseConfig(input: []const u8) !Config {
    var config = Config{
        .entries = std.ArrayList(ConfigEntry).init(std.testing.allocator),
    };
    errdefer config.entries.deinit();

    var lines = std.mem.split(u8, input, "\n");
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;

        if (std.mem.indexOf(u8, trimmed, "=")) |equals_pos| {
            const key = std.mem.trim(u8, trimmed[0..equals_pos], " \t");
            const value = std.mem.trim(u8, trimmed[equals_pos + 1..], " \t");

            try config.entries.append(.{
                .key = key,
                .value = value,
            });
        } else {
            return error.InvalidConfigLine;
        }
    }

    return config;
}
```

## Security Fuzzing

```zig
test "security fuzzing" {
    try ghostspec.fuzz("sql injection", fuzzSqlInjection);
    try ghostspec.fuzz("xss attacks", fuzzXss);
    try ghostspec.fuzz("path traversal", fuzzPathTraversal);
}

fn fuzzSqlInjection(data: []const u8) !void {
    // Check for common SQL injection patterns
    const dangerous_patterns = [_][]const u8{
        "'; DROP TABLE",
        "1' OR '1'='1",
        "UNION SELECT",
        "--",
        "/*",
        "*/",
        "xp_cmdshell",
        "EXEC(",
    };

    for (dangerous_patterns) |pattern| {
        if (std.mem.indexOf(u8, data, pattern)) |_| {
            // Found potential SQL injection
            return;
        }
    }

    // If no dangerous patterns, try to "sanitize" and check
    const sanitized = sanitizeSqlInput(data);
    if (!std.mem.eql(u8, data, sanitized)) {
        // Input was modified during sanitization
        // This indicates potential issues
    }
}

fn sanitizeSqlInput(input: []const u8) []const u8 {
    // Very basic sanitization for fuzzing
    if (std.mem.indexOf(u8, input, "'")) |_| {
        return "sanitized";
    }
    return input;
}

fn fuzzXss(data: []const u8) !void {
    // Check for XSS patterns
    const xss_patterns = [_][]const u8{
        "<script>",
        "javascript:",
        "onload=",
        "onerror=",
        "onclick=",
        "<iframe",
        "<object",
        "<embed",
        "data:text/html",
    };

    for (xss_patterns) |pattern| {
        if (std.mem.indexOf(u8, data, pattern)) |_| {
            // Found potential XSS
            return;
        }
    }

    // Try HTML escaping
    const escaped = escapeHtml(data);
    if (escaped.len > data.len) {
        // Escaping added characters, indicating special chars were present
    }
}

fn escapeHtml(input: []const u8) []const u8 {
    // Simple HTML escaping for fuzzing
    var result = std.ArrayList(u8).init(std.testing.allocator);
    defer result.deinit();

    for (input) |char| {
        switch (char) {
            '<' => result.appendSlice("&lt;") catch return input,
            '>' => result.appendSlice("&gt;") catch return input,
            '&' => result.appendSlice("&amp;") catch return input,
            '"' => result.appendSlice("&quot;") catch return input,
            '\'' => result.appendSlice("&#x27;") catch return input,
            else => result.append(char) catch return input,
        }
    }

    return result.items;
}

fn fuzzPathTraversal(data: []const u8) !void {
    // Check for path traversal patterns
    const traversal_patterns = [_][]const u8{
        "..",
        "../",
        "..\\",
        "%2e%2e%2f",
        "%2e%2e/",
        "..%2f",
        "%2e%2e%5c",
        "..\\",
        "....//",
    };

    for (traversal_patterns) |pattern| {
        if (std.mem.indexOf(u8, data, pattern)) |_| {
            // Found potential path traversal
            return;
        }
    }

    // Try to resolve the path and check if it escapes base directory
    const resolved = resolvePath(data) catch return;
    if (std.mem.indexOf(u8, resolved, "../")) |_| {
        // Path resolution didn't fully canonicalize
        return;
    }
}

fn resolvePath(input: []const u8) ![]const u8 {
    // Simple path resolution for fuzzing
    var parts = std.ArrayList([]const u8).init(std.testing.allocator);
    defer parts.deinit();

    var it = std.mem.split(u8, input, "/");
    while (it.next()) |part| {
        if (std.mem.eql(u8, part, "..")) {
            _ = parts.popOrNull();
        } else if (part.len > 0 and !std.mem.eql(u8, part, ".")) {
            try parts.append(part);
        }
    }

    // Join back
    var result = std.ArrayList(u8).init(std.testing.allocator);
    defer result.deinit();

    for (parts.items, 0..) |part, i| {
        if (i > 0) try result.append('/');
        try result.appendSlice(part);
    }

    return result.items;
}
```</content>
<parameter name="filePath">/data/projects/ghostspec/docs/examples/fuzzing.md