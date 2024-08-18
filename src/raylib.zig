const builtin = @import("builtin");

pub usingnamespace @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");

    if (builtin.target.isWasm()) {
        @cInclude("emscripten.h");
    }
});
