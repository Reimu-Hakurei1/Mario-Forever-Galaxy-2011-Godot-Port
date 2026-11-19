extends Control
## NativeShop — upgrade shop (ports the GameMaker `room_shop`).
##
## The original Mushroom Kingdom shop sells ship upgrades for coins.
## This native version offers the four tracks that already affect
## gameplay in NativeGame: handling (wing), speed (boost), cooling
## (freezer) and firepower (weapon). Costs scale with each track's
## level so early upgrades stay affordable.
##
## Flow: level clear → shop → star map. "CONTINUE" returns to the map.

# Upgrade definitions: [NativeGame field, display name, effect blurb,
# base coin cost, cost growth per level].
const UPGRADES := [
	{"field": "upgrade_wing", "name": "WINGS", "desc": "+handling & turn rate",
		"base": 50, "growth": 1.6},
	{"field": "upgrade_boost", "name": "BOOSTERS", "desc": "+max speed",
		"base": 75, "growth": 1.7},
	{"field": "upgrade_freezer", "name": "FREEZER", "desc": "+overheat capacity",
		"base": 60, "growth": 1.6},
	{"field": "weapon_power", "name": "WEAPON", "desc": "+bolts per muzzle",
		"base": 120, "growth": 2.0},
	# Spare ships are a shop purchase in the original (zycia is bought
	# and sold for coins between levels, capped at a few extras).
	{"field": "lives", "name": "LIVES", "desc": "+1 spare ship",
		"base": 300, "growth": 1.8, "max": 5},
]
const MAX_LEVEL := 5               # original caps upgrades around here

var _rows: Array = []


func _ready() -> void:
	# Shop backdrop — the original room_shop uses its own background.
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shop_bg := NativeAssets.background(45)
	if shop_bg != null:
		var plate := Sprite2D.new()
		plate.texture = shop_bg
		plate.centered = false
		plate.scale = Vector2(1024.0 / shop_bg.get_width(), 768.0 / shop_bg.get_height())
		plate.modulate = Color(0.8, 0.8, 0.9)
		plate.z_index = -1
		add_child(plate)

	_build_header()
	for i in UPGRADES.size():
		_build_row(i)
	_build_footer()


func _build_header() -> void:
	var title := Label.new()
	title.text = "MUSHROOM SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.6, 0.8))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 24
	title.offset_bottom = 76
	add_child(title)

	var coins := Label.new()
	coins.name = "Coins"
	coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins.add_theme_font_size_override("font_size", 22)
	coins.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	coins.set_anchors_preset(Control.PRESET_TOP_WIDE)
	coins.offset_top = 76
	coins.offset_bottom = 110
	add_child(coins)

	# Results line — the shop doubles as the level-clear report.
	var result := Label.new()
	result.name = "Result"
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 16)
	result.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	result.set_anchors_preset(Control.PRESET_TOP_WIDE)
	result.offset_top = 110
	result.offset_bottom = 134
	result.text = "LEVEL %d CLEAR — SCORE %d — KILLS %d" % [
		NativeGame.active_level + 1, NativeGame.score, NativeGame.enemies_killed]
	add_child(result)


func _build_row(i: int) -> void:
	var u: Dictionary = UPGRADES[i]
	var row := HBoxContainer.new()
	row.position = Vector2(140, 140 + i * 96)
	row.add_theme_constant_override("separation", 24)
	add_child(row)

	# Name + current level + effect description.
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(300, 0)
	row.add_child(info)
	var name_l := Label.new()
	name_l.name = "Name"
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(name_l)
	var desc := Label.new()
	desc.text = u["desc"]
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info.add_child(desc)
	var lvl := Label.new()
	lvl.name = "Level"
	lvl.add_theme_font_size_override("font_size", 16)
	lvl.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	info.add_child(lvl)

	# Buy button showing the next-level cost.
	var buy := Button.new()
	buy.name = "Buy"
	buy.custom_minimum_size = Vector2(160, 56)
	buy.add_theme_font_size_override("font_size", 18)
	buy.pressed.connect(_on_buy.bind(i))
	row.add_child(buy)
	_rows.append({"buy": buy, "info": info})


func _build_footer() -> void:
	var cont := Button.new()
	cont.text = "CONTINUE"
	cont.custom_minimum_size = Vector2(240, 60)
	cont.add_theme_font_size_override("font_size", 22)
	cont.position = Vector2(392, 640)
	cont.pressed.connect(_on_continue)
	add_child(cont)


## Read/write an upgrade level by field name. NativeGame's fields are
## static class vars, so Object.get/set can't reach them — explicit
## match keeps it type-safe and obvious.
func _get_lvl(field: String) -> int:
	match field:
		"upgrade_wing": return NativeGame.upgrade_wing
		"upgrade_boost": return NativeGame.upgrade_boost
		"upgrade_freezer": return NativeGame.upgrade_freezer
		"weapon_power": return NativeGame.weapon_power
		"lives": return NativeGame.lives
		_: return 0


func _set_lvl(field: String, value: int) -> void:
	match field:
		"upgrade_wing": NativeGame.upgrade_wing = value
		"upgrade_boost": NativeGame.upgrade_boost = value
		"upgrade_freezer": NativeGame.upgrade_freezer = value
		"weapon_power": NativeGame.weapon_power = value
		"lives": NativeGame.lives = value


func _process(_delta: float) -> void:
	_refresh()


## Repaint levels/costs/affordability every frame — cheap for 4 rows.
func _refresh() -> void:
	var coins_lbl := get_node_or_null("Coins") as Label
	if coins_lbl != null:
		coins_lbl.text = "COINS: %d" % NativeGame.coins
	for i in _rows.size():
		var u: Dictionary = UPGRADES[i]
		var lvl := _get_lvl(u["field"])
		var maxed: bool = lvl >= int(u.get("max", MAX_LEVEL))
		var cost := _cost(u, lvl)
		var row: Dictionary = _rows[i]
		(row["info"].get_node("Name") as Label).text = "%s  Lv%d" % [u["name"], lvl]
		(row["info"].get_node("Level") as Label).text = \
			("MAX" if maxed else "next: %d coins" % cost)
		var buy: Button = row["buy"]
		buy.text = "MAX" if maxed else str(cost)
		buy.disabled = maxed or NativeGame.coins < cost


func _cost(u: Dictionary, lvl: int) -> int:
	return int(u["base"] * pow(u["growth"], lvl))


func _on_buy(i: int) -> void:
	var u: Dictionary = UPGRADES[i]
	var lvl := _get_lvl(u["field"])
	if lvl >= int(u.get("max", MAX_LEVEL)):
		return
	var cost := _cost(u, lvl)
	if NativeGame.coins < cost:
		return
	NativeGame.coins -= cost
	_set_lvl(u["field"], lvl + 1)
	NativeGame.save()
	NativeAssets.play_sound(62)


func _on_continue() -> void:
	NativeGame.save()
	get_tree().change_scene_to_file("res://native/levels/star_map.tscn")
