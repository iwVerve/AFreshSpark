# Zig Raylib Template
Personal minimal template for [raylib](https://github.com/raysan5/raylib) projects.
There is no set list of what I intend to include, I'm just unlikely to make something before needing it in practice first.
While this is made entirely for personal purposes, I am open to questions and suggestions if you somehow ended up here.

### Features
- Hotreloading

### Setup
Update to your raylib commit of choice:
`zig fetch https://github.com/raysan5/raylib/archive/<hash>.tar.gz --save=raylib`

### Usage
```bash
zig build [run] # Build for hotreloading
zig build [run] -Dstatic # Build standalone executable
zig build reload # Rebuild game dll, game will try to reload it
```

### Hotreloading
If we keep game state in the main process but keep the update function in a dll, we can swap out the update function without reseting state.
This means restarting is still needed if you change the game struct variables.

### TODO
- Look into other export platforms.
- Remove raylib.zig in anticipation of usingnamespace getting removed.
- Reload sometimes fails to get picked up by game, add manual reload key.

### References
- https://github.com/samhattangady/hotreload
