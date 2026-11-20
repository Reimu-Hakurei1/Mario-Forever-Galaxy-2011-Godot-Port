extends Node2D
class_name NativeExplosion
## NativeExplosion — death burst effect (ports the `o_exploder_*` /
## `o_flash_*` / `o_fallexploder_*` / `o_kaboom` object family).
##
## The original has ~40 cosmetic variants; they collapse into a small
## set of behaviors keyed by sprite + motion:
##   exploder_1      sprite 14, plain 37-frame burst          (depth -2000)
##   exploder_4      sprite 14, random dir, decaying drift    (debris)
##   exploder_6/7/8  sprite 14, same burst, different depths
##   exploder_*_as   sprite 14, asteroid-kill bursts
##   flash_1         sprite 21, additive, rotates to direction
##   flash_4/6       sprite 28, additive spark — grows, spins,
##                   random drift 0-3 px/f, random start angle
##   fallexploder_*  sprite 14, dir 45-135°, gravity vspeed+0.1
##   kaboom          sprite 236, the big special explosion
## `variant` selects the preset; sprite_id/burst_scale still override.

const SPRITE_ID := 14             # s_explo_1 — 37 frame explosion
const ANIM_FPS := 30.0
const SCALE := 1.4

## variant -> {sprite, scale, additive, spin, grow, drift, gravity,
##             life_frames}. drift = px/frame launch speed, gravity =
## px/frame^2 downward accel (fallexploder's vspeed += 0.1).
const VARIANTS := {
	"burst":    {"sprite": 14, "scale": 1.4},
	"debris":   {"sprite": 14, "scale": 1.0, "drift": 2.0,
		"decay": 1.03},
	"spark":    {"sprite": 28, "scale": 0.7, "additive": true,
		"spin": 4.0, "grow": 0.02, "drift": 2.0, "life": 40.0},
	"muzzle":   {"sprite": 21, "scale": 0.8, "additive": true,
		"spin": 6.0, "life": 12.0},
	"falling":  {"sprite": 14, "scale": 1.1, "gravity": 0.1,
		"drift": 4.5, "life": 90.0},
	"kaboom":   {"sprite": 236, "scale": 2.2},
}

var sprite_id := SPRITE_ID
var burst_scale := SCALE
var variant := "burst"

var _anim: AnimatedSprite2D
var _drift_dir := Vector2.ZERO
var _drift_speed := 0.0
var _gravity := 0.0
var _spin := 0.0
var _grow := 0.0
var _life := 0.0
var _decay := 1.0


func _ready() -> void:
	var cfg: Dictionary = VARIANTS.get(variant, VARIANTS["burst"])
	if sprite_id == SPRITE_ID:
		sprite_id = cfg.get("sprite", SPRITE_ID)
	_anim = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("boom")
	for tex in NativeAssets.sprite_frames(sprite_id):
		frames.add_frame("boom", tex)
	frames.set_animation_speed("boom", ANIM_FPS)
	_anim.sprite_frames = frames
	_anim.play("boom")
	_anim.offset = -NativeAssets.sprite_origin(sprite_id)
	_anim.scale = Vector2(burst_scale, burst_scale) \
		* cfg.get("scale", 1.0)
	if cfg.get("additive", false):
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_anim.material = mat
	if cfg.get("spin", 0.0) != 0.0 or cfg.get("grow", 0.0) != 0.0:
		_anim.rotation = randf() * TAU
		_spin = cfg.get("spin", 0.0)
		_grow = cfg.get("grow", 0.0)
	# flash_4/6 launch on a random angle at speed 0-3; fallexploder_*
	# launches 45-135° with gravity; exploder_4 decays /1.03 per frame.
	if cfg.has("drift"):
		var lo := 45.0 if variant == "falling" else 0.0
		var hi := 135.0 if variant == "falling" else 360.0
		_drift_dir = Vector2.RIGHT.rotated(
			deg_to_rad(randf_range(lo, hi)))
		_drift_speed = randf_range(0.0, cfg["drift"]) \
			if variant != "falling" else randf_range(3.0, 6.0)
	_gravity = cfg.get("gravity", 0.0)
	_life = cfg.get("life", 0.0)
	_decay = cfg.get("decay", 1.0)
	_anim.animation_finished.connect(_on_anim_done)
	add_child(_anim)


func _physics_process(_delta: float) -> void:
	if NativeGame.paused:
		return
	if _drift_speed > 0.0:
		_drift_speed /= _decay
		if _gravity > 0.0:
			_drift_dir.y += _gravity
		position += _drift_dir * _drift_speed
	if _spin != 0.0:
		_anim.rotation += _spin * 0.02
	if _grow != 0.0:
		_anim.scale *= 1.0 + _grow
	if _life > 0.0:
		_life -= 1.0
		if _life <= 0.0:
			queue_free()


func _on_anim_done() -> void:
	if _life <= 0.0:
		queue_free()
