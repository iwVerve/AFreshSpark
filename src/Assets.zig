const ray = @import("raylib.zig");
const Texture2D = ray.Texture2D;

const Assets = @This();

const assets_dir = "assets/";

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
            .{ "fox", "fox.png" },
        },
    },
};

fox: Texture2D = undefined,

pub fn init(self: *Assets) !void {
    inline for (assets) |asset_data| {
        inline for (asset_data.assets) |asset| {
            const field_name = asset[0];
            const path = assets_dir ++ asset_data.directory ++ asset[1];
            const field = &@field(self, field_name);

            field.* = asset_data.load_fn(path);

            if (field.id <= 0) {
                return error.AssetLoadError;
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
