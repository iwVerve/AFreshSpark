const std = @import("std");

const ray = @import("raylib.zig");
const Assets = @import("Assets.zig");

const Game = @This();

const center: ray.Vector2 = .{ .x = 320, .y = 180 };
const radius = 120;
const scale = 2;
const color: ray.Color = .{ .r = 240, .g = 120, .b = 40, .a = 255 };
const background_color: ray.Color = .{ .r = 60, .g = 100, .b = 240, .a = 255 };

assets: Assets = .{},
angle: f32 = 0,
position: ray.Vector2 = undefined,

pub fn init() !Game {
    ray.InitWindow(640, 360, "Hello, world!");
    ray.SetTargetFPS(60);

    var game: Game = .{};

    game.assets.init();

    return game;
}

pub fn deinit(game: *Game) void {
    game.assets.deinit();
    ray.CloseWindow();
}

pub export fn update(self: *Game) void {
    const math = std.math;

    self.angle += 2;
    self.position = .{
        .x = center.x + radius * @cos(math.degreesToRadians(self.angle)),
        .y = center.y - radius * @sin(math.degreesToRadians(self.angle)),
    };

    try self.draw();
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
