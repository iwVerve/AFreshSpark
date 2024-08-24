const std = @import("std");

const util = @import("util.zig");
const ray = @import("raylib.zig");
const Game = @import("Game.zig");
const Assets = @import("Assets.zig");
const config = @import("config.zig");

const UVector2 = util.UVector2;

const Object = @This();

pub const Prototype = struct {
    has_control: bool,
    board_position: UVector2 = undefined,
    // Weird hack but probably required one way or another without a static game var.
    texture_name: []const u8,
    texture: ray.Texture2D = undefined,

    pub fn init(prototype: Prototype, board_position: UVector2) Prototype {
        var copy = prototype;
        copy.board_position = board_position;
        return copy;
    }

    pub const prototypes = .{
        block,
        player,
    };

    pub const block: Prototype = .{
        .has_control = false,
        .texture_name = "wall",
    };

    pub const player: Prototype = .{
        .has_control = true,
        .texture_name = "wall",
    };
};

prototype: Prototype,
board_position: UVector2 = undefined,
world_position: ray.Vector2 = undefined,
texture: ray.Texture2D = undefined,

pub fn init(prototype: Prototype, assets: Assets) Object {
    const board_position = prototype.board_position;
    const world_position = getTargetWorldPosition(board_position);
    // const texture = @field(assets, prototype.texture_name);

    var texture: ray.Texture2D = undefined;
    // Weird!
    inline for (Prototype.prototypes) |prototype_compare| {
        if (std.mem.eql(u8, prototype.texture_name, prototype_compare.texture_name)) {
            texture = @field(assets, prototype_compare.texture_name);
        }
    }

    return .{
        .prototype = prototype,
        .board_position = board_position,
        .world_position = world_position,
        .texture = texture,
    };
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

pub fn draw(self: *Object, color: ray.Color) void {
    ray.DrawTextureV(self.prototype.texture, self.world_position, color);
}
