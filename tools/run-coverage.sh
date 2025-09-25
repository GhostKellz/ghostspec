#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/zig-out/bin"
COVERAGE_DIR="$PROJECT_ROOT/coverage"
TEST_BIN="$BUILD_DIR/ghostspec-tests"

rm -rf "$COVERAGE_DIR"
mkdir -p "$COVERAGE_DIR" "$BUILD_DIR"

zig test "$PROJECT_ROOT/src/main.zig" \
  -O Debug \
  -femit-bin="$TEST_BIN" \
  --test-name-prefix ghostspec-

if ! command -v kcov >/dev/null 2>&1; then
  echo "error: kcov not found. Install kcov (https://github.com/SimonKagstrom/kcov)" >&2
  exit 1
fi

kcov \
  --clean \
  --include-path="$PROJECT_ROOT/src" \
  --exclude-pattern="zig-cache" \
  "$COVERAGE_DIR" \
  "$TEST_BIN"

echo "Coverage report generated at $COVERAGE_DIR/index.html"
