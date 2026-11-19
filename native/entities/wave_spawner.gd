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

## One wave entry: [delay_seconds, count, spawn_edge, mode, health].
## spawn_edge: "top" | "left" | "right" | "bottom" — where the group enters.
## mode: "formation" | "chase".
@export var waves: Array = [
	{"delay": 1.0, "count": 4, "edge": "top", "mode": "formation", "health": 100.0},
	{"delay": 6.0, "count": 5, "edge": "right", "mode": "formation", "health": 100.0},
	{"delay": 12.0, "count": 6, "edge": "top", "mode": "chase", "health": 100.0},
	{"delay": 20.0, "count": 8, "edge": "left", "mode": "formation", "health": 100.0},
	{"delay": 30.0, "count": 10, "edge": "top", "mode": "chase", "health": 100.0},
]

@export var spawn_interval := 0.5     # seconds between enemies in a wave
@export var formation_rows := 4       # slots per row in formation layout

var _clock := 0.0
var _pending: Array = []              # waves waiting for their delay
var _active: Array = []               # wave groups currently spawning
var _done := false


func _ready() -> void:
	# Copy the export so runtime state never mutates the inspector value.
	_pending = waves.duplicate(true)
	_pending.sort_custom(func(a, b): return a["delay"] < b["delay"])
	add_to_group("spawners")


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
	enemy.health = wave.get("health", 100.0)
	enemy.global_position = pos

	# Formation slots are laid out in the upper half of the room — enemies
	# enter, take a slot, and sway there while the player fights through.
	var slot_index: int = wave.get("spawned", 0)
	enemy.formation_slot = _formation_slot(slot_index)
	if wave.get("mode", "formation") == "chase":
		enemy.mode = NativeEnemy.Mode.CHASE
	else:
		enemy.mode = NativeEnemy.Mode.SPAWN

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
