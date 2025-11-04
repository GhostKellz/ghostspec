# Changelog

All notable changes to this project will be documented here following [Keep a Changelog](https://keepachangelog.com/) guidelines.

## [0.9.2] - 2025-11-03
### Fixed
- **Critical**: Updated deprecated `std.time` API calls to use Zig 0.16+ API
  - Replaced `std.time.timestamp()` with `std.time.Instant.now()`
  - Replaced `std.time.nanoTimestamp()` with `std.time.Instant` and `Timer` API
  - Fixes compilation errors in `fuzzer.zig`, `benchmark.zig`, `mock.zig`, and `property.zig`
- Fixed typo in `build.zig` comment (releative → relative)

### Changed
- Added LICENSE and README.md to `build.zig.zon` paths for proper package distribution
- Bumped package version to `0.9.2`

## [0.9.0-beta.1] - 2025-09-24
### Added
- Architecture guide, best practices, troubleshooting, and migration documentation.
- Contributor onboarding docs and code of conduct.
- Issue templates, triage process, and coverage script.
- GitHub Actions CI workflow with formatting, tests, and coverage artifacts.
- Example projects for CLI, HTTP handler, and data structures.

### Changed
- Bumped package version to `0.9.0-beta.1` to signal approaching beta quality.

## [Unreleased]
- Track upcoming fixes and features here.
