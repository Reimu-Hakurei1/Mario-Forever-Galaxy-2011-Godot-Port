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
		while wave["spawned"] < wave["count"] and wave["spawn_timer"] >= spawn_interval:
			wave["spawn_timer"] -= spawn_interval
			wave["spawned"] += 1
			_spawn_enemy(wave)

	_active = _active.filter(func(w): return w["spawned"] < w["count"])
	if _pending.is_empty() and _active.is_empty():
		_done = true


## Spawn one enemy at the wave's entry edge, aimed at a formation slot.
func _spawn_enemy(wave: Dictionary) -> void:
	var edge: String = wave["edge"]
	var pos := _edge_position(edge, wave.get("spawned", 0))

	var enemy := NativeEnemy.new()
	enemy.health = wave.get("health", 10.0)
	enemy.global_position = pos

	# Enemy variant — string name → Kind enum. Keep in sync with
	# NativeLevelTable.KINDS and enemy.gd's KIND_PROFILES.
	match wave.get("kind", "goomba"):
		"shooter", "ufo": enemy.kind = NativeEnemy.Kind.SHOOTER
		"kamikaze": enemy.kind = NativeEnemy.Kind.KAMIKAZE
		"tank": enemy.kind = NativeEnemy.Kind.TANK
		"eye": enemy.kind = NativeEnemy.Kind.EYE
		"mini": enemy.kind = NativeEnemy.Kind.MINI
		"ufo_a": enemy.kind = NativeEnemy.Kind.UFO_A
		"ufo_b": enemy.kind = NativeEnemy.Kind.UFO_B
		"ros": enemy.kind = NativeEnemy.Kind.ROS
		"crab": enemy.kind = NativeEnemy.Kind.CRAB
		"jumbo": enemy.kind = NativeEnemy.Kind.JUMBO
		"elite": enemy.kind = NativeEnemy.Kind.ELITE
		"dart": enemy.kind = NativeEnemy.Kind.DART
		"stinger": enemy.kind = NativeEnemy.Kind.STINGER
		"weaver": enemy.kind = NativeEnemy.Kind.WEAVER
		"drone": enemy.kind = NativeEnemy.Kind.DRONE
		"hunter": enemy.kind = NativeEnemy.Kind.HUNTER
		"warlord": enemy.kind = NativeEnemy.Kind.WARLORD
		"lancer": enemy.kind = NativeEnemy.Kind.LANCER
		"ace": enemy.kind = NativeEnemy.Kind.ACE
		_: enemy.kind = NativeEnemy.Kind.GOOMBA

	# Formation slots are laid out in the upper half of the room — enemies
	# enter, take a slot, and sway there while the player fights through.
	var slot_index: int = wave["spawned"]
	enemy.formation_slot = _formation_slot(slot_index)
	match wave.get("mode", "formation"):
		"chase": enemy.mode = NativeEnemy.Mode.CHASE
		"kamikaze": enemy.mode = NativeEnemy.Mode.KAMIKAZE
		_: enemy.mode = NativeEnemy.Mode.SPAWN

	get_parent().add_child(enemy)


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
