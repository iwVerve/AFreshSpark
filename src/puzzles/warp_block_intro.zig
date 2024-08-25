const ray = @import("../raylib.zig");

pub const colors = .{};
pub const exit = .{ .x = 8, .y = 2 };
pub const exit_direction = .right;

pub const tiles =
    \\#########
    \\#...#...#
    \\P...#.#..
    \\#...#..##
    \\#########
;
pub const connections = &.{
    \\.........
    \\.........
    \\..X-j....
    \\....L-X..
    \\.........
    ,
};
pub const buttons = &.{};
