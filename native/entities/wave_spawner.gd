extends Node2D
class_name NativeWaveSpawner
## NativeWaveSpawner — schedules enemy waves for a level.
##
## The original GameMaker level spawns enemies through `o_przeciwnikor`
## (enemy_controller) plus per-wave objects like `o_perioder_*`. Each wave
## entry below describes one group: what enemy, how many, where they enter
## from, and whether they hold formation or chase the player.
##
## Wave data is intentionally data-driven — a level scene can add
## `NativeWaveSpawner` children with different `waves` arrays, which is the
## native equivalent of editing the Waves/Enemies nodes in the old editor.

## One wave entry: {delay, count, edge, mode, kind, health}.
##   delay  — seconds before the wave starts
##   count  — enemies in the group
##   edge   — "top" | "left" | "right" | "bottom" entry side
##   mode   — "formation" | "chase" | "kamikaze"
##   kind   — "goomba" | "shooter"/"ufo" | "kamikaze" | "tank" | "eye"
##   health — hit points per enemy
@export var waves: Array = [
	{"delay": 1.0, "count": 4, "edge": "top", "mode": "formation", "kind": "goomba", "health": 10.0},
	{"delay": 6.0, "count": 5, "edge": "right", "mode": "formation", "kind": "goomba", "health": 10.0},
	{"delay": 12.0, "count": 3, "edge": "top", "mode": "formation", "kind": "shooter", "health": 14.0},
	{"delay": 18.0, "count": 4, "edge": "left", "mode": "kamikaze", "kind": "kamikaze", "health": 6.0},
	{"delay": 26.0, "count": 6, "edge": "top", "mode": "chase", "kind": "goomba", "health": 10.0},
	{"delay": 34.0, "count": 2, "edge": "top", "mode": "formation", "kind": "tank", "health": 40.0},
	{"delay": 42.0, "count": 3, "edge": "top", "mode": "formation", "kind": "eye", "health": 16.0},
	{"delay": 52.0, "count": 8, "edge": "right", "mode": "kamikaze", "kind": "kamikaze", "health": 6.0},
]

@export var spawn_interval := 0.5     # seconds between enemies in a wave
@export var formation_rows := 4       # slots per row in formation layout

var _clock := 0.0
var _pending: Array = []              # waves waiting for their delay
var _active: Array = []               # wave groups currently spawning
var _done := false


func _ready() -> void:
	# Copy the export so runtime state never mutates the inspector value.
	set_waves(waves)
	add_to_group("spawners")


## Replace the wave schedule at runtime — used when a level scene loads
## a config staged by the star map. Safe to call before the first tick.
func set_waves(new_waves: Array) -> void:
	waves = new_waves
	_pending = waves.duplicate(true)
	_pending.sort_custom(func(a, b): return a["delay"] < b["delay"])
	_active.clear()
	_done = false
	_clock = 0.0


func _physics_process(delta: float) -> void:
	if NativeGame.paused or _done:
		return
	_clock += delta

	# Launch waves whose delay has elapsed. Runtime keys (spawned,
	# spawn_timer) are initialised here so the tick loop stays simple.
	while not _pending.is_empty() and _clock >= _pending[0]["delay"]:
		var wave: Dictionary = _pending.pop_front()
		wave["spawned"] = 0
		wave["spawn_timer"] = 0.0
		_active.append(wave)

	# Tick each active wave: spawn one enemy per interval until count is met.
	for wave in _active:
		wave["spawn_timer"] += delta
		var gap: float = wave.get("interval_s", spawn_interval)
		while wave["spawned"] < wave["count"] and wave["spawn_timer"] >= gap:
			wave["spawn_timer"] -= gap
			wave["spawned"] += 1
			_spawn_enemy(wave)

	_active = _active.filter(func(w): return w["spawned"] < w["count"])
	if _pending.is_empty() and _active.is_empty():
		_done = true


## Spawn one enemy at the wave's entry edge, aimed at a formation slot.
func _spawn_enemy(wave: Dictionary) -> void:
	var edge: String = wave["edge"]
	# Scripted waves (ported o_wave_* spawner objects) carry a `pattern`
	# and a `kinds` mix — position/kind come from the choreography.
	var script_pattern: String = wave.get("pattern", "")
	if script_pattern == "loot":
		_maybe_spawn_loot(wave)
		return
	if script_pattern == "circle":
		_spawn_ring_wave(wave, edge)
		return
	var pos := _scripted_position(script_pattern, edge,
		wave.get("spawned", 0))

	# Scripted waves mix several kinds — cycle the `kinds` list by spawn
	# index; plain waves use the single `kind` string.
	var kind_name: String = wave.get("kind", "goomba")
	var kinds: Array = wave.get("kinds", [])
	if not kinds.is_empty():
		kind_name = str(kinds[wave.get("spawned", 0) % kinds.size()])

	# The orbiting swarm is a spawner object, not a single enemy —
	# o_enemy_around_1 releases ten grunts on a rotating ring.
	match wave.get("kind", ""):
		"ring":
			var ring := NativeEnemyRing.new()
			ring.global_position = pos
			get_parent().add_child(ring)
			return
		"ducher_ring":
			# o_ducher_around — 12 spirits glued to the player, tight
			# fast-shrinking ring, self-destructs after the assault.
			var ring2 := NativeEnemyRing.new()
			ring2.orbiters_count = 12
			ring2.start_radius = 320.0
			ring2.shrink_delay = 0.0
			ring2.shrink_rate = 10.0
			ring2.glue_to_player = true
			ring2.lifetime = 1400.0
			ring2.orbiter_kind = NativeEnemy.Kind.GHOST
			ring2.orbiter_health = 12.0
			ring2.global_position = pos
			get_parent().add_child(ring2)
			return

	# Team fighters (o_goomba_team/o_ufo_team/o_ufos_team/o_cyber_team/
	# o_hammer_team) — mixed squads crossing the screen and firing.
	if kind_name.ends_with("_team"):
		_spawn_team(wave, kind_name, pos)
		return

	var enemy := NativeEnemy.new()
	enemy.health = wave.get("health", 10.0)
	enemy.global_position = pos
	enemy.kind = _kind_from_name(kind_name)

	# Formation slots are laid out in the upper half of the room — enemies
	# enter, take a slot, and sway there while the player fights through.
	var slot_index: int = wave["spawned"]
	enemy.formation_slot = _formation_slot(slot_index)
	# Pattern-driven mode overrides: divers kamikaze, piranhas chase
	# from below, castle streams scroll with the world.
	match script_pattern:
		"divers", "kamikaze_spikeys":
			enemy.mode = NativeEnemy.Mode.KAMIKAZE
		"piranhas", "stream", "gunship", "swarm", "asteroids", "zigzag", "ghosts", "ufo_stream":
			enemy.mode = NativeEnemy.Mode.CHASE
		"grid", "castle_stream":
			enemy.mode = NativeEnemy.Mode.SPAWN   # glides to its grid slot
		_:
			match wave.get("mode", "formation"):
				"chase": enemy.mode = NativeEnemy.Mode.CHASE
				"kamikaze": enemy.mode = NativeEnemy.Mode.KAMIKAZE
				_: enemy.mode = NativeEnemy.Mode.SPAWN
	# castle_stream releases are the o_castle_enemier phalanx grids —
	# same 30-slot layout as `grid`, handled above.
	# Grid slots come from the original's dox/doy layout (10 columns,
	# 80px pitch, three rows at y=64/128/196 — o_castle_enemier /
	# wave_map_4_grouping_*) instead of sway slots.
	if script_pattern == "grid" or script_pattern == "castle_stream":
		var col := slot_index % 10
		var row := slot_index / 10
		enemy.formation_slot = Vector2(60 + col * 80,
			[64.0, 128.0, 196.0][mini(row, 2)])

	get_parent().add_child(enemy)


## Position for a scripted spawn — the o_wave_* choreography reduced
## to entry edge + pattern offset.
func _scripted_position(pattern: String, edge: String, index: int) -> Vector2:
	var room := NativeGame.room_size()
	match pattern:
		"piranhas":
			# Piranha waves rise from below the arena.
			return Vector2(randf_range(60, room.x - 60), room.y + 60.0)
		"ghosts":
			# Ghost waves drip in from the top corners alternately.
			var side := -1.0 if index % 2 == 0 else 1.0
			return Vector2(room.x / 2.0 + side * randf_range(200, 460),
				-(60.0 + randf() * 200.0))
		"zigzag":
			# Alternating side entries crossing the screen.
			var left := index % 2 == 0
			return Vector2(-40.0 if left else room.x + 40.0,
				randf_range(80, room.y * 0.6))
		"grid", "castle_stream":
			# Enter above the grid slot and glide down to it — the
			# original drops each phalanx member from y=-200-rand(200).
			var col := index % 10
			var row := index / 10
			return Vector2(60 + col * 80,
				-(200.0 + randf() * 200.0) - row * 30.0)
		"asteroids", "swarm":
			# Clumps — several enemies share a spawn x.
			var clump := index / 5
			return Vector2(80 + int((clump * 173) % int(room.x - 160))
				+ randf_range(-30, 30), -(80.0 + randf() * 200.0))
		_:
			return _edge_position(edge, index)


## Circle waves (o_wave_*_circle*) release their whole count as one
## orbiting ring — reuse the ring-mother with a bigger orbiter count.
func _spawn_ring_wave(wave: Dictionary, edge: String) -> void:
	var count: int = int(wave.get("count", 10))
	# Only the first spawn of the wave creates the ring; the rest are
	# no-ops so the wave completes right after.
	if wave.get("ring_done", false):
		return
	wave["ring_done"] = true
	var ring := NativeEnemyRing.new()
	# enemy_around_1 uses 10, ducher_around 12, enemy_around_2 20.
	ring.orbiters_count = clampi(count, 4, 24)
	ring.start_radius = 190.0
	ring.shrink_delay = 600.0
	ring.orbiter_kind = _kind_from_name(
		str(wave.get("kinds", ["goomba"])[0]))
	ring.orbiter_health = wave.get("health", 10.0)
	ring.global_position = _edge_position(edge, 0)
	get_parent().add_child(ring)


## Bonus/loot waves (o_wave_6_bonus_wave, wave_funny_bonus_catch) drop
## pickups instead of enemies — the original's "catch the bonus" waves.
func _maybe_spawn_loot(wave: Dictionary) -> void:
	var pickup := NativePickup.new()
	var roll := randf()
	pickup.kind = NativePickup.Kind.GEM if roll < 0.4 \
		else (NativePickup.Kind.COIN if roll < 0.8 else NativePickup.Kind.HEALTH)
	pickup.global_position = Vector2(randf_range(80, 944),
		randf_range(80, 400))
	get_parent().add_child(pickup)


## Team fighter squads — ports o_goomba_team/o_ufo_team/o_ufos_team/
## o_cyber_team/o_hammer_team: a mother carries 5 mixed members on a
## loose orbit while crossing the screen and firing volleys.
func _spawn_team(wave: Dictionary, team_name: String, pos: Vector2) -> void:
	var squads := {
		"goomba_team": [NativeEnemy.Kind.GOOMBA, NativeEnemy.Kind.GOOMBA,
			NativeEnemy.Kind.KAMIKAZE],
		"ufo_team": [NativeEnemy.Kind.UFO_A, NativeEnemy.Kind.SHOOTER,
			NativeEnemy.Kind.UFO_B],
		"ufos_team": [NativeEnemy.Kind.UFO_A, NativeEnemy.Kind.UFO_B,
			NativeEnemy.Kind.SHOOTER, NativeEnemy.Kind.UFO_A],
		"cyber_team": [NativeEnemy.Kind.DRONE, NativeEnemy.Kind.STINGER,
			NativeEnemy.Kind.WEAVER],
		"hammer_team": [NativeEnemy.Kind.WARLORD, NativeEnemy.Kind.LANCER,
			NativeEnemy.Kind.TANK],
	}
	var ring := NativeEnemyRing.new()
	ring.orbiters_count = 5
	ring.orbiter_kinds = squads.get(team_name,
		[NativeEnemy.Kind.GOOMBA, NativeEnemy.Kind.SHOOTER])
	ring.orbiter_health = wave.get("health", 10.0) * 0.5
	ring.start_radius = 95.0
	ring.shrink_delay = 999999.0     # squads hold formation — no shrink
	ring.global_position = pos
	# Cross the screen horizontally, direction set by entry edge.
	var dir := 1.0 if wave.get("edge", "left") in ["left", "top"] else -1.0
	ring.drift = Vector2(dir * 1.5, dir * 0.12)
	ring.shoot_interval = 2.4
	ring.volley_count = 3
	get_parent().add_child(ring)


## String wave-kind name → NativeEnemy.Kind (single source of truth —
## used by both regular and scripted/circle waves).
static func _kind_from_name(kind_name: String) -> int:
	match kind_name:
		"shooter", "ufo": return NativeEnemy.Kind.SHOOTER
		"kamikaze": return NativeEnemy.Kind.KAMIKAZE
		"tank": return NativeEnemy.Kind.TANK
		"eye": return NativeEnemy.Kind.EYE
		"mini": return NativeEnemy.Kind.MINI
		"ufo_a": return NativeEnemy.Kind.UFO_A
		"ufo_b": return NativeEnemy.Kind.UFO_B
		"ros": return NativeEnemy.Kind.ROS
		"crab": return NativeEnemy.Kind.CRAB
		"jumbo": return NativeEnemy.Kind.JUMBO
		"elite": return NativeEnemy.Kind.ELITE
		"dart": return NativeEnemy.Kind.DART
		"stinger": return NativeEnemy.Kind.STINGER
		"weaver": return NativeEnemy.Kind.WEAVER
		"drone": return NativeEnemy.Kind.DRONE
		"hunter": return NativeEnemy.Kind.HUNTER
		"warlord": return NativeEnemy.Kind.WARLORD
		"lancer": return NativeEnemy.Kind.LANCER
		"ace": return NativeEnemy.Kind.ACE
		"ghost": return NativeEnemy.Kind.GHOST
		"rocket_ufo": return NativeEnemy.Kind.ROCKET_UFO
		"cannon": return NativeEnemy.Kind.CANNON
		"flame_cannon": return NativeEnemy.Kind.FLAME_CANNON
		"rotary": return NativeEnemy.Kind.ROTARY
		"fat_cannon": return NativeEnemy.Kind.FAT_CANNON
		"fat_boy", "fat_boy_a": return NativeEnemy.Kind.FAT_BOY
		"flame": return NativeEnemy.Kind.FLAME
		"flame_shooter", "flame_cans_shooter": return NativeEnemy.Kind.FLAME_SHOOTER
		"fan": return NativeEnemy.Kind.FAN
		"ducher_fall": return NativeEnemy.Kind.FALLER
		"bonus_fall": return NativeEnemy.Kind.BONUS
		"eye2", "sky_eye_2": return NativeEnemy.Kind.EYE2
		"ufo_a2": return NativeEnemy.Kind.UFO_A2
		"ghost2", "shy_ghost_2": return NativeEnemy.Kind.GHOST2
		"ghost3", "shy_ghost_3": return NativeEnemy.Kind.GHOST3
		"runner", "enemy_9": return NativeEnemy.Kind.RUNNER
		_: return NativeEnemy.Kind.GOOMBA


## Pick a spawn point just outside the requested room edge.
func _edge_position(edge: String, index: int) -> Vector2:
	var room := NativeGame.room_size()
	var spread := fposmod(index * 97.0, room.x * 0.8) + room.x * 0.1
	match edge:
		"top": return Vector2(spread, -40.0)
		"bottom": return Vector2(spread, room.y + 40.0)
		"left": return Vector2(-40.0, spread * 0.75 + 60.0)
		"right": return Vector2(room.x + 40.0, spread * 0.75 + 60.0)
		_: return Vector2(room.x * 0.5, -40.0)


## Deterministic-ish formation grid in the upper play area.
func _formation_slot(index: int) -> Vector2:
	var room := NativeGame.room_size()
	var col := index % formation_rows
	var row := index / formation_rows
	return Vector2(
		room.x * 0.15 + col * (room.x * 0.7 / maxf(1.0, formation_rows - 1)),
		140.0 + row * 70.0
	)


## True once every wave has been launched and finished spawning.
func is_finished() -> bool:
	return _done
