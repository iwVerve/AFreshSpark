const std = @import("std");
const builtin = @import("builtin");

const ray = @import("raylib.zig");
const config = @import("config.zig");
const Game = @import("Game.zig");
const LevelState = @import("LevelState.zig");
const levels = @import("levels.zig");
const Assets = @import("Assets.zig");

const Vector2 = ray.Vector2;

const MenuState = @This();

const background_color = .{ .r = 41, .g = 46, .b = 51, .a = 255 };
const font_name = "m5x7";

const text_color = ray.WHITE;

const title = config.game_name;
const title_font_size = 60;
const title_center: Vector2 = .{ .x = config.resolution.width / 2, .y = config.resolution.height / 6 };

const options_font_size = 36;
const options_center: Vector2 = .{ .x = config.resolution.width / 2, .y = config.resolution.height / 24 * 13 };
const options_step = 32;

const select_text = ">          <";

const MenuOption = enum {
    start,
    select,
    controls,
    credits,
    exit,

    pub fn getName(self: MenuOption) [*c]const u8 {
        return switch (self) {
            .start => "Start",
            .select => "Select",
            .controls => "Controls",
            .credits => "Credits",
            .exit => "Exit",
        };
    }
};

const options = blk: {
    var out: []const MenuOption = &.{
        .start,
        .select,
        .controls,
        .credits,
    };
    if (!builtin.target.isWasm()) {
        out = out ++ .{.exit};
    }
    break :blk out;
};

title_pos: Vector2 = undefined,
select_offset: Vector2 = undefined,
selected_option: usize = 0,

pub fn init(assets: Assets) MenuState {
    const font = @field(assets, font_name);

    const measure = ray.MeasureTextEx(font, title, title_font_size, 1);
    const title_pos_f = ray.Vector2Subtract(title_center, ray.Vector2Scale(measure, 0.5));
    const title_pos: Vector2 = .{ .x = @floor(title_pos_f.x), .y = @floor(title_pos_f.y) };

    const select_offset = ray.Vector2Scale(ray.Vector2Negate(ray.MeasureTextEx(font, select_text, options_font_size, 1)), 0.5);

    return .{
        .title_pos = title_pos,
        .select_offset = select_offset,
    };
}

pub fn deinit(self: *MenuState) void {
    _ = self;
}

pub fn update(self: *MenuState, game: *Game) !void {
    _ = self;
    if (ray.IsKeyPressed(config.close_key)) {
        game.running = false;
        return;
    }

    inline for (config.confirm_keys) |key| {
        if (ray.IsKeyPressed(key)) {
            const level = try LevelState.init(game.allocator, &levels.warp_exit, &game.assets);
            game.state.deinit();
            game.state = .{ .level = level };
            return;
        }
    }
}

pub fn draw(self: MenuState, assets: Assets) void {
    ray.ClearBackground(background_color);

    const font = @field(assets, font_name);
    ray.DrawTextEx(font, title, self.title_pos, title_font_size, 1, text_color);

    var option_y = options_center.y - (options.len - 1) * options_step / 2;
    inline for (options, 0..) |option, index| {
        const option_text = option.getName();
        const measure = ray.MeasureTextEx(font, option_text, options_font_size, 1);

        option_y += options_step;
        const position: Vector2 = .{
            .x = @floor(options_center.x - measure.x / 2),
            .y = @floor(option_y - measure.y / 2),
        };
        ray.DrawTextEx(font, option_text, position, options_font_size, 1, text_color);

        if (index == self.selected_option) {
            const select_position: Vector2 = .{
                .x = @floor(options_center.x + self.select_offset.x),
                .y = @floor(option_y + self.select_offset.y),
            };
            ray.DrawTextEx(font, select_text, select_position, options_font_size, 1, text_color);
        }
    }
}
