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

var _scroll_acc := 0.0            # px scrolled since last row spawn
var _chunk := 0
var _level_index := 0
var _path_tiles: Array[Sprite2D] = []


func _ready() -> void:
	_level_index = NativeGame.active_level
	# Pre-seed rows above the screen so the stage starts busy.
	for i in 5:
		_spawn_row(-40.0 - i * ROW_GAP)
		_chunk += 1


func _physics_process(_delta: float) -> void:
	if NativeGame.paused:
		return
	# Conveyor: a new row enters at the top every ROW_GAP px scrolled.
	_scroll_acc += 2.0
	if _scroll_acc >= ROW_GAP:
		_scroll_acc -= ROW_GAP
		_spawn_row(-40.0)
		_chunk += 1
	# o_pather_1 — castle floor/path tiles (sprite 306) scroll down
	# with the stage between the obstacle rows.
	for i in range(_path_tiles.size() - 1, -1, -1):
		var tile := _path_tiles[i]
		if not is_instance_valid(tile):
			_path_tiles.remove_at(i)
			continue
		tile.position.y += 2.0
		if tile.position.y > NativeGame.room_size().y + 80.0:
			_path_tiles.remove_at(i)
			tile.queue_free()


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

	# castle_enemy phalanx — the original's signature castle wave: a
	# 3x10 grid of grunts released from above in formation. ~10% of rows.
	if randf() < 0.10:
		_spawn_phalanx(y)

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
		coin.tier = randi_range(1, 4)
		coin.position = Vector2(corridor_x + randf_range(-60, 60), y - 100)
		add_child(coin)

	# Path tiles dress the floor between obstacle rows — the original's
	# castle rooms are lined with scrolling castle pieces.
	if randf() < 0.6:
		var tile := Sprite2D.new()
		var tex := NativeAssets.sprite_frame(306, 0)
		if tex != null:
			tile.texture = tex
			tile.offset = -NativeAssets.sprite_origin(306)
			tile.scale = Vector2(0.8, 0.8)
			tile.modulate = Color(0.55, 0.55, 0.65, 0.8)
			tile.position = Vector2(randf_range(60, 964), y + randf_range(-60, 60))
		add_child(tile)
		_path_tiles.append(tile)


## o_castle_enemy — releases a 30-slot phalanx: 3 rows of 10 grunts at
## dox 60+i*80 / doy 64,128,196, entering from y=-200..-400 and riding
## the stage scroll down in perfect formation.
func _spawn_phalanx(row_y: float) -> void:
	var kind: int = ENEMY_KINDS[randi() % ENEMY_KINDS.size()]
	for row in 3:
		for col in 10:
			var enemy := NativeEnemy.new()
			enemy.kind = kind
			enemy.phalanx = true
			enemy.scroll_down = 2.0
			# Center the original's 60..780 grid on the 1024 room.
			enemy.position = Vector2(
				182.0 + col * 80.0,
				row_y - 160.0 - row * 68.0 - randf_range(0, 60))
			add_child(enemy)
			enemy.health *= 1.0 + clampf(float(_level_index) / 40.0, 0.0, 1.0)


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
