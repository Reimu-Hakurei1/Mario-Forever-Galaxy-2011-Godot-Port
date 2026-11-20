# Mario Forever Galaxy — Godot Port

A faithful Godot 4 port of **Mario Forever Galaxy** (the 2011 GameMaker 8 fan game).
Every room, object, enemy, boss, cutscene, minigame, menu, and save mechanic from
the original is preserved — the GameMaker event code is machine-translated into
GDScript and runs on a custom compatibility runtime that reproduces GM8 semantics
(instances, events, collision masks, rooms, paths, surfaces, sound).

## Features

- **Complete game flow** — title screen, hero select, intro/story rooms, world map,
  shops, card-game minigame, all 8 worlds, bonus stages, and the ending sequence.
- **Faithful mechanics** — weapons, power-ups, enemies, bosses, formations, waves,
  and room creation code all behave as authored in the original.
- **Editable levels** — every stage is a real `.tscn` scene you can open in the
  Godot editor: backgrounds, placed objects, wave tables, spawn rules, and
  formation slots are all nodes you can move and tweak.
- **Performance** — fixed-timestep simulation decoupled from render FPS, draw
  command record/replay, off-screen culling, spatial-hash collisions, and cached
  event handlers keep heavy fights smooth.
- **Cutscene fast-forward** — hold the fire button during world-ending cutscenes
  to play them at 2× speed.
- **Options** — VSync, FPS limit (30/60/120), volume, and key rebinding.

## Running

Requires **Godot 4.7+** (developed on 4.7.2 stable, Compatibility renderer).

```
godot --path .
```

Or open the folder in the Godot editor and press **F5** / **F6**. `scenes/game.tscn`
is the main scene; `main.gd` boots the GameMaker runtime, loads settings, and
drives the title → intro → map → level flow.

## Controls

Default bindings (rebindable in the title-screen options menu):

| Action | Key |
| --- | --- |
| Move | Arrow keys / WASD |
| Fire | Shift |
| Bomb | X |
| Pause | P |
| Fast-forward cutscene | Hold fire during cutscenes |

## How a level is built

Each playable stage is a scene like `stages/world_1/level_04_asteroids.tscn`.
Opening one in the editor shows the full level as nodes:

```
level_04_asteroids (Node2D)
├── Camera2D                     # view limits = room bounds (1024×768)
├── Bg0_background0, Bg1_...     # scrolling background layers (z-ordered)
├── Objects_-10000000            # static/decor instances, sorted by GM depth
├── Objects_-1000000
├── Objects_0                    # dynamic objects (player, enemies, items)
│   └── o_bonusho_2              # placed instance + editor marker/label
├── Waves                        # the wave/spawn director (see below)
│   ├── TopSpawnZone/Center/Bottom  # visible spawn-area guides
│   ├── Timing                   # numeric tables read by the original scripts
│   │   └── Level_Start/...      #   lev, pozd, levtime, sekwencus, kamik,
│   │                             #   perioder, sila_wrogow, spawn rate,
│   │                             #   enemy budget, timed events, formations
│   └── Enemies                  # spawn rules (one node per authored spawn)
└── LevelBoundsGuide             # draws the playable bounds rectangle
```

### Scene metadata

The root node carries the room identity in metadata:

- `gm_room` — GameMaker room name (`level_0000`)
- `gm_map`, `gm_lev` — world map index and level index
- `gm_minigame` — non-zero for minigame rooms
- `gm_label` — display name shown on the map ("ASTEROIDS")

`editor/stage_launch.gd` reads these when you run a stage scene directly (F6):
it sets `R.pending_stage_room/map/lev` and hands off to `scenes/game.tscn`, so a
stage scene always boots the real game flow into that exact room.

### The Waves system

GameMaker levels don't place most enemies statically — a controller object
(`o_perioder_*`) reads timing tables and spawns enemies over the level's duration.
The `Waves` node mirrors that data as editable nodes:

- **`Waves/Timing/*`** — scalar table entries (`level_wave_setting.gd`). Each node
  stores `table`, `stage`, `first_index`/`last_index` (the row range it applies
  to), `value`, and `source_expression`/`source_key` pointing back to the exact
  line of decompiled GML it came from. Examples: kamikaze attack waves, spawn
  rate, enemy budget, arrival sequences, formation slots.
- **`Waves/Enemies/*`** — spawn rules (`level_spawn_rule.gd`). Each node has an
  `object_index`, optional `match_enemy_kind`, a `position` you can drag to move
  the spawn/formation target, and `preview_layers` so the editor shows what will
  appear. The `source_description` explains which original script action it
  controls.
- **Spawn zones** — the red/green/blue rectangles at the top of `Waves` mark the
  screen regions enemies enter from.

At runtime `engine/level_wave_runtime.gd` binds these nodes back into the
GameMaker variable tables the translated scripts read, so editing a node changes
actual gameplay — not just the preview.

### Source data

`levels/*.json` holds the raw imported room data (instances, tiles, creation
code, views) that the `.tscn` scenes were generated from, and `levels/index.json`
maps every room to its scene + data file. `game/registry.json` maps every
GameMaker object index to its English script path.

### Custom level editor

`editor/level_editor.tscn` is a standalone scene for building your own levels:

```
godot --path . editor/level_editor.tscn
```

- Pick a **base stage** — it supplies the wave timeline, music, and win
  condition — or check **Blank level** to start from an empty timeline.
- Choose a **background** and scroll speed; drag the **green marker** to set
  the player start position.
- Pick an enemy type, press **Place mode**, and click the canvas to add timed
  spawns. Each spawn has a start period, count, interval, arrival sequence and
  target — all editable in the properties panel or by dragging its marker.
- **Timing rows** override the wave tables (`num`, `perioder`, `kamik`, ...)
  for the base stage; **Add timing row** inserts a new one.
- **Save** writes `stages/custom/<name>.tscn`, registers the room in
  `game/rooms.json` / `game/registry.json`, and adds it to `levels/index.json`.
- **Play** launches the saved level straight into the game.
- **Open** reloads any previously saved custom level for further editing.

Custom levels reuse the same `Waves` node format as the built-in stages, so
they run through the exact same runtime path (`engine/level_wave_runtime.gd`).

## Repository layout

| Path | Contents |
| --- | --- |
| `engine/` | Hand-written compatibility runtime: `r.gd` (GM8 interpreter), `gm_instance.gd`, wave runtime, audio, surfaces |
| `objects/<category>/` | One script per GameMaker object, named in English (`enemies/ufo_a.gd`, `effects/explosion_1.gd`, ...) |
| `game/` | Generated data: globals, constants, registry, every GameMaker script body, room creation code |
| `stages/` | All room scenes — `world_1..8/` levels plus map, shop, card game, cutscene scenes, and `custom/` user-made levels |
| `levels/` | Imported room JSON + `index.json` room catalog |
| `data/` | `assets.json` mapping GameMaker sprite/sound ids to files |
| `gfx/`, `music/`, `sfx/` | Extracted sprites, backgrounds, music, and sound effects |
| `images/` | Additional sprite/background PNGs |
| `native/` | Early experimental native-GDScript port (kept for reference; the shipping game uses the `engine/` runtime) |
| `editor/` | Editor-only helpers: `stage_launch.gd` (boot stage scenes), `level_editor.*` + `level_view.gd` + `marker_ring.gd` (custom level editor) |
| `tools/` | Headless probes and validation scripts |
| `addons/room_frame/` | Editor plugin that draws level scenes |

## How the runtime works

- Object scripts expose one static function per GameMaker event:
  `ev_<main_event>_<sub_event>(S, A)` where `S` is the instance and `A` the
  event arguments.
- `R.step()` advances the simulation at a fixed timestep (60 Hz by default,
  `room_speed` in GM terms). Render frames replay recorded draw commands, so
  game speed never depends on FPS — including on 30/120 FPS settings.
- Draw events run inside the logic step (as in GameMaker) and emit canvas
  commands bucketed by blend mode; `_draw` only replays them.
- Collision uses spatial-hash broad-phase + cached sprite masks; array access
  (`aget`/`aset`) supports per-wave value overrides via the Waves bindings.

## Conventions

- GDScript files are `snake_case`; classes are `PascalCase` (`R`, `G`, `K`,
  `GMVars`, `REG`, `P<n>`).
- Files under `game/` and `objects/` are produced by `gm2gd_emit.py` +
  `gm_postmin.py` from the decompiled GameMaker corpus — edit the generator,
  not the generated file. `tools/object_names.json` is the Polish-to-English
  glossary.
- Indent with tabs, UTF-8, LF.

## Save data

The game writes to the Godot user directory (`user://`, i.e.
`%APPDATA%\Godot\app_userdata\<project name>`). `settings.ini` and `data/skipper`
are seeded from the project on first run.

## Validation

```
godot --headless --path . --quit-after 120                          # boot smoke test
godot --headless --path . -s tools/flow_shot.gd -- --frames=600      # screenshot a room
godot --headless --path . -s tools/probe.gd -- --frames=120          # asset warnings
godot --headless --path . -s tools/enemy_compare.gd -- --mode=scene \
    --scene=res://stages/world_1/level_04_asteroids.tscn --frames=600
```

Debug args on the main scene: `--room=<name>`, `--map=<n> --lev=<n>`,
`--spawn=<obj>:<count>`, `--perf`, `--fftest`, `--maxfps=<n>`.
