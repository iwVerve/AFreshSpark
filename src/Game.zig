const std = @import("std");
const builtin = @import("builtin");

const config = @import("config.zig");
const ray = @import("raylib.zig");
const Assets = @import("Assets.zig");
const LevelState = @import("LevelState.zig");
const levels = @import("levels.zig");

const Game = @This();

const Allocator = std.mem.Allocator;

const center: ray.Vector2 = .{ .x = 320, .y = 180 };
const radius = 120;
const scale = 2;
const color: ray.Color = .{ .r = 240, .g = 120, .b = 40, .a = 255 };
const background_color: ray.Color = .{ .r = 60, .g = 100, .b = 240, .a = 255 };

const State = union(enum) {
    level: LevelState,

    pub fn deinit(self: *State) void {
        switch (self.*) {
            .level => |*l| l.deinit(),
        }
    }
};

allocator: Allocator,
assets: Assets = undefined,
state: State = undefined,

pub fn init(self: *Game, init_window: bool) !void {
    if (init_window) {
        ray.InitWindow(config.resolution.width, config.resolution.height, config.game_name);
        ray.SetTargetFPS(60);
        ray.SetExitKey(0);
    }

    try self.assets.init();

    const level = try LevelState.init(self.allocator, &levels.test1, self.assets);
    self.state = .{ .level = level };
}

// Exported functions can't return zig errors, wrap regular init function.
pub export fn initWrapper(self: *Game, init_window: bool) c_int {
    self.init(init_window) catch return 1;
    return 0;
}

pub fn deinit(self: *Game, deinit_window: bool) void {
    self.state.deinit();

    self.assets.deinit();

    if (deinit_window) {
        ray.CloseWindow();
    }
}

pub fn update(self: *Game) void {
    switch (self.state) {
        .level => |*l| l.update(),
    }

    try self.draw();
}

// Exported functions can't return zig errors, wrap regular update function.
pub export fn updateWrapper(self: *Game) c_int {
    self.update(); // catch return 1;
    return 0;
}

fn draw(self: Game) !void {
    ray.BeginDrawing();
    defer ray.EndDrawing();

    switch (self.state) {
        .level => |l| l.draw(self),
    }
}
