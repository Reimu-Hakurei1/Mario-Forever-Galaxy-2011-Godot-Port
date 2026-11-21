extends Control
## NativeTitle — boot/title screen for the native game.
##
## Ports the role of the GameMaker title/menu rooms: the first thing the
## player sees. CONTINUE loads the saved profile and opens the star map;
## NEW GAME wipes it. ENTER shortcuts to CONTINUE.
##
## Scene: native/ui/title.tscn — make it the main scene to boot the
## native game instead of the legacy compatibility runtime.

const HERO_SCENE := "res://native/ui/hero_select.tscn"
const INTRO_SCENE := "res://native/ui/intro.tscn"
const MAP_SCENE := "res://native/levels/star_map.tscn"

var _has_save := false


func _ready() -> void:

	var _preview := get_node_or_null("Preview")
	if _preview != null:
		remove_child(_preview)
		_preview.free()
	NativeAssets.play_music("title")

	# deep-space backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.025, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_add_nebula()
	_add_starfield()

	# real title logo art
	var logo := TextureRect.new()
	logo.texture = load("res://gfx/title/title_0.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo.anchor_top = 0.06
	logo.anchor_bottom = 0.44
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)

	var sub := TextureRect.new()
	sub.texture = load("res://gfx/title/title_1.png")
	sub.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sub.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub.anchor_top = 0.45
	sub.anchor_bottom = 0.53
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sub)

	var has_save := NativeGame.any_save()
	# Apply the saved display mode before the first frame is shown.
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if NativeGame.fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)
	_has_save = has_save

	var menu := VBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_CENTER)
	menu.offset_left = -140
	menu.offset_right = 140
	menu.offset_top = -160 if has_save else -120
	menu.offset_bottom = 160
	menu.add_theme_constant_override("separation", 14)
	add_child(menu)

	menu.add_child(_menu_button("CONTINUE" if has_save else "START", _on_continue))
	if has_save:
		menu.add_child(_menu_button("NEW GAME", _on_new_game))
	var opts := _menu_button("OPTIONS", _on_options)
	opts.add_theme_font_size_override("font_size", 20)
	opts.custom_minimum_size = Vector2(280, 50)
	menu.add_child(opts)

	var hint := Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.offset_bottom = -16
	add_child(hint)
	_refresh_hint()


func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 60)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 24)
	var normal := _btn_box(Color(0.04, 0.07, 0.2, 0.88), Color(0.35, 0.5, 0.9), 12, 2)
	var hover := _btn_box(Color(0.1, 0.16, 0.38, 0.95), Color(1.0, 0.85, 0.3), 12, 2)
	var pressed := _btn_box(Color(0.02, 0.04, 0.12, 0.95), Color(1.0, 0.85, 0.3), 12, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.5))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.5))
	b.pressed.connect(cb)
	return b


func _btn_box(bg: Color, border: Color, radius: int, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## Soft colored nebula blobs behind the starfield.
func _add_nebula() -> void:
	var blobs := [
		[Vector2(180, 140), 340.0, Color(0.1, 0.05, 0.25, 0.5)],
		[Vector2(860, 560), 420.0, Color(0.05, 0.12, 0.3, 0.45)],
		[Vector2(700, 120), 300.0, Color(0.22, 0.08, 0.12, 0.4)],
	]
	for bl in blobs:
		var p := Polygon2D.new()
		var pts := PackedVector2Array()
		var c: Vector2 = bl[0]
		var r: float = bl[1]
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(c + Vector2(cos(a), sin(a)) * r * (0.75 + 0.25 * sin(a * 3.0)))
		p.polygon = pts
		p.color = bl[2]
		add_child(p)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ENTER:
		_on_continue()


## Bottom hint shows best score once a save exists.
## Slow-drifting starfield behind the title — generated dots on a
## texture that scrolls, same trick as the star map backdrop.
func _add_starfield() -> void:
	var img := Image.create(1024, 768, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 160:
		var x := randi() % 1024
		var y := randi() % 768
		img.set_pixel(x, y, Color(1, 1, 1, 0.25 + randf() * 0.6))
	var tex := ImageTexture.create_from_image(img)
	var stars := TextureRect.new()
	stars.texture = tex
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.stretch_mode = TextureRect.STRETCH_TILE
	stars.modulate = Color(1, 1, 1, 0.7)
	add_child(stars)
	var tw := create_tween().set_loops()
	tw.tween_property(stars, "position:x", -1024.0, 60.0) \
		.from(0.0).set_trans(Tween.TRANS_LINEAR)


func _refresh_hint() -> void:
	var hint := get_node_or_null("Hint") as Label
	if hint == null:
		return
	hint.text = "BEST %d    —    ENTER to continue" % NativeGame.best_score \
		if _has_save else "ENTER to start"


func _on_continue() -> void:
	# The original's room_savegame: pick one of the three save slots.
	# Picking a hero resets weapons/upgrades (choose_hero semantics),
	# so hero select only happens on NEW GAME via the intro story.
	_open_slot_picker(true)


func _on_new_game() -> void:
	_open_slot_picker(false)


## Save-slot picker — ports room_savegame / o_savegame_draw: three
## slots showing score/coins/level for occupied ones.
func _open_slot_picker(continue_only: bool) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -320
	box.offset_right = 320
	box.offset_top = -220
	box.offset_bottom = 220
	box.add_theme_constant_override("separation", 18)
	overlay.add_child(box)
	var head := Label.new()
	head.text = "CONTINUE — SELECT SAVE" if continue_only else "NEW GAME — SELECT SAVE"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 28)
	head.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	box.add_child(head)
	for i in NativeGame.SLOT_COUNT:
		var info := NativeGame.peek_slot(i)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(640, 90)
		btn.add_theme_font_size_override("font_size", 20)
		if info.is_empty():
			btn.text = "SLOT %d — EMPTY" % (i + 1)
			btn.disabled = continue_only
		else:
			var hero_name: String = NativeGame.HEROES[clampi(
				int(info.get("hero", 0)), 0, NativeGame.HEROES.size() - 1)]["name"]
			btn.text = "SLOT %d — %s   SCORE %d   COINS %d   LEVEL %d   MAP %s" % [
				i + 1, hero_name, int(info["score"]), int(info["coins"]),
				int(info["level"]), str(info["map"])]
		btn.pressed.connect(_on_slot_picked.bind(i, continue_only, overlay))
		box.add_child(btn)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(200, 44)
	cancel.pressed.connect(overlay.queue_free)
	box.add_child(cancel)


func _on_slot_picked(slot: int, continue_only: bool, overlay: Control) -> void:
	overlay.queue_free()
	NativeGame.save_slot = slot
	if continue_only:
		NativeGame.load_save()
		get_tree().change_scene_to_file(MAP_SCENE)
		return
	NativeGame.reset_profile()
	# New game plays the opening story cinematic (room_animation_1)
	# before the intro pages — the original's room order is logo →
	# anim_1..4 → title → hero select.
	var cs = load("res://native/ui/cutscene.gd").new()
	cs.setup("opening")
	cs.next_scene = INTRO_SCENE
	get_tree().root.add_child(cs)


## Options opens as an overlay — it frees itself on close, no scene swap.
func _on_options() -> void:
	add_child(load("res://native/ui/options.tscn").instantiate())
