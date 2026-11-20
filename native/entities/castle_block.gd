extends Node2D
class_name NativeCastleBlock
## NativeCastleBlock — destructible castle obstacle (ports `o_castle_obj`).
##
## The original castle stages scroll obstacles past the ship; blocks are
## solid (mask 242) — the player bounces off them and takes collision
## damage, while player bullets chew through their hull. This port keeps
## both behaviours: bullets damage it (it's in the "blocks" group the
## bullet scan also checks), the ship gets shoved away on contact.

const SCROLL_SPEED := 2.0        # px/frame — G.castle_speed
const BASE_HP := 60.0
const PUSH_RADIUS := 42.0
const CONTACT_DAMAGE := 3.0

var hp := BASE_HP
var max_hp := BASE_HP
var variant := -1               # <0 = random castle_obj piece
var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	# "blocks" — the bullet scan checks this group alongside "enemies".
	# Blocks are NOT enemies: no kill score, no enemy AI.
	add_to_group("blocks")
	_sprite = Sprite2D.new()
	# Castle pieces — o_castle_obj draws sprite 293 (frames = breakable
	# chunks) plus 294/295 rotated/mirrored orientations (rodzaj 2-7).
	if variant < 0:
		variant = randi_range(0, 7)
	var sid := 293
	var frame := randi_range(0, 5)
	var rot := 0.0
	match variant:
		2: sid = 294; rot = PI        # flipped horizontal
		3: sid = 294
		4: sid = 294; rot = -PI / 2.0 # vertical, mirrored
		5: sid = 294; rot = PI / 2.0
		6: sid = 295
		7: sid = 295; rot = PI / 2.0
	var tex := NativeAssets.sprite_frame(sid, frame if sid == 293 else 0)
	if tex != null:
		_sprite.texture = tex
		_sprite.offset = -NativeAssets.sprite_origin(sid)
	_sprite.scale = Vector2(0.8, 0.8)
	_sprite.rotation = rot
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	if NativeGame.paused:
		return
	_t += 0.05
	# World scroll — everything in a castle stage drifts downward.
	position.y += SCROLL_SPEED

	var ship := NativeGame.player()
	if ship == null or not is_instance_valid(ship):
		return
	var to_ship: Vector2 = ship.global_position - global_position
	var dist: float = to_ship.length()

	# Solid collision — shove the ship out along the contact normal and
	# chip hull proportional to closing speed (place_meeting mask 242).
	if dist < PUSH_RADIUS and dist > 0.01:
		var push := to_ship.normalized() * (PUSH_RADIUS - dist)
		ship.global_position += push
		var ship_vel: Vector2 = ship.get("vel") if ship.get("vel") != null else Vector2.ZERO
		NativeGame.damage_player(
			CONTACT_DAMAGE + ship_vel.length() * 0.4)

	# Fell below the screen = missed obstacle.
	if position.y > NativeGame.room_size().y + 80.0:
		queue_free()


## Player bullets call this — returns true when the block breaks.
func take_damage(amount: float) -> void:
	hp -= amount
	if _sprite != null:
		_sprite.modulate = Color(2.0, 2.0, 2.0) if hp > 0 else Color.WHITE
	if hp <= 0.0:
		var boom := NativeExplosion.new()
		boom.global_position = global_position
		get_parent().add_child(boom)
		NativeGame.add_score(50)
		queue_free()
