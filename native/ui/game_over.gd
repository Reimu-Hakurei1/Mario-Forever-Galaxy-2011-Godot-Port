extends Control
## NativeGameOver — shown when the player runs out of lives.
##
## Ports the original's game-over flow: display the run's final stats,
## then return to the star map. Progress (score/coins/unlocks) was
## already saved by the arena before this scene loads.

const MAP_SCENE := "res://native/levels/star_map.tscn"


var _entry_active := false      # initials entry mode
var _initials := ""             # letters typed so far
var _entry_label: Label = null


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
	stats.text = "SCORE %d\nBEST %d\nCOINS %d\nLEVEL %d" % [
		NativeGame.score, NativeGame.best_score,
		NativeGame.coins, NativeGame.level_index]
	add_child(stats)

	var btn := Button.new()
	btn.text = "RETURN TO MAP"
	btn.custom_minimum_size = Vector2(280, 60)
	btn.add_theme_font_size_override("font_size", 22)
	btn.position = Vector2(372, 420)
	btn.pressed.connect(_on_map)
	add_child(btn)

	# New high score → offer initials entry before leaving.
	if NativeGame.score > 0 and NativeGame.score >= NativeGame.best_score:
		_entry_active = true
		_entry_label = Label.new()
		_entry_label.text = "NEW HIGH SCORE!\nENTER INITIALS: ___"
		_entry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_entry_label.add_theme_font_size_override("font_size", 22)
		_entry_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		_entry_label.set_anchors_preset(Control.PRESET_CENTER)
		_entry_label.offset_left = -250
		_entry_label.offset_right = 250
		_entry_label.offset_top = 160
		_entry_label.offset_bottom = 220
		add_child(_entry_label)


func _unhandled_input(event: InputEvent) -> void:
	if _entry_active:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER:
				_finish_entry()
			elif event.keycode == KEY_BACKSPACE:
				_initials = _initials.left(_initials.length() - 1)
				_refresh_entry()
			elif event.keycode >= KEY_A and event.keycode <= KEY_Z \
					and _initials.length() < 3:
				_initials += char(event.keycode)
				_refresh_entry()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ENTER:
		_on_map()


func _refresh_entry() -> void:
	_entry_label.text = "NEW HIGH SCORE!\nENTER INITIALS: %s" % \
		(_initials.ljust(3, "_"))


func _finish_entry() -> void:
	if _initials.length() > 0:
		NativeGame.hiscore_name = _initials
		NativeGame.save()
	_entry_active = false
	if _entry_label != null:
		_entry_label.queue_free()


func _on_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)
