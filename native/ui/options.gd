extends Control
## NativeOptions — settings screen (ports the GameMaker options room).
##
## Toggles map to the same NativeGame settings fields the legacy game
## used: music_enabled (music), sound_enabled (sound fx), effects (particle quality),
## sound_volume (sfx volume). Changes save immediately and apply
## live — music players already read the fields each frame.

signal closed


func _ready() -> void:

	var _preview := get_node_or_null("Preview")
	if _preview != null:
		remove_child(_preview)
		_preview.free()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -320
	panel.offset_bottom = 320
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	box.add_child(title)

	box.add_child(_toggle("MUSIC", NativeGame.music_enabled, func(v): NativeGame.music_enabled = v))
	box.add_child(_toggle("SOUND FX", NativeGame.sound_enabled, func(v): NativeGame.sound_enabled = v))
	box.add_child(_effects_row())
	box.add_child(_volume_row("SFX VOLUME", "sound_volume"))
	box.add_child(_volume_row("MUSIC VOLUME", "music_volume"))
	box.add_child(_controls_section())
	box.add_child(_toggle("FULLSCREEN", 1 if NativeGame.fullscreen else 0,
		func(v):
			NativeGame.fullscreen = v != 0
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if NativeGame.fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED)))

	var controls := Label.new()
	controls.text = "Move · fire · special keys are rebindable above\nESC/P pause · Q quit to map"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 13)
	controls.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	box.add_child(controls)

	var close := Button.new()
	close.text = "DONE"
	close.custom_minimum_size = Vector2(200, 50)
	close.pressed.connect(_on_close)
	box.add_child(close)


func _toggle(label_text: String, initial: int, apply: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_font_size_override("font_size", 20)
	row.add_child(lbl)
	var chk := CheckBox.new()
	chk.button_pressed = initial != 0
	chk.toggled.connect(func(on):
		apply.call(1 if on else 0)
		NativeGame.save())
	row.add_child(chk)
	return row


func _effects_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = "EFFECTS"
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_font_size_override("font_size", 20)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.add_item("LOW")
	opt.add_item("MEDIUM")
	opt.add_item("HIGH")
	opt.select(clampi(NativeGame.effects, 0, 2))
	opt.item_selected.connect(func(i):
		NativeGame.effects = i
		NativeGame.save())
	row.add_child(opt)
	return row


func _volume_row(label_text: String, field: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_font_size_override("font_size", 20)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = NativeGame.sound_volume if field == "sound_volume" \
		else NativeGame.music_volume
	slider.custom_minimum_size = Vector2(220, 0)
	slider.value_changed.connect(func(v):
		if field == "sound_volume":
			NativeGame.sound_volume = v
		else:
			NativeGame.music_volume = v
		NativeGame.save())
	row.add_child(slider)
	return row


# ster1..ster9 rebinding — the original's options screen captures the
# next keypress per row and writes it to the ini "options" section.
var _capturing := ""
var _bind_buttons := {}


func _controls_section() -> Control:
	var box := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = "CONTROLS (click a key to rebind)"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	box.add_child(lbl)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	var names := {
		"up": "MOVE UP", "down": "MOVE DOWN",
		"left": "MOVE LEFT", "right": "MOVE RIGHT",
		"fire": "FIRE", "special": "SPECIAL",
		"special_prev": "SPECIAL PREV", "special_next": "SPECIAL NEXT",
		"pause": "PAUSE",
	}
	for action in NativeGame.KEY_ACTIONS:
		var l := Label.new()
		l.text = names.get(action, action)
		l.add_theme_font_size_override("font_size", 15)
		grid.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(140, 30)
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_start_capture.bind(action, b))
		_bind_buttons[action] = b
		grid.add_child(b)
	_refresh_bind_labels()
	box.add_child(grid)
	return box


func _key_name(code: int) -> String:
	var s := OS.get_keycode_string(code)
	return s if s != "" else "KEY_%d" % code


func _refresh_bind_labels() -> void:
	for action in _bind_buttons:
		(_bind_buttons[action] as Button).text = \
			_key_name(int(NativeGame.key_bindings[action]))


func _start_capture(action: String, btn: Button) -> void:
	_capturing = action
	btn.text = "PRESS KEY..."


func _unhandled_input(event: InputEvent) -> void:
	if _capturing != "" and event is InputEventKey \
			and event.pressed and not event.echo:
		NativeGame.key_bindings[_capturing] = event.keycode
		_capturing = ""
		_refresh_bind_labels()
		NativeGame.save()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and _capturing == "":
		_on_close()


func _on_close() -> void:
	NativeGame.save()
	closed.emit()
	queue_free()
