const std = @import("std");

pub fn build(b: *std.Build) void {
    // TARGET
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // OPTIONS
    const static = b.option(bool, "static", "Build standalone executable") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "static", static);
    options.addOption([]const u8, "dll_name", "game");

    // DEPENDENCIES
    const raylib = blk: {
        const raylib_dep = b.dependency("raylib", .{
            .target = target,
            .optimize = .ReleaseFast,
            // Build raylib in shared library when hotreloading to share raylib state between executable and game library.
            .shared = !static,
        });
        break :blk raylib_dep.artifact("raylib");
    };
    b.installArtifact(raylib);

    // COMPILE STEPS
    var dll = b.addSharedLibrary(.{
        .name = "game",
        .root_source_file = b.path("src/Game.zig"),
        .target = target,
        .optimize = optimize,
    });
    dll.linkLibrary(raylib);
    const dll_install = b.addInstallArtifact(dll, .{});

    const reload_step = b.step("reload", "Build the dll");
    reload_step.dependOn(&dll_install.step);

    const dynamic_exe = b.addExecutable(.{
        .name = "dynamic",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    dynamic_exe.linkLibrary(raylib);
    dynamic_exe.root_module.addOptions("config", options);
    dynamic_exe.step.dependOn(&dll_install.step);
    b.installArtifact(dynamic_exe);

    const static_exe = b.addExecutable(.{
        .name = "static",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    static_exe.linkLibrary(raylib);
    static_exe.root_module.addOptions("config", options);
    b.installArtifact(static_exe);

    // RUN STEPS
    const run_cmd = b.addRunArtifact(dynamic_exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // TODO(verve): Put test step back.
}
