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
    native_game.gd     Global run state + save/load (score, lives, hull,
                        heat, upgrades, settings) — static class
    native_assets.gd   Asset manifest loader — sprites, audio, play_sound()
    level_table.gd     Campaign catalogue — 8 worlds x 10 levels, procedural
                        wave generation, boss flags, per-world theme
  entities/
    ship.gd            Player ship — inertia movement, hull tilt, 5 gun muzzles
    bullet.gd          Player projectile
    enemy_bullet.gd    Enemy projectile (shooter/kamikaze return fire)
    enemy.gd           Enemy — goomba/shooter/kamikaze/tank/eye variants,
                        drops, directional knockback
    boss.gd            Level boss — hover, attack patterns, enrage, minions,
                        health bar
    pickup.gd          Collectibles — coin / gem / health with magnet
    explosion.gd       Death burst effect
    wave_spawner.gd    Wave scheduler — data-driven spawn groups
  ui/
    hud.gd             Score / hull / heat / lives display
    shop.gd            Upgrade shop — wings/boosters/freezer/weapon for coins
    title.gd           Boot screen — CONTINUE (save) / NEW GAME
  levels/
    star_map.gd/.tscn  Level select — 8x10 campaign grid with unlocks
    arena.gd/.tscn     Playable single-screen arena (1024x768)
```

## Running it

The native game boots at `native/ui/title.tscn`:

```
title → star map → arena → (level clear) → shop → star map
                 └→ (game over) → star map
```

- **title.tscn** — CONTINUE loads `user://native_save.cfg`; NEW GAME wipes it
- **star_map.tscn** — click an unlocked level node; every 5th level ends in a boss
- **arena.tscn** — the gameplay scene; ESC/P pauses, Space fires, arrows move
- **shop.tscn** — reached automatically after each level clear

Controls: **Arrow keys** move · **Space** fires · **ESC/P** pause.

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
| `o_coindrop` / `o_diamonddrop`         | `NativePickup` (coin/gem/health)        |
| `o_bullet_*` enemy shots               | `NativeEnemyBullet`                     |
| `o_explosion_*` death effects          | `NativeExplosion`                       |
| `room_map*` level select               | `star_map.gd` (NativeLevelTable grid)   |
| `room_shop` upgrades                   | `shop.gd` (coins → upgrade tracks)      |
| Title/menu rooms                       | `title.gd`                              |
| `.ini` save files                      | `NativeGame.save()` → `user://native_save.cfg` |

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
