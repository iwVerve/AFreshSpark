const std = @import("std");
const builtin = @import("builtin");

const ray = @import("raylib.zig");
const config = @import("config.zig");
const Game = @import("Game.zig");
const LevelState = @import("LevelState.zig");
const levels = @import("levels.zig");
const Assets = @import("Assets.zig");
const util = @import("util.zig");

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

const select_center: Vector2 = .{ .x = config.resolution.width / 2, .y = config.resolution.height / 2 };
const select_step = 40;
const select_font_size = 24;
const select_selected_text = ">    <";

const select_title_text = "Select level";
const select_title_center: Vector2 = .{ .x = config.resolution.width / 2, .y = config.resolution.height / 5 * 1 };
const select_title_font_size = 36;

const select_back_text = "Press Escape to return";
const select_back_center: Vector2 = .{ .x = config.resolution.width / 2, .y = config.resolution.height / 5 * 4 };
const select_back_font_size = 36;

const select_options = blk: {
    var out: []const struct { [:0]const u8, usize } = &.{};

    for (0..levels.levels.len - 1) |index| {
        var buffer: [3:0]u8 = undefined;
        const label = std.fmt.bufPrintZ(&buffer, "{:0>2}", .{index + 1}) catch @compileError("");
        const final: @TypeOf(buffer) = buffer;
        const final_label = final[0 .. label.len + 1];
        const entry = .{ final_label, index };
        out = out ++ .{entry};
    }

    break :blk out;
};

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

    pub fn select(self: MenuOption, state: *MenuState) !void {
        switch (self) {
            .start => {
                const level = try LevelState.init(state.game, 0);
                state.game.state.deinit();
                state.game.state = .{ .level = level };
            },
            .select => state.state = .select,
            .controls => state.state = .controls,
            .credits => state.state = .credits,
            .exit => state.game.running = false,
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

game: *Game,
state: MenuSubstate = .main,
title_pos: Vector2 = undefined,
select_offset: Vector2 = undefined,
selected_option: usize = 0,
selected_level: usize = 0,

pub fn init(game: *Game) MenuState {
    const font = @field(game.assets, font_name);

    const measure = ray.MeasureTextEx(font, title, title_font_size, 1);
    const title_pos_f = ray.Vector2Subtract(title_center, ray.Vector2Scale(measure, 0.5));
    const title_pos: Vector2 = .{ .x = @floor(title_pos_f.x), .y = @floor(title_pos_f.y) };

    const select_offset = ray.Vector2Scale(ray.Vector2Negate(ray.MeasureTextEx(font, select_text, options_font_size, 1)), 0.5);

    return .{
        .game = game,
        .title_pos = title_pos,
        .select_offset = select_offset,
    };
}

pub fn deinit(self: *MenuState) void {
    _ = self;
}

pub fn update(self: *MenuState) !void {
    switch (self.state) {
        .main => {
            if (!builtin.target.isWasm()) {
                inline for (config.close_keys) |key| {
                    if (ray.IsKeyPressed(key)) {
                        self.game.running = false;
                        return;
                    }
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
                const result = @mod(@as(isize, @intCast(self.selected_option)) + v_input, options.len);
                self.selected_option = @intCast(result);
            }

            inline for (config.confirm_keys) |key| {
                if (ray.IsKeyPressed(key)) {
                    const option = options[self.selected_option];
                    try option.select(self);
                    return;
                }
            }
        },
        .select => {
            inline for (config.close_keys) |key| {
                if (ray.IsKeyPressed(key)) {
                    self.state = .main;
                    return;
                }
            }

            var h_input: isize = 0;
            const h_dirs = .{
                .{ config.right_keys, 1 },
                .{ config.left_keys, -1 },
            };
            inline for (h_dirs) |h_dir| {
                const keys = h_dir[0];
                const dir = h_dir[1];
                inline for (keys) |key| {
                    if (ray.IsKeyPressed(key)) {
                        h_input += dir;
                    }
                }
            }
            if (h_input != 0) {
                const result = @mod(@as(isize, @intCast(self.selected_level)) + h_input, select_options.len);
                self.selected_level = @intCast(result);
            }

            inline for (config.confirm_keys) |key| {
                if (ray.IsKeyPressed(key)) {
                    const level = try LevelState.init(self.game, self.selected_level);
                    self.deinit();
                    self.game.state = .{ .level = level };
                    return;
                }
            }
        },
        .controls, .credits => {
            const all_keys = .{ config.confirm_keys, config.close_keys };
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
        .select => {
            const title_pos = ray.Vector2Subtract(
                select_title_center,
                ray.Vector2Scale(ray.MeasureTextEx(font, select_title_text, select_title_font_size, 1), 0.5),
            );
            ray.DrawTextEx(font, select_title_text, util.vec2Floor(title_pos), select_title_font_size, 1, text_color);

            const back_pos = ray.Vector2Subtract(
                select_back_center,
                ray.Vector2Scale(ray.MeasureTextEx(font, select_back_text, select_back_font_size, 1), 0.5),
            );
            ray.DrawTextEx(font, select_back_text, util.vec2Floor(back_pos), select_back_font_size, 1, text_color);

            var select_x = select_center.x - (select_options.len - 1) * select_step / 2;
            for (select_options, 0..) |select_option, index| {
                const label = select_option[0];

                const position = ray.Vector2Subtract(
                    .{ .x = select_x, .y = select_center.y },
                    ray.Vector2Scale(ray.MeasureTextEx(font, label, select_font_size, 1), 0.5),
                );
                ray.DrawTextEx(font, label, util.vec2Floor(position), select_font_size, 1, text_color);

                if (self.selected_level == index) {
                    const measure = ray.MeasureTextEx(font, select_selected_text, select_font_size, 1);
                    const select_position: Vector2 = .{
                        .x = @floor(select_x),
                        .y = @floor(select_center.y),
                    };
                    const origin = ray.Vector2Scale(measure, 0.5);
                    ray.DrawTextPro(font, select_selected_text, select_position, origin, 90, select_font_size, 1, text_color);
                }

                select_x += select_step;
            }
        },
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
