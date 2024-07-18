const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const static = b.option(bool, "static", "Build standalone executable") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "static", static);
    options.addOption([]const u8, "dll_name", "game");

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = .ReleaseFast,
        // Build raylib in shared library when hotreloading to share raylib state between executable and game library.
        .shared = !static,
    });
    const raylib = raylib_dep.artifact("raylib");

    var dll = b.addSharedLibrary(.{
        .name = "game",
        .root_source_file = b.path("src/Game.zig"),
        .target = target,
        .optimize = optimize,
    });
    dll.linkLibrary(raylib);

    const dll_install = b.addInstallArtifact(dll, .{});

    const exe = b.addExecutable(.{
        .name = if (static) "static" else "dynamic",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(raylib);
    exe.root_module.addOptions("config", options);
    if (!static) {
        exe.step.dependOn(&dll_install.step);
    }
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const reload_step = b.step("reload", "Build the dll");
    reload_step.dependOn(&dll_install.step);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // TODO(verve): Put test step back.
}
