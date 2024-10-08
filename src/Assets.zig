const ray = @import("raylib.zig");
const config = @import("config.zig");

const Texture2D = ray.Texture2D;
const Font = ray.Font;
const Sound = ray.Sound;

const Assets = @This();

const assets_dir = config.asset_dir_name ++ "/";

fn AssetData(T: type) type {
    const AssetEntry = struct {
        []const u8, // field name
        []const u8, // asset path
    };

    return struct {
        load_fn: fn ([*c]const u8) callconv(.C) T,
        unload_fn: fn (T) callconv(.C) void,
        directory: []const u8,
        assets: []const AssetEntry,
    };
}

const assets = .{
    AssetData(Texture2D){
        .load_fn = ray.LoadTexture,
        .unload_fn = ray.UnloadTexture,
        .directory = "sprites/",
        .assets = &.{
            .{ "wall", "wall.png" },
            .{ "player", "player.png" },
            .{ "block", "block.png" },
            .{ "button", "button.png" },
            .{ "door", "door.png" },
            .{ "door_open", "door_open.png" },
            .{ "connection_end", "connection_end.png" },
            .{ "connection_h", "connection_h.png" },
            .{ "connection_v", "connection_v.png" },
            .{ "connection_ur", "connection_ur.png" },
            .{ "connection_ul", "connection_ul.png" },
            .{ "connection_dr", "connection_dr.png" },
            .{ "connection_dl", "connection_dl.png" },
        },
    },
    AssetData(Font){
        .load_fn = ray.LoadFont,
        .unload_fn = ray.UnloadFont,
        .directory = "fonts/",
        .assets = &.{
            .{ "m5x7", "m5x7.fnt" },
        },
    },
    AssetData(Sound){
        .load_fn = ray.LoadSound,
        .unload_fn = ray.UnloadSound,
        .directory = "sounds/",
        .assets = &.{
            .{ "step", "step.wav" },
            .{ "push", "push.wav" },
            .{ "warp", "warp.wav" },
            .{ "win", "win.wav" },
        },
    },
};

wall: Texture2D,
player: Texture2D,
block: Texture2D,
button: Texture2D,
door: Texture2D,
door_open: Texture2D,

connection_end: Texture2D,
connection_h: Texture2D,
connection_v: Texture2D,
connection_ur: Texture2D,
connection_ul: Texture2D,
connection_dr: Texture2D,
connection_dl: Texture2D,

m5x7: Font,

step: Sound,
push: Sound,
warp: Sound,
win: Sound,

pub fn init(self: *Assets) !void {
    inline for (assets) |asset_data| {
        inline for (asset_data.assets) |asset| {
            const field_name = asset[0];
            const path = assets_dir ++ asset_data.directory ++ asset[1];
            const field = &@field(self, field_name);

            field.* = asset_data.load_fn(path);

            if (@TypeOf(field.*) == Texture2D) {
                ray.SetTextureFilter(field.*, ray.TEXTURE_FILTER_BILINEAR);
                ray.SetTextureWrap(field.*, ray.TEXTURE_WRAP_CLAMP);

                if (field.id <= 0) {
                    return error.AssetLoadError;
                }
            }
            if (@TypeOf(field.*) == Font) {
                if (field.*.texture.id <= 0) {
                    return error.AssetLoadError;
                }
            }
        }
    }
}

pub fn deinit(self: *Assets) void {
    inline for (assets) |asset_data| {
        inline for (asset_data.assets) |asset| {
            const field_name = asset[0];
            const field = @field(self, field_name);

            asset_data.unload_fn(field);
        }
    }
}
