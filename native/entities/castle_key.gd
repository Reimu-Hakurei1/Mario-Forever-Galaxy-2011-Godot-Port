extends Node2D
class_name NativeCastleKey
## NativeCastleKey — the stage-exit key (ports `o_key` / key_2..5).
##
## Keys spawn at the top of a castle stage and scroll down with the
## world. The first one the ship touches ends the level
## (g_end_level = 1 in the original). Sprite 497 is the key sheet.

const SCROLL_SPEED := 2.0

var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	add_to_group("castle_keys")
	_sprite = Sprite2D.new()
	var tex := NativeAssets.sprite_frame(497, 0)
	if tex != null:
		_sprite.texture = tex
		_sprite.offset = -NativeAssets.sprite_origin(497)
	_sprite.scale = Vector2(0.7, 0.7)
	_sprite.modulate = Color(1.0, 0.9, 0.3)
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	if NativeGame.paused:
		return
	_t += 0.08
	position.y += SCROLL_SPEED
	_sprite.rotation = sin(_t) * 0.25

	var ship := NativeGame.player()
	if ship != null and is_instance_valid(ship) \
			and position.distance_to(ship.global_position) < 34.0:
		# Key reached — level complete. The arena listens for this.
		NativeGame.castle_key_found = true
		NativeAssets.play_sound(62)
		queue_free()
		return

	if position.y > NativeGame.room_size().y + 60.0:
		queue_free()
