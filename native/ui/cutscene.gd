extends Control
## NativeCutscene — the original's room_animation_* story cinematics.
##
## The legacy anim_1..4 rooms play pre-rendered story cards (data/a/
## txt_*.png dialogue, toad_*/anim_obj_*/hero* character art,
## background*.png backdrops) as timed image sequences. This scene
## reproduces that presentation: full-screen cards crossfading on a
## fixed beat. Any key/click skips the whole sequence.

signal finished

## Scene to open when the sequence ends (empty = just free).
var next_scene := ""

const IMG_DIR := "res://data/a/"
const BEAT := 3.2               # seconds per card

# The four legacy sequences, flattened to ordered card lists. anim_1 is
# the opening story (toad + txt cards over backgrounds), anim_3 the
# mid-campaign scene, anim_4 the hero/metroid finale.
const SEQUENCES := {
	"opening": [
		"background1.png",
		"toad_0.png", "txt_1.png", "txt_2.png",
		"toad_1.png", "txt_3.png", "txt_4.png",
		"toad_2.png", "txt_5.png", "txt_6.png",
		"toad_3.png", "txt_7.png", "txt_8.png",
		"toad_4.png", "txt_9.png", "txt_10.png",
		"toad_5.png", "txt_11.png", "txt_12.png",
		"toad_6.png",
		"background2.png",
		"anim_obj_0.png", "anim_obj_1.png", "anim_obj_2.png",
		"anim_obj_5.png", "anim_obj_6.png", "anim_obj_7.png",
		"anim_obj_8.png", "anim_obj_9.png",
	],
	"mid": [
		"background.png",
		"toad_0_1.png", "anim_obj_17.png", "anim_obj_18.png",
		"toad_1_1.png", "anim_obj_19.png",
		"toad_2_1.png", "anim_obj_20.png",
		"toad_3_1.png", "toad_4_1.png",
		"toad_5_1.png", "toad_6_1.png",
	],
	"finale": [
		"background2.png",
		"hero_0.png", "hero_1.png", "hero_2.png", "hero_3.png",
		"hero1_obj_0.png", "hero1_obj_1.png", "hero1_obj_2.png",
		"hero1_obj_3.png", "hero1_obj_4.png",
		"hero2_obj_0.png", "hero2_obj_1.png", "hero2_obj_2.png",
		"hero2_obj_3.png", "hero2_obj_4.png",
		"anim_metroid_0.png", "anim_metroid_1.png", "anim_metroid_2.png",
		"anim_metroid_3.png", "anim_metroid_4.png",
		"anim_metroid_5.png", "anim_metroid_6.png", "anim_metroid_7.png",
		"anim_metroid_8.png", "anim_metroid_9.png", "anim_metroid_10.png",
		"txt_13.png",
	],
}

var _sequence := "opening"
var _layer_a: TextureRect
var _layer_b: TextureRect
var _front := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layer_a = _make_layer()
	_layer_b = _make_layer()
	add_child(_layer_a)
	add_child(_layer_b)
	var cards: Array = SEQUENCES.get(_sequence, SEQUENCES["opening"])
	_play(cards)


func setup(seq: String) -> void:
	_sequence = seq


func _make_layer() -> TextureRect:
	var r := TextureRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.modulate.a = 0.0
	return r


func _tex(file: String) -> Texture2D:
	var img := Image.new()
	if img.load(IMG_DIR + file) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed \
			or event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_skip()


func _skip() -> void:
	set_process_input(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_finish)


func _finish() -> void:
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
	queue_free()


func _play(cards: Array) -> void:
	var idx := 0
	while idx < cards.size() and is_inside_tree():
		var tex := _tex(cards[idx])
		idx += 1
		if tex == null:
			continue
		var back: TextureRect = _layer_b if _front else _layer_a
		var front: TextureRect = _layer_a if _front else _layer_b
		back.texture = tex
		back.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(back, "modulate:a", 1.0, 0.6)
		if front.texture != null:
			tw.tween_property(front, "modulate:a", 0.0, 0.6)
		_front = not _front
		await get_tree().create_timer(BEAT).timeout
	if not is_inside_tree():
		return
	# Fade out and finish.
	var fade := create_tween().set_parallel()
	fade.tween_property(_layer_a, "modulate:a", 0.0, 0.5)
	fade.tween_property(_layer_b, "modulate:a", 0.0, 0.5)
	await fade.finished
	_finish()
