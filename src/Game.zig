const std = @import("std");

const ray = @import("raylib.zig");

const Game = @This();

const center: ray.Vector2 = .{ .x = 320, .y = 180 };
const radius = 120;
const size = 64;
const color: ray.Color = .{ .r = 240, .g = 120, .b = 40, .a = 255 };
const background_color: ray.Color = .{ .r = 60, .g = 100, .b = 240, .a = 255 };

angle: f32 = 0,
position: ray.Vector2 = undefined,

pub fn init() !Game {
    ray.InitWindow(640, 360, "Hello, world!");
    ray.SetTargetFPS(60);

    return .{};
}

pub fn deinit() void {
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

    const rectangle: ray.Rectangle = .{
        .x = self.position.x - size / 2,
        .y = self.position.y - size / 2,
        .width = size,
        .height = size,
    };
    ray.DrawRectangleRec(rectangle, color);
}
