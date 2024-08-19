Zig version: `0.14.0-dev.125+a016ca617`

# Zig Raylib Template
Personal minimal template for [raylib](https://github.com/raysan5/raylib)
projects.
There is no set list of what I intend to include, I'm just unlikely to make
something before needing it in practice first.
While this is made entirely for personal purposes, I am open to questions and
suggestions if you somehow ended up here.

## Features
- Code and asset hotreloading
- Web export

## Setup
Update to your raylib commit of choice:
```bash
zig fetch https://github.com/raysan5/raylib/archive/<hash>.tar.gz --save=raylib
```

## Usage
```bash
zig build [run] # Build for hotreloading
zig build [run] -Dstatic -Dstrip -Doptimize=Release-Fast # Build standalone executable
zig build -Dstrip -Doptimize=ReleaseSmall -Dtarget=wasm32-emscripten --sysroot "%EMSDK%/upstream/emscripten" # Build for web (Windows)
zig build reload # Rebuild game dll, game will try to reload it
```

### Container variables
All variables should be strictly part of the Game struct. Container variables
(globals) will break code hotreloading, as there will exist one copy of the
variable in the executable and one in the library.

## Hotreloading
If we keep game state in the main process but keep the update function in a
dll, we can swap out the update function without reseting state. This means
restarting is still needed if you change the game struct variable definitions.

In dynamic (hotreloadable) builds, F2 restarts the game and F3 forces the game
dll to reload. These keys are modifiable in main.zig. The init function is
reloadable as well.

Dynamic builds need to be launched from the project root directory, as they
need to see the asset directory.

## Web Export
Follow emscripten installation instructions from
[here](https://github.com/raysan5/raylib/wiki/Working-for-Web-(HTML5)#1-install-emscripten-toolchain).

To test web builds locally, run `py -m http.server 8080` in `zig-out/web/` or
`py -m http.server 8080 --directory zig-out/web/` in the root folder, then
visit `localhost:8080`.

Hotreloading is not supported web builds.

## TODO
- Remove raylib.zig in anticipation of usingnamespace getting removed.
- Include emsdk as build dependency.
- Hotreloading is very much Windows-only.

## References
- https://github.com/samhattangady/hotreload
- https://github.com/SimonLSchlee/zig15game
- https://github.com/raysan5/raylib/blob/master/src/minshell.html
