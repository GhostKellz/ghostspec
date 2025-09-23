# Comprehensive Example

This example demonstrates using all GhostSpec features together in a realistic testing scenario.

```zig
const std = @import("std");
const ghostspec = @import("ghostspec");

// A simple web service for managing users
const UserService = struct {
    database: Database,
    cache: Cache,
    logger: Logger,
    validator: Validator,

    pub fn init(db: Database, cache: Cache, logger: Logger, validator: Validator) UserService {
        return .{
            .database = db,
            .cache = cache,
            .logger = logger,
            .validator = validator,
        };
    }

    pub fn createUser(self: *UserService, name: []const u8, email: []const u8) !User {
        // Validate input
        if (!try self.validator.validateName(name)) return error.InvalidName;
        if (!try self.validator.validateEmail(email)) return error.InvalidEmail;

        // Check cache first
        const cache_key = try std.fmt.allocPrint(std.testing.allocator, "user:{}", .{email});
        defer std.testing.allocator.free(cache_key);

        if (try self.cache.get(cache_key)) |cached| {
            _ = await async self.logger.log(.info, "User found in cache", null);
            return std.json.parseFromSlice(User, std.testing.allocator, cached, .{}) catch error.CacheCorrupted;
        }

        // Create user in database
        const user = User{
            .id = std.crypto.random.int(u32),
            .name = try std.testing.allocator.dupe(u8, name),
            .email = try std.testing.allocator.dupe(u8, email),
            .created_at = std.time.timestamp(),
        };

        try self.database.saveUser(user);

        // Cache the result
        const user_json = try std.json.stringifyAlloc(std.testing.allocator, user, .{});
        defer std.testing.allocator.free(user_json);

        try self.cache.set(cache_key, user_json, 3600); // 1 hour TTL

        _ = await async self.logger.log(.info, "User created successfully", .{
            .{"user_id", std.fmt.allocPrint(std.testing.allocator, "{}", .{user.id}) catch ""},
            .{"email", email},
        });

        return user;
    }

    pub fn getUser(self: *UserService, id: u32) !User {
        // Check cache first
        const cache_key = try std.fmt.allocPrint(std.testing.allocator, "user_id:{}", .{id});
        defer std.testing.allocator.free(cache_key);

        if (try self.cache.get(cache_key)) |cached| {
            _ = await async self.logger.log(.debug, "User retrieved from cache", null);
            return std.json.parseFromSlice(User, std.testing.allocator, cached, .{}) catch error.CacheCorrupted;
        }

        // Get from database
        const user = try self.database.getUser(id);

        // Cache the result
        const user_json = try std.json.stringifyAlloc(std.testing.allocator, user, .{});
        defer std.testing.allocator.free(user_json);

        try self.cache.set(cache_key, user_json, 1800); // 30 minutes TTL

        return user;
    }

    pub fn updateUser(self: *UserService, id: u32, updates: UserUpdates) !User {
        // Validate updates
        if (updates.name) |name| {
            if (!try self.validator.validateName(name)) return error.InvalidName;
        }
        if (updates.email) |email| {
            if (!try self.validator.validateEmail(email)) return error.InvalidEmail;
        }

        // Update in database
        const updated_user = try self.database.updateUser(id, updates);

        // Invalidate cache
        const id_cache_key = try std.fmt.allocPrint(std.testing.allocator, "user_id:{}", .{id});
        defer std.testing.allocator.free(id_cache_key);

        const email_cache_key = try std.fmt.allocPrint(std.testing.allocator, "user:{}", .{updated_user.email});
        defer std.testing.allocator.free(email_cache_key);

        _ = try self.cache.delete(id_cache_key);
        _ = try self.cache.delete(email_cache_key);

        _ = await async self.logger.log(.info, "User updated", .{
            .{"user_id", std.fmt.allocPrint(std.testing.allocator, "{}", .{id}) catch ""},
        });

        return updated_user;
    }
};

const User = struct {
    id: u32,
    name: []const u8,
    email: []const u8,
    created_at: i64,
};

const UserUpdates = struct {
    name: ?[]const u8 = null,
    email: ?[]const u8 = null,
};

const Database = struct {
    pub fn saveUser(self: *Database, user: User) !void {
        _ = self;
        _ = user;
    }

    pub fn getUser(self: *Database, id: u32) !User {
        _ = self;
        _ = id;
        return undefined;
    }

    pub fn updateUser(self: *Database, id: u32, updates: UserUpdates) !User {
        _ = self;
        _ = id;
        _ = updates;
        return undefined;
    }
};

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

const Logger = struct {
    pub fn log(self: *Logger, level: LogLevel, message: []const u8, context: ?std.StringHashMap([]const u8)) callconv(.Async) !void {
        _ = self;
        _ = level;
        _ = message;
        _ = context;
    }
};

const LogLevel = enum {
    debug,
    info,
    warn,
    error,
};

const Validator = struct {
    pub fn validateName(self: *Validator, name: []const u8) !bool {
        _ = self;
        return name.len >= 2 and name.len <= 50;
    }

    pub fn validateEmail(self: *Validator, email: []const u8) !bool {
        _ = self;
        return std.mem.indexOf(u8, email, "@") != null and email.len >= 5;
    }
};

// Property-based tests for the service
test "user service properties" {
    // Test that creating a user with valid data always succeeds
    try ghostspec.property(struct{ name: []const u8, email: []const u8 }, testCreateUserProperties);

    // Test that getting a user returns the same data that was created
    try ghostspec.property(User, testUserPersistence);

    // Test that updating a user preserves other fields
    try ghostspec.property(struct{ user: User, updates: UserUpdates }, testUserUpdatePreservesFields);
}

fn testCreateUserProperties(values: struct{ name: []const u8, email: []const u8 }) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Only test with valid inputs
    if (values.name.len < 2 or values.name.len > 50) return;
    if (std.mem.indexOf(u8, values.email, "@") == null or values.email.len < 5) return;

    // Create service with mocks
    var db_mock = try ghostspec.Mock(Database).init(allocator);
    defer db_mock.deinit();

    var cache_mock = try ghostspec.Mock(Cache).init(allocator);
    defer cache_mock.deinit();

    var logger_mock = try ghostspec.Mock(Logger).init(allocator);
    defer logger_mock.deinit();

    var validator = Validator{};

    // Setup mocks
    try db_mock.expect("saveUser", .{mock.any(User)}, .{ .returns = {} });
    try cache_mock.expect("get", .{mock.any([]const u8)}, .{ .returns = null });
    try cache_mock.expect("set", .{mock.any([]const u8), mock.any([]const u8), mock.any(?u32)}, .{ .returns = {} });
    try logger_mock.expect("log", .{mock.any(LogLevel), mock.any([]const u8), mock.any(?std.StringHashMap([]const u8))}, .{ .returns = {} });

    var service = UserService.init(db_mock.mock(), cache_mock.mock(), logger_mock.mock(), validator);

    // This should always succeed with valid input
    const user = try service.createUser(values.name, values.email);
    try std.testing.expect(user.id != 0);
    try std.testing.expect(std.mem.eql(u8, user.name, values.name));
    try std.testing.expect(std.mem.eql(u8, user.email, values.email));
    try std.testing.expect(user.created_at > 0);

    try db_mock.verify();
    try cache_mock.verify();
    try logger_mock.verify();
}

fn testUserPersistence(user: User) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var db_mock = try ghostspec.Mock(Database).init(allocator);
    defer db_mock.deinit();

    var cache_mock = try ghostspec.Mock(Cache).init(allocator);
    defer cache_mock.deinit();

    var logger_mock = try ghostspec.Mock(Logger).init(allocator);
    defer logger_mock.deinit();

    var validator = Validator{};

    // Setup mocks to return the user
    try db_mock.expect("getUser", .{user.id}, .{ .returns = user });
    try cache_mock.expect("get", .{mock.any([]const u8)}, .{ .returns = null });
    try cache_mock.expect("set", .{mock.any([]const u8), mock.any([]const u8), mock.any(?u32)}, .{ .returns = {} });
    try logger_mock.expect("log", .{mock.any(LogLevel), mock.any([]const u8), mock.any(?std.StringHashMap([]const u8))}, .{ .returns = {} });

    var service = UserService.init(db_mock.mock(), cache_mock.mock(), logger_mock.mock(), validator);

    const retrieved = try service.getUser(user.id);
    try std.testing.expectEqual(user.id, retrieved.id);
    try std.testing.expect(std.mem.eql(u8, user.name, retrieved.name));
    try std.testing.expect(std.mem.eql(u8, user.email, retrieved.email));
    try std.testing.expectEqual(user.created_at, retrieved.created_at);
}

fn testUserUpdatePreservesFields(values: struct{ user: User, updates: UserUpdates }) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Skip invalid updates
    if (values.updates.name) |name| {
        if (name.len < 2 or name.len > 50) return;
    }
    if (values.updates.email) |email| {
        if (std.mem.indexOf(u8, email, "@") == null or email.len < 5) return;
    }

    var db_mock = try ghostspec.Mock(Database).init(allocator);
    defer db_mock.deinit();

    var cache_mock = try ghostspec.Mock(Cache).init(allocator);
    defer cache_mock.deinit();

    var logger_mock = try ghostspec.Mock(Logger).init(allocator);
    defer logger_mock.deinit();

    var validator = Validator{};

    // Calculate expected result
    const expected = User{
        .id = values.user.id,
        .name = values.updates.name orelse values.user.name,
        .email = values.updates.email orelse values.user.email,
        .created_at = values.user.created_at,
    };

    try db_mock.expect("updateUser", .{values.user.id, values.updates}, .{ .returns = expected });
    try cache_mock.expect("delete", .{mock.any([]const u8)}, .{ .returns = true }).times(2);
    try logger_mock.expect("log", .{mock.any(LogLevel), mock.any([]const u8), mock.any(?std.StringHashMap([]const u8))}, .{ .returns = {} });

    var service = UserService.init(db_mock.mock(), cache_mock.mock(), logger_mock.mock(), validator);

    const updated = try service.updateUser(values.user.id, values.updates);
    try std.testing.expectEqual(expected.id, updated.id);
    try std.testing.expect(std.mem.eql(u8, expected.name, updated.name));
    try std.testing.expect(std.mem.eql(u8, expected.email, updated.email));
    try std.testing.expectEqual(expected.created_at, updated.created_at);
}

// Benchmarking the service
test "user service benchmarks" {
    try ghostspec.benchmark("create user", benchmarkCreateUser);
    try ghostspec.benchmark("get user", benchmarkGetUser);
    try ghostspec.benchmark("update user", benchmarkUpdateUser);
}

fn benchmarkCreateUser(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Setup minimal mocks for benchmarking
    var db_mock = try ghostspec.Mock(Database).init(allocator);
    var cache_mock = try ghostspec.Mock(Cache).init(allocator);
    var logger_mock = try ghostspec.Mock(Logger).init(allocator);
    var validator = Validator{};

    try db_mock.expect("saveUser", .{mock.any(User)}, .{ .returns = {} });
    try cache_mock.expect("get", .{mock.any([]const u8)}, .{ .returns = null });
    try cache_mock.expect("set", .{mock.any([]const u8), mock.any([]const u8), mock.any(?u32)}, .{ .returns = {} });
    try logger_mock.expect("log", .{mock.any(LogLevel), mock.any([]const u8), mock.any(?std.StringHashMap([]const u8))}, .{ .returns = {} });

    var service = UserService.init(db_mock.mock(), cache_mock.mock(), logger_mock.mock(), validator);

    b.iterate(|| {
        const user = service.createUser("Benchmark User", "bench@example.com") catch unreachable;
        _ = user;
    });
}

fn benchmarkGetUser(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var db_mock = try ghostspec.Mock(Database).init(allocator);
    var cache_mock = try ghostspec.Mock(Cache).init(allocator);
    var logger_mock = try ghostspec.Mock(Logger).init(allocator);
    var validator = Validator{};

    const test_user = User{
        .id = 1,
        .name = "Test User",
        .email = "test@example.com",
        .created_at = 1234567890,
    };

    try db_mock.expect("getUser", .{1}, .{ .returns = test_user });
    try cache_mock.expect("get", .{mock.any([]const u8)}, .{ .returns = null });
    try cache_mock.expect("set", .{mock.any([]const u8), mock.any([]const u8), mock.any(?u32)}, .{ .returns = {} });
    try logger_mock.expect("log", .{mock.any(LogLevel), mock.any([]const u8), mock.any(?std.StringHashMap([]const u8))}, .{ .returns = {} });

    var service = UserService.init(db_mock.mock(), cache_mock.mock(), logger_mock.mock(), validator);

    b.iterate(|| {
        const user = service.getUser(1) catch unreachable;
        _ = user;
    });
}

fn benchmarkUpdateUser(b: *ghostspec.Benchmark) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var db_mock = try ghostspec.Mock(Database).init(allocator);
    var cache_mock = try ghostspec.Mock(Cache).init(allocator);
    var logger_mock = try ghostspec.Mock(Logger).init(allocator);
    var validator = Validator{};

    const original_user = User{
        .id = 1,
        .name = "Original Name",
        .email = "original@example.com",
        .created_at = 1234567890,
    };

    const updated_user = User{
        .id = 1,
        .name = "Updated Name",
        .email = "updated@example.com",
        .created_at = 1234567890,
    };

    try db_mock.expect("updateUser", .{1, mock.any(UserUpdates)}, .{ .returns = updated_user });
    try cache_mock.expect("delete", .{mock.any([]const u8)}, .{ .returns = true }).times(2);
    try logger_mock.expect("log", .{mock.any(LogLevel), mock.any([]const u8), mock.any(?std.StringHashMap([]const u8))}, .{ .returns = {} });

    var service = UserService.init(db_mock.mock(), cache_mock.mock(), logger_mock.mock(), validator);

    b.iterate(|| {
        const user = service.updateUser(1, .{ .name = "Updated Name", .email = "updated@example.com" }) catch unreachable;
        _ = user;
    });
}

// Fuzzing the service
test "user service fuzzing" {
    try ghostspec.fuzz("user creation", fuzzUserCreation);
    try ghostspec.fuzz("user data", fuzzUserData);
    try ghostspec.fuzz("user updates", fuzzUserUpdates);
}

fn fuzzUserCreation(data: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Try to parse as name and email
    if (std.mem.indexOf(u8, data, "|")) |sep| {
        const name = data[0..sep];
        const email = data[sep + 1..];

        // Skip invalid inputs that would cause validation errors
        if (name.len < 2 or name.len > 50) return;
        if (std.mem.indexOf(u8, email, "@") == null or email.len < 5) return;

        var db_mock = try ghostspec.Mock(Database).init(allocator);
        defer db_mock.deinit();

        var cache_mock = try ghostspec.Mock(Cache).init(allocator);
        defer cache_mock.deinit();

        var logger_mock = try ghostspec.Mock(Logger).init(allocator);
        defer logger_mock.deinit();

        var validator = Validator{};

        try db_mock.expect("saveUser", .{mock.any(User)}, .{ .returns = {} });
        try cache_mock.expect("get", .{mock.any([]const u8)}, .{ .returns = null });
        try cache_mock.expect("set", .{mock.any([]const u8), mock.any([]const u8), mock.any(?u32)}, .{ .returns = {} });
        try logger_mock.expect("log", .{mock.any(LogLevel), mock.any([]const u8), mock.any(?std.StringHashMap([]const u8))}, .{ .returns = {} });

        var service = UserService.init(db_mock.mock(), cache_mock.mock(), logger_mock.mock(), validator);

        // This should succeed
        const user = service.createUser(name, email) catch return;
        try std.testing.expect(user.id != 0);
        try std.testing.expect(std.mem.eql(u8, user.name, name));
        try std.testing.expect(std.mem.eql(u8, user.email, email));
    }
}

fn fuzzUserData(data: []const u8) !void {
    // Try to parse as JSON user data
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const parsed = std.json.parseFromSlice(std.json.Value, allocator, data, .{}) catch return;
    defer parsed.deinit();

    const obj = parsed.value.object;

    // Check if it looks like user data
    const has_id = obj.get("id") != null;
    const has_name = obj.get("name") != null;
    const has_email = obj.get("email") != null;

    if (!has_id or !has_name or !has_email) return;

    // Validate the structure
    const id_val = obj.get("id").?;
    const name_val = obj.get("name").?;
    const email_val = obj.get("email").?;

    if (id_val != .integer or name_val != .string or email_val != .string) return;

    const id = @as(u32, @intCast(id_val.integer));
    const name = name_val.string;
    const email = email_val.string;

    // Basic validation
    if (id == 0) return;
    if (name.len == 0 or name.len > 100) return;
    if (email.len == 0 or std.mem.indexOf(u8, email, "@") == null) return;
}

fn fuzzUserUpdates(data: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Try to parse as JSON update data
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, data, .{}) catch return;
    defer parsed.deinit();

    const obj = parsed.value.object;

    // Check for update fields
    if (obj.get("name")) |name_val| {
        if (name_val != .string) return;
        if (name_val.string.len < 2 or name_val.string.len > 50) return;
    }

    if (obj.get("email")) |email_val| {
        if (email_val != .string) return;
        if (std.mem.indexOf(u8, email_val.string, "@") == null) return;
    }

    // If we get here, the update data is structurally valid
}

// Integration test with all components
test "user service integration" {
    try ghostspec.mock(Database, "integration database", testUserServiceIntegration);
}

fn testUserServiceIntegration(db_mock: *ghostspec.Mock(Database)) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var cache_mock = try ghostspec.Mock(Cache).init(allocator);
    defer cache_mock.deinit();

    var logger_mock = try ghostspec.Mock(Logger).init(allocator);
    defer logger_mock.deinit();

    var validator = Validator{};

    // Setup database mock for the full workflow
    const test_user = User{
        .id = 42,
        .name = "Integration Test User",
        .email = "integration@example.com",
        .created_at = std.time.timestamp(),
    };

    try db_mock.expect("saveUser", .{mock.any(User)}, .{ .returns = {} });
    try db_mock.expect("getUser", .{42}, .{ .returns = test_user });
    try db_mock.expect("updateUser", .{42, mock.any(UserUpdates)}, .{ .returns = User{
        .id = 42,
        .name = "Updated Integration User",
        .email = "integration@example.com",
        .created_at = test_user.created_at,
    }});

    // Setup cache mocks
    try cache_mock.expect("get", .{mock.any([]const u8)}, .{ .returns = null }).times(3); // create, get, update
    try cache_mock.expect("set", .{mock.any([]const u8), mock.any([]const u8), mock.any(?u32)}, .{ .returns = {} }).times(2); // create, get
    try cache_mock.expect("delete", .{mock.any([]const u8)}, .{ .returns = true }).times(2); // update

    // Setup logger mocks
    try logger_mock.expect("log", .{mock.any(LogLevel), mock.any([]const u8), mock.any(?std.StringHashMap([]const u8))}, .{ .returns = {} }).times(3); // create, get, update

    var service = UserService.init(db_mock.mock(), cache_mock.mock(), logger_mock.mock(), validator);

    // Test the full workflow
    const created = try service.createUser("Integration Test User", "integration@example.com");
    try std.testing.expect(created.id != 0);

    const retrieved = try service.getUser(42);
    try std.testing.expectEqual(@as(u32, 42), retrieved.id);
    try std.testing.expect(std.mem.eql(u8, "Integration Test User", retrieved.name));

    const updated = try service.updateUser(42, .{ .name = "Updated Integration User" });
    try std.testing.expectEqual(@as(u32, 42), updated.id);
    try std.testing.expect(std.mem.eql(u8, "Updated Integration User", updated.name));

    // Verify all mocks
    try db_mock.verify();
    try cache_mock.verify();
    try logger_mock.verify();
}
```</content>
<parameter name="filePath">/data/projects/ghostspec/docs/examples/comprehensive.md