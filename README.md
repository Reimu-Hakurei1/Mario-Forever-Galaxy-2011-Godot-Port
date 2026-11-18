# Mario Forever Galaxy — Godot port

A faithful Godot 4 port of *Mario Forever Galaxy* (the 2011 GameMaker 8 release).
The GameMaker event code is machine-translated into GDScript and runs on a small
compatibility runtime that reproduces GM8 semantics (instances, events, collision
masks, rooms, paths, surfaces, sound).

## Running

Open the folder in Godot 4.7+ or run:

```
godot --path .
```

`scenes/game.tscn` is the main scene; `main.gd` boots the GameMaker runtime.

## Layout

| Path | Contents |
| --- | --- |
| `engine/` | Hand-written runtime: GM8 interpreter (`r.gd`), instance class, audio, surfaces, level waves, preview capture |
| `objects/<category>/` | One script per GameMaker object, named in English (`enemies/ufo_a.gd`, `effects/explosion_1.gd`, ...) |
| `game/` | Generated data: globals, constants, registry, every GameMaker script, room creation code |
| `stages/world_1..8/` | Editable per-level scenes (`level_04_asteroids.tscn`, ...) |
| `stages/` | Menu, map, shop, card game and cutscene scenes |
| `scenes/` | Main and viewer scenes |
| `data/` | Imported sprites, backgrounds, sound effects and music (`assets.json` maps GameMaker ids to files) |
| `images/` | Sprite and background PNGs |
| `tools/` | Headless probes used to validate gameplay, plus `object_names.json` |
| `addons/room_frame/` | Editor plugin that draws level scenes |

Object scripts are loaded through `game/registry.json`; a GameMaker object still
keeps its original name there (`name`), while `name_en` and `category` point at
the English file and folder. Scene source keys reference the original GameMaker
names, so those must not change.

## Conventions

- GDScript files are `snake_case`; classes are `PascalCase` (`R`, `G`, `K`, `GMVars`, `REG`, `P<n>`).
- Object scripts expose one static function per event: `ev_<main_event>_<sub_event>(S, A)`.
- `S` is the running instance, `A` the event argument array.
- Files under `game/` and `objects/` are produced by `gm2gd_emit.py` + `gm_postmin.py`
  from the decompiled GameMaker corpus (`gm8tools/galaxy_mfa`). Edit the generator,
  not the generated file; `tools/object_names.json` is the Polish-to-English glossary.
- Indent with tabs, UTF-8, LF.

## Save data

The game writes to the Godot user directory (`user://`, i.e.
`%APPDATA%\Godot\app_userdata\Mario Forever Galaxy Godot Port`). `settings.ini`
and `data/m/skipper` are seeded from the project on first run. Tests should point
`R.working_directory` at a copy under `_test_saves/` — never at the real saves.

## Validation

```
godot --headless --path . -s tools/probe.gd -- --frames=120      # boot, warns on missing assets
godot --headless --path . -s tools/flow_direct.gd -- --map=0 --lev=4 --room=2
godot --headless --path . -s tools/enemy_compare.gd -- --mode=scene --scene=res://stages/world_1/level_04_asteroids.tscn --frames=600
```

`tools/probe.gd` prints `WARNINGS {...}`; an empty object means a clean boot.
