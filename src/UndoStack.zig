const std = @import("std");

const Object = @import("Object.zig");
const util = @import("util.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const UVector2 = util.UVector2;

const UndoStack = @This();

pub const Move = struct {
    index: usize,
    from: UVector2,
};

allocator: Allocator,
stored_positions: []UVector2,
stack: ArrayList([]Move),

pub fn init(objects: ArrayList(Object), allocator: Allocator) !UndoStack {
    const stored_positions = try allocator.alloc(UVector2, objects.items.len);
    errdefer allocator.free(stored_positions);

    const stack = ArrayList([]Move).init(allocator);
    errdefer stack.deinit();

    return .{
        .allocator = allocator,
        .stored_positions = stored_positions,
        .stack = stack,
    };
}

pub fn deinit(self: *UndoStack) void {
    for (self.stack.items) |turn| {
        self.allocator.free(turn);
    }
    self.stack.deinit();
    self.allocator.free(self.stored_positions);
}

pub fn startTurn(self: *UndoStack, objects: ArrayList(Object)) void {
    for (self.stored_positions, objects.items) |*store, object| {
        store.* = object.board_position;
    }
}

pub fn endTurn(self: *UndoStack, objects: ArrayList(Object)) !void {
    var moves = ArrayList(Move).init(self.allocator);
    errdefer moves.deinit();

    for (self.stored_positions, objects.items, 0..) |store, object, index| {
        if (!util.vec2Eql(store, object.board_position)) {
            const move: Move = .{
                .index = index,
                .from = store,
            };
            try moves.append(move);
        }
    }

    if (moves.items.len > 0) {
        try self.stack.append(try moves.toOwnedSlice());
    } else {
        moves.deinit();
    }
}

pub fn undo(self: *UndoStack, objects: ArrayList(Object)) bool {
    const turn = self.stack.popOrNull() orelse return false;
    for (turn) |move| {
        const object = &objects.items[move.index];
        object.board_position = move.from;
    }

    self.allocator.free(turn);

    return true;
}
