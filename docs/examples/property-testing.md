# Property Testing Examples

Examples of using GhostSpec's property-based testing features.

## Basic Property Testing

```zig
const std = @import("std");
const ghostspec = @import("ghostspec");

test "addition properties" {
    // Test that addition is commutative
    try ghostspec.property(struct{ a: i32, b: i32 }, testAdditionCommutative);

    // Test that addition is associative
    try ghostspec.property(struct{ a: i32, b: i32, c: i32 }, testAdditionAssociative);

    // Test that addition has an identity element
    try ghostspec.property(i32, testAdditionIdentity);
}

fn testAdditionCommutative(values: struct{ a: i32, b: i32 }) !void {
    try std.testing.expect(values.a + values.b == values.b + values.a);
}

fn testAdditionAssociative(values: struct{ a: i32, b: i32, c: i32 }) !void {
    try std.testing.expect((values.a + values.b) + values.c == values.a + (values.b + values.c));
}

fn testAdditionIdentity(value: i32) !void {
    try std.testing.expect(value + 0 == value);
    try std.testing.expect(0 + value == value);
}
```

## Collection Properties

```zig
test "array sorting properties" {
    try ghostspec.property([]i32, testSortMaintainsLength);
    try ghostspec.property([]i32, testSortIsIdempotent);
    try ghostspec.property([]i32, testSortPreservesElements);
}

fn testSortMaintainsLength(arr: []i32) !void {
    const original_len = arr.len;
    std.mem.sort(i32, arr, {}, std.sort.asc(i32));
    try std.testing.expect(arr.len == original_len);
}

fn testSortIsIdempotent(arr: []i32) !void {
    // Make a copy
    var arr_copy = try std.ArrayList(i32).initCapacity(std.testing.allocator, arr.len);
    defer arr_copy.deinit();
    try arr_copy.appendSlice(arr);

    // Sort both
    std.mem.sort(i32, arr, {}, std.sort.asc(i32));
    std.mem.sort(i32, arr_copy.items, {}, std.sort.asc(i32));

    // Should be identical
    try std.testing.expect(std.mem.eql(i32, arr, arr_copy.items));
}

fn testSortPreservesElements(arr: []i32) !void {
    var original = std.ArrayList(i32).init(std.testing.allocator);
    defer original.deinit();
    try original.appendSlice(arr);

    std.mem.sort(i32, arr, {}, std.sort.asc(i32));
    std.mem.sort(i32, original.items, {}, std.sort.asc(i32));

    // All elements should be preserved (just reordered)
    for (arr) |item| {
        try std.testing.expect(std.mem.indexOfScalar(i32, original.items, item) != null);
    }
}
```

## String Properties

```zig
test "string concatenation properties" {
    try ghostspec.property(struct{ a: []const u8, b: []const u8 }, testConcatenationAssociative);
    try ghostspec.property([]const u8, testConcatenationIdentity);
}

fn testConcatenationAssociative(values: struct{ a: []const u8, b: []const u8, c: []const u8 }) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // (a + b) + c
    var ab = std.ArrayList(u8).init(allocator);
    try ab.appendSlice(values.a);
    try ab.appendSlice(values.b);
    var abc1 = std.ArrayList(u8).init(allocator);
    try abc1.appendSlice(ab.items);
    try abc1.appendSlice(values.c);

    // a + (b + c)
    var bc = std.ArrayList(u8).init(allocator);
    try bc.appendSlice(values.b);
    try bc.appendSlice(values.c);
    var abc2 = std.ArrayList(u8).init(allocator);
    try abc2.appendSlice(values.a);
    try abc2.appendSlice(bc.items);

    try std.testing.expect(std.mem.eql(u8, abc1.items, abc2.items));
}

fn testConcatenationIdentity(value: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // value + "" = value
    var concat1 = std.ArrayList(u8).init(allocator);
    try concat1.appendSlice(value);
    try concat1.appendSlice("");

    // "" + value = value
    var concat2 = std.ArrayList(u8).init(allocator);
    try concat2.appendSlice("");
    try concat2.appendSlice(value);

    try std.testing.expect(std.mem.eql(u8, concat1.items, value));
    try std.testing.expect(std.mem.eql(u8, concat2.items, value));
}
```

## Custom Generators

```zig
test "custom data structure properties" {
    try ghostspec.property(Person, testPersonAgeValid);
    try ghostspec.property([]Person, testPersonListSortedByAge);
}

const Person = struct {
    name: []const u8,
    age: u32,
    email: []const u8,
};

fn testPersonAgeValid(person: Person) !void {
    try std.testing.expect(person.age >= 0 and person.age <= 150);
    try std.testing.expect(person.name.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, person.email, "@") != null);
}

fn testPersonListSortedByAge(people: []Person) !void {
    for (1..people.len) |i| {
        try std.testing.expect(people[i - 1].age <= people[i].age);
    }
}
```

## Error Handling Properties

```zig
test "error handling properties" {
    try ghostspec.property(struct{ input: []const u8 }, testParseErrorHandling);
}

fn testParseErrorHandling(values: struct{ input: []const u8 }) !void {
    // This function should either succeed or return a well-defined error
    const result = parseNumber(values.input);

    if (result) |value| {
        // If it succeeds, it should produce a valid number
        _ = value; // Use the value
    } else |err| {
        // If it fails, it should be one of the expected errors
        try std.testing.expect(
            err == error.InvalidCharacter or
            err == error.EmptyString or
            err == error.Overflow
        );
    }
}

fn parseNumber(input: []const u8) !i32 {
    if (input.len == 0) return error.EmptyString;
    if (std.mem.indexOfAny(u8, input, "abcdefghijklmnopqrstuvwxyz")) |_| {
        return error.InvalidCharacter;
    }

    return std.fmt.parseInt(i32, input, 10) catch return error.Overflow;
}
```

## Statistical Properties

```zig
test "statistical distribution properties" {
    // Test that random sampling follows expected distributions
    try ghostspec.property(struct{ sample_size: u32 }, testRandomUniform, .{
        .num_tests = 50, // Fewer tests for statistical properties
    });
}

fn testRandomUniform(values: struct{ sample_size: u32 }) !void {
    if (values.sample_size < 10 or values.sample_size > 1000) return;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Generate sample
    var samples = try std.ArrayList(u32).initCapacity(allocator, values.sample_size);
    var rng = std.Random.DefaultPrng.init(42);

    for (0..values.sample_size) |_| {
        const value = rng.random().uintLessThan(u32, 100);
        try samples.append(value);
    }

    // Basic statistical tests
    const mean = calculateMean(samples.items);
    const variance = calculateVariance(samples.items, mean);

    // For uniform [0,99], mean should be around 49.5
    try std.testing.expect(mean > 40.0 and mean < 60.0);

    // Variance should be reasonable
    try std.testing.expect(variance > 700.0 and variance < 900.0);
}

fn calculateMean(values: []const u32) f64 {
    var sum: f64 = 0;
    for (values) |v| sum += @floatFromInt(v);
    return sum / @as(f64, @floatFromInt(values.len));
}

fn calculateVariance(values: []const u32, mean: f64) f64 {
    var sum_sq: f64 = 0;
    for (values) |v| {
        const diff = @as(f64, @floatFromInt(v)) - mean;
        sum_sq += diff * diff;
    }
    return sum_sq / @as(f64, @floatFromInt(values.len));
}
```</content>
<parameter name="filePath">/data/projects/ghostspec/docs/examples/property-testing.md