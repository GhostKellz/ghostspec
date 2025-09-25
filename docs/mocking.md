# Mocking Guide

GhostSpec's mocking utilities let you isolate code under test, define expectations, and verify interactions with dependencies.

## Creating a Mock

```zig
const ghostspec = @import("ghostspec");

const Database = struct {
    pub fn save(self: *const @This(), user: User) !void { /* real impl */ }
    pub fn load(self: *const @This(), id: u32) !User { /* real impl */ }
};

test "service stores user" {
    var mock_db = ghostspec.mocking.Mock(Database).init();
    defer mock_db.deinit();

    _ = mock_db.expect("save", .{ mock.any(User) }, .{ .returns = {} });
    _ = mock_db.expect("load", .{ 42 }, .{ .returns = User{ .id = 42, .name = "Ada" } });

    var service = UserService.init(mock_db.mock());
    try service.createUser(User{ .id = 42, .name = "Ada" });

    try mock_db.verify();
}
```

## Expectations

- `expect(method, args, behavior)` registers required calls in order.
- `when(method)` defines stubs that apply until overridden.
- `times(n)` enforces call counts; omit for “at least once”.
- Argument matchers: `mock.any(T)`, `mock.eq(value)`, `mock.matching(fn)`.

## Verification

- `mock.verify()` ensures all expectations were met.
- `mock.verifyCalled(method, args)` checks specific invocations.
- Unmet expectations or unexpected calls raise descriptive errors during verification.

## Partial Mocks

`ghostspec.partialMock(Type, label, fn)` wraps a real instance but lets you override selected methods. Use when most behavior should remain genuine.

## Async Support

Mocks work with async methods returning `!void` or `!T` by awaiting results inside expectations. Configure via `.returns = asyncFn` or `.returns_error = error.SomeError`.

## Tips

- Reset mocks between tests to avoid state leakage.
- Encode domain concepts in helper functions to set up complex expectations.
- Combine with property tests to generate rich call sequences.
- Prefer verifying outcomes over interactions unless collaboration matters.

Check `docs/examples/mocking.md` for comprehensive patterns.
