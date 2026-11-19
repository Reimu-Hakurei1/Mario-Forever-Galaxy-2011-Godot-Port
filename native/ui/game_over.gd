extends Control
## NativeGameOver — shown when the player runs out of lives.
##
## Ports the original's game-over flow: display the run's final stats,
## then return to the star map. Progress (score/coins/unlocks) was
## already saved by the arena before this scene loads.

const MAP_SCENE := "res://native/levels/star_map.tscn"


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.02, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 120
	title.offset_bottom = 200
	add_child(title)

	var stats := Label.new()
	stats.name = "Stats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 24)
	stats.add_theme_color_override("font_color", Color.WHITE)
	stats.set_anchors_preset(Control.PRESET_CENTER)
	stats.offset_left = -250
	stats.offset_right = 250
	stats.offset_top = -40
	stats.offset_bottom = 60
	stats.text = "SCORE %d\nCOINS %d\nLEVEL %d" % [
		NativeGame.score, NativeGame.coins, NativeGame.level_index]
	add_child(stats)

	var btn := Button.new()
	btn.text = "RETURN TO MAP"
	btn.custom_minimum_size = Vector2(280, 60)
	btn.add_theme_font_size_override("font_size", 22)
	btn.position = Vector2(372, 420)
	btn.pressed.connect(_on_map)
	add_child(btn)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ENTER:
		_on_map()


func _on_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)
