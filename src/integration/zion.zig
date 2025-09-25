const std = @import("std");

/// Metadata describing how GhostSpec integrates with the Zion CLI.
///
/// The manifest follows Zig package guidance: consumers import this module
/// (or call `ghostspec.zion.manifest()`) to discover supported wrapper
/// commands, recommended build hooks, and documentation links. Zion uses this
/// manifest to expose first-class GhostSpec workflows without depending on
/// brittle string parsing.
pub const Manifest = struct {
    version: []const u8,
    release_channel: []const u8,
    summary: []const u8,
    commands: []const CommandSpec,
    wrappers: []const WrapperSpec,
    resources: []const ResourceLink,
};

/// High-level GhostSpec operation surfaced in Zion (install, run, etc.).
pub const CommandSpec = struct {
    name: []const u8,
    description: []const u8,
    usage: []const []const u8,
    category: []const u8,
    stage: []const u8,
};

/// Zion wrapper describing how to invoke GhostSpec from a project build.
pub const WrapperSpec = struct {
    name: []const u8,
    summary: []const u8,
    zig_command: []const []const u8,
    requirements: []const []const u8,
};

/// Additional documentation or assets.
pub const ResourceLink = struct {
    name: []const u8,
    description: []const u8,
    url: []const u8,
};

/// Options when wiring GhostSpec steps into a consumer build.zig.
pub const BuildOptions = struct {
    step_name: []const u8 = "ghostspec-test",
    step_description: []const u8 = "Run GhostSpec test suites",
};

/// Artifacts returned after registering GhostSpec with a build graph.
pub const BuildArtifacts = struct {
    module: *std.Build.Module,
    test_step: *std.Build.Step,
};

/// Add a `zig build ghostspec-test` step backed by the GhostSpec tests.
pub fn addBuildSteps(b: *std.Build, dep: *std.Build.Dependency, options: BuildOptions) BuildArtifacts {
    const ghostspec_module = dep.module("ghostspec");
    const test_artifact = b.addTest(.{ .root_module = ghostspec_module });
    const run_tests = b.addRunArtifact(test_artifact);

    const step = b.step(options.step_name, options.step_description);
    step.dependOn(&run_tests.step);

    return .{
        .module = ghostspec_module,
        .test_step = step,
    };
}

const install_usage = [_][]const u8{
    "zion ghostspec install",
    "zion add ghostkellz/ghostspec",
};

const scaffold_usage = [_][]const u8{
    "zion ghostspec scaffold",
    "zig build ghostspec:init",
};

const info_usage = [_][]const u8{
    "zion ghostspec info",
    "zion ghostspec commands",
};

const run_usage = [_][]const u8{
    "zion ghostspec run -- suite=all",
    "zig build ghostspec-test",
};

const commands_list = [_]CommandSpec{
    .{
        .name = "install",
        .description = "Add GhostSpec as a dependency and lock it to the RC1 channel.",
        .usage = &install_usage,
        .category = "setup",
        .stage = "beta",
    },
    .{
        .name = "scaffold",
        .description = "Generate a GhostSpec-optimised test skeleton for the current project.",
        .usage = &scaffold_usage,
        .category = "bootstrap",
        .stage = "rc1",
    },
    .{
        .name = "info",
        .description = "Show the available Zion wrappers and documentation links.",
        .usage = &info_usage,
        .category = "docs",
        .stage = "rc1",
    },
    .{
        .name = "run",
        .description = "Execute GhostSpec test suites through Zion with rich progress reporting.",
        .usage = &run_usage,
        .category = "execution",
        .stage = "rc1",
    },
};

const wrappers_list = [_]WrapperSpec{
    .{
        .name = "ghostspec-test",
        .summary = "Runs all GhostSpec suites using the project build graph (maps to `zig build ghostspec-test`).",
        .zig_command = &[_][]const u8{
            "zig",
            "build",
            "ghostspec-test",
        },
        .requirements = &[_][]const u8{
            "Require GhostSpec added via `b.dependency(\"ghostspec\", .{})`.",
            "Invoke `ghostspec.zion.addBuildSteps` from the consumer build script.",
        },
    },
};

const resources_list = [_]ResourceLink{
    .{
        .name = "Architecture Guide",
        .description = "Detailed module map and extension points for GhostSpec.",
        .url = "https://github.com/ghostkellz/ghostspec/blob/main/docs/architecture.md",
    },
    .{
        .name = "Property Testing Guide",
        .description = "How to configure generators and shrinkers using GhostSpec.",
        .url = "https://github.com/ghostkellz/ghostspec/blob/main/docs/property-testing.md",
    },
    .{
        .name = "SPECTRA RC1 Update",
        .description = "Release candidate status report consumed by Zion.",
        .url = "https://github.com/ghostkellz/ghostspec/blob/main/SPECTRA_RC1.md",
    },
};

const manifest_data = Manifest{
    .version = "0.9.0-rc1",
    .release_channel = "rc1",
    .summary = "GhostSpec RC1 integration manifest for Zion-powered workflows.",
    .commands = &commands_list,
    .wrappers = &wrappers_list,
    .resources = &resources_list,
};

/// Return the static manifest.
pub fn manifest() Manifest {
    return manifest_data;
}

/// Find a command definition by name. Returns null if not found.
pub fn commandByName(name: []const u8) ?CommandSpec {
    inline for (commands_list) |cmd| {
        if (std.mem.eql(u8, cmd.name, name)) {
            return cmd;
        }
    }
    return null;
}

/// Convenience helper to stream a manifest summary to any std.io.Writer.
pub fn printSummary(writer: anytype) !void {
    const man = manifest();
    try writer.print("GhostSpec {s} ({s})\n", .{ man.version, man.release_channel });
    try writer.print("{s}\n\n", .{man.summary});

    try writer.print("Commands:\n", .{});
    inline for (commands_list) |cmd| {
        try writer.print("  • {s} — {s}\n", .{ cmd.name, cmd.description });
    }

    try writer.print("\nWrappers:\n", .{});
    inline for (wrappers_list) |wrap| {
        try writer.print("  • {s} — {s}\n", .{ wrap.name, wrap.summary });
    }
}
