const std = @import("std");
const builtin = @import("builtin");

const config = @import("config.zig");
const ray = @import("raylib.zig");
const Assets = @import("Assets.zig");
const LevelState = @import("LevelState.zig");
const MenuState = @import("MenuState.zig");
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
    menu: MenuState,

    pub fn update(self: *State) !void {
        switch (self.*) {
            .menu => |*m| try m.update(),
            .level => |*l| try l.update(),
        }
    }

    pub fn deinit(self: *State) void {
        switch (self.*) {
            .menu => |*m| m.deinit(),
            .level => |*l| l.deinit(),
        }
    }

    pub fn draw(self: State) void {
        switch (self) {
            .menu => |m| m.draw(m.game.assets),
            .level => |l| l.draw(l.game.*),
        }
    }
};

allocator: Allocator,
assets: Assets = undefined,
running: bool = true,
state: State = undefined,
completed_levels: [levels.levels.len]bool = [_]bool{false} ** levels.levels.len,
volume: usize = 10,

pub fn init(self: *Game, init_window: bool) !void {
    if (init_window) {
        ray.InitWindow(config.resolution.width, config.resolution.height, config.game_name);
        ray.SetTargetFPS(60);
        ray.SetExitKey(0);
    }

    ray.InitAudioDevice();
    try self.assets.init();

    ray.SetSoundVolume(self.assets.warp, 0.7);

    const menu = MenuState.init(self);
    self.state = .{ .menu = menu };
}

// Exported functions can't return zig errors, wrap regular init function.
pub export fn initWrapper(self: *Game, init_window: bool) c_int {
    self.init(init_window) catch return 1;
    return 0;
}

pub fn deinit(self: *Game, deinit_window: bool) void {
    self.state.deinit();

    self.assets.deinit();
    ray.CloseAudioDevice();

    if (deinit_window) {
        ray.CloseWindow();
    }
}

pub fn update(self: *Game) !void {
    try self.state.update();
    try self.draw();
}

// Exported functions can't return zig errors, wrap regular update function.
pub export fn updateWrapper(self: *Game) c_int {
    self.update() catch return 1;
    return 0;
}

fn draw(self: Game) !void {
    ray.BeginDrawing();
    defer ray.EndDrawing();

    self.state.draw();
}
