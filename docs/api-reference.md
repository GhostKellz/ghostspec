# GhostSpec API Reference

Complete API documentation for all GhostSpec modules.

## 📦 Core Module

### `ghostspec` (root.zig)

The main entry point that re-exports all functionality.

```zig
const ghostspec = @import("ghostspec");

// Re-exported modules
pub const property_testing = @import("property.zig");
pub const benchmarking = @import("benchmark.zig");
pub const fuzzing = @import("fuzzer.zig");
pub const mocking = @import("mock.zig");
pub const runner = @import("runner.zig");
pub const reporter = @import("reporter.zig");
pub const colors = @import("colors.zig");  // New in v0.9.2
pub const filter = @import("filter.zig");  // New in v0.9.2

// Convenience functions
pub fn property(comptime T: type, comptime property_fn: anytype) !void;
pub fn benchmark(comptime name: []const u8, comptime bench_fn: anytype) !void;
pub fn mock(comptime Interface: type) type;
```

## 🧪 Property Testing API

### `PropertyTest`

```zig
pub const PropertyTest = struct {
    pub fn init(allocator: std.mem.Allocator, config: Config) PropertyTest
    pub fn deinit(self: *PropertyTest) void
    pub fn runProperty(self: *PropertyTest, comptime T: type, comptime property_fn: anytype) !PropertyResult
};
```

### `Config`

```zig
pub const Config = struct {
    num_tests: u32 = 100,
    max_size: u32 = 100,
    max_shrinking_attempts: u32 = 1000,
    seed: u64 = 0,
};
```

### `PropertyResult`

```zig
pub const PropertyResult = struct {
    passed: bool,
    num_tests_run: u32,
    failing_case: ?[]const u8,
    error_message: ?[]const u8,
};
```

## 📊 Benchmarking API

### `Benchmark`

```zig
pub const Benchmark = struct {
    pub fn init(allocator: std.mem.Allocator, config: BenchConfig) Benchmark
    pub fn deinit(self: *Benchmark) void
    pub fn runBenchmark(self: *Benchmark, name: []const u8, comptime bench_fn: anytype) !BenchmarkResult
};
```

### `BenchConfig`

```zig
pub const BenchConfig = struct {
    warmup_iterations: u32 = 100,
    min_iterations: u32 = 1000,
    max_time_ms: u32 = 1000,
    target_precision: f64 = 0.01,
};
```

### `BenchmarkResult`

```zig
pub const BenchmarkResult = struct {
    name: []const u8,
    iterations_run: u32,
    total_time_ns: u64,
    stats: BenchmarkStats,
    memory_info: MemoryInfo,
    is_regression: bool,
    regression_percentage: f64,
};
```

## 🎯 Fuzzing API

### `Fuzzer`

```zig
pub const Fuzzer = struct {
    pub fn init(allocator: std.mem.Allocator, config: FuzzConfig) !Fuzzer
    pub fn deinit(self: *Fuzzer) void
    pub fn run(self: *Fuzzer, comptime target_fn: anytype, iterations: u32) !FuzzResult
    pub fn addCorpus(self: *Fuzzer, input: []const u8) !void
};
```

### `FuzzConfig`

```zig
pub const FuzzConfig = struct {
    max_iterations: u32 = 10000,
    timeout_ms: u32 = 1000,
    corpus_dir: ?[]const u8 = null,
};
```

### `FuzzResult`

```zig
pub const FuzzResult = struct {
    target_function: []const u8,
    inputs_tested: u32,
    total_iterations: u32,
    crashes_found: u32,
    timeouts: u32,
    crash_inputs: std.ArrayList([]const u8),
};
```

## 🎭 Mocking API

### `Mock(Interface)`

Generic mock constructor that creates a mock implementation of any interface.

```zig
pub fn Mock(comptime Interface: type) type
```

Returns a struct with:

```zig
pub fn init() Self
pub fn deinit(self: *Self) void
pub fn when(self: *Self, comptime function_name: []const u8) *MockBehavior
pub fn executeCall(self: *Self, comptime function_name: []const u8, comptime ReturnType: type, args: anytype) !ReturnType
pub fn recordCall(self: *Self, function_name: []const u8, args: anytype) void
```

### `MockBehavior`

```zig
pub const MockBehavior = struct {
    pub fn returnValue(self: *MockBehavior, comptime T: type, value: T) void
    pub fn panic(self: *MockBehavior) void
    pub fn err(self: *MockBehavior, error_value: anyerror) void
};
```

## 🏃 Test Runner API

### `Runner`

```zig
pub const Runner = struct {
    pub fn init(allocator: std.mem.Allocator, config: RunnerConfig) Runner
    pub fn deinit(self: *Runner) void
    pub fn addTest(self: *Runner, test_fn: TestFunction) !void
    pub fn runAll(self: *Runner) !TestSuiteResult
};
```

### `RunnerConfig`

```zig
pub const RunnerConfig = struct {
    parallel: bool = true,
    num_threads: u32 = 0, // 0 = auto-detect
    timeout_ms: u32 = 30000,
    fail_fast: bool = false,
};
```

## 📋 Reporter API

### `TestReporter`

```zig
pub const TestReporter = struct {
    pub fn init(allocator: std.mem.Allocator, config: ReporterConfig) TestReporter
    pub fn deinit(self: *TestReporter) void
    pub fn report(self: *TestReporter, result: TestSuiteResult) !void
    pub fn exportJson(self: *TestReporter, writer: anytype, result: TestSuiteResult) !void
    pub fn exportJUnit(self: *TestReporter, writer: anytype, result: TestSuiteResult) !void
};
```

### `ReporterConfig`

```zig
pub const ReporterConfig = struct {
    format: ReportFormat = .console,
    output_file: ?[]const u8 = null,
    verbose: bool = false,
    show_progress: bool = true,
};
```

## 🔧 Generator API

### Core Generation Functions

```zig
pub fn generate(comptime T: type, allocator: std.mem.Allocator, rng: std.Random, max_size: u32) !T
pub fn deinit(comptime T: type, value: T, allocator: std.mem.Allocator) void
```

### Built-in Generators

```zig
// Integers
pub fn positiveInt(comptime T: type) fn(std.mem.Allocator, std.Random, u32) anyerror!T
pub fn smallInt(allocator: std.mem.Allocator, rng: std.Random, max_size: u32) !u32

// Strings
pub fn nonEmptyString(allocator: std.mem.Allocator, rng: std.Random, max_size: u32) ![]const u8
pub fn alphanumericString(allocator: std.mem.Allocator, rng: std.Random, max_size: u32) ![]const u8

// Collections
pub fn array(comptime T: type, allocator: std.mem.Allocator, rng: std.Random, max_size: u32) ![]T
pub fn slice(comptime T: type, allocator: std.mem.Allocator, rng: std.Random, max_size: u32) ![]T
```

## 📊 Statistics API

### `BenchmarkStats`

```zig
pub const BenchmarkStats = struct {
    mean: f64,
    median: f64,
    std_dev: f64,
    min: f64,
    max: f64,
    p95: f64,
    p99: f64,
};
```

### `MemoryInfo`

```zig
pub const MemoryInfo = struct {
    bytes_allocated: usize,
    bytes_freed: usize,
    peak_memory: usize,
    allocations: usize,

    pub fn netMemory(self: MemoryInfo) isize {
        return @as(isize, @intCast(self.bytes_allocated)) - @as(isize, @intCast(self.bytes_freed));
    }
};
```

## 🎛️ Configuration Types

### Common Configuration Patterns

All modules follow similar configuration patterns:

```zig
// Initialize with defaults
const instance = Module.init(allocator, .{});

// Initialize with custom config
const config = Module.Config{
    .field1 = value1,
    .field2 = value2,
};
const instance = Module.init(allocator, config);
```

### Error Types

GhostSpec uses standard Zig error handling:

- `error.TestFailed` - Test assertion failed
- `error.PropertyFailed` - Property test found counterexample
- `error.BenchmarkFailed` - Benchmark execution failed
- `error.MockError` - Mock verification failed
- `error.FuzzCrash` - Fuzzer found a crash

## 🔄 Type System Integration

### Comptime Integration

GhostSpec heavily uses Zig's comptime features:

```zig
// Type-safe property testing
try ghostspec.property(MyStruct, myProperty);

// Type-safe mocking
var mock = ghostspec.mocking.Mock(MyInterface).init();

// Type-safe benchmarking
try ghostspec.benchmark("my_function", myBenchmarkFunction);
```

### Memory Management

All GhostSpec types follow consistent memory management:

```zig
// Initialize
var instance = Module.init(allocator, config);
defer instance.deinit(); // Always call deinit

// Or use with errdefer
var instance = Module.init(allocator, config);
errdefer instance.deinit();
```

## 🚀 Performance Characteristics

### Property Testing
- **Time Complexity**: O(num_tests × property_complexity)
- **Space Complexity**: O(max_size × num_tests)
- **Typical Performance**: 1000 tests/second for simple properties

### Benchmarking
- **Warmup Overhead**: ~100μs per benchmark
- **Measurement Precision**: ±1% typical
- **Memory Tracking**: ~10% overhead

### Fuzzing
- **Corpus Growth**: Exponential with coverage
- **Mutation Efficiency**: ~1 crash per 1000 iterations (typical)
- **Memory Usage**: O(corpus_size)

### Mocking
- **Call Recording**: O(1) per call
- **Verification**: O(num_calls) per verification
- **Memory Usage**: O(num_calls × avg_arg_size)

## 🛡️ Safety & Correctness

### Memory Safety
- All allocations tracked and freed
- No use-after-free or double-free
- Proper error handling prevents leaks

### Thread Safety
- Test runner is thread-safe
- Individual tests isolated
- Shared state properly synchronized

### Type Safety
- Full comptime type checking
- No runtime type errors possible
- Generic code validated at compile time

---

For more detailed examples and usage patterns, see the [examples directory](./examples/) and [getting started guide](./getting-started.md).</content>
<parameter name="filePath">/data/projects/ghostspec/docs/api-reference.md
## 🎨 Colors API (New in v0.9.2)

### `ColorConfig`

Control color output in terminal.

```zig
pub const ColorConfig = struct {
    enabled: bool = true,
    force: bool = false,
    
    pub fn auto() ColorConfig;    // Auto-detect terminal colors
    pub fn always() ColorConfig;  // Always use colors
    pub fn never() ColorConfig;   // Never use colors
};
```

### `Style`

Terminal styling and colored output.

```zig
pub const Style = struct {
    pub fn init(config: ColorConfig) Style;
    pub fn success(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void;
    pub fn err(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void;
    pub fn warn(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void;
    pub fn info(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void;
    pub fn dim(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void;
    pub fn bold(self: Style, writer: anytype, comptime fmt: []const u8, args: anytype) !void;
};
```

**Example:**
```zig
const style = ghostspec.colors.styled();
try style.success(stdout, "All tests passed!\n", .{});
try style.err(stderr, "Test failed: {s}\n", .{error_msg});
```

**Environment Variables:**
- `NO_COLOR`: Disable colors
- `FORCE_COLOR`: Force enable colors

## 🔍 Filter API (New in v0.9.2)

### `FilterConfig`

Configure test filtering rules.

```zig
pub const FilterConfig = struct {
    include_patterns: []const []const u8 = &.{},  // e.g., &.{"test_*", "*_integration"}
    exclude_patterns: []const []const u8 = &.{},  // e.g., &.{"*_slow", "*_manual"}
    exact_names: []const []const u8 = &.{},       // e.g., &.{"test_login", "test_auth"}
    failed_only: bool = false,                     // Run only previously failed tests
};
```

### `TestFilter`

Filter tests based on patterns.

```zig
pub const TestFilter = struct {
    pub fn init(allocator: std.mem.Allocator, config: FilterConfig) TestFilter;
    pub fn deinit(self: *TestFilter) void;
    pub fn shouldRun(self: *const TestFilter, test_name: []const u8) bool;
    pub fn countMatches(self: *const TestFilter, test_names: []const []const u8) usize;
    pub fn loadFailedTests(self: *TestFilter, file_path: []const u8) !void;
};
```

### Pattern Matching

Supports glob-style patterns:
- `*` - matches any sequence of characters
- `?` - matches a single character
- Literal strings for exact matches

**Examples:**
```zig
// Include only integration tests
const config = FilterConfig{
    .include_patterns = &.{"*_integration"},
};

// Exclude slow tests
const config = FilterConfig{
    .exclude_patterns = &.{"*_slow"},
};

// Run specific tests
const config = FilterConfig{
    .exact_names = &.{"test_auth", "test_login"},
};

// Combine filters
const config = FilterConfig{
    .include_patterns = &.{"test_*"},
    .exclude_patterns = &.{"*_slow", "*_manual"},
};
```

**Usage:**
```zig
const filter = ghostspec.filter.TestFilter.init(allocator, config);
defer filter.deinit();

for (all_tests) |test_name| {
    if (filter.shouldRun(test_name)) {
        // Run this test
    }
}
```
