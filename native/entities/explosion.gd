extends Node2D
class_name NativeExplosion
## NativeExplosion — death burst effect (ports `o_explosion_1` / exploder_*).
##
## The original plays a 37-frame explosion animation where enemies die.
## This plays the same sprite sheet once, then frees itself. Cheap enough
## to spawn on every kill.

const SPRITE_ID := 14             # s_explo_1 — 37 frame explosion
const ANIM_FPS := 30.0
const SCALE := 1.4


func _ready() -> void:
	var anim := AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("boom")
	for tex in NativeAssets.sprite_frames(SPRITE_ID):
		frames.add_frame("boom", tex)
	frames.set_animation_speed("boom", ANIM_FPS)
	anim.sprite_frames = frames
	anim.play("boom")
	anim.offset = -NativeAssets.sprite_origin(SPRITE_ID)
	anim.scale = Vector2(SCALE, SCALE)
	anim.animation_finished.connect(queue_free)
	add_child(anim)
