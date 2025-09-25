# Contributing to GhostSpec

Thanks for helping improve GhostSpec! This document describes how to get set up, propose changes, and keep the project healthy.

## Getting Started

1. **Fork & clone** the repository.
2. Install **Zig 0.16.0-dev** (matching `build.zig.zon`).
3. Run the test suite:
   ```bash
   zig build test
   ```
4. Generate an optional coverage report:
   ```bash
   tools/run-coverage.sh
   ```

## Development Workflow

- Create feature branches from `main`.
- Format code with `zig fmt` before committing.
- Add/ update tests alongside code changes.
- Document behavior in `docs/` when introducing new features.
- Keep commits focused; reference issues (e.g., `Fixes #123`).

## Pull Request Checklist

- [ ] Tests (`zig build test`) pass locally.
- [ ] Formatting (`zig fmt`) was run.
- [ ] Coverage script succeeds (if applicable).
- [ ] Documentation updated (README, docs/, changelog).
- [ ] PR description explains motivation and testing strategy.

## Issue Labels

- `needs-triage`: awaiting categorization.
- `type:*`: bug, feature, docs, infra.
- `area:*`: property, benchmark, runner, fuzzing, mocking.
- `good-first-issue`: accessible tasks for newcomers.

## Coding Standards

- Prefer explicit error handling using `try`/`catch`.
- Keep property tests deterministic for a given seed (log the seed when debugging).
- Avoid global mutable state; pass allocators explicitly.
- Document public APIs with comments including usage snippets.

## Project Structure

- `src/`: framework implementation.
- `docs/`: user guides, API reference, architecture.
- `examples/`: runnable samples.
- `tools/`: developer utilities (coverage, linting).
- `.github/`: CI workflows and issue templates.

## Communication

- Use GitHub Discussions for design proposals.
- Join the community chat (planned for RC4) for synchronous support.
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md).

Thanks for building the future of testing in Zig with us! 🚀
