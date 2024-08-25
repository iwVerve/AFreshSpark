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

// MAIN

const title = config.game_name;
const title_font_size = 72;
const title_center: Vector2 = .{ .x = config.resolution.width / 2, .y = config.resolution.height / 6 };

const options_font_size = 36;
const options_center: Vector2 = .{ .x = config.resolution.width / 2, .y = config.resolution.height / 24 * 13 };
const options_step = 36;

const select_text = ">          <";

// SELECT

// CONTROLS

const controls_font_size = 36;
const controls_step = 36;
const controls_center: Vector2 = .{ .x = config.resolution.width / 2, .y = config.resolution.height / 2 };

const controls_text =
    \\Arrows keys / WASD - Move
    \\Z / Enter - Confirm
    \\R - Restart
    \\Escape - Back to menu / Close
    \\
    \\Press confirm to return
;

const controls_lines = blk: {
    var lines: []const [*c]const u8 = &.{};
    var it = std.mem.splitScalar(u8, controls_text, '\n');
    while (it.next()) |line| {
        const c_line = line ++ .{0};
        lines = lines ++ .{c_line};
    }
    break :blk lines;
};

// CREDITS

const credits_font_size = 36;
const credits_step = 36;
const credits_center: Vector2 = .{ .x = config.resolution.width / 2, .y = config.resolution.height / 2 };

const credits_text =
    \\Made by iwVerve
    \\for Swap Jam 3
    \\
    \\Made using zig and raylib
    \\
    \\m5x7 font by Daniel Linssen
    \\
    \\Press confirm to continue
;

const credits_lines = blk: {
    var lines: []const [*c]const u8 = &.{};
    var it = std.mem.splitScalar(u8, credits_text, '\n');
    while (it.next()) |line| {
        const c_line = line ++ .{0};
        lines = lines ++ .{c_line};
    }
    break :blk lines;
};

const MenuSubstate = enum {
    main,
    select,
    controls,
    credits,
};

const MenuOption = enum {
    start,
    select,
    controls,
    credits,
    exit,

    pub fn select(self: MenuOption, state: *MenuState, game: *Game) !void {
        switch (self) {
            .start => {
                const level = try LevelState.init(game.allocator, &levels.warp_exit, &game.assets);
                game.state.deinit();
                game.state = .{ .level = level };
            },
            .select => {},
            .controls => state.state = .controls,
            .credits => state.state = .credits,
            .exit => game.running = false,
        }
    }

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

state: MenuSubstate = .main,
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
    switch (self.state) {
        .main => {
            if (!builtin.target.isWasm()) {
                if (ray.IsKeyPressed(config.close_key)) {
                    game.running = false;
                    return;
                }
            }

            var v_input: isize = 0;
            const v_dirs = .{
                .{ config.up_keys, -1 },
                .{ config.down_keys, 1 },
            };
            inline for (v_dirs) |v_dir| {
                const keys = v_dir[0];
                const dir = v_dir[1];
                inline for (keys) |key| {
                    if (ray.IsKeyPressed(key)) {
                        v_input += dir;
                    }
                }
            }
            if (v_input != 0) {
                var result = @as(isize, @intCast(self.selected_option)) + v_input;
                while (result < 0) {
                    result += options.len;
                }
                while (result >= options.len) {
                    result -= options.len;
                }
                self.selected_option = @intCast(result);
            }

            inline for (config.confirm_keys) |key| {
                if (ray.IsKeyPressed(key)) {
                    const option = options[self.selected_option];
                    try option.select(self, game);
                    return;
                }
            }
        },
        .select => {},
        .controls, .credits => {
            const all_keys = .{ config.confirm_keys, .{config.close_key} };
            inline for (all_keys) |keys| {
                inline for (keys) |key| {
                    if (ray.IsKeyPressed(key)) {
                        self.state = .main;
                        return;
                    }
                }
            }
        },
    }
}

pub fn draw(self: MenuState, assets: Assets) void {
    ray.ClearBackground(background_color);

    const font = @field(assets, font_name);

    switch (self.state) {
        .main => {
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
        },
        .select => {},
        .controls => {
            var line_y = controls_center.y - (controls_lines.len - 1) * controls_step / 2;
            inline for (controls_lines) |line| {
                const measure = ray.MeasureTextEx(font, line, controls_font_size, 1);
                const position: Vector2 = .{
                    .x = @floor(controls_center.x - measure.x / 2),
                    .y = @floor(line_y - measure.y / 2),
                };
                ray.DrawTextEx(font, line, position, controls_font_size, 1, text_color);

                line_y += controls_step;
            }
        },
        .credits => {
            var line_y = credits_center.y - (credits_lines.len - 1) * credits_step / 2;
            inline for (credits_lines) |line| {
                const measure = ray.MeasureTextEx(font, line, credits_font_size, 1);
                const position: Vector2 = .{
                    .x = @floor(credits_center.x - measure.x / 2),
                    .y = @floor(line_y - measure.y / 2),
                };
                ray.DrawTextEx(font, line, position, credits_font_size, 1, text_color);

                line_y += credits_step;
            }
        },
    }
}
