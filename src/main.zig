/// Starts and runs the game loop, manages hot reloading.
/// Shouldn't run actual game logic.
const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const config = @import("config");

const ray = @import("raylib.zig");
const Game = @import("Game.zig");

// Null to disable either key.
const restart_key: ?c_int = ray.KEY_F2;
const reload_key: ?c_int = ray.KEY_F3;

const game_path = "zig-out/dynamic/";
const dll_name = game_path ++ config.dll_name ++ ".dll";
const temp_dll_name = game_path ++ config.dll_name ++ "-temp.dll";
var dll: std.DynLib = undefined;

const dll_watch_path = blk: {
    var str: []const u8 = &.{};

    for (game_path) |char| {
        if (char == '/') {
            str = str ++ .{'\\'};
        } else {
            const array: []const u8 = &.{char};
            str = str ++ array;
        }
    }

    break :blk str;
};
var dll_watcher_thread: std.Thread = undefined;
var dll_change_detected = false;

const asset_watch_path = "assets";
var asset_watcher_thread: std.Thread = undefined;
var asset_change_detected = false;

var init_fn: if (config.static) void else *@TypeOf(Game.initWrapper) = undefined;
var update_fn: if (config.static) void else *@TypeOf(Game.update) = undefined;

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // const allocator = gpa.allocator();

    var game: Game = .{};
    if (config.static) {
        try game.init(true);
    } else {
        try hotOpen();
        if (init_fn(&game, true) != 0) return error.InitializationError;
        try spawnDLLWatcher();
        try spawnAssetWatcher();
    }
    defer game.deinit(true);

    if (builtin.target.isWasm()) {
        // Emscripten game loop
        emscripten_game_ptr = &game;
        ray.emscripten_set_main_loop(&emscriptenUpdate, 0, 1);
    } else {
        // Native game loop
        while (!ray.WindowShouldClose()) {
            if (config.static) {
                Game.update(&game);
            } else {
                if (reload_key != null and ray.IsKeyPressed(reload_key.?)) {
                    dll_change_detected = true;
                }

                if (dll_change_detected) {
                    try hotReload();
                    try spawnDLLWatcher();
                }

                if (asset_change_detected) {
                    game.assets.deinit();
                    game.assets.init();
                    try spawnAssetWatcher();
                }

                if (restart_key != null and ray.IsKeyPressed(restart_key.?)) {
                    game.deinit(false);
                    game = .{};
                    if (init_fn(&game, false) != 0) return error.InitializationError;
                }

                update_fn(&game);
            }
        }
    }
}

var emscripten_game_ptr: ?*Game = null;

fn emscriptenUpdate() callconv(.C) void {
    Game.update(emscripten_game_ptr.?);
}

fn hotOpen() !void {
    const dir = std.fs.cwd();
    try dir.copyFile(dll_name, dir, temp_dll_name, .{});
    dll = try std.DynLib.open(temp_dll_name);

    init_fn = dll.lookup(@TypeOf(init_fn), "initWrapper") orelse return error.FunctionNotFound;
    update_fn = dll.lookup(@TypeOf(update_fn), "update") orelse return error.FunctionNotFound;
}

fn hotClose() void {
    dll.close();
}

fn hotReload() !void {
    hotClose();
    try hotOpen();
}

fn spawnAssetWatcher() !void {
    asset_change_detected = false;
    asset_watcher_thread = std.Thread.spawn(.{}, watcher, .{ asset_watch_path, &asset_change_detected }) catch unreachable;
    asset_watcher_thread.detach();
}

fn spawnDLLWatcher() !void {
    dll_change_detected = false;
    dll_watcher_thread = std.Thread.spawn(.{}, watcher, .{ dll_watch_path, &dll_change_detected }) catch unreachable;
    dll_watcher_thread.detach();
}

fn watcher(dir_path: []const u8, out: *bool) void {
    var dirname_path_space: std.os.windows.PathSpace = undefined;
    dirname_path_space.len = std.unicode.utf8ToUtf16Le(&dirname_path_space.data, dir_path) catch unreachable;
    dirname_path_space.data[dirname_path_space.len] = 0;
    const dir_handle = std.os.windows.OpenFile(dirname_path_space.span(), .{
        .dir = std.fs.cwd().fd,
        .access_mask = std.os.windows.GENERIC_READ,
        .creation = std.os.windows.FILE_OPEN,
        .filter = .dir_only,
        .follow_symlinks = false,
    }) catch |err| {
        std.debug.print("Error in opening file: {any}\n", .{err});
        unreachable;
    };
    var event_buf: [4096]u8 align(@alignOf(std.os.windows.FILE_NOTIFY_INFORMATION)) = undefined;
    var num_bytes: u32 = 0;
    _ = std.os.windows.kernel32.ReadDirectoryChangesW(
        dir_handle,
        &event_buf,
        event_buf.len,
        std.os.windows.TRUE,
        std.os.windows.FILE_NOTIFY_CHANGE_FILE_NAME | std.os.windows.FILE_NOTIFY_CHANGE_DIR_NAME |
            std.os.windows.FILE_NOTIFY_CHANGE_ATTRIBUTES | std.os.windows.FILE_NOTIFY_CHANGE_SIZE |
            std.os.windows.FILE_NOTIFY_CHANGE_LAST_WRITE | std.os.windows.FILE_NOTIFY_CHANGE_LAST_ACCESS |
            std.os.windows.FILE_NOTIFY_CHANGE_CREATION | std.os.windows.FILE_NOTIFY_CHANGE_SECURITY,
        &num_bytes,
        null,
        null,
    );
    out.* = true;
}
