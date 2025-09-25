# Testing Best Practices with GhostSpec

## Organize Your Suites

- Group related tests in dedicated Zig files (`tests/property_math.zig`, `tests/http.zig`).
- Use namespaces or structs to scope helper functions and avoid name collisions.
- Tag tests (planned API) or segregate slow/fast suites for selective execution.

## Write Focused Properties

- Express domain invariants (commutativity, associativity, roundtrip) clearly.
- Avoid embedding business logic in the property body—delegate to helpers.
- Limit side effects; properties should be deterministic for a given seed.

## Keep Benchmarks Honest

- Separate setup from the hot path. Initialize data outside `b.iterate` when possible.
- Disable logging and debug assertions within the benchmark loop.
- Compare relative performance by keeping benchmark durations similar.

## Use Mocks Strategically

- Mock only external interactions (network, filesystem). Real implementations are better when fast and deterministic.
- Prefer verifying outcomes, not interactions; use mocks to assert side effects sparingly.
- Reset or recreate mocks per test to avoid state leakage.

## Manage Test Data

- Store reusable corpora under `tests/corpus/` and load via `std.fs.cwd()`.
- Generate fixtures with helper builders to keep tests concise.
- For property generators, limit sizes to keep runtime reasonable.

## Debugging Workflow

1. Re-run failing tests with higher verbosity (`ghostspec.config.log_level = .debug`).
2. Capture counterexamples and promote them to regression tests when appropriate.
3. Use `zig test -femit-bin` with a debugger for complex failures.

## Continuous Integration

- `zig fmt` to enforce consistent style before commits.
- Run `zig build test` locally; mirror CI steps to avoid surprises.
- Generate coverage via `tools/run-coverage.sh` and keep the report as an artifact.

Adopting these habits keeps the test suite fast, reliable, and maintainable as GhostSpec evolves.
