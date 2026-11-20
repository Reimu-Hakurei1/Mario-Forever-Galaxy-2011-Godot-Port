extends Node2D
class_name NativeEnemyBullet
## NativeEnemyBullet — projectile fired BY enemies (ports `o_bullet_*`).
##
## Unlike player bolts these are meant to hurt the ship: they fly straight,
## damage on contact, and fizzle at the room edge. `hostile` tint keeps
## them visually distinct from player fire.

const SPRITE_ID := 25            # s_bullet_6 — enemy shot graphic
const SPEED := 3.5               # px/frame
const DAMAGE := 12.0
const MARGIN := 80.0

var velocity := Vector2.ZERO
var sprite_id := -1             # >=0 overrides SPRITE_ID (cannonballs etc.)
var damage := -1.0              # >0 overrides DAMAGE
## boss_N_fight bullet objects (o_bossbul_1/2/3/33): "aimed" = speed 6
## toward the player ±10°, "down_accel" = bossbul_2 (speed 3 +0.05/f,
## straight down), "slow_home" = bossbul_1 (speed 4, clamped homing),
## "fast_home" = bossbul_33 (speed 10 +0.1/f, ±10° jitter).
var move_kind := ""
var _accel := 0.0
var life_frames := 0           # >0 self-destructs after N frames (obj 59)
var _sprite: Sprite2D
var _sprite_id := SPRITE_ID
var _dmg := DAMAGE


func _ready() -> void:
	add_to_group("enemy_bullets")   # CHRONO special clears this group
	if sprite_id >= 0:
		_sprite_id = sprite_id
	if damage > 0.0:
		_dmg = damage
	_sprite = Sprite2D.new()
	var tex := NativeAssets.sprite_frame(_sprite_id, 0)
	if tex != null:
		_sprite.texture = tex
		_sprite.offset = -NativeAssets.sprite_origin(_sprite_id)
	# Reddish tint separates enemy fire from the player's cyan bolts.
	_sprite.modulate = Color(1.0, 0.45, 0.4)
	add_child(_sprite)
	if velocity != Vector2.ZERO:
		_sprite.rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	if NativeGame.paused:
		return
	_f = delta * 60.0
	if life_frames > 0:
		life_frames -= 1
		if life_frames <= 0:
			queue_free()
			return
	if move_kind != "":
		_boss_bullet_tick()
	position += velocity

	# Contact with the ship = damage. The ship's invulnerable flag covers
	# spawn protection, same as enemy ramming.
	var ship := get_tree().get_first_node_in_group("player")
	if ship != null and not ship.invulnerable \
			and position.distance_to(ship.global_position) < 30.0:
		NativeGame.damage_player(_dmg)
		queue_free()
		return

	# Companion buddies soak fire too — the original's bullet mask
	# includes object 26 (o_kumpel_a).
	for buddy in get_tree().get_nodes_in_group("buddies"):
		if is_instance_valid(buddy) and buddy.alive \
				and position.distance_to(buddy.global_position) < 30.0:
			buddy.take_damage(_dmg)
			queue_free()
			return

	var room := NativeGame.room_size()
	if position.x < -MARGIN or position.x > room.x + MARGIN \
			or position.y < -MARGIN or position.y > room.y + MARGIN:
		queue_free()


## o_bossbul_* movement — ported from objects/bullets/boss_bullet_*.gd.
## Speeds are px/frame like the original; _delta*60 converts to frames.
func _boss_bullet_tick() -> void:
	var f := _f
	var ship := get_tree().get_first_node_in_group("player")
	match move_kind:
		"aimed":            # bossbul_3 — speed 6 at player ±10° once
			if ship != null and velocity == Vector2.ZERO:
				var d: float = (ship.global_position - position).angle()
				d += randf_range(-0.17, 0.17)
				velocity = Vector2.RIGHT.rotated(d) * 6.0
				_sprite.rotation = d
		"down_accel":       # bossbul_2 — starts ~3, +0.05/frame, down
			_accel += 0.05 * f
			velocity = Vector2.DOWN * minf(3.0 + _accel, 12.0)
		"slow_home":        # bossbul_1 — speed 4, exact aim at player
			if velocity == Vector2.ZERO:
				var d: float = (ship.global_position - position).angle() \
					if ship != null else PI / 2.0
				velocity = Vector2.RIGHT.rotated(d) * 4.0
				_sprite.rotation = d
		"fatboy":          # o_bullet_fatboy2 — speed 4 +0.02/f, 200 dmg
			if velocity == Vector2.ZERO and ship != null:
				var d: float = (ship.global_position - position).angle()
				velocity = Vector2.RIGHT.rotated(d) * 4.0
				_sprite.rotation = d
			else:
				var sp := velocity.length()
				if sp > 0.01:
					velocity = velocity.normalized() * minf(sp + 0.02 * f, 12.0)
		"fast_home":        # bossbul_33 — speed 10 +0.1/frame
			_accel += 0.1 * f
			if velocity == Vector2.ZERO and ship != null:
				var d: float = (ship.global_position - position).angle() \
					+ randf_range(-0.17, 0.17)
				velocity = Vector2.RIGHT.rotated(d)
				_sprite.rotation = d
			velocity = velocity.normalized() * minf(
				velocity.length() + _accel, 14.0)


var _f := 1.0
