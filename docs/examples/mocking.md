# Mocking Examples

Examples of using GhostSpec's mocking capabilities for isolated testing.

## Basic Mocking

```zig
const std = @import("std");
const ghostspec = @import("ghostspec");

test "basic mocking" {
    try ghostspec.mock(Database, "database mock", testWithDatabaseMock);
    try ghostspec.mock(HttpClient, "http client mock", testWithHttpMock);
    try ghostspec.mock(FileSystem, "filesystem mock", testWithFsMock);
}

const Database = struct {
    pub fn connect(url: []const u8) !*Database {
        _ = url;
        return undefined;
    }

    pub fn query(self: *Database, sql: []const u8) ![]User {
        _ = self;
        _ = sql;
        return undefined;
    }

    pub fn close(self: *Database) void {
        _ = self;
    }
};

const User = struct {
    id: u32,
    name: []const u8,
    email: []const u8,
};

fn testWithDatabaseMock(mock: *ghostspec.Mock(Database)) !void {
    // Setup mock expectations
    try mock.expect("connect", .{ "postgresql://localhost/test" }, .{ .returns = mock });
    try mock.expect("query", .{ "SELECT * FROM users" }, .{
        .returns = &[_]User{
            .{ .id = 1, .name = "Alice", .email = "alice@example.com" },
            .{ .id = 2, .name = "Bob", .email = "bob@example.com" },
        }
    });
    try mock.expect("close", .{}, .{ .returns = {} });

    // Test code that uses the database
    const db = try Database.connect("postgresql://localhost/test");
    const users = try db.query("SELECT * FROM users");
    try std.testing.expectEqual(@as(usize, 2), users.len);
    try std.testing.expect(std.mem.eql(u8, users[0].name, "Alice"));
    db.close();

    // Verify all expectations were met
    try mock.verify();
}

const HttpClient = struct {
    pub fn get(self: *HttpClient, url: []const u8) !HttpResponse {
        _ = self;
        _ = url;
        return undefined;
    }

    pub fn post(self: *HttpClient, url: []const u8, data: []const u8) !HttpResponse {
        _ = self;
        _ = url;
        _ = data;
        return undefined;
    }
};

const HttpResponse = struct {
    status: u16,
    body: []const u8,
    headers: std.StringHashMap([]const u8),
};

fn testWithHttpMock(mock: *ghostspec.Mock(HttpClient)) !void {
    // Setup mock for successful API call
    try mock.expect("get", .{ "https://api.example.com/users" }, .{
        .returns = HttpResponse{
            .status = 200,
            .body = "{\"users\": [{\"id\": 1, \"name\": \"Alice\"}]}",
            .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        }
    });

    // Setup mock for failed API call
    try mock.expect("post", .{ "https://api.example.com/users", "{\"name\": \"invalid\"}" }, .{
        .returns = error.ValidationError
    });

    // Test code
    var client = HttpClient{};
    const response = try client.get("https://api.example.com/users");
    try std.testing.expectEqual(@as(u16, 200), response.status);

    const post_result = client.post("https://api.example.com/users", "{\"name\": \"invalid\"}");
    try std.testing.expectError(error.ValidationError, post_result);

    try mock.verify();
}

const FileSystem = struct {
    pub fn readFile(self: *FileSystem, path: []const u8) ![]const u8 {
        _ = self;
        _ = path;
        return undefined;
    }

    pub fn writeFile(self: *FileSystem, path: []const u8, data: []const u8) !void {
        _ = self;
        _ = path;
        _ = data;
    }

    pub fn exists(self: *FileSystem, path: []const u8) bool {
        _ = self;
        _ = path;
        return undefined;
    }
};

fn testWithFsMock(mock: *ghostspec.Mock(FileSystem)) !void {
    // Setup file system mocks
    try mock.expect("readFile", .{ "/etc/config.json" }, .{
        .returns = "{\"database\": \"prod\"}"
    });
    try mock.expect("exists", .{ "/tmp/cache" }, .{ .returns = true });
    try mock.expect("exists", .{ "/tmp/missing" }, .{ .returns = false });
    try mock.expect("writeFile", .{ "/tmp/output.txt", "test data" }, .{ .returns = {} });

    // Test code
    var fs = FileSystem{};
    const config = try fs.readFile("/etc/config.json");
    try std.testing.expect(std.mem.indexOf(u8, config, "prod") != null);

    try std.testing.expect(fs.exists("/tmp/cache"));
    try std.testing.expect(!fs.exists("/tmp/missing"));

    try fs.writeFile("/tmp/output.txt", "test data");

    try mock.verify();
}
```

## Advanced Mocking

```zig
test "advanced mocking" {
    try ghostspec.mock(NetworkService, "network service", testNetworkService);
    try ghostspec.mock(Cache, "cache with errors", testCacheWithErrors);
    try ghostspec.mock(Logger, "async logger", testAsyncLogger);
}

const NetworkService = struct {
    pub fn request(self: *NetworkService, method: []const u8, url: []const u8, body: ?[]const u8) !NetworkResponse {
        _ = self;
        _ = method;
        _ = url;
        _ = body;
        return undefined;
    }

    pub fn stream(self: *NetworkService, url: []const u8) !NetworkStream {
        _ = self;
        _ = url;
        return undefined;
    }
};

const NetworkResponse = struct {
    status: u16,
    body: []const u8,
    content_type: []const u8,
};

const NetworkStream = struct {
    pub fn read(self: *NetworkStream, buffer: []u8) !usize {
        _ = self;
        _ = buffer;
        return undefined;
    }

    pub fn close(self: *NetworkStream) void {
        _ = self;
    }
};

fn testNetworkService(mock: *ghostspec.Mock(NetworkService)) !void {
    // Mock different responses based on input
    try mock.when("request")
        .with(.{ "GET", "https://api.example.com/status", null })
        .returns(.{
            .status = 200,
            .body = "{\"status\": \"ok\"}",
            .content_type = "application/json"
        });

    try mock.when("request")
        .with(.{ "POST", "https://api.example.com/data", std.testing.allocator.dupe(u8, "{\"key\": \"value\"}") catch unreachable })
        .returns(.{
            .status = 201,
            .body = "{\"id\": 123}",
            .content_type = "application/json"
        });

    // Mock streaming response
    const stream_mock = try mock.expect("stream", .{ "https://example.com/large-file" }, .{
        .returns = mock.createMock(NetworkStream)
    });

    try stream_mock.expect("read", .{ std.testing.allocator.alloc(u8, 1024) catch unreachable }, .{
        .returns = 512
    });
    try stream_mock.expect("close", .{}, .{ .returns = {} });

    // Test code
    var service = NetworkService{};
    const status_resp = try service.request("GET", "https://api.example.com/status", null);
    try std.testing.expectEqual(@as(u16, 200), status_resp.status);

    const data_resp = try service.request("POST", "https://api.example.com/data", "{\"key\": \"value\"}");
    try std.testing.expectEqual(@as(u16, 201), data_resp.status);

    const stream = try service.stream("https://example.com/large-file");
    var buffer: [1024]u8 = undefined;
    const bytes_read = try stream.read(&buffer);
    try std.testing.expectEqual(@as(usize, 512), bytes_read);
    stream.close();

    try mock.verify();
}

const Cache = struct {
    pub fn get(self: *Cache, key: []const u8) !?[]const u8 {
        _ = self;
        _ = key;
        return undefined;
    }

    pub fn set(self: *Cache, key: []const u8, value: []const u8, ttl: ?u32) !void {
        _ = self;
        _ = key;
        _ = value;
        _ = ttl;
    }

    pub fn delete(self: *Cache, key: []const u8) !bool {
        _ = self;
        _ = key;
        return undefined;
    }
};

fn testCacheWithErrors(mock: *ghostspec.Mock(Cache)) !void {
    // Mock cache miss
    try mock.expect("get", .{ "missing_key" }, .{ .returns = null });

    // Mock cache hit
    try mock.expect("get", .{ "existing_key" }, .{ .returns = "cached_value" });

    // Mock set operation
    try mock.expect("set", .{ "new_key", "new_value", @as(?u32, 3600) }, .{ .returns = {} });

    // Mock delete operation
    try mock.expect("delete", .{ "existing_key" }, .{ .returns = true });
    try mock.expect("delete", .{ "missing_key" }, .{ .returns = false });

    // Mock error conditions
    try mock.expect("get", .{ "error_key" }, .{ .returns = error.ConnectionFailed });
    try mock.expect("set", .{ "readonly_key", "value", null }, .{ .returns = error.ReadOnly });

    // Test code
    var cache = Cache{};

    // Test cache miss
    const miss = try cache.get("missing_key");
    try std.testing.expect(miss == null);

    // Test cache hit
    const hit = try cache.get("existing_key");
    try std.testing.expect(hit != null);
    try std.testing.expect(std.mem.eql(u8, hit.?, "cached_value"));

    // Test set
    try cache.set("new_key", "new_value", 3600);

    // Test delete
    try std.testing.expect(try cache.delete("existing_key"));
    try std.testing.expect(!(try cache.delete("missing_key")));

    // Test errors
    try std.testing.expectError(error.ConnectionFailed, cache.get("error_key"));
    try std.testing.expectError(error.ReadOnly, cache.set("readonly_key", "value", null));

    try mock.verify();
}

const Logger = struct {
    pub fn log(self: *Logger, level: LogLevel, message: []const u8, context: ?std.StringHashMap([]const u8)) callconv(.Async) !void {
        _ = self;
        _ = level;
        _ = message;
        _ = context;
    }

    pub fn flush(self: *Logger) !void {
        _ = self;
    }
};

const LogLevel = enum {
    debug,
    info,
    warn,
    error,
};

fn testAsyncLogger(mock: *ghostspec.Mock(Logger)) !void {
    // Mock async logging calls
    try mock.expect("log", .{ .info, "User logged in", null }, .{ .returns = {} });
    try mock.expect("log", .{ .error, "Database connection failed", null }, .{ .returns = {} });
    try mock.expect("flush", .{}, .{ .returns = {} });

    // Test async code
    var logger = Logger{};

    // Simulate async logging
    const frame1 = async logger.log(.info, "User logged in", null);
    try await frame1;

    const frame2 = async logger.log(.error, "Database connection failed", null);
    try await frame2;

    try logger.flush();

    try mock.verify();
}
```

## Mock Verification

```zig
test "mock verification" {
    try ghostspec.mock(Calculator, "calculator", testCalculatorVerification);
    try ghostspec.mock(Validator, "validator", testValidatorVerification);
}

const Calculator = struct {
    pub fn add(self: *Calculator, a: i32, b: i32) i32 {
        _ = self;
        return a + b; // Real implementation
    }

    pub fn multiply(self: *Calculator, a: i32, b: i32) i32 {
        _ = self;
        return a * b; // Real implementation
    }
};

fn testCalculatorVerification(mock: *ghostspec.Mock(Calculator)) !void {
    // Setup expectations
    try mock.expect("add", .{ 2, 3 }, .{ .returns = 5 });
    try mock.expect("multiply", .{ 4, 5 }, .{ .returns = 20 });

    // Use the mock
    var calc = Calculator{};
    const sum = calc.add(2, 3);
    const product = calc.multiply(4, 5);

    try std.testing.expectEqual(@as(i32, 5), sum);
    try std.testing.expectEqual(@as(i32, 20), product);

    // Verify all expectations were met
    try mock.verify();

    // Test that unmet expectations cause verification to fail
    try mock.expect("add", .{ 1, 1 }, .{ .returns = 2 });
    // Don't call add(1, 1), so expectation is unmet
    try std.testing.expectError(error.UnmetExpectations, mock.verify());
}

const Validator = struct {
    pub fn validateEmail(self: *Validator, email: []const u8) !bool {
        _ = self;
        _ = email;
        return undefined;
    }

    pub fn validatePassword(self: *Validator, password: []const u8) !bool {
        _ = self;
        _ = password;
        return undefined;
    }
};

fn testValidatorVerification(mock: *ghostspec.Mock(Validator)) !void {
    // Setup expectations with argument matchers
    try mock.expect("validateEmail", .{ mock.any([]const u8) }, .{ .returns = true });
    try mock.expect("validatePassword", .{ mock.matching(struct {
        fn matches(pwd: []const u8) bool {
            return pwd.len >= 8;
        }
    }.matches) }, .{ .returns = true });

    try mock.expect("validatePassword", .{ mock.matching(struct {
        fn matches(pwd: []const u8) bool {
            return pwd.len < 8;
        }
    }.matches) }, .{ .returns = false });

    // Test code
    var validator = Validator{};

    try std.testing.expect(try validator.validateEmail("test@example.com"));
    try std.testing.expect(try validator.validateEmail("another@test.com"));

    try std.testing.expect(try validator.validatePassword("strongpassword"));
    try std.testing.expect(!(try validator.validatePassword("weak")));

    // Verify expectations
    try mock.verify();

    // Test call count verification
    try mock.expect("validateEmail", .{ "count@test.com" }, .{ .returns = true })
        .times(2);

    try validator.validateEmail("count@test.com");
    try validator.validateEmail("count@test.com");

    try mock.verify(); // Should pass - called exactly 2 times

    // This would fail if called 3 times
    // try validator.validateEmail("count@test.com");
    // try std.testing.expectError(error.UnmetExpectations, mock.verify());
}
```

## Partial Mocking

```zig
test "partial mocking" {
    try ghostspec.partialMock(DatabaseService, "database service", testPartialMock);
    try ghostspec.partialMock(ApiClient, "api client", testPartialMockClient);
}

const DatabaseService = struct {
    connection: ?*Database,

    pub fn init() DatabaseService {
        return .{ .connection = null };
    }

    pub fn connect(self: *DatabaseService) !void {
        self.connection = try Database.connect("postgresql://localhost/test");
    }

    pub fn getUser(self: *DatabaseService, id: u32) !User {
        if (self.connection) |conn| {
            const users = try conn.query(std.fmt.allocPrint(std.testing.allocator, "SELECT * FROM users WHERE id = {}", .{id}));
            if (users.len > 0) return users[0];
            return error.UserNotFound;
        }
        return error.NotConnected;
    }

    pub fn createUser(self: *DatabaseService, user: User) !void {
        if (self.connection) |conn| {
            _ = try conn.query(std.fmt.allocPrint(std.testing.allocator, "INSERT INTO users VALUES ({}, '{}', '{}')", .{user.id, user.name, user.email}));
        } else {
            return error.NotConnected;
        }
    }
};

fn testPartialMock(mock: *ghostspec.Mock(DatabaseService)) !void {
    // Mock only the database connection, let other methods use real implementation
    const db_mock = try mock.expect("connect", .{}, .{ .returns = {} });

    // But mock the database query calls
    try db_mock.expect("query", .{ "SELECT * FROM users WHERE id = 1" }, .{
        .returns = &[_]User{.{ .id = 1, .name = "Alice", .email = "alice@example.com" }}
    });

    // Test code
    var service = DatabaseService.init();
    try service.connect(); // This will use the mock

    const user = try service.getUser(1); // This will call real getUser, which calls mocked query
    try std.testing.expectEqual(@as(u32, 1), user.id);
    try std.testing.expect(std.mem.eql(u8, user.name, "Alice"));

    try mock.verify();
}

const ApiClient = struct {
    base_url: []const u8,
    http_client: HttpClient,

    pub fn init(base_url: []const u8) ApiClient {
        return .{
            .base_url = base_url,
            .http_client = HttpClient{},
        };
    }

    pub fn getUser(self: *ApiClient, id: u32) !User {
        const url = try std.fmt.allocPrint(std.testing.allocator, "{}/users/{}", .{self.base_url, id});
        defer std.testing.allocator.free(url);

        const response = try self.http_client.get(url);
        if (response.status != 200) return error.ApiError;

        // Parse JSON response
        var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, response.body, .{});
        defer parsed.deinit();

        const user_obj = parsed.value.object;
        return User{
            .id = @intCast(user_obj.get("id").?.integer),
            .name = user_obj.get("name").?.string,
            .email = user_obj.get("email").?.string,
        };
    }

    pub fn createUser(self: *ApiClient, user: User) !void {
        const url = try std.fmt.allocPrint(std.testing.allocator, "{}/users", .{self.base_url});
        defer std.testing.allocator.free(url);

        const json_data = try std.fmt.allocPrint(std.testing.allocator,
            \\{{"id": {}, "name": "{}", "email": "{}"}}
        , .{user.id, user.name, user.email});
        defer std.testing.allocator.free(json_data);

        const response = try self.http_client.post(url, json_data);
        if (response.status != 201) return error.ApiError;
    }
};

fn testPartialMockClient(mock: *ghostspec.Mock(ApiClient)) !void {
    // Mock only the HTTP client methods, let API client logic remain real
    const http_mock = try mock.expect("get", .{ "https://api.example.com/users/1" }, .{
        .returns = HttpResponse{
            .status = 200,
            .body = "{\"id\": 1, \"name\": \"Alice\", \"email\": \"alice@example.com\"}",
            .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        }
    });

    try mock.expect("post", .{ "https://api.example.com/users",
        "{\"id\": 2, \"name\": \"Bob\", \"email\": \"bob@example.com\"}" }, .{
        .returns = HttpResponse{
            .status = 201,
            .body = "{\"id\": 2}",
            .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        }
    });

    // Test code
    var client = ApiClient.init("https://api.example.com");

    const user = try client.getUser(1);
    try std.testing.expectEqual(@as(u32, 1), user.id);
    try std.testing.expect(std.mem.eql(u8, user.name, "Alice"));

    try client.createUser(.{ .id = 2, .name = "Bob", .email = "bob@example.com" });

    try mock.verify();
}
```</content>
<parameter name="filePath">/data/projects/ghostspec/docs/examples/mocking.md