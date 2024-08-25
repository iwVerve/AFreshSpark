const ray = @import("../raylib.zig");

pub const colors = .{
    .background = .{ .r = 239, .g = 206, .b = 40, .a = 255 },
    .foreground = .{ .r = 103, .g = 20, .b = 119, .a = 255 },
};
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
