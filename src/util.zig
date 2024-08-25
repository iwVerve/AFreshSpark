const std = @import("std");

pub const UVector2 = struct {
    x: usize,
    y: usize,
};

pub const IVector2 = struct {
    x: isize,
    y: isize,
};

pub fn vec2Eql(a: anytype, b: anytype) bool {
    if (@TypeOf(a) != @TypeOf(b)) {
        @compileError("vec2Eql passed arguents of different types.");
    }
    return (a.x == b.x and a.y == b.y);
}

pub fn vec2Cast(T: type, vector: anytype) ?T {
    const FieldType = @TypeOf(vector.x);
    const field_type_info = @typeInfo(FieldType);
    const t_type_info = @typeInfo(T);
    const TFieldType = t_type_info.Struct.fields[0].type;
    const t_field_type_info = @typeInfo(TFieldType);

    const field_int = field_type_info == .Int or field_type_info == .ComptimeInt;
    const t_int = t_field_type_info == .Int or t_field_type_info == .ComptimeInt;

    const cast = std.math.cast;

    if (field_int and t_int) {
        return .{
            .x = cast(TFieldType, vector.x) orelse return null,
            .y = cast(TFieldType, vector.y) orelse return null,
        };
    } else {
        @panic("Unimplemented");
    }
}

pub const Direction = enum {
    up,
    right,
    down,
    left,

    pub fn toVector2(self: Direction, T: type) T {
        return switch (self) {
            .up => .{ .x = 0, .y = -1 },
            .right => .{ .x = 1, .y = 0 },
            .down => .{ .x = 0, .y = 1 },
            .left => .{ .x = -1, .y = 0 },
        };
    }
};

pub fn vec2Floor(vec: anytype) @TypeOf(vec) {
    return .{
        .x = @floor(vec.x),
        .y = @floor(vec.y),
    };
}
