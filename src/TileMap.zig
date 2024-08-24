const std = @import("std");

const ray = @import("raylib.zig");
const Tile = @import("Tile.zig");
const config = @import("config.zig");
const Game = @import("Game.zig");
const Object = @import("Object.zig");
const Assets = @import("Assets.zig");
const util = @import("util.zig");
const Button = @import("Button.zig");

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

    pub const LineType = enum {
        horizontal,
        vertical,
        up_right,
        up_left,
        down_right,
        down_left,
    };

    pub const Line = struct {
        line_type: LineType,
        position: UVector2,

        pub fn draw(self: Line, assets: Assets, color: ray.Color) void {
            const texture = switch (self.line_type) {
                .horizontal => assets.connection_h,
                .vertical => assets.connection_v,
                .up_right => assets.connection_ur,
                .up_left => assets.connection_ul,
                .down_right => assets.connection_dr,
                .down_left => assets.connection_dl,
            };

            const position: ray.Vector2 = .{
                .x = config.tile_size * @as(f32, @floatFromInt(self.position.x)),
                .y = config.tile_size * @as(f32, @floatFromInt(self.position.y)),
            };

            ray.DrawTextureV(texture, position, color);
        }
    };

    pub const Connection = struct {
        a: UVector2,
        b: UVector2,
        lines: []const Line,
    };

    options: Options,
    camera: ray.Camera2D,
    tiles: []const []const Tile,
    objects: []const Object.Prototype,
    connections: []const Connection,
    buttons: []const Button.Prototype,
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
allocator: Allocator,
assets: *Assets,
objects: ArrayList(Object),
buttons: ArrayList(Button),

pub fn init(prototype: *const Prototype, assets: *Assets, allocator: Allocator) !TileMap {
    var objects = ArrayList(Object).init(allocator);
    errdefer objects.deinit();
    for (prototype.objects) |object_prototype| {
        const object = Object.init(&object_prototype, assets);
        try objects.append(object);
    }

    var buttons = ArrayList(Button).init(allocator);
    errdefer buttons.deinit();
    for (prototype.buttons) |button_prototype| {
        const door_prototype: Object.Prototype = .{
            .object_type = .door,
            .board_position = button_prototype.door,
        };
        const door = door_prototype.init(assets);
        try objects.append(door);

        const button: Button = .{
            .board_position = button_prototype.button,
            .door = objects.items.len - 1,
        };
        try buttons.append(button);
    }

    return .{
        .prototype = prototype,
        .allocator = allocator,
        .assets = assets,
        .objects = objects,
        .buttons = buttons,
    };
}

pub fn deinit(self: *TileMap) void {
    self.objects.deinit();
    self.buttons.deinit();
}

pub fn update(self: *TileMap) !void {
    if (ray.IsKeyPressed(config.restart_key)) {
        self.deinit();
        self.* = try TileMap.init(self.prototype, self.assets, self.allocator);
    }

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
    self.resolveButtons();
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

            const target = util.vec2Cast(UVector2, IVector2{
                .x = position.x + offset.x,
                .y = position.y + offset.y,
            }) orelse continue;
            const effective_target = self.getEffectivePosition(target) orelse continue;

            const target_objects = &.{
                self.getObjectAtPosition(target),
                self.getObjectAtPosition(effective_target),
            };

            inline for (target_objects) |target_object| {
                if (target_object != null and target_object.?.attempted_direction == null and target_object.?.movable) {
                    target_object.?.attempted_direction = object.attempted_direction;
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
            const target = util.vec2Cast(UVector2, .{
                .x = position.x + offset.x,
                .y = position.y + offset.y,
            }) orelse continue;
            const effective_target = self.getEffectivePosition(target) orelse unreachable;

            if (self.getObjectAtPosition(effective_target) != null) {
                continue;
            }

            const tile = self.getTile(effective_target) orelse continue;
            if (tile.wall) {
                continue;
            }

            if (target.x != effective_target.x or target.y != effective_target.y) {
                const offset_x = config.tile_size * (@as(f32, @floatFromInt(effective_target.x)) - @as(f32, @floatFromInt(target.x)));
                const offset_y = config.tile_size * (@as(f32, @floatFromInt(effective_target.y)) - @as(f32, @floatFromInt(target.y)));
                object.world_position.x += offset_x;
                object.world_position.y += offset_y;

                object.lerp_progress = 0;
                object.offset = .{
                    .x = -offset_x,
                    .y = -offset_y,
                };
            }
            object.board_position = util.vec2Cast(UVector2, effective_target) orelse unreachable;
            object.attempted_direction = null;
            updated = true;
        }
    }

    for (self.objects.items) |*object| {
        object.attempted_direction = null;
    }
}

fn resolveButtons(self: *TileMap) void {
    blk: for (self.buttons.items) |button| {
        const door = &self.objects.items[button.door];
        for (self.objects.items) |object| {
            if (util.vec2Eql(object.board_position, button.board_position)) {
                door.open = true;
                continue :blk;
            }
        }
        door.open = false;
    }
}

fn getEffectivePosition(self: TileMap, position: anytype) ?UVector2 {
    const u_position = util.vec2Cast(UVector2, position) orelse return null;

    for (self.prototype.connections) |connection| {
        if (u_position.x == connection.a.x and u_position.y == connection.a.y) {
            return connection.b;
        }
        if (u_position.x == connection.b.x and u_position.y == connection.b.y) {
            return connection.a;
        }
    }

    return u_position;
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
        if (object.open) {
            continue;
        }
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
    for (self.prototype.connections) |connection| {
        for (connection.lines) |line| {
            line.draw(game.assets, self.prototype.colors.foreground);
        }

        const ends = .{ connection.a, connection.b };
        inline for (ends) |end| {
            const position: ray.Vector2 = .{
                .x = config.tile_size * @as(f32, @floatFromInt(end.x)),
                .y = config.tile_size * @as(f32, @floatFromInt(end.y)),
            };
            ray.DrawTextureV(game.assets.connection_end, position, self.prototype.colors.foreground);
        }
    }
    for (self.prototype.buttons) |button| {
        for (button.lines) |line| {
            line.draw(game.assets, self.prototype.colors.foreground);
        }

        const position: ray.Vector2 = .{
            .x = config.tile_size * @as(f32, @floatFromInt(button.button.x)),
            .y = config.tile_size * @as(f32, @floatFromInt(button.button.y)),
        };
        ray.DrawTextureV(game.assets.button, position, self.prototype.colors.foreground);
    }

    self.drawObjectLayer(.default, self.prototype.colors.foreground);
    self.drawObjectLayer(.player, self.prototype.colors.foreground);
}

fn drawObjectLayer(self: TileMap, layer: Object.DrawLayer, color: ray.Color) void {
    for (self.objects.items) |object| {
        if (object.draw_layer == layer) {
            object.draw(color);
        }
    }
}
