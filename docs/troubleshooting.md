# Troubleshooting Guide

Common issues and fixes when working with GhostSpec.

## Installation

| Symptom | Fix |
| --- | --- |
| `error: unable to resolve package 'ghostspec'` | Run `zig fetch --save https://github.com/ghostkellz/ghostspec/archive/refs/heads/main.tar.gz` and ensure `build.zig.zon` includes the dependency. |
| `error: hash mismatch when fetching` | Update the dependency hash after fetching: run `zig fetch --save` again or edit `build.zig.zon` with the latest hash. |
| Zig version mismatch | GhostSpec targets Zig `0.16.0-dev`. Update Zig or adjust `minimum_zig_version` if you validated compatibility. |

## Running Tests

| Symptom | Fix |
| --- | --- |
| Property tests hang or run slowly | Reduce `num_tests`, lower `max_size`, or seed RNG for reproducibility. |
| Benchmark output missing memory stats | Enable `track_memory = true` and use `std.testing.allocator` or an instrumented allocator. |
| Fuzzer stops early | Increase `max_iterations` or remove `timeout_ms`. Ensure target function returns errors instead of panicking silently. |

## Mocking

| Symptom | Fix |
| --- | --- |
| `unexpected call` errors | Register `when()` stubs for background operations, or widen argument matchers. |
| Expectations never met | Verify the code under test invokes the mock; log arguments to detect mismatch. |

## Build & CI

| Symptom | Fix |
| --- | --- |
| CI fails with formatting errors | Run `zig fmt src/` before committing. Workflow enforces formatting. |
| Coverage job fails | Install `kcov` or update `tools/run-coverage.sh` to point at your coverage tool of choice. |

## Debugging Failing Properties

1. Re-run with `PROPERTY_SEED=<seed>` environment variable (future feature) or temporarily log `ghostspec.property_testing.PropertyTest.seed`.
2. Enable `.shrink_trace = true` in config to view shrink attempts.
3. Add `std.debug.print` statements inside the property function for additional context.

## Getting Help

- Search existing issues and discussions.
- File a new issue using the templates.
- Join the community channel (planned for RC4) for real-time support.
