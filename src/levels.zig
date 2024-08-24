const std = @import("std");

const ArrayList = std.ArrayList;

const ray = @import("raylib.zig");
const TileMap = @import("TileMap.zig");
const Tile = @import("Tile.zig");
const config = @import("config.zig");
const Object = @import("Object.zig");
const util = @import("util.zig");

const UVector2 = util.UVector2;

pub const test1 = parse(.{
    .tiles =
    \\#########
    \\#P......#
    \\#...X...#
    \\#.......#
    \\#...X...#
    \\#.......#
    \\#########
    ,
    .colors = .{},
    .connections = &.{
        \\.........
        \\...l-j...
        \\...|.|...
        \\..XJ.LX..
        \\.........
        \\.........
        \\.........
        ,
        \\.........
        \\.........
        \\.........
        \\.........
        \\.........
        \\...X.X...
        \\...L-J...
    },
});

const LevelDefition = struct {
    tiles: []const u8,
    colors: TileMap.Prototype.Colors = .{},
    connections: []const []const u8,
};

fn parse(comptime level: LevelDefition) TileMap.Prototype {
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
        var lines: []const TileMap.Prototype.Connection.Line = &.{};

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
                blk: {
                    const line_type: TileMap.Prototype.Connection.LineType = switch (char) {
                        '-' => .horizontal,
                        '|' => .vertical,
                        'L' => .up_right,
                        'J' => .up_left,
                        'l' => .down_right,
                        'j' => .down_left,
                        '.' => break :blk,
                        else => @compileError(std.fmt.comptimePrint("Invalid connection char {c} in string:\n{s}\n", .{ char, connection_string })),
                    };
                    const line: TileMap.Prototype.Connection.Line = .{
                        .position = position,
                        .line_type = line_type,
                    };
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

    const options: TileMap.Options = .{
        .width = width,
        .height = height,
    };

    const width_px: comptime_float = @floatFromInt(config.tile_size * width);
    const height_px: comptime_float = @floatFromInt(config.tile_size * height);
    const ratio = config.resolution.width / config.resolution.height;

    const camera_data = blk: {
        if (ratio * height_px > width_px) {
            const zoom = @as(f32, @floatFromInt(config.resolution.width)) / width_px;
            break :blk .{
                .target = .{
                    .x = 0,
                    .y = -(config.resolution.height / zoom - height_px) / 2,
                },
                .zoom = zoom,
            };
        } else {
            const zoom = @as(f32, @floatFromInt(config.resolution.height)) / height_px;
            break :blk .{
                .target = .{
                    .x = -(config.resolution.width / zoom - width_px) / 2,
                    .y = 0,
                },
                .zoom = zoom,
            };
        }
    };

    const camera: ray.Camera2D = .{
        .target = camera_data.target,
        .offset = .{ .x = 0, .y = 0 },
        .zoom = camera_data.zoom,
        .rotation = 0,
    };

    return .{
        .options = options,
        .tiles = tiles,
        .camera = camera,
        .objects = objects,
        .colors = level.colors,
        .connections = connections,
    };
}
