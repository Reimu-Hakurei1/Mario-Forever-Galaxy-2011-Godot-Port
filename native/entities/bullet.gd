extends Node2D
class_name NativeBullet
## NativeBullet — player projectile (ports GameMaker `o_laser_u`).
##
## The original bolt accelerates after firing (speed ramps 4 -> ~8 px/frame)
## and grows slightly as it travels. It dies when it leaves the room or
## hits an enemy, dealing its `damage` to the target's energy.

const SPRITE_ID := 95            # s_bulletprof_1
const START_SPEED := 4.0         # px/frame — original ramps +0.4/frame
const MAX_SPEED := 9.0
const ACCEL := 0.4
const SCALE_GROWTH := 0.005      # visual stretch per frame (g_wielkoscx)
const MARGIN := 200.0            # original kills bolts 200px outside the room

var velocity := Vector2.ZERO     # world px/frame
var damage := 34.0
var explosive := false          # EXPLOSIVE AMMO — splash damage on hit
var coin_on_hit := false        # CREATE COINS — GOLD GUN drops a coin
var pierce := false             # PIERCER SLUG — passes through enemies

var _sprite: Sprite2D
var _scale := 0.2
var _dead := false
var _hit := {}                  # pierce: enemy_id -> last-hit physics frame


func _ready() -> void:
	_sprite = Sprite2D.new()
	var tex := NativeAssets.sprite_frame(SPRITE_ID, 0)
	if tex != null:
		_sprite.texture = tex
		_sprite.offset = -NativeAssets.sprite_origin(SPRITE_ID)
	_sprite.scale = Vector2(_scale, _scale)
	# Bullets fly toward enemies — mark them so the ship's hurtbox ignores
	# friendly fire and enemies can detect them via group scan.
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	if NativeGame.paused or _dead:
		return

	# Accelerate like the original (speed += 0.4/frame up to the cap).
	var speed := velocity.length()
	if speed > 0.0 and speed < MAX_SPEED:
		velocity = velocity.normalized() * minf(speed + ACCEL, MAX_SPEED)
	position += velocity

	# Hit test — the original used place_meeting() against the enemy parent
	# object; a group scan is the same check in native terms. Bullets are
	# small and few, so the scan is cheap.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) \
				or position.distance_to(enemy.global_position) >= 34.0:
			continue
		var eid := enemy.get_instance_id()
		var frame := Engine.get_physics_frames()
		# Piercing bolts keep flying — a per-target cooldown stops one
		# enemy eating the whole volley in a single frame.
		if pierce:
			if frame - int(_hit.get(eid, -9999)) < 12:
				continue
			_hit[eid] = frame
		enemy.take_damage(damage)
		if explosive:
			_splash(enemy)
		if coin_on_hit:
			_drop_coin()
		if not pierce:
			_dead = true
			queue_free()
			return

	# Slight visual stretch as the bolt travels.
	_scale += SCALE_GROWTH
	_sprite.scale = Vector2(_scale, _scale)
	_sprite.rotation = velocity.angle()

	# Original: destroy once comfortably outside the room bounds.
	# Uses the design room size, not the viewport (headless viewports lie).
	var room := NativeGame.room_size()
	if position.x < -MARGIN or position.x > room.x + MARGIN \
			or position.y < -MARGIN or position.y > room.y + MARGIN:
		queue_free()


## EXPLOSIVE AMMO — the ISOMATIC CANNON's warhead: on impact it also
## damages every other enemy within splash range for half damage.
func _splash(primary: Node2D) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy != primary \
				and position.distance_to(enemy.global_position) < 70.0:
			enemy.take_damage(damage * 0.5)


## CREATE COINS — the GOLD GUN literally mints currency: each hit drops
## a coin pickup where the bolt landed.
func _drop_coin() -> void:
	var coin := NativePickup.new()
	coin.kind = NativePickup.Kind.COIN
	coin.global_position = position
	get_parent().add_child(coin)
