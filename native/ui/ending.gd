extends Control
## NativeEnding — shown after the final boss (level 80) falls.
##
## The original ends the campaign with a victory sequence. This screen
## is the native equivalent: campaign stats, then back to the star map
## (post-game free play stays unlocked).

const MAP_SCENE := "res://native/levels/star_map.tscn"


func _ready() -> void:
	# Deep-space backdrop with a slow starfield — victory deserves a sky.
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.06, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_add_starfield()

	var title := Label.new()
	title.text = "GALAXY SAVED!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 100
	title.offset_bottom = 180
	add_child(title)

	var story := Label.new()
	story.text = "The Mushroom Kingdom shines once more.\nThe stars are safe... for now."
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.add_theme_font_size_override("font_size", 22)
	story.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	story.set_anchors_preset(Control.PRESET_CENTER)
	story.offset_left = -350
	story.offset_right = 350
	story.offset_top = -60
	story.offset_bottom = 0
	add_child(story)

	var stats := Label.new()
	stats.name = "Stats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 24)
	stats.add_theme_color_override("font_color", Color.WHITE)
	stats.set_anchors_preset(Control.PRESET_CENTER)
	stats.offset_left = -250
	stats.offset_right = 250
	stats.offset_top = 20
	stats.offset_bottom = 120
	stats.text = "FINAL SCORE %d\nBEST %d\nCOINS %d" % [
		NativeGame.score, NativeGame.best_score, NativeGame.coins]
	add_child(stats)

	var btn := Button.new()
	btn.text = "KEEP EXPLORING"
	btn.custom_minimum_size = Vector2(280, 60)
	btn.add_theme_font_size_override("font_size", 22)
	btn.position = Vector2(372, 480)
	btn.pressed.connect(_on_map)
	add_child(btn)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ENTER:
		_on_map()


func _on_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)


## Drifting starfield, same generated-dot technique as title/intro.
func _add_starfield() -> void:
	var img := Image.create(1024, 768, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 180:
		img.set_pixel(randi() % 1024, randi() % 768,
			Color(1, 1, 1, 0.25 + randf() * 0.6))
	var tex := ImageTexture.create_from_image(img)
	var stars := TextureRect.new()
	stars.texture = tex
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.stretch_mode = TextureRect.STRETCH_TILE
	stars.modulate = Color(1, 1, 1, 0.7)
	add_child(stars)
	var tw := create_tween().set_loops()
	tw.tween_property(stars, "position:x", -1024.0, 70.0) \
		.from(0.0).set_trans(Tween.TRANS_LINEAR)
