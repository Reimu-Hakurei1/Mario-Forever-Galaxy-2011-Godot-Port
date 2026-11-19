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
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("enemy_bullets")   # CHRONO special clears this group
	_sprite = Sprite2D.new()
	var tex := NativeAssets.sprite_frame(SPRITE_ID, 0)
	if tex != null:
		_sprite.texture = tex
		_sprite.offset = -NativeAssets.sprite_origin(SPRITE_ID)
	# Reddish tint separates enemy fire from the player's cyan bolts.
	_sprite.modulate = Color(1.0, 0.45, 0.4)
	add_child(_sprite)
	if velocity != Vector2.ZERO:
		_sprite.rotation = velocity.angle()


func _physics_process(_delta: float) -> void:
	if NativeGame.paused:
		return
	position += velocity

	# Contact with the ship = damage. The ship's invulnerable flag covers
	# spawn protection, same as enemy ramming.
	var ship := get_tree().get_first_node_in_group("player")
	if ship != null and not ship.invulnerable \
			and position.distance_to(ship.global_position) < 30.0:
		NativeGame.damage_player(DAMAGE)
		queue_free()
		return

	# Companion buddies soak fire too — the original's bullet mask
	# includes object 26 (o_kumpel_a).
	for buddy in get_tree().get_nodes_in_group("buddies"):
		if is_instance_valid(buddy) and buddy.alive \
				and position.distance_to(buddy.global_position) < 30.0:
			buddy.take_damage(DAMAGE)
			queue_free()
			return

	var room := NativeGame.room_size()
	if position.x < -MARGIN or position.x > room.x + MARGIN \
			or position.y < -MARGIN or position.y > room.y + MARGIN:
		queue_free()
