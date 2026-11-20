extends Control
## NativeHeroSelect — ship selection (ports the GameMaker hero-choose room).
##
## The original lets the player pick a ship before entering the galaxy.
## Each card shows the ship name, a stat blurb, and a tinted swatch —
## picking one calls NativeGame.apply_hero() then opens the star map.

const MAP_SCENE := "res://native/levels/star_map.tscn"


func _ready() -> void:
	NativeAssets.play_music("choose_hero")
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "CHOOSE YOUR SHIP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 6)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40
	title.offset_bottom = 96
	add_child(title)

	# One card per hero, laid out in a row.
	var count: int = NativeGame.HEROES.size()
	var card_w := 200.0
	var gap := 40.0
	var start_x := (1024.0 - (count * card_w + (count - 1) * gap)) / 2.0
	for i in count:
		_build_card(i, start_x + i * (card_w + gap))

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(200, 50)
	back.add_theme_font_size_override("font_size", 20)
	back.position = Vector2(412, 640)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://native/ui/title.tscn"))
	add_child(back)


func _build_card(i: int, x: float) -> void:
	var h: Dictionary = NativeGame.HEROES[i]
	var card := PanelContainer.new()
	card.position = Vector2(x, 160)
	card.custom_minimum_size = Vector2(200, 380)
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)

	# Ship preview — the real hull sprite tinted per hero.
	var ship_tex := NativeAssets.sprite_frame(543, 1)
	if ship_tex != null:
		var preview := TextureRect.new()
		preview.texture = ship_tex
		preview.custom_minimum_size = Vector2(120, 90)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.modulate = h["tint"]
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(preview)
	else:
		var swatch := ColorRect.new()
		swatch.color = h["tint"]
		swatch.custom_minimum_size = Vector2(180, 120)
		swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(swatch)

	var name_l := Label.new()
	name_l.text = h["name"]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 26)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(name_l)

	var desc := Label.new()
	desc.text = h["desc"]
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 15)
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	# Stat line — weapon loadout + quirks from the original hero table.
	var stats := Label.new()
	var wname := "—"
	for slot in h.get("loadout", {}):
		var wid: int = h["loadout"][slot][0]
		if wid >= 0:
			wname = NativeWeaponTable.at(wid).get("name", "?")
	var extras: Array = []
	for field in h.get("upgrades", {}):
		extras.append(field.trim_prefix("upgrade_").to_upper())
	if h.has("lives"):
		extras.append("+1 SHIP")
	stats.text = "%s\nSPD %s\nROF %s\n%s" % [
		wname,
		"FAST" if h["slower"] < 1.0 else ("SLOW" if h["slower"] > 1.1 else "NORM"),
		"HIGH" if h["firerate"] > 0.05 else "NORM",
		", ".join(extras) if not extras.is_empty() else ""]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_theme_font_size_override("font_size", 14)
	stats.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	box.add_child(stats)

	var pick := Button.new()
	pick.text = "SELECT"
	pick.custom_minimum_size = Vector2(160, 50)
	pick.add_theme_font_size_override("font_size", 20)
	pick.pressed.connect(_on_pick.bind(i))
	box.add_child(pick)

	# Highlight the currently selected hero.
	if i == NativeGame.hero:
		card.modulate = Color(1.0, 0.9, 0.5)


func _on_pick(i: int) -> void:
	NativeGame.hero = i
	NativeGame.apply_hero()
	get_tree().change_scene_to_file(MAP_SCENE)
