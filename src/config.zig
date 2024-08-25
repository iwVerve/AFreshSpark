const ray = @import("raylib.zig");

pub const game_name = "game";

// INSTALL CONFIG

pub const install_dir_dynamic = "dynamic";
pub const install_dir_static = "static";

pub const asset_dir_name = "assets";

// Directories listed here get copied to the static build directory and embedded into the web build.
pub const install_dirs = &.{
    asset_dir_name,
};

// Hotreloading only. Set to null to disable.
pub const game_restart_key: ?c_int = ray.KEY_F2;
pub const game_reload_key: ?c_int = ray.KEY_F3;

// GAME CONFIG

pub const resolution = .{
    .width = 640,
    .height = 360,
};

pub const tile_size = 64;

pub const up_keys = .{ ray.KEY_UP, ray.KEY_W };
pub const right_keys = .{ ray.KEY_RIGHT, ray.KEY_D };
pub const down_keys = .{ ray.KEY_DOWN, ray.KEY_S };
pub const left_keys = .{ ray.KEY_LEFT, ray.KEY_A };
pub const restart_key = ray.KEY_R;
pub const confirm_keys = .{ ray.KEY_ENTER, ray.KEY_Z };
pub const close_keys = .{ray.KEY_ESCAPE};
