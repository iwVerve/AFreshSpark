const ray = @import("../raylib.zig");

pub const colors = .{
    .background = .{ .r = 239, .g = 40, .b = 206, .a = 255 },
    .foreground = .{ .r = 119, .g = 20, .b = 36, .a = 255 },
};
pub const exit = .{ .x = 0, .y = 0 };
pub const exit_direction = .right;

pub const tiles =
    \\#######
    \\##...##
    \\#.....#
    \\P.....#
    \\#.....#
    \\##...##
    \\#######
;
pub const connections = &.{};
pub const buttons = &.{};
