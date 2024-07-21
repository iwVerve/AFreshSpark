const std = @import("std");
const Build = std.Build;
const Compile = std.Build.Step.Compile;
const ResolvedTarget = std.Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const Options = std.Build.Step.Options;

pub fn build(b: *std.Build) !void {
    // TARGET
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // OPTIONS
    const static = b.option(bool, "static", "Build standalone executable") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "static", static);
    options.addOption([]const u8, "dll_name", "game");

    // DEPENDENCY
    const raylib = blk: {
        const raylib_dep = b.dependency("raylib", .{
            .target = target,
            .optimize = .ReleaseFast,
            // Build raylib in shared library when hotreloading to share raylib state between executable and game library.
            .shared = !static,
        });
        break :blk raylib_dep.artifact("raylib");
    };

    // COMPILE
    if (target.result.isWasm()) {
        try buildWeb(b, target, optimize);
    } else {
        const exe = if (static) blk: {
            break :blk buildStaticNative(b, target, optimize, raylib, options);
        } else blk: {
            const dll = buildGameLib(b, target, optimize, raylib, options);
            const dll_install = b.addInstallArtifact(dll, .{});

            const reload_step = b.step("reload", "Build the dll");
            reload_step.dependOn(&dll_install.step);

            const exe = buildDynamicNative(b, target, optimize, raylib, options);
            exe.step.dependOn(&dll_install.step);
            break :blk exe;
        };
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    // TODO: Put test step back.
}

fn buildStaticNative(b: *Build, target: ResolvedTarget, optimize: OptimizeMode, raylib: *Compile, options: *Options) *Compile {
    const exe = b.addExecutable(.{
        .name = "static",
        .root_source_file = b.path("src/desktop.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(raylib);
    exe.root_module.addOptions("config", options);

    return exe;
}

fn buildDynamicNative(b: *Build, target: ResolvedTarget, optimize: OptimizeMode, raylib: *Compile, options: *Options) *Compile {
    const exe = b.addExecutable(.{
        .name = "dynamic",
        .root_source_file = b.path("src/desktop.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(raylib);
    exe.root_module.addOptions("config", options);

    b.installArtifact(raylib);

    return exe;
}

fn buildGameLib(b: *Build, target: ResolvedTarget, optimize: OptimizeMode, raylib: *Compile, options: *Options) *Compile {
    var dll = b.addSharedLibrary(.{
        .name = "game",
        .root_source_file = b.path("src/Game.zig"),
        .target = target,
        .optimize = optimize,
    });
    dll.linkLibrary(raylib);
    dll.root_module.addOptions("config", options);

    return dll;
}

/// Unimplemented
fn buildWeb(b: *Build, target: ResolvedTarget, optimize: OptimizeMode) !void {
    _ = b;
    _ = target;
    _ = optimize;
    @panic("Unimplemented");
}
