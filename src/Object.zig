const std = @import("std");

const util = @import("util.zig");
const ray = @import("raylib.zig");
const Game = @import("Game.zig");
const Assets = @import("Assets.zig");
const config = @import("config.zig");

const UVector2 = util.UVector2;

const Object = @This();

pub const ObjectType = enum {
    player,
    block,
};

pub const Prototype = struct {
    object_type: ObjectType,
    board_position: UVector2 = undefined,

    pub fn init(self: *const Prototype, assets: Assets) Object {
        const ObjectData = struct {
            texture: ray.Texture2D,
            has_control: bool,
        };

        const data: ObjectData = switch (self.object_type) {
            .player => .{
                .texture = assets.wall,
                .has_control = true,
            },
            .block => .{
                .texture = assets.wall,
                .has_control = false,
            },
        };

        return .{
            .prototype = self,
            .board_position = self.board_position,
            .world_position = getTargetWorldPosition(self.board_position),
            .texture = data.texture,
            .has_control = data.has_control,
        };
    }
};

prototype: *const Prototype,
board_position: UVector2,
world_position: ray.Vector2,
texture: ray.Texture2D,
has_control: bool,

pub fn init(prototype: *const Prototype, assets: Assets) Object {
    return prototype.init(assets);
}

pub fn update(self: *Object) void {
    self.lerpWorldPosition();
}

pub fn getTargetWorldPosition(vector: UVector2) ray.Vector2 {
    return .{
        .x = @floatFromInt(config.tile_size * vector.x),
        .y = @floatFromInt(config.tile_size * vector.y),
    };
}

fn lerpWorldPosition(self: *Object) void {
    const lerp = std.math.lerp;
    const lerp_factor = 0.3;

    const target = getTargetWorldPosition(self.board_position);
    self.world_position.x = lerp(self.world_position.x, target.x, lerp_factor);
    self.world_position.y = lerp(self.world_position.y, target.y, lerp_factor);
}

pub fn draw(self: Object, color: ray.Color) void {
    ray.DrawTextureV(self.texture, self.world_position, color);
}
