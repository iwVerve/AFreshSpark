const std = @import("std");

const ray = @import("raylib.zig");
const Tile = @import("Tile.zig");
const config = @import("config.zig");
const Game = @import("Game.zig");
const Object = @import("Object.zig");
const Assets = @import("Assets.zig");
const util = @import("util.zig");
const Button = @import("Button.zig");
const LevelState = @import("LevelState.zig");
const levels = @import("levels.zig");
const UndoStack = @import("UndoStack.zig");

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
    colors: Colors = .{},

    exit: UVector2,
    exit_direction: Direction,
    tiles: []const []const Tile,
    objects: []const Object.Prototype,
    connections: []const Connection,
    buttons: []const Button.Prototype,

    camera: ray.Camera2D,
    outside_rectangles: []const ray.Rectangle,

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
control: bool = true,
undo_stack: UndoStack,

player_moved: bool = undefined,
block_moved: bool = undefined,
something_warped: bool = undefined,
won: bool = undefined,

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

        var door = door_prototype.init(assets);
        if (button_prototype.invert) {
            door.invert_open = true;
        }
        try objects.append(door);

        const button: Button = .{
            .board_position = button_prototype.button,
            .door = objects.items.len - 1,
        };
        try buttons.append(button);
    }

    const undo_stack = try UndoStack.init(objects, allocator);

    var tile_map: TileMap = .{
        .prototype = prototype,
        .allocator = allocator,
        .assets = assets,
        .objects = objects,
        .buttons = buttons,
        .undo_stack = undo_stack,
    };
    tile_map.resolveButtons();

    return tile_map;
}

pub fn deinit(self: *TileMap) void {
    self.undo_stack.deinit();
    self.objects.deinit();
    self.buttons.deinit();
}

pub fn update(self: *TileMap, state: *LevelState) !void {
    if (self.control) {
        if (ray.IsKeyPressed(config.restart_key)) {
            ray.PlaySound(self.assets.push);
            self.deinit();
            self.* = try TileMap.init(self.prototype, self.assets, self.allocator);
        }

        inline for (config.undo_keys) |key| {
            if (ray.IsKeyPressed(key)) {
                const did_undo = self.undo_stack.undo(self.objects);
                if (did_undo) {
                    ray.PlaySound(self.assets.push);
                    self.snapObjects();
                    self.resolveButtons();
                }
            }
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
                    try self.takeTurn(input_direction[1], state);
                }
            }
        }
    }

    for (self.objects.items) |*object| {
        object.update();
    }
}

fn takeTurn(self: *TileMap, direction: Direction, state: *LevelState) !void {
    self.resetSound();
    self.snapObjects();
    self.undo_stack.startTurn(self.objects);

    self.setControlledObjects(direction);
    self.propagateAttemptedDirection();
    self.resolveMovement();
    self.resolveButtons();

    try self.undo_stack.endTurn(self.objects);

    if (self.checkWin()) {
        state.game.completed_levels[state.current_level] = true;
        self.won = true;
        if (state.current_level < levels.levels.len - 1) {
            self.control = false;
            state.transition.start(self.prototype.exit_direction);
        }
    }

    self.playSound();
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
            const effective_target = self.getEffectivePosition(target, object.attempted_direction.?) orelse continue;

            const target_positions = &.{
                target,
                effective_target,
            };

            inline for (target_positions) |target_position| {
                const target_object = self.getObjectAtPosition(target_position);
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
    var strict = true;
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
            const effective_target = self.getEffectivePosition(target, object.attempted_direction.?) orelse unreachable;

            const move_to = blk: {
                if (self.getObjectAtPosition(target) == null) {
                    if (self.getObjectAtPosition(effective_target) == null) {
                        const tile = self.getTile(effective_target) orelse continue;
                        if (!tile.wall) {
                            break :blk effective_target;
                        }
                    }
                    if (!strict) {
                        const tile = self.getTile(target) orelse continue;
                        if (!tile.wall) {
                            break :blk target;
                        }
                    }
                    continue;
                }
                continue;
            };

            const tile = self.getTile(move_to) orelse continue;
            if (tile.wall) {
                continue;
            }

            if (target.x != move_to.x or target.y != move_to.y) {
                const offset_x = config.tile_size * (@as(f32, @floatFromInt(move_to.x)) - @as(f32, @floatFromInt(target.x)));
                const offset_y = config.tile_size * (@as(f32, @floatFromInt(move_to.y)) - @as(f32, @floatFromInt(target.y)));
                object.world_position.x += offset_x;
                object.world_position.y += offset_y;

                object.lerp_progress = 0;
                object.offset = .{
                    .x = -offset_x,
                    .y = -offset_y,
                };
                self.something_warped = true;
            }
            object.board_position = util.vec2Cast(UVector2, move_to) orelse unreachable;
            object.attempted_direction = null;
            updated = true;
            strict = true;

            if (object.has_control) {
                self.player_moved = true;
            } else {
                self.block_moved = true;
            }
        }
        if (!updated and strict) {
            updated = true;
            strict = false;
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
            if (!object.charged) {
                continue;
            }
            if (util.vec2Eql(object.board_position, button.board_position)) {
                door.open = !door.invert_open;
                continue :blk;
            }
        }
        door.open = door.invert_open;
    }
}

fn checkWin(self: TileMap) bool {
    for (self.objects.items) |object| {
        if (!object.has_control) {
            continue;
        }
        if (util.vec2Eql(object.board_position, self.prototype.exit)) {
            return true;
        }
    }
    return false;
}

fn resetSound(self: *TileMap) void {
    self.player_moved = false;
    self.block_moved = false;
    self.something_warped = false;
    self.won = false;
}

fn playSound(self: TileMap) void {
    const assets = self.assets;
    if (self.won) {
        ray.PlaySound(assets.win);
        return;
    }
    if (self.something_warped) {
        ray.PlaySound(assets.warp);
    } else if (self.block_moved) {
        ray.PlaySound(assets.push);
    } else if (self.player_moved) {
        ray.PlaySound(assets.step);
    }
}

fn getEffectivePosition(self: TileMap, position: anytype, direction: util.Direction) ?UVector2 {
    const u_position = util.vec2Cast(UVector2, position) orelse return null;
    const offset = direction.toVector2(IVector2);

    for (self.prototype.connections) |connection| {
        const target = if (u_position.x == connection.a.x and u_position.y == connection.a.y)
            connection.b
        else if (u_position.x == connection.b.x and u_position.y == connection.b.y)
            connection.a
        else
            continue;
        const i_target = util.vec2Cast(IVector2, target) orelse return null;
        const result: IVector2 = .{
            .x = i_target.x + offset.x,
            .y = i_target.y + offset.y,
        };
        return util.vec2Cast(UVector2, result) orelse null;
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
    {
        ray.BeginMode2D(self.prototype.camera);
        defer ray.EndMode2D();

        self.prototype.draw(game);

        const things_with_lines = .{
            self.prototype.connections,
            self.prototype.buttons,
        };
        inline for (things_with_lines) |group| {
            for (group) |thing| {
                for (thing.lines) |line| {
                    line.draw(game.assets, self.prototype.colors.foreground);
                }
            }
        }

        for (self.prototype.connections) |connection| {
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
            const position: ray.Vector2 = .{
                .x = config.tile_size * @as(f32, @floatFromInt(button.button.x)),
                .y = config.tile_size * @as(f32, @floatFromInt(button.button.y)),
            };
            ray.DrawTextureV(game.assets.button, position, self.prototype.colors.foreground);
        }

        self.drawObjectLayer(.default, self.prototype.colors.foreground);

        self.drawObjectLayer(.player, self.prototype.colors.foreground);

        for (self.prototype.outside_rectangles) |rectangle| {
            ray.DrawRectangleRec(rectangle, self.prototype.colors.foreground);
        }
    }

    if (game.state.level.current_level == levels.levels.len - 1) {
        const win_text =
            \\Thanks for
            \\  playing!
        ;
        const win_size = 36;
        const win_font = game.assets.m5x7;
        const win_measure = ray.MeasureTextEx(win_font, win_text, win_size, 1);
        const win_center: ray.Vector2 = .{
            .x = config.resolution.width / 2,
            .y = config.resolution.height / 2,
        };
        const win_position = ray.Vector2Subtract(win_center, ray.Vector2Scale(win_measure, 0.5));
        ray.DrawTextEx(win_font, win_text, win_position, win_size, 1, ray.BLACK);
    }
}

fn drawObjectLayer(self: TileMap, layer: Object.DrawLayer, color: ray.Color) void {
    for (self.objects.items) |object| {
        if (object.draw_layer == layer) {
            object.draw(color);
        }
    }
}
