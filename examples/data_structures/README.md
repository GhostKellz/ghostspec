# Data Structures Example

Illustrates property testing and fuzzing for a custom data structure (a bounded deque) using GhostSpec.

## Running

```bash
zig test deque_example.zig
```

## Highlights

- Property tests for invariants (size, front/back consistency).
- Fuzzer to stress push/pop sequences.
- Benchmark of batch operations.
