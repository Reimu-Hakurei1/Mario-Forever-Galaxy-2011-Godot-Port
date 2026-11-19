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
var pierce := false              # max weapon power — bolt passes through foes

var _sprite: Sprite2D
var _scale := 0.2
var _dead := false
var _hit_ids := {}               # enemies already struck (pierce bookkeeping)


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
		if not is_instance_valid(enemy):
			continue
		var eid := enemy.get_instance_id()
		if _hit_ids.has(eid):
			continue   # pierce: don't strike the same enemy twice
		if position.distance_to(enemy.global_position) < 34.0:
			_hit_ids[eid] = true
			enemy.take_damage(damage)
			if not pierce:
				_dead = true
				queue_free()
				return
			# Piercing bolts keep flying through the target.

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
