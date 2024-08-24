const std = @import("std");

const Allocator = std.mem.Allocator;

const ray = @import("raylib.zig");
const TileMap = @import("TileMap.zig");
const Game = @import("Game.zig");
const Assets = @import("Assets.zig");

const LevelState = @This();

tile_map: TileMap,

pub fn init(allocator: Allocator, prototype: *const TileMap.Prototype, assets: *Assets) !LevelState {
    const tile_map = try TileMap.init(prototype, assets, allocator);
    return .{
        .tile_map = tile_map,
    };
}

pub fn deinit(self: *LevelState) void {
    self.tile_map.deinit();
}

pub fn update(self: *LevelState) !void {
    try self.tile_map.update();
}

pub fn draw(self: LevelState, game: Game) void {
    ray.ClearBackground(self.tile_map.prototype.colors.background);

    self.tile_map.draw(game);
}
