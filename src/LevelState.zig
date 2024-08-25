const std = @import("std");

const Allocator = std.mem.Allocator;

const ray = @import("raylib.zig");
const TileMap = @import("TileMap.zig");
const Game = @import("Game.zig");
const Assets = @import("Assets.zig");
const config = @import("config.zig");
const MenuState = @import("MenuState.zig");

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

pub fn update(self: *LevelState, game: *Game) !void {
    if (ray.IsKeyPressed(config.close_key)) {
        const menu = MenuState.init(game.assets);
        game.state.deinit();
        game.state = .{ .menu = menu };
        return;
    }

    try self.tile_map.update();
}

pub fn draw(self: LevelState, game: Game) void {
    ray.ClearBackground(self.tile_map.prototype.colors.background);

    self.tile_map.draw(game);
}
