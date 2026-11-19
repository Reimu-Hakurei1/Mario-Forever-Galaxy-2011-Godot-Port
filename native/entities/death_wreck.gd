extends Sprite2D
class_name NativeDeathWreck
## NativeDeathWreck — the o_death wreck: the destroyed hull (sprite
## 151, s_die) tumbles for ~40 frames then accelerates off the bottom
## of the screen. Self-contained; add_child() and forget it.

const SPRITE_ID := 151            # s_die
const TUMBLE_FRAMES := 40.0


func _init() -> void:
	texture = NativeAssets.sprite_frame(SPRITE_ID, 0)
	if texture != null:
		offset = -NativeAssets.sprite_origin(SPRITE_ID)
	scale = Vector2(0.5, 0.5)
	rotation = randf() * TAU
	set_meta("vy", -10.0)
	set_meta("spin", randf_range(-0.15, 0.15))
	set_meta("t", 0.0)


func _physics_process(_delta: float) -> void:
	var t: float = get_meta("t") + 1.0
	set_meta("t", t)
	if t > TUMBLE_FRAMES:
		set_meta("vy", float(get_meta("vy")) + 0.5)
	position.y += float(get_meta("vy"))
	rotation += float(get_meta("spin"))
	if position.y > 830.0:
		queue_free()
