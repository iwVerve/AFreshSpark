const std = @import("std");
const builtin = @import("builtin");

const Build = std.Build;
const Compile = std.Build.Step.Compile;
const ResolvedTarget = std.Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const Options = std.Build.Step.Options;
const Dependency = std.Build.Dependency;

const game_name = "game";
const install_dir_dynamic = "dynamic";
const install_dir_static = "static";

const include_dirs = &.{
    "assets",
};

pub fn build(b: *std.Build) !void {
    // TARGET
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .cpu_model = .{ .explicit = &std.Target.wasm.cpu.mvp },
        .cpu_features_add = std.Target.wasm.featureSet(&.{
            .atomics,
            .bulk_memory,
        }),
        .os_tag = .emscripten,
    });
    const is_wasm = target.result.isWasm();
    const actual_target = if (is_wasm) wasm_target else target;

    // OPTIONS
    const static = if (is_wasm or actual_target.result.os.tag != .windows)
        true
    else
        b.option(bool, "static", "Build standalone executable") orelse false;

    const strip = b.option(bool, "strip", "Strip debug symbols") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "static", static);
    options.addOption([]const u8, "dll_name", "game");

    // DEPENDENCY
    const raylib_dep = b.dependency("raylib", .{
        .target = actual_target,
        .optimize = .ReleaseFast,
        // Build raylib in shared library when hotreloading to share raylib state between executable and game library.
        .shared = !static,
        .rmodels = false,
    });
    const raylib = raylib_dep.artifact("raylib");

    // COMPILE
    if (is_wasm) {
        try buildWeb(b, actual_target, optimize, raylib_dep, raylib, options);
    } else {
        const ExeBuild = struct {
            compile: *Compile,
            dir: []const u8,
        };

        const exe: ExeBuild = if (static) blk: {
            break :blk .{
                .compile = buildStaticExecutable(b, actual_target, optimize, raylib, options, strip),
                .dir = install_dir_static,
            };
        } else blk: {
            const dll = buildGameLib(b, actual_target, optimize, raylib, options);
            const dll_install = b.addInstallArtifact(dll, .{ .dest_dir = .{ .override = .{ .custom = install_dir_dynamic } } });

            const reload_step = b.step("reload", "Build the dll");
            reload_step.dependOn(&dll_install.step);

            const exe = buildDynamicExecutable(b, actual_target, optimize, raylib, options);
            exe.step.dependOn(&dll_install.step);
            break :blk .{
                .compile = exe,
                .dir = install_dir_dynamic,
            };
        };
        // b.installArtifact(exe.compile);
        const install = b.addInstallArtifact(exe.compile, .{ .dest_dir = .{ .override = .{ .custom = exe.dir } } });
        b.default_step.dependOn(&install.step);

        const run_cmd = b.addRunArtifact(exe.compile);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    // TODO: Put test step back.
}

fn buildStaticExecutable(b: *Build, target: ResolvedTarget, optimize: OptimizeMode, raylib: *Compile, options: *Options, strip: bool) *Compile {
    const exe = b.addExecutable(.{
        .name = game_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    exe.linkLibrary(raylib);
    exe.root_module.addOptions("build_options", options);

    inline for (include_dirs) |include_dir| {
        b.installDirectory(.{
            .source_dir = b.path(include_dir),
            .install_dir = .{ .custom = "" },
            .install_subdir = install_dir_static ++ "/" ++ include_dir,
        });
    }

    return exe;
}

fn buildDynamicExecutable(b: *Build, target: ResolvedTarget, optimize: OptimizeMode, raylib: *Compile, options: *Options) *Compile {
    const exe = b.addExecutable(.{
        .name = game_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(raylib);
    exe.root_module.addOptions("build_options", options);

    const install = b.addInstallArtifact(raylib, .{ .dest_dir = .{ .override = .{ .custom = install_dir_dynamic } } });
    b.default_step.dependOn(&install.step);

    return exe;
}

fn buildGameLib(b: *Build, target: ResolvedTarget, optimize: OptimizeMode, raylib: *Compile, options: *Options) *Compile {
    var dll = b.addSharedLibrary(.{
        .name = game_name,
        .root_source_file = b.path("src/Game.zig"),
        .target = target,
        .optimize = optimize,
    });
    dll.linkLibrary(raylib);
    dll.root_module.addOptions("config", options);

    return dll;
}

fn buildWeb(b: *Build, target: ResolvedTarget, optimize: OptimizeMode, raylib_dep: *Dependency, raylib: *Compile, options: *Options) !void {
    if (b.sysroot == null) {
        @panic("Pass '--sysroot \"[path to emsdk installation]/upstream/emscripten\"'");
    }

    const exe_lib = b.addStaticLibrary(.{
        .name = game_name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    exe_lib.linkLibrary(raylib);
    exe_lib.addIncludePath(raylib_dep.path("src"));
    exe_lib.root_module.addOptions("build_options", options);

    const sysroot_include = b.pathJoin(&.{ b.sysroot.?, "cache", "sysroot", "include" });
    var dir = std.fs.openDirAbsolute(sysroot_include, std.fs.Dir.OpenDirOptions{ .access_sub_paths = true, .no_follow = true }) catch @panic("No emscripten cache. Generate it!");
    dir.close();

    exe_lib.addIncludePath(.{ .cwd_relative = sysroot_include });

    const cwd = std.fs.cwd();
    try cwd.makePath("zig-out/web");

    const emcc_exe = switch (builtin.os.tag) {
        .windows => "emcc.bat",
        else => "emcc",
    };
    const emcc_exe_path = b.pathJoin(&.{ b.sysroot.?, emcc_exe });

    const emcc_command = b.addSystemCommand(&[_][]const u8{emcc_exe_path});
    emcc_command.addArgs(&[_][]const u8{
        "-o",
        "zig-out/web/index.html",
        "-sFULL-ES3=1",
        "-sUSE_GLFW=3",
        "-O3",

        "-sINITIAL_MEMORY=167772160",

        "-sUSE_OFFSET_CONVERTER",
        "--shell-file",
        b.path("src/shell.html").getPath(b),
    });

    inline for (include_dirs) |include_dir| {
        emcc_command.addArgs(&.{
            "--embed-file",
            include_dir,
        });
    }

    const link_items: []const *std.Build.Step.Compile = &.{
        raylib,
        exe_lib,
    };
    for (link_items) |item| {
        emcc_command.addFileArg(item.getEmittedBin());
        emcc_command.step.dependOn(&item.step);
    }

    const install = emcc_command;
    b.default_step.dependOn(&install.step);
}
