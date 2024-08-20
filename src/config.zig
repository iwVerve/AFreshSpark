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
pub const restart_key: ?c_int = ray.KEY_F2;
pub const reload_key: ?c_int = ray.KEY_F3;

// GAME CONFIG

pub const resolution = .{
    .width = 640,
    .height = 360,
};
