# Native Galaxy — Godot-native rewrite

This folder is the **clean-room native port** of Mario Forever Galaxy.
It does not use the GameMaker compatibility runtime (`engine/r.gd`) —
everything here is ordinary Godot 4 nodes, scenes, and GDScript that any
Godot developer can read and edit.

The legacy port (`engine/`, `game/`, `objects/`, `stages/`) keeps running
unchanged. The two coexist until the native version reaches feature parity.

## Layout

```
native/
  core/
    native_game.gd     Global run state (score, lives, hull, heat, upgrades)
    native_assets.gd   Asset manifest loader — sprites, backgrounds, audio
  entities/
    ship.gd            Player ship — inertia movement, hull tilt, 5 gun muzzles
    bullet.gd          Player projectile
    enemy.gd           Basic enemy — HP, formation slots, player tracking
    wave_spawner.gd    Wave scheduler — data-driven spawn groups
  ui/
    hud.gd             Score / hull / heat / lives display
  levels/
    arena.tscn/.gd     Playable single-screen arena (1024x768)
```

## Running it

Open `native/levels/arena.tscn` and press F6 (or F5 for the whole project —
the native scene can be wired as `run/main_scene` once it replaces the
legacy boot).

Controls: **Arrow keys** move · **Space** fires.

## How GameMaker concepts map to Godot

| GameMaker (legacy)                     | Godot (native)                          |
|----------------------------------------|-----------------------------------------|
| `global.*` variables                   | `NativeGame` static class               |
| `o_player_a` object + events           | `NativeShip` node + `_physics_process`  |
| `instance_create()`                    | `add_child()` / `PackedScene.instantiate()` |
| `place_meeting()` collision            | Group scan / `Area2D` signals           |
| `draw_sprite_ext` per frame            | `AnimatedSprite2D` / `Sprite2D` nodes   |
| `g_energia` / `g_overheating`          | `NativeGame.energy` / `.overheating`    |
| Level `Waves/Enemies` editor nodes     | `wave_spawner.gd` `waves` array         |
| Sprite frames `s_name.id.frame.png`    | `NativeAssets.sprite_frames()`          |
| Sound/music index tables               | `NativeAssets.sound()` / `.music()`     |

## Design rules

- **Fixed 1024x768 arenas.** Galaxy levels are single-screen rooms — the
  camera never scrolls in gameplay. Use `NativeGame.ROOM_SIZE`, never the
  viewport size (it differs headless/windowed).
- **Data over code.** Level content lives in exported arrays (`waves`),
  not hard-coded spawn calls — that's what makes levels editable.
- **Comments explain the *why*.** Every ported mechanic cites the original
  GameMaker variable/function it replaces so future ports can verify
  behavior against the legacy runtime.

## Porting more content

To add an enemy type: subclass or configure `NativeEnemy` (health, sway,
chase speed), add a wave entry in the level's `waves` array. To add a
weapon: extend `ship.gd`'s `MUZZLES`/`FIRE_DELAY` tables or spawn a custom
`NativeBullet` variant. Bosses, items, shop, and the star map port the
same way — one entity at a time, verified against the legacy behavior.
