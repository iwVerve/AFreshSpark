const ray = @import("../raylib.zig");

pub const colors = .{};
pub const exit = .{ .x = 10, .y = 1 };
pub const exit_direction = .right;

pub const tiles =
    \\###########
    \\#.....##...
    \\#.....##.##
    \\P.X.X.#...#
    \\#..#..#...#
    \\###########
;
pub const connections = &.{
    \\...........
    \\...........
    \\...........
    \\...X----X..
    \\...........
    \\...........
    ,
};
pub const buttons = &.{};
