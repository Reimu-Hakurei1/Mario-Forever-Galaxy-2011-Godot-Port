# Mario Forever Galaxy — Godot port

A faithful Godot 4 port of *Mario Forever Galaxy* (the 2011 GameMaker 8 release).
The game runs entirely on native GDScript — there is no GameMaker runtime. The
original decompiled corpus is kept outside the project for reference only.

## Running

Open the folder in Godot 4.7+ or run:

```
godot --path .
```

`native/ui/title.tscn` is the main scene.

## Layout

| Path | Contents |
| --- | --- |
| `native/` | The game — core state, entities (ship/enemies/bosses/bullets), levels (arena, castle, star map), UI scenes |
| `native/core/` | `NativeGame` (run state, saves, settings), `NativeLevelTable` (stage schedules), `NativeAssets` (sprite/sound/music manifest) |
| `native/entities/` | `NativeShip`, `NativeEnemy`, `NativeBoss`, `NativeBullet`, `NativeEnemyBullet`, `NativeWaveSpawner`, pickups, explosions |
| `native/levels/` | Arena, castle and star-map scenes |
| `native/ui/` | Title, options, shop, hero select, card game, ending, game over, intro |
| `levels/native/` | Stage/wave/map JSON data consumed by `NativeLevelTable` |
| `levels/enemy_editor_catalog.json` | Enemy-kind → sprite-layer catalog used by the level editor previews |
| `stages/world_1..8/` | Editable level scenes — static Godot layouts with enemy spawn previews (open in the 2D editor). Pressing play on one launches the matching native level via `editor/stage_launch.gd` |
| `editor/` | `@tool` editor scripts for the level scenes (spawn-rule previews, wave timing, bounds guide, snapshot capture) plus `stage_launch.gd`, the run-scene bridge into the native game |
| `gfx/` | All images — `sprites/`, `backgrounds/`, `cutscene/`, `map/`, `logo/`, `title/` |
| `music/` | Music tracks |
| `sfx/` | Sound effects |
| `data/assets.json` | Asset manifest mapping ids to `gfx/`/`sfx/`/`music/` files |
| `tools/` | Headless probes used to validate gameplay |

## Conventions

- GDScript files are `snake_case`; classes are `PascalCase` (`NativeGame`, `NativeEnemy`, ...).
- Indent with tabs, UTF-8, LF.

## Reference corpus

The original GameMaker decompilation (`game/`, `objects/`, `engine/`, room JSONs)
is **not** part of this project — it was moved to `../galaxy_reference/` (outside
`res://`) for fidelity tracing. Nothing in the game loads from it.

## Save data

The game writes to the Godot user directory (`user://`, i.e.
`%APPDATA%/Godot/app_userdata/Mario Forever Galaxy Godot Port/` on Windows).
