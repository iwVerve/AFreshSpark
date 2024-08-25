const util = @import("util.zig");
const TileMap = @import("TileMap.zig");
const Object = @import("Object.zig");

const UVector2 = util.UVector2;
const Line = TileMap.Prototype.Line;

pub const Prototype = struct {
    button: UVector2,
    door: UVector2,
    invert: bool,
    lines: []const Line,
};

board_position: UVector2,
door: usize,
