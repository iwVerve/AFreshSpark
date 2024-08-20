const std = @import("std");
const Allocator = std.mem.Allocator;

const config = @import("config.zig");
const ray = @import("raylib.zig");
const Assets = @import("Assets.zig");

const Game = @This();

const center: ray.Vector2 = .{ .x = 320, .y = 180 };
const radius = 120;
const scale = 2;
const color: ray.Color = .{ .r = 240, .g = 120, .b = 40, .a = 255 };
const background_color: ray.Color = .{ .r = 60, .g = 100, .b = 240, .a = 255 };

allocator: Allocator,
assets: Assets = .{},
angle: f32 = 0,
position: ray.Vector2 = undefined,

pub fn init(self: *Game, init_window: bool) !void {
    if (init_window) {
        ray.InitWindow(config.resolution.width, config.resolution.height, config.game_name);
        ray.SetTargetFPS(60);
        ray.SetExitKey(0);
    }

    try self.assets.init();
}

// Exported functions can't return zig errors, wrap regular init function.
pub export fn initWrapper(self: *Game, init_window: bool) c_int {
    self.init(init_window) catch return 1;
    return 0;
}

pub fn deinit(game: *Game, deinit_window: bool) void {
    game.assets.deinit();

    if (deinit_window) {
        ray.CloseWindow();
    }
}

pub fn update(self: *Game) !void {
    const math = std.math;

    self.angle += 2;
    self.position = .{
        .x = center.x + radius * @cos(math.degreesToRadians(self.angle)),
        .y = center.y - radius * @sin(math.degreesToRadians(self.angle)),
    };

    try self.draw();
}

pub export fn updateWrapper(self: *Game) c_int {
    self.update() catch return 1;
    return 0;
}

fn draw(self: Game) !void {
    ray.BeginDrawing();
    defer ray.EndDrawing();

    ray.ClearBackground(background_color);

    const texture = self.assets.fox;
    const source: ray.Rectangle = .{
        .x = 0,
        .y = 0,
        .width = @floatFromInt(texture.width),
        .height = @floatFromInt(texture.height),
    };
    const destination: ray.Rectangle = .{
        .x = self.position.x - scale * @as(f32, @floatFromInt(texture.width)) / 2,
        .y = self.position.y - scale * @as(f32, @floatFromInt(texture.height)) / 2,
        .width = scale * @as(f32, @floatFromInt(texture.width)),
        .height = scale * @as(f32, @floatFromInt(texture.height)),
    };
    ray.DrawTexturePro(texture, source, destination, .{ .x = 0, .y = 0 }, 0, ray.WHITE);
}
