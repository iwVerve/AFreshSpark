/// Starts and runs the game loop, manages hot reloading.
/// Shouldn't run actual game logic.
const std = @import("std");
const builtin = @import("builtin");
const build_options = @import("build_options");

const hot = @import("hotreloading.zig");
const ray = @import("raylib.zig");
const Game = @import("Game.zig");

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = if (builtin.target.isWasm())
        std.heap.c_allocator
    else
        gpa.allocator();

    if (build_options.static and !builtin.target.isWasm()) {
        // Set working directory to load assets correctly regardless of where the game was launched from.
        const game_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        var game_dir = try std.fs.openDirAbsolute(game_dir_path, .{});
        try game_dir.setAsCwd();
        game_dir.close();
        allocator.free(game_dir_path);
    }

    var game: Game = .{
        .allocator = allocator,
    };

    if (build_options.static) {
        try game.init(true);
    } else {
        try hot.dllOpen();
        if (hot.init_fn(&game, true) != 0) return error.InitializationError;
        try hot.spawnAssetWatcher();
        try hot.spawnDLLWatcher();
    }
    defer game.deinit(true);

    if (builtin.target.isWasm()) {
        // Emscripten game loop
        emscripten_game_ptr = &game;
        ray.emscripten_set_main_loop(&emscriptenUpdate, 0, 1);
    } else {
        // Native game loop
        while (!ray.WindowShouldClose()) {
            if (build_options.static) {
                try game.update();
            } else {
                try hot.update(&game, allocator);
            }
        }
    }
}

var emscripten_game_ptr: ?*Game = null;

fn emscriptenUpdate() callconv(.C) void {
    Game.update(emscripten_game_ptr.?);
}
