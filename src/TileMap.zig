const std = @import("std");

const ray = @import("raylib.zig");
const Tile = @import("Tile.zig");
const config = @import("config.zig");
const Game = @import("Game.zig");
const Object = @import("Object.zig");
const Assets = @import("Assets.zig");
const util = @import("util.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Direction = util.Direction;
const UVector2 = util.UVector2;
const IVector2 = util.IVector2;

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
        const object = Object.init(&object_prototype, assets);
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

pub fn update(self: *TileMap) void {
    const input_directions = .{
        .{ config.up_keys, Direction.up },
        .{ config.right_keys, Direction.right },
        .{ config.down_keys, Direction.down },
        .{ config.left_keys, Direction.left },
    };

    inline for (input_directions) |input_direction| {
        inline for (input_direction[0]) |key| {
            if (ray.IsKeyPressed(key)) {
                self.takeTurn(input_direction[1]);
            }
        }
    }

    for (self.objects.items) |*object| {
        object.update();
    }
}

fn takeTurn(self: *TileMap, direction: Direction) void {
    self.snapObjects();
    self.setControlledObjects(direction);
    self.propagateAttemptedDirection();
    self.resolveMovement();
}

fn snapObjects(self: *TileMap) void {
    for (self.objects.items) |*object| {
        object.snap();
    }
}

fn setControlledObjects(self: *TileMap, direction: Direction) void {
    for (self.objects.items) |*object| {
        if (object.has_control) {
            object.attempted_direction = direction;
        }
    }
}

fn propagateAttemptedDirection(self: *TileMap) void {
    var updated = true;
    while (updated) {
        updated = false;
        for (self.objects.items) |*object| {
            if (object.attempted_direction == null) {
                continue;
            }
            const position = util.vec2Cast(IVector2, object.board_position) orelse continue;
            const offset = object.attempted_direction.?.toVector2(IVector2);
            const target: IVector2 = .{
                .x = position.x + offset.x,
                .y = position.y + offset.y,
            };
            for (self.objects.items) |*target_object| {
                if (target_object.attempted_direction != null) {
                    continue;
                }
                const target_object_position = util.vec2Cast(IVector2, target_object.board_position) orelse continue;
                if (target_object_position.x == target.x and target_object_position.y == target.y) {
                    target_object.attempted_direction = object.attempted_direction;
                    updated = true;
                }
            }
        }
    }
}

fn resolveMovement(self: *TileMap) void {
    var updated = true;
    while (updated) {
        updated = false;
        for (self.objects.items) |*object| {
            if (object.attempted_direction == null) {
                continue;
            }
            const position = util.vec2Cast(IVector2, object.board_position) orelse continue;
            const offset = object.attempted_direction.?.toVector2(IVector2);
            const target: IVector2 = .{
                .x = position.x + offset.x,
                .y = position.y + offset.y,
            };

            if (self.getObjectAtPosition(target) != null) {
                continue;
            }

            const tile = self.getTile(target) orelse continue;
            if (tile.wall) {
                continue;
            }

            object.board_position = util.vec2Cast(UVector2, target) orelse unreachable;
            object.attempted_direction = null;
            updated = true;
        }
    }

    for (self.objects.items) |*object| {
        object.attempted_direction = null;
    }
}

fn getTile(self: TileMap, position: anytype) ?Tile {
    if (position.x < 0 or position.y < 0) {
        return null;
    }
    if (position.x >= self.prototype.options.width or position.y >= self.prototype.options.height) {
        return null;
    }
    return self.prototype.tiles[@intCast(position.y)][@intCast(position.x)];
}

fn getObjectAtPosition(self: *TileMap, position: anytype) ?*Object {
    const cast = std.math.cast;

    for (self.objects.items) |*object| {
        if (cast(usize, position.x) orelse continue != object.board_position.x) {
            continue;
        }
        if (cast(usize, position.y) orelse continue != object.board_position.y) {
            continue;
        }

        return object;
    }

    return null;
}

pub fn draw(self: TileMap, game: Game) void {
    ray.BeginMode2D(self.prototype.camera);
    defer ray.EndMode2D();

    self.prototype.draw(game);
    for (self.objects.items) |object| {
        object.draw(self.prototype.colors.foreground);
    }
}
