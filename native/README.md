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
    level_table.gd     Campaign catalogue — 8 worlds x 10 levels,
                        5 wave blueprints + procedural finales, boss flags
  entities/
    ship.gd            Player ship — inertia movement, hull tilt, 5 gun
                        muzzles with per-slot weapons (43-weapon catalog +
                        1000-series super weapons), special-item ring,
                        buddy companions, booster orbs, CHRONO slow-mo
    bullet.gd          Player projectile — per-weapon sprites, homing /
                        weave / arcing / bounce / turret behaviors
    enemy_bullet.gd    Enemy projectile (shooter/kamikaze return fire)
    enemy.gd           Enemy — 34 kinds ported from the original objects:
                        grunts (goomba/mini/dart/weaver/ghost/ghost2/
                        ghost3/ducher_fall/bonus), shooters (shooter/
                        ufo_a/ufo_a2/ufo_b/ros/crab/stinger/drone/hunter/
                        lancer/rocket_ufo/flame_shooter), divers
                        (kamikaze/ace/runner — the accelerating suicide
                        runner), heavies (tank/jumbo/elite/warlord/
                        fat_boy), the sky-eye laser boss (+blue EYE2
                        phase), castle defenses (cannon/flame_cannon/
                        rotary/fat_cannon/flame/fan), indestructible
                        bonus-stage blockers, sprite-derived contact
                        radii, original o_drop table
    enemy_ring.gd      Orbiting swarm + team fighters — o_enemy_around/
                        ducher_around rings, o_*_team squads (mixed
                        members, screen drift, mother volleys)
    boss.gd            Level boss — original HP escalation curve, hover,
                        attack patterns, enrage, tiered minions, named
                        health bar, alternate variants (ufo_mega/fat_boy/
                        flame_cans)
    pickup.gd          Collectibles — coin/gem sizeof tiers, health/lives,
                        special items, weapon boosters (original o_drop)
    explosion.gd       Death burst effect — sprite/scale variants
                        (boss kaboom, radius-scaled enemy bursts)
    death_wreck.gd    o_death — the tumbling ship wreck on player death
    castle_block.gd    Destructible castle block (sprite 293/294/295/306)
    castle_key.gd     Stage key — touch = castle level clear
    castle_scroller.gd Castle conveyor — scroll-distance row spawner with
                        blocks, defenses, enemies, fans, coins, path tiles
    wave_spawner.gd    Wave scheduler — delayed groups plus scripted
                        o_wave_* patterns (grid phalanxes, circles,
                        streams, piranhas, ghosts, zigzag, loot)
  ui/
    hud.gd             Score / hull / heat / lives display
    shop.gd            Upgrade shop — support upgrades, WEAPONS tab (5 gun
                        slots + 53-weapon catalog), SPECIALS tab, buddy
                        tracks, LIVES, hull repair
    title.gd           Boot screen — CONTINUE (save) / NEW GAME
    intro.gd           Opening story pages (first boot)
    hero_select.gd     Ship select — CLASSIC/SAMUS/COMET/TITAN
    options.gd         Settings overlay — music/sfx/effects/volume
    game_over.gd       Final stats screen on game over
    boss_dialogue.gd   Typewriter overlay — boss speeches, NAME| tags
    ending.gd          Victory sequence — character sprites, epilogue,
                        stats (o_ending_* objects)
  core/
    dialogue_table.gd Boss intro/end talks + inter-map briefings
                        (o_boss_*_talk/end_talk, next_map_obj)
  levels/
    star_map.gd/.tscn  Level select — 8x10 campaign grid with unlocks,
                        starfield backdrop
    arena.gd/.tscn     Playable single-screen arena (1024x768)
    castle.gd/.tscn    Castle crawl — scrolling stage, blocks/keys/defenses
```

## Running it

The native game boots at `native/ui/title.tscn` (it's the project main
scene — press F5):

```
title → intro (new game only) → hero select → star map
      → arena → (level clear) → shop → star map
                 ├→ (level 80 clear) → ending → star map
                 └→ (game over) → game over screen → star map
```

- **title.tscn** — CONTINUE loads `user://native_save.cfg`; NEW GAME wipes it
- **intro.tscn** — fading story pages, any key advances (first boot only)
- **hero_select.tscn** — CLASSIC / SAMUS / COMET / TITAN stat variants
- **star_map.tscn** — click an unlocked level node; every 5th level ends in a boss
- **arena.tscn** — the gameplay scene; ESC/P pauses, Space fires, arrows move
- **shop.tscn** — reached automatically after each level clear (also shows results)
- **game_over.tscn** — final stats when lives run out
- **options.tscn** — overlay from title or star map (music/sfx/effects/volume)

Controls: **Arrow keys** (or WASD) move · **Space/Ctrl** fires ·
**X** fires the active special item · **Z/C** rotate the special ring ·
**ESC/P** pause.

Special items (`NativeSpecialTable`, ports `G.specialslot` + the
`g_sekwencja_special` sequences): each hero starts with up to four —
X fires slot 0, Z/C cycle which item is active. Items come from rare
enemy drops and the shop's SPECIALS tab (the original's SUPPORT page).

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

## Hand-authoring levels

Drop a JSON file at `data/levels/native/<index>.json` (zero-based —
`00.json` is level 1, `09.json` is world 1's boss level) and it
replaces the generated config for that level entirely. Missing keys
fall back to the world's theme defaults.

```json
{
	"label": "W1-01",
	"background": 0,
	"music": "mixed_battle",
	"waves": [
		{"delay": 1.0, "count": 4, "edge": "top",
		 "mode": "formation", "kind": "goomba", "health": 100}
	],
	"boss": {"tier": 0}
}
```

- `waves` — `delay` (seconds), `count`, `edge` (top/left/right/bottom),
  `mode` (formation/chase/kamikaze), `kind` (see KINDS in
  `level_table.gd` — goomba, shooter, kamikaze, tank, eye, mini, ufo_a,
  ufo_b, ros, crab, jumbo, elite, dart, stinger, weaver, drone,
  hunter, warlord, lancer, ace), `health`.
- `boss` — `{}` for none, `{"tier": N}` for a boss fight after the waves.
- `00.json` ships as a working example of a hand-authored opener.

## Porting more content

To add an enemy type: subclass or configure `NativeEnemy` (health, sway,
chase speed), add a wave entry in the level's `waves` array. To add a
weapon: extend `ship.gd`'s `MUZZLES`/`FIRE_DELAY` tables or spawn a custom
`NativeBullet` variant. Bosses, items, shop, and the star map port the
same way — one entity at a time, verified against the legacy behavior.
