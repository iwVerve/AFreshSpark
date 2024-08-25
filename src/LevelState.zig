const std = @import("std");

const ray = @import("raylib.zig");
const TileMap = @import("TileMap.zig");
const Game = @import("Game.zig");
const Assets = @import("Assets.zig");
const config = @import("config.zig");
const MenuState = @import("MenuState.zig");
const levels = @import("levels.zig");
const util = @import("util.zig");

const Allocator = std.mem.Allocator;
const Direction = util.Direction;

const LevelState = @This();

const Transition = struct {
    const duration = 20;

    state: enum { wait, fade_in, fade_out } = .wait,
    time: usize = 0,
    direction: Direction = .right,

    pub fn start(self: *Transition, direction: Direction) void {
        self.time = 0;
        self.direction = direction;
        self.state = .fade_in;
    }

    pub fn update(self: *Transition, state: *LevelState) !void {
        switch (self.state) {
            .wait => {},
            .fade_in => {
                self.time += 1;
                if (self.time == duration) {
                    // Wow!
                    self.direction = switch (self.direction) {
                        .up => .down,
                        .right => .left,
                        .down => .up,
                        .left => .right,
                    };
                    self.state = .fade_out;
                    try state.nextLevel(state.game.allocator, &state.game.assets);
                }
            },
            .fade_out => {
                self.time -= 1;
                if (self.time == 0) {
                    self.state = .wait;
                }
            },
        }
    }

    pub fn draw(self: Transition, color: ray.Color) void {
        const progress = blk: {
            const f = @as(f32, @floatFromInt(self.time)) / @as(comptime_float, duration);
            const in = f * f;
            const out = 1 - (1 - f) * (1 - f);
            break :blk std.math.lerp(in, out, f);
        };
        var rectangle: ray.Rectangle = .{
            .x = 0,
            .y = 0,
            .width = config.resolution.width,
            .height = config.resolution.height,
        };
        if (self.direction == .up or self.direction == .down) {
            rectangle.height *= progress;
            if (self.direction == .up) {
                rectangle.y = config.resolution.height - rectangle.height;
            }
        } else {
            rectangle.width *= progress;
            if (self.direction == .left) {
                rectangle.x = config.resolution.width - rectangle.width;
            }
        }
        ray.DrawRectangleRec(rectangle, color);
    }
};

game: *Game,
tile_map: TileMap,
current_level: usize,
transition: Transition = .{},

pub fn init(game: *Game, level_index: usize) !LevelState {
    const prototype = &levels.levels[level_index];
    const tile_map = try TileMap.init(prototype, &game.assets, game.allocator);
    return .{
        .game = game,
        .tile_map = tile_map,
        .current_level = level_index,
    };
}

pub fn deinit(self: *LevelState) void {
    self.tile_map.deinit();
}

pub fn update(self: *LevelState) !void {
    inline for (config.close_keys) |key| {
        if (ray.IsKeyPressed(key)) {
            ray.PlaySound(self.game.assets.push);
            const menu = MenuState.init(self.game);
            self.game.state.deinit();
            self.game.state = .{ .menu = menu };
            return;
        }
    }

    try self.tile_map.update(self);
    try self.transition.update(self);
}

pub fn nextLevel(self: *LevelState, allocator: Allocator, assets: *Assets) !void {
    self.current_level += 1;
    if (self.current_level >= levels.levels.len) {
        return;
    }
    const prototype = &levels.levels[self.current_level];
    const tile_map = try TileMap.init(prototype, assets, allocator);
    self.tile_map.deinit();
    self.tile_map = tile_map;
}

pub fn draw(self: LevelState, game: Game) void {
    ray.ClearBackground(self.tile_map.prototype.colors.background);

    self.tile_map.draw(game);
    self.transition.draw(ray.BLACK);
}
