# HTTP Server Example

Demonstrates testing an asynchronous HTTP handler using GhostSpec with mocks and property tests.

## Running

```bash
zig test http_example.zig
```

## Highlights

- Property tests for query parsing.
- Mock network channel to isolate async behavior.
- Benchmark of request handler latency.
