const std = @import("std");

const ray = @import("raylib.zig");
const Tile = @import("Tile.zig");
const config = @import("config.zig");
const Game = @import("Game.zig");
const Object = @import("Object.zig");
const Assets = @import("Assets.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const TileMap = @This();

pub const Options = struct {
    width: usize,
    height: usize,
};

pub const Prototype = struct {
    pub const Colors = struct {
        background: ray.Color = .{ .r = 40, .g = 240, .b = 80, .a = 255 },
        foreground: ray.Color = .{ .r = 20, .g = 120, .b = 40, .a = 255 },
    };

    options: Options,
    camera: ray.Camera2D,
    tiles: []const []const Tile,
    objects: []const Object.Prototype,
    colors: Colors = .{},

    pub fn draw(self: *const Prototype, game: Game) void {
        for (self.tiles, 0..) |tile_row, tile_y| {
            for (tile_row, 0..) |tile, tile_x| {
                const x: c_int = @intCast(tile_x * config.tile_size);
                const y: c_int = @intCast(tile_y * config.tile_size);
                if (tile.wall) {
                    ray.DrawTexture(game.assets.wall, x, y, self.colors.foreground);
                }
            }
        }
    }
};

prototype: *const Prototype,
objects: ArrayList(Object),

pub fn init(prototype: *const Prototype, assets: Assets, allocator: Allocator) !TileMap {
    var objects = ArrayList(Object).init(allocator);
    for (prototype.objects) |object_prototype| {
        const object = Object.init(object_prototype, assets);
        try objects.append(object);
    }

    return .{
        .prototype = prototype,
        .objects = objects,
    };
}

pub fn deinit(self: *TileMap) void {
    self.objects.deinit();
}

pub fn draw(self: TileMap, game: Game) void {
    ray.BeginMode2D(self.prototype.camera);
    defer ray.EndMode2D();

    self.prototype.draw(game);
}
