extends Control
## NativeOptions — settings screen (ports the GameMaker options room).
##
## Toggles map to the same NativeGame settings fields the legacy game
## used: muzyka (music), dzwiek (sound fx), efekty (particle quality),
## glosnosc_dzwieku (sfx volume). Changes save immediately and apply
## live — music players already read the fields each frame.

signal closed


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -180
	panel.offset_bottom = 180
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

	box.add_child(_toggle("MUSIC", NativeGame.muzyka, func(v): NativeGame.muzyka = v))
	box.add_child(_toggle("SOUND FX", NativeGame.dzwiek, func(v): NativeGame.dzwiek = v))
	box.add_child(_effects_row())
	box.add_child(_volume_row())

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
	opt.select(clampi(NativeGame.efekty, 0, 2))
	opt.item_selected.connect(func(i):
		NativeGame.efekty = i
		NativeGame.save())
	row.add_child(opt)
	return row


func _volume_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var lbl := Label.new()
	lbl.text = "SFX VOLUME"
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_font_size_override("font_size", 20)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = NativeGame.glosnosc_dzwieku
	slider.custom_minimum_size = Vector2(220, 0)
	slider.value_changed.connect(func(v):
		NativeGame.glosnosc_dzwieku = v
		NativeGame.save())
	row.add_child(slider)
	return row


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()


func _on_close() -> void:
	NativeGame.save()
	closed.emit()
	queue_free()
