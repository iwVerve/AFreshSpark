const ray = @import("../raylib.zig");

pub const colors = .{
    .background = .{ .r = 113, .g = 255, .b = 43, .a = 255 },
    .foreground = .{ .r = 32, .g = 59, .b = 193, .a = 255 },
};
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
