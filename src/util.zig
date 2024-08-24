const std = @import("std");

pub const UVector2 = struct {
    x: usize,
    y: usize,
};

pub const IVector2 = struct {
    x: isize,
    y: isize,
};

pub fn vec2Cast(T: type, vector: anytype) T {
    const vector_type_info = @typeInfo(@TypeOf(vector.x));
    const t_type_info = @typeInfo(T);

    const both_int = vector_type_info == .Int and t_type_info == .Int;
    const both_comptime_int = vector_type_info == .ComptimeInt and t_type_info == .ComptimeInt;

    if (both_int or both_comptime_int) {
        return .{
            .x = @intCast(vector.x),
            .y = @intCast(vector.y),
        };
    } else {
        @panic("Unimplemented");
    }
}
