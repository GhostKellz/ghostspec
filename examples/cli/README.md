# CLI Example

This example demonstrates how to test a simple command-line interface using GhostSpec's property testing and mocking features.

## Running

```bash
zig test cli_example.zig
```

## Highlights

- Property tests for argument parsing.
- Mocking stdout/stderr to verify user-visible output.
- Benchmark to monitor command performance.
