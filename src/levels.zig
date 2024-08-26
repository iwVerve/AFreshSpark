const std = @import("std");

const ArrayList = std.ArrayList;

const ray = @import("raylib.zig");
const TileMap = @import("TileMap.zig");
const Tile = @import("Tile.zig");
const config = @import("config.zig");
const Object = @import("Object.zig");
const util = @import("util.zig");
const Button = @import("Button.zig");

const UVector2 = util.UVector2;
const Direction = util.Direction;

const level_imports = .{
    @import("puzzles/intro.zig"),
    @import("puzzles/buttons_1.zig"),
    @import("puzzles/warp_intro_2.zig"),
    @import("puzzles/warp_intro.zig"),
    @import("puzzles/simple_pushies.zig"),
    @import("puzzles/simple_pushies_2.zig"),
    @import("puzzles/warp_block_intro.zig"),
    @import("puzzles/warp_block_intro_2.zig"),
    @import("puzzles/warp_exit.zig"),
    @import("puzzles/tight.zig"),
    @import("puzzles/final.zig"),
};

pub const levels = blk: {
    var out: []const TileMap.Prototype = &.{};

    for (level_imports) |level_import| {
        const level = parse(level_import);
        out = out ++ .{level};
    }

    break :blk out;
};

// Unused, parse expects type with these consts.
const LevelDefition = struct {
    tiles: []const u8,
    colors: TileMap.Prototype.Colors = .{},
    exit: UVector2,
    exit_direction: Direction,
    connections: []const []const u8,
    buttons: []const []const u8,
};

fn parse(comptime level: anytype) TileMap.Prototype {
    @setEvalBranchQuota(10000);
    var current_width: usize = 0;
    var first_row = true;
    var width: usize = 0;
    var height: usize = 0;

    var tiles: []const []const Tile = &.{};
    var tile_row: []const Tile = &.{};
    var objects: []const Object.Prototype = &.{};

    for (level.tiles) |char| {
        if (char == '\n') {
            if (first_row) {
                width = current_width;
                first_row = false;
            } else {
                if (current_width != width) {
                    @compileError(std.fmt.comptimePrint("Level definition not uniformally wide:\n{s}\n", .{level.tiles}));
                }
            }

            tiles = tiles ++ .{tile_row};
            tile_row = &.{};

            height += 1;
            current_width = 0;
        } else {
            const tile: Tile = if (char == '#') .{ .wall = true } else .{ .wall = false };

            blk: {
                const object: Object.Prototype = .{
                    .object_type = switch (char) {
                        'P' => .player,
                        'X' => .block,
                        else => break :blk,
                    },
                    .board_position = .{ .x = current_width, .y = height },
                };
                objects = objects ++ .{object};
            }

            tile_row = tile_row ++ .{tile};
            current_width += 1;
        }
    }
    tiles = tiles ++ .{tile_row};
    height += 1;

    var connections: []const TileMap.Prototype.Connection = &.{};
    for (level.connections) |connection_string| {
        var connection_width: usize = 0;
        var connection_height: usize = 0;
        var first_end: ?UVector2 = null;
        var second_end: ?UVector2 = null;
        var lines: []const TileMap.Prototype.Line = &.{};

        for (connection_string) |char| {
            if (char == '\n') {
                if (connection_width != width) {
                    @compileError(std.fmt.comptimePrint("Connection string isn't the correct width:\n{s}\n", .{connection_string}));
                }

                connection_width = 0;
                connection_height += 1;
            } else if (char == 'X') {
                const position: UVector2 = .{ .x = connection_width, .y = connection_height };
                if (first_end == null) {
                    first_end = position;
                } else if (second_end == null) {
                    second_end = position;
                } else @compileError(std.fmt.comptimePrint("Too many connection ends in string:\n{s}\n", .{connection_string}));

                connection_width += 1;
            } else {
                const position: UVector2 = .{ .x = connection_width, .y = connection_height };
                const maybe_line = parseLine(char, position);
                if (maybe_line) |line| {
                    lines = lines ++ .{line};
                }
                connection_width += 1;
            }
        }
        connection_height += 1;

        if (second_end == null) {
            @compileError(std.fmt.comptimePrint("Connection string doesn't contain two ends:\n{s}\n", .{connection_string}));
        }

        const connection: TileMap.Prototype.Connection = .{
            .a = first_end.?,
            .b = second_end.?,
            .lines = lines,
        };
        connections = connections ++ .{connection};
    }

    var buttons: []const Button.Prototype = &.{};
    for (level.buttons) |button_string| {
        var button_width: usize = 0;
        var button_height: usize = 0;

        var button_position: ?UVector2 = null;
        var door_position: ?UVector2 = null;
        var invert: bool = false;
        var lines: []const TileMap.Prototype.Line = &.{};

        for (button_string) |char| {
            if (char == '\n') {
                if (button_width != width) {
                    @compileError("Button string isn't right width.");
                }
                button_width = 0;
                button_height += 1;
            } else if (char == 'B') {
                if (button_position != null) {
                    @compileError("Button string has multiple buttons.");
                }
                button_position = .{ .x = button_width, .y = button_height };
                button_width += 1;
            } else if (char == 'D' or char == 'd') {
                if (door_position != null) {
                    @compileError("Button string has multiple doors.");
                }
                door_position = .{ .x = button_width, .y = button_height };
                button_width += 1;
                if (char == 'd') {
                    invert = true;
                }
            } else {
                const position: UVector2 = .{ .x = button_width, .y = button_height };
                const maybe_line = parseLine(char, position);
                if (maybe_line) |line| {
                    lines = lines ++ .{line};
                }
                button_width += 1;
            }
        }

        if (button_position == null) {
            @compileError("Button string is missing button.");
        }
        if (door_position == null) {
            @compileError("Button string is missing door.");
        }
        const button: Button.Prototype = .{
            .button = button_position.?,
            .door = door_position.?,
            .invert = invert,
            .lines = lines,
        };
        buttons = buttons ++ .{button};
    }

    const options: TileMap.Options = .{
        .width = width,
        .height = height,
    };

    const width_px: comptime_float = @floatFromInt(config.tile_size * width);
    const height_px: comptime_float = @floatFromInt(config.tile_size * height);
    const ratio = @as(comptime_float, config.resolution.width) / @as(comptime_float, config.resolution.height);

    const camera_data = blk: {
        if (ratio * height_px < width_px) {
            const zoom = @as(f32, @floatFromInt(config.resolution.width)) / width_px;
            break :blk .{
                .target = .{
                    .x = 0,
                    .y = -(config.resolution.height / zoom - height_px) / 2,
                },
                .zoom = zoom,
                .wide_camera = false,
            };
        } else {
            const zoom = @as(f32, @floatFromInt(config.resolution.height)) / height_px;
            break :blk .{
                .target = .{
                    .x = -(config.resolution.width / zoom - width_px) / 2,
                    .y = 0,
                },
                .zoom = zoom,
                .wide_camera = true,
            };
        }
    };

    const camera: ray.Camera2D = .{
        .target = camera_data.target,
        .offset = .{ .x = 0, .y = 0 },
        .zoom = camera_data.zoom,
        .rotation = 0,
    };

    const outside_rectangles = if (camera_data.wide_camera)
        &.{
            ray.Rectangle{
                .x = camera.target.x,
                .y = camera.target.y,
                .width = -camera.target.x,
                .height = height_px,
            },
            ray.Rectangle{
                .x = width_px,
                .y = camera.target.y,
                .width = -camera.target.x,
                .height = height_px,
            },
        }
    else
        &.{
            ray.Rectangle{
                .x = camera.target.x,
                .y = camera.target.y,
                .width = width_px,
                .height = -camera.target.y,
            },
            ray.Rectangle{
                .x = camera.target.x,
                .y = height_px,
                .width = width_px,
                .height = -camera.target.y,
            },
        };

    return .{
        .options = options,
        .exit = level.exit,
        .exit_direction = level.exit_direction,
        .tiles = tiles,
        .camera = camera,
        .objects = objects,
        .colors = level.colors,
        .connections = connections,
        .buttons = buttons,
        .outside_rectangles = outside_rectangles,
    };
}

fn parseLine(char: u8, position: UVector2) ?TileMap.Prototype.Line {
    const line_type: TileMap.Prototype.LineType = switch (char) {
        '-' => .horizontal,
        '|' => .vertical,
        'L' => .up_right,
        'J' => .up_left,
        'l' => .down_right,
        'j' => .down_left,
        '.' => return null,
        else => @compileError(std.fmt.comptimePrint("Invalid connection char {c}.", .{char})),
    };
    return .{
        .position = position,
        .line_type = line_type,
    };
}
