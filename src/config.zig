pub const game_name = "game";

// INSTALL CONFIG

pub const install_dir_dynamic = "dynamic";
pub const install_dir_static = "static";

pub const asset_dir_name = "assets";

// Directories listed here get copied to the static build directory and embedded into the web build.
pub const install_dirs = &.{
    asset_dir_name,
};

// GAME CONFIG

pub const resolution = .{
    .width = 640,
    .height = 360,
};
