extends Node2D
class_name NativeCastleScroller
## NativeCastleScroller — generates the endless castle-stage stream
## (ports the scrolling object flow of the original castle rooms).
##
## The original castle stages place blocks/enemies/keys in room
## coordinates and scroll them down at G.castle_speed. This port
## generates the stream procedurally: rows of obstacles drift down,
## always leaving a corridor the ship can slip through, with castle
## enemies and a key interleaved. Touching a key ends the level.
##
## Layout per "chunk" (one screen-height of content):
##   - 2-4 destructible blocks forming partial walls
##   - 0-2 scrolling enemies
##   - coin/gem pickups sprinkled in the gaps
##   - a key every few chunks (first touch = level clear)

const ROW_GAP := 210.0          # px between obstacle rows
const KEY_EVERY := 4            # a key appears every Nth chunk
const ENEMY_KINDS := [
	NativeEnemy.Kind.GOOMBA, NativeEnemy.Kind.SHOOTER,
	NativeEnemy.Kind.KAMIKAZE, NativeEnemy.Kind.TANK,
	NativeEnemy.Kind.GHOST, NativeEnemy.Kind.ROCKET_UFO,
	NativeEnemy.Kind.FLAME,
]
# Castle defenses are the rooms' signature threats — the original
# stages are built around script_castle_cannon/flame/rotary. Weighted
# so roughly half of spawned hostiles are guns.
const DEFENSE_KINDS := [
	NativeEnemy.Kind.CANNON, NativeEnemy.Kind.CANNON,
	NativeEnemy.Kind.FLAME_CANNON, NativeEnemy.Kind.ROTARY,
	NativeEnemy.Kind.FAT_CANNON,
]

var _next_y := -120.0           # next spawn row's y (local space)
var _chunk := 0
var _level_index := 0


func _ready() -> void:
	_level_index = NativeGame.active_level
	# Seed a few rows already above the screen so the stage starts busy.
	_next_y = -120.0


func _physics_process(_delta: float) -> void:
	if NativeGame.paused:
		return
	# Spawn rows until the next one is inside the visible band.
	while _next_y < NativeGame.room_size().y + 100.0:
		_spawn_row(_next_y)
		_next_y += ROW_GAP
		_chunk += 1


func _spawn_row(y: float) -> void:
	# Difficulty scales gently with campaign progress.
	var diff := clampf(float(_level_index) / 40.0, 0.0, 1.0)

	# A key every KEY_EVERY chunks — guarantees the exit arrives steadily.
	if _chunk > 0 and _chunk % KEY_EVERY == KEY_EVERY - 1:
		var key := NativeCastleKey.new()
		key.position = Vector2(randf_range(120, 900), y)
		add_child(key)
		# Keys get a small escort so they're not trivially safe.
		_maybe_add_enemy(y - 160.0, diff)
		return

	# Blocks: 2-4 per row, always leaving the middle third open enough
	# to fly through (the original's rooms are hand-designed; a guaranteed
	# corridor keeps procedural rows fair).
	var count := randi_range(2, 4)
	var corridor_x := randf_range(300, 724)
	for i in count:
		var bx := randf_range(90, 934)
		if absf(bx - corridor_x) < 160.0:
			bx += 200.0 if bx < corridor_x else -200.0
		bx = clampf(bx, 80, 944)
		var block := NativeCastleBlock.new()
		block.position = Vector2(bx, y + randf_range(-30, 30))
		block.hp = NativeCastleBlock.BASE_HP * (1.0 + diff)
		block.max_hp = block.hp
		add_child(block)

	# Enemies drift in behind the blocks — shootable targets.
	if randf() < 0.45 + diff * 0.3:
		_maybe_add_enemy(y - randf_range(120, 200), diff)

	# Windmill hazards (o_fan) spin through the corridor — unkillable,
	# they just punish sloppy flying. More common deeper in the stage.
	if randf() < 0.18 + diff * 0.15:
		var fan := NativeEnemy.new()
		fan.kind = NativeEnemy.Kind.FAN
		fan.scroll_down = 2.0
		fan.position = Vector2(randf_range(140, 884), y - randf_range(60, 160))
		add_child(fan)

	# Occasional coin/gem in the corridor — rewards risky lines.
	if randf() < 0.3:
		var coin := NativePickup.new()
		coin.kind = NativePickup.Kind.COIN if randf() < 0.8 \
			else NativePickup.Kind.GEM
		coin.position = Vector2(corridor_x + randf_range(-60, 60), y - 100)
		add_child(coin)


func _maybe_add_enemy(y: float, diff: float) -> void:
	if y < -150.0 or y > NativeGame.room_size().y + 150.0:
		return
	var pool: Array = DEFENSE_KINDS if randf() < 0.5 else ENEMY_KINDS
	var kind: int = pool[randi() % pool.size()]
	var enemy := NativeEnemy.new()
	enemy.kind = kind
	# Castle enemies drift down with the world scroll and hunt the ship
	# (CHASE — SPAWN would drag them toward the (0,0) formation slot).
	enemy.scroll_down = 2.0
	enemy.mode = NativeEnemy.Mode.CHASE
	enemy.position = Vector2(randf_range(100, 924), y)
	add_child(enemy)
	# Scale AFTER add_child — _ready/_apply_profile sets the kind's
	# profile health (cannons are tanky), then difficulty multiplies it.
	enemy.health *= (1.0 + diff)
