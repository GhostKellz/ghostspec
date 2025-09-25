# GhostSpec Roadmap

_Updated: September 24, 2025_

This roadmap tracks GhostSpec's journey from the current MVP to a public release. Each milestone builds on the previous one, with explicit quality gates before we promote to the next stage. Checkboxes reflect completion status based on the project state today.

- ✅ — complete
- ☐ — planned / in progress

---

## Stage 0 — MVP (Current)

Focus: Core feature coverage and foundational docs demonstrating GhostSpec's capabilities.

- ✅ Core property-testing engine (`src/property.zig`)
- ✅ Benchmarking module with statistical output (`src/benchmark.zig`)
- ✅ Fuzzing harness foundation (`src/fuzzer.zig`)
- ✅ Mocking primitives for dependency isolation (`src/mock.zig`)
- ✅ Baseline runner and reporter pipeline (`src/runner.zig`, `src/reporter.zig`)
- ✅ Root module export and integration entry point (`src/root.zig`)
- ✅ Quick-start README with Zig fetch instructions
- ✅ Documentation baseline: `docs/getting-started.md`, `docs/api-reference.md`, example suites
- ✅ Documented architecture overview (dedicated guide)
- ✅ Automated test coverage report for the framework itself
- ✅ Public issue tracker triage and tagging hygiene

_Milestone exit criteria_: all remaining MVP tasks checked or re-scoped into Alpha.

---

## Stage 1 — Alpha Hardening

Focus: Close documentation gaps, polish ergonomics, and ensure contributors have a clear path forward.

- ✅ Complete documentation set (property testing, benchmarking, fuzzing, mocking, troubleshooting guides)
- ✅ Migration guide from popular C/C++ and Zig test frameworks
- ✅ Best-practices and patterns guide (how to structure suites, how to shrink failures)
- ✅ Troubleshooting playbook for common runtime failures
- ✅ Contributor onboarding docs (CONTRIBUTING.md, CODE_OF_CONDUCT.md)
- ✅ Enforce formatting/linting (`zig fmt`, `zig build test`, coverage)
- ✅ Minimal example projects verified (CLI, HTTP server, data-structures)

_Go/no-go_: internal team comfortable dogfooding GhostSpec across two real projects.

---

## Stage 2 — Beta (Release-Quality)

Focus: Ship a version we would trust in production. Beta is effectively a release-quality build.

- ✅ Feature freeze declared and communicated
- ✅ Semantic versioning in `build.zig.zon` with reproducible lockfile
- ✅ API stability report + breaking-change policy documented
- ✅ Full end-to-end CI (unit, property, fuzz smoke, benchmark regression guardrails)
- ✅ Tagged `v0.9.0-beta` release with binaries/artifacts if applicable
- ✅ Publish comprehensive docs site (hosted or via GitHub Pages)
- ✅ Real-world adoption pilot (at least one external project) with feedback loop
- ✅ Security checklist (dependency audit, safe allocator usage, fuzz corpora storage)
- ✅ Public roadmap and changelog updated for transparency

_Beta exit_: no P0/P1 bugs open, docs and tooling polished enough for wider public use.

---

## Stage 3 — Release Candidates

Each RC tightens a specific axis. Promotion requires all checkboxes for the prior RC to be complete.

### RC1 — Stability Freeze
- ✅ Bug backlog triaged; only release blockers remain
- ☐ Automated regression suite green for 7 consecutive days
- ☐ Telemetry/reporting outputs verified and version locked
- ☐ Release playbook drafted (cut/tag/release steps)

### RC2 — Performance & Scalability
- ☐ Benchmark suite comparing GhostSpec vs baseline frameworks
- ☐ Performance budgets enforced (startup <100 ms, overhead <1 µs/test)
- ☐ Memory profiling across representative workloads
- ☐ Parallel execution benchmarks across 2/4/8 cores documented

### RC3 — Cross-Platform Confidence
- ☐ Nightly CI matrix (Linux/macOS/Windows) with Zig 0.13–0.16-dev
- ☐ WASM test harness validated (where supported)
- ☐ ARM64 (Linux/macOS) smoke tests passing
- ☐ Packaging verified for Zig package manager & zigmod (if applicable)

### RC4 — Ecosystem & Integrations
- ☐ GitHub Actions templates published and tested end-to-end
- ☐ Docker/OCI images for CI usage
- ☐ Editor integrations (VS Code snippets/commands) available
- ☐ Community channels launched (Discussions, Discord, etc.) with moderation plan

### RC5 — Final Polish & Launch Readiness
- ☐ Security review (internal or third-party) signed off
- ☐ Accessibility review of docs & tooling outputs
- ☐ Marketing assets prepared (blog posts, release notes, demo scripts)
- ☐ Release FAQ & support triage plan finalized

---

## Stage 4 — General Availability (1.0.0)

Focus: Deliver the public release and kick off long-term support.

- ☐ Tag and publish `v1.0.0`
- ☐ Announce via blog, social channels, and Zig community outlets
- ☐ Update documentation with GA status and upgrade notes
- ☐ Post-release monitoring: collect issue reports for 2 weeks
- ☐ Schedule first post-release patch (if needed) and outline maintenance cadence

---

## Backlog & Stretch Goals

Items that may enter the roadmap once core milestones are green.

- ☐ Mutation testing engine
- ☐ Test impact analysis for targeted reruns
- ☐ Coverage visualizer integration (kcov or equivalent)
- ☐ Rich HTML/JSON reporters with dashboards
- ☐ Long-running benchmark dashboard with historical trends

---

## How to Use This Roadmap

1. Review remaining checkboxes before moving a milestone forward.
2. File issues referencing the relevant milestone (e.g. `Milestone: Alpha`).
3. Update this document alongside major planning meetings or releases.
4. Keep the roadmap honest—if scope shifts, reflect it here.

Together, these milestones ensure GhostSpec graduates from an exceptional MVP to a battle-tested release trusted by the Zig community.
