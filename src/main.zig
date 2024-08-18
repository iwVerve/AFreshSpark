/// Starts and runs the game loop, manages hot reloading.
/// Shouldn't run actual game logic.
const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const config = @import("config");

const ray = @import("raylib.zig");
const Game = @import("Game.zig");

const dll_name = config.dll_name ++ ".dll";
const temp_dll_name = config.dll_name ++ "-temp.dll";
var dll: std.DynLib = undefined;

var watcher_thread: std.Thread = undefined;
var change_detected = true;

var update_fn: if (config.static) void else *@TypeOf(Game.update) = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    if (!config.static) {
        const game_dir_path = try std.fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(game_dir_path);
        const game_dir = try std.fs.openDirAbsolute(game_dir_path, .{});

        // NOTE(verve): Not ideal, but dllWatcher wasn't behaving.
        try game_dir.setAsCwd();

        try hotOpen();
    }

    var game = try Game.init();

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
                if (change_detected) {
                    try hotReload();
                    try spawnWatcher();
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

    update_fn = dll.lookup(@TypeOf(update_fn), "update") orelse return error.FunctionNotFound;
}

fn hotClose() void {
    dll.close();
}

fn hotReload() !void {
    hotClose();
    try hotOpen();
}

fn spawnWatcher() !void {
    change_detected = false;
    watcher_thread = std.Thread.spawn(.{}, dllWatcher, .{}) catch unreachable;
    watcher_thread.detach();
}

fn dllWatcher() void {
    var dirname_path_space: std.os.windows.PathSpace = undefined;
    dirname_path_space.len = std.unicode.utf8ToUtf16Le(&dirname_path_space.data, "") catch unreachable;
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
        std.os.windows.FALSE,
        std.os.windows.FILE_NOTIFY_CHANGE_FILE_NAME | std.os.windows.FILE_NOTIFY_CHANGE_DIR_NAME |
            std.os.windows.FILE_NOTIFY_CHANGE_ATTRIBUTES | std.os.windows.FILE_NOTIFY_CHANGE_SIZE |
            std.os.windows.FILE_NOTIFY_CHANGE_LAST_WRITE | std.os.windows.FILE_NOTIFY_CHANGE_LAST_ACCESS |
            std.os.windows.FILE_NOTIFY_CHANGE_CREATION | std.os.windows.FILE_NOTIFY_CHANGE_SECURITY,
        &num_bytes,
        null,
        null,
    );
    change_detected = true;
}
