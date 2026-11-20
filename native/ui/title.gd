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
	NativeAssets.play_music("title")
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_add_starfield()

	var title := Label.new()
	title.text = "MARIO FOREVER\nGALAXY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.offset_top = -140
	title.offset_bottom = -40
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 8)
	add_child(title)

	var has_save := NativeGame.any_save()
	# Apply the saved display mode before the first frame is shown.
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if NativeGame.fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)
	_has_save = has_save

	var cont := Button.new()
	cont.text = "CONTINUE" if has_save else "START"
	cont.custom_minimum_size = Vector2(280, 60)
	cont.add_theme_font_size_override("font_size", 24)
	cont.position = Vector2(372, 400)
	cont.pressed.connect(_on_continue)
	add_child(cont)

	if has_save:
		var fresh := Button.new()
		fresh.text = "NEW GAME"
		fresh.custom_minimum_size = Vector2(280, 60)
		fresh.add_theme_font_size_override("font_size", 24)
		fresh.position = Vector2(372, 480)
		fresh.pressed.connect(_on_new_game)
		add_child(fresh)

	var opts := Button.new()
	opts.text = "OPTIONS"
	opts.custom_minimum_size = Vector2(280, 50)
	opts.add_theme_font_size_override("font_size", 20)
	opts.position = Vector2(372, has_save and 550 or 470)
	opts.pressed.connect(_on_options)
	add_child(opts)

	var hint := Label.new()
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hint.offset_bottom = -16
	add_child(hint)
	_refresh_hint()


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
