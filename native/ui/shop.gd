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
	{"field": "upgrade_armour", "name": "ARMOUR", "desc": "+max hull",
		"base": 150, "growth": 1.7},
	{"field": "upgrade_orbit", "name": "ORBIT", "desc": "hull regeneration",
		"base": 200, "growth": 1.8},
	{"field": "upgrade_balls", "name": "BALLS", "desc": "orbiting weapon balls",
		"base": 180, "growth": 1.9},
	# Spare ships are a shop purchase in the original (zycia is bought
	# and sold for coins between levels, capped at a few extras).
	{"field": "lives", "name": "LIVES", "desc": "+1 spare ship",
		"base": 300, "growth": 1.8, "max": 5},
	# Companion buddies (G.jakikumpel) — flat cena_kumpla prices,
	# two independent tracks for the left/right creatures.
	{"field": "buddy_left", "name": "BUDDY L", "desc": "left companion tier",
		"base": 0, "growth": 1.0, "max": 2,
		"prices": NativeGame.BUDDY_PRICES},
	{"field": "buddy_right", "name": "BUDDY R", "desc": "right companion tier",
		"base": 0, "growth": 1.0, "max": 2,
		"prices": NativeGame.BUDDY_PRICES},
]
const MAX_LEVEL := 5               # original caps upgrades around here

var _rows: Array = []
var _tab := "upgrades"          # "upgrades" | "weapons" | "specials"
var _weapon_panel: Control
var _slot_rows: Array = []      # per-slot UI state
var _catalog: ItemList
var _sel_slot := -1             # slot the catalog BUY equips into
var _sel_weapon := -1           # catalog index highlighted in the list
var _special_panel: Control
var _special_list: ItemList
var _sel_special := -1          # catalog index highlighted in the list
var _special_slots_ui: Array = []  # the four equipped-slot labels


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
	_build_tabs()
	for i in UPGRADES.size():
		_build_row(i)
	_build_weapons_panel()
	_build_specials_panel()
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


## UPGRADES / WEAPONS tab switch — the original shop has separate
## weapon and support pages (G.bron_albo_support toggles them).
func _build_tabs() -> void:
	var up := Button.new()
	up.name = "TabUpgrades"
	up.text = "UPGRADES"
	up.position = Vector2(300, 136)
	up.custom_minimum_size = Vector2(200, 40)
	up.pressed.connect(_set_tab.bind("upgrades"))
	add_child(up)
	var wp := Button.new()
	wp.name = "TabWeapons"
	wp.text = "WEAPONS"
	wp.position = Vector2(524, 136)
	wp.custom_minimum_size = Vector2(200, 40)
	wp.pressed.connect(_set_tab.bind("weapons"))
	add_child(wp)
	var sp := Button.new()
	sp.name = "TabSpecials"
	sp.text = "SPECIALS"
	sp.position = Vector2(748, 136)
	sp.custom_minimum_size = Vector2(200, 40)
	sp.pressed.connect(_set_tab.bind("specials"))
	add_child(sp)


func _set_tab(tab: String) -> void:
	_tab = tab
	for row in _rows:
		(row["row"] as Control).visible = tab == "upgrades"
	_weapon_panel.visible = tab == "weapons"
	_special_panel.visible = tab == "specials"
	NativeAssets.play_sound(62)


func _build_row(i: int) -> void:
	var u: Dictionary = UPGRADES[i]
	# Three-column grid — nine tracks (7 upgrades + 2 buddy tiers)
	# don't fit in the old two-column layout.
	var row := HBoxContainer.new()
	row.position = Vector2(60 + (i % 3) * 335, 190 + (i / 3) * 160)
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	# Name + current level + effect description.
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(210, 0)
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
	buy.custom_minimum_size = Vector2(120, 50)
	buy.add_theme_font_size_override("font_size", 18)
	buy.pressed.connect(_on_buy.bind(i))
	row.add_child(buy)
	_rows.append({"buy": buy, "info": info, "row": row})


## WEAPONS tab — the original shop's armory page: your five gun slots on
## the left (click to select), the full 43-weapon catalog on the right.
## BUY equips the highlighted catalog weapon into the selected slot
## (NativeGame.equip_weapon refunds a replaced weapon automatically);
## UPGRADE/SELL act on the selected slot.
func _build_weapons_panel() -> void:
	_weapon_panel = Control.new()
	_weapon_panel.name = "WeaponPanel"
	_weapon_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_weapon_panel.visible = false
	add_child(_weapon_panel)

	# --- Left: the five gun slots -------------------------------------
	for i in 5:
		var slot := PanelContainer.new()
		slot.position = Vector2(70, 190 + i * 92)
		slot.custom_minimum_size = Vector2(400, 80)
		_weapon_panel.add_child(slot)
		var box := VBoxContainer.new()
		slot.add_child(box)
		var head := HBoxContainer.new()
		box.add_child(head)
		var title := Label.new()
		title.name = "Title"
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
		head.add_child(title)
		var lvl := Label.new()
		lvl.name = "Level"
		lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lvl.add_theme_font_size_override("font_size", 16)
		lvl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		head.add_child(lvl)
		var desc := Label.new()
		desc.name = "Desc"
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc)
		var btns := HBoxContainer.new()
		box.add_child(btns)
		var up := Button.new()
		up.name = "Upgrade"
		up.text = "UPGRADE"
		up.custom_minimum_size = Vector2(150, 34)
		up.add_theme_font_size_override("font_size", 14)
		up.pressed.connect(_on_upgrade_weapon.bind(i))
		btns.add_child(up)
		var sell := Button.new()
		sell.name = "Sell"
		sell.text = "SELL"
		sell.custom_minimum_size = Vector2(110, 34)
		sell.add_theme_font_size_override("font_size", 14)
		sell.pressed.connect(_on_sell_weapon.bind(i))
		btns.add_child(sell)
		# Clicking anywhere on the panel selects this slot for BUY.
		slot.gui_input.connect(_on_slot_pick.bind(i))
		_slot_rows.append({"panel": slot, "title": title, "lvl": lvl,
			"desc": desc, "upgrade": up, "sell": sell})

	# --- Right: catalog list + detail ----------------------------------
	_catalog = ItemList.new()
	_catalog.position = Vector2(510, 190)
	_catalog.size = Vector2(440, 340)
	_catalog.add_theme_font_size_override("font_size", 15)
	_catalog.item_selected.connect(_on_catalog_pick)
	for i in NativeWeaponTable.WEAPONS.size():
		var w: Dictionary = NativeWeaponTable.WEAPONS[i]
		_catalog.add_item("%02d  %s" % [i, w["name"]])
	_weapon_panel.add_child(_catalog)

	var detail := Label.new()
	detail.name = "Detail"
	detail.position = Vector2(510, 540)
	detail.size = Vector2(440, 80)
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_panel.add_child(detail)

	var buy := Button.new()
	buy.name = "BuyWeapon"
	buy.text = "SELECT A SLOT, THEN BUY"
	buy.position = Vector2(510, 630)
	buy.custom_minimum_size = Vector2(440, 44)
	buy.add_theme_font_size_override("font_size", 17)
	buy.pressed.connect(_on_buy_weapon)
	_weapon_panel.add_child(buy)

	# Hint line under the slot list.
	var hint := Label.new()
	hint.text = "Click a gun slot to arm it, then BUY a catalog weapon."
	hint.position = Vector2(70, 650)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_weapon_panel.add_child(hint)


## SPECIALS tab — the original shop's SUPPORT page (G.bron_albo_support):
## your four G.specialslot rings on the left, the special-item catalog
## on the right. BUY stores the highlighted item in the first empty
## slot (NativeGame.buy_special); in-game, X fires slot 0 and Z/C
## rotate the ring.
func _build_specials_panel() -> void:
	_special_panel = Control.new()
	_special_panel.name = "SpecialPanel"
	_special_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_special_panel.visible = false
	add_child(_special_panel)

	# Left: the four special slots — "ACTIVE" marks slot 0.
	for i in 4:
		var row := PanelContainer.new()
		row.position = Vector2(70, 190 + i * 92)
		row.custom_minimum_size = Vector2(400, 80)
		_special_panel.add_child(row)
		var box := VBoxContainer.new()
		row.add_child(box)
		var title := Label.new()
		title.name = "Title"
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		box.add_child(title)
		var desc := Label.new()
		desc.name = "Desc"
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc)
		_special_slots_ui.append({"panel": row, "title": title, "desc": desc})

	# Right: the nine special items + detail + BUY.
	_special_list = ItemList.new()
	_special_list.position = Vector2(510, 190)
	_special_list.size = Vector2(440, 340)
	_special_list.add_theme_font_size_override("font_size", 15)
	_special_list.item_selected.connect(_on_special_pick)
	for i in range(1, NativeSpecialTable.ITEMS.size()):
		_special_list.add_item("%02d  %s" % [i, NativeSpecialTable.ITEMS[i]["name"]])
	_special_panel.add_child(_special_list)

	var detail := Label.new()
	detail.name = "Detail"
	detail.position = Vector2(510, 540)
	detail.size = Vector2(440, 80)
	detail.add_theme_font_size_override("font_size", 14)
	detail.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_special_panel.add_child(detail)

	var buy := Button.new()
	buy.name = "BuySpecial"
	buy.text = "SELECT AN ITEM"
	buy.position = Vector2(510, 630)
	buy.custom_minimum_size = Vector2(440, 44)
	buy.add_theme_font_size_override("font_size", 17)
	buy.pressed.connect(_on_buy_special)
	_special_panel.add_child(buy)

	var hint := Label.new()
	hint.text = "In game: X fires the ACTIVE special, Z/C rotate the ring."
	hint.position = Vector2(70, 650)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_special_panel.add_child(hint)


func _on_special_pick(index: int) -> void:
	_sel_special = index + 1   # list row 0 = item id 1
	NativeAssets.play_sound(62)


func _on_buy_special() -> void:
	if _sel_special > 0:
		NativeGame.buy_special(_sel_special)
		NativeAssets.play_sound(62)


func _on_slot_pick(event: InputEvent, slot: int) -> void:
	# Only left-clicks select the slot — gui_input fires for every event.
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_sel_slot = slot
		NativeAssets.play_sound(62)


func _on_catalog_pick(index: int) -> void:
	_sel_weapon = index
	NativeAssets.play_sound(62)


func _on_buy_weapon() -> void:
	if _sel_slot < 0 or _sel_weapon < 0:
		return
	if NativeGame.equip_weapon(_sel_slot, _sel_weapon):
		NativeAssets.play_sound(62)


func _on_upgrade_weapon(slot: int) -> void:
	NativeGame.upgrade_weapon(slot)


func _on_sell_weapon(slot: int) -> void:
	NativeGame.sell_weapon(slot)
	NativeAssets.play_sound(62)


func _build_footer() -> void:
	# Hull repair — the original shop sells missing hull back for coins
	# (energia < max → buy full repair). Hidden when already at full.
	var repair := Button.new()
	repair.name = "Repair"
	repair.custom_minimum_size = Vector2(240, 60)
	repair.add_theme_font_size_override("font_size", 18)
	repair.position = Vector2(120, 640)
	repair.pressed.connect(_on_repair)
	add_child(repair)

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
		"upgrade_armour": return NativeGame.upgrade_armour
		"upgrade_orbit": return NativeGame.upgrade_orbit
		"upgrade_balls": return NativeGame.upgrade_balls
		"lives": return NativeGame.lives
		"buddy_left": return NativeGame.buddy_left
		"buddy_right": return NativeGame.buddy_right
		_: return 0


func _set_lvl(field: String, value: int) -> void:
	match field:
		"upgrade_wing": NativeGame.upgrade_wing = value
		"upgrade_boost": NativeGame.upgrade_boost = value
		"upgrade_freezer": NativeGame.upgrade_freezer = value
		"upgrade_armour": NativeGame.upgrade_armour = value
		"upgrade_orbit": NativeGame.upgrade_orbit = value
		"upgrade_balls": NativeGame.upgrade_balls = value
		"lives": NativeGame.lives = value
		"buddy_left": NativeGame.buddy_left = value
		"buddy_right": NativeGame.buddy_right = value


## Repair cost — the original charges ~10 coins per missing hull point
## on its 1000-point bar; on our 100-point bar that's ~1 coin per point,
## rounded up to keep it meaningful.
func _repair_cost() -> int:
	return maxi(1, int(ceil(NativeGame.max_energy() - NativeGame.energy)))


func _process(_delta: float) -> void:
	var repair := get_node_or_null("Repair") as Button
	if repair != null:
		var missing := NativeGame.max_energy() - NativeGame.energy
		repair.visible = missing > 0.5
		repair.text = "REPAIR %d" % _repair_cost()
		repair.disabled = NativeGame.coins < _repair_cost()
	_refresh()


## Repaint levels/costs/affordability every frame — cheap for 4 rows.
func _refresh() -> void:
	var coins_lbl := get_node_or_null("Coins") as Label
	if coins_lbl != null:
		coins_lbl.text = "COINS: %d" % NativeGame.coins
	if _weapon_panel != null and _weapon_panel.visible:
		_refresh_weapons()
		return
	if _special_panel != null and _special_panel.visible:
		_refresh_specials()
		return
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


## Repaint the WEAPONS tab — slot contents, upgrade/sell affordability,
## and the catalog detail line for the highlighted weapon.
func _refresh_weapons() -> void:
	for i in _slot_rows.size():
		var row: Dictionary = _slot_rows[i]
		var wid := NativeGame.weapons[i]
		var panel: PanelContainer = row["panel"]
		# Highlight the slot selected as the BUY target.
		panel.modulate = Color(1.0, 0.9, 0.5) if i == _sel_slot else Color.WHITE
		if wid < 0:
			(row["title"] as Label).text = "GUN %d — EMPTY" % (i + 1)
			(row["lvl"] as Label).text = ""
			(row["desc"] as Label).text = ""
			(row["upgrade"] as Button).text = "—"
			(row["upgrade"] as Button).disabled = true
			(row["sell"] as Button).text = "—"
			(row["sell"] as Button).disabled = true
			continue
		var w: Dictionary = NativeWeaponTable.at(wid)
		var lv: int = NativeGame.weapon_level[i]
		(row["title"] as Label).text = "%s  Lv%d" % [w["name"], lv]
		(row["lvl"] as Label).text = "DMG %.1f  OH %.1f" % [
			w["fp"] + lv * w["fp_per"], w["oh"] + lv * w["oh_per"]]
		(row["desc"] as Label).text = "%s  (%s)" % [w["type"], w["desc"]]
		var up: Button = row["upgrade"]
		var maxed := lv >= NativeWeaponTable.MAX_LEVEL
		up.text = "MAX" if maxed else "UPGRADE %d" % NativeGame.weapon_upgrade_price(i)
		up.disabled = maxed or NativeGame.coins < NativeGame.weapon_upgrade_price(i)
		var sell: Button = row["sell"]
		sell.text = "SELL +%d" % NativeGame.weapon_sell_price(i)
		sell.disabled = false

	# Catalog detail + BUY button state.
	var detail := _weapon_panel.get_node_or_null("Detail") as Label
	var buy := _weapon_panel.get_node_or_null("BuyWeapon") as Button
	if _sel_weapon >= 0:
		var w: Dictionary = NativeWeaponTable.at(_sel_weapon)
		if detail != null:
			detail.text = "%s — %s\nDMG %.1f  OH %.1f  DELAY %.0f  x%d bolts\nCost %d coins" % [
				w["name"], w["type"], w["fp"], w["oh"], w["fr"], w["multi"],
				NativeGame.weapon_buy_price(_sel_weapon)]
		if buy != null:
			if _sel_slot < 0:
				buy.text = "SELECT A SLOT FIRST"
				buy.disabled = true
			else:
				var price := NativeGame.weapon_buy_price(_sel_weapon)
				if NativeGame.weapons[_sel_slot] >= 0:
					price -= NativeGame.weapon_sell_price(_sel_slot)
				buy.text = "BUY %s → GUN %d  (%+d coins)" % [
					w["name"], _sel_slot + 1, price]
				buy.disabled = NativeGame.coins < price
	elif detail != null:
		detail.text = ""
	if buy != null and _sel_weapon < 0:
		buy.text = "SELECT A WEAPON"
		buy.disabled = true


## Repaint the SPECIALS tab — equipped ring slots and catalog buy state.
func _refresh_specials() -> void:
	for i in _special_slots_ui.size():
		var row: Dictionary = _special_slots_ui[i]
		var id: int = NativeGame.special_slots[i]
		# Slot 0 is the active special — highlight it.
		(row["panel"] as PanelContainer).modulate = \
			Color(1.0, 0.85, 0.4) if i == 0 else Color.WHITE
		if id <= 0:
			(row["title"] as Label).text = "SLOT %d — EMPTY%s" % [
				i + 1, "  (ACTIVE)" if i == 0 else ""]
			(row["desc"] as Label).text = ""
			continue
		var item := NativeSpecialTable.at(id)
		(row["title"] as Label).text = "%s%s" % [item["name"],
			"  (ACTIVE)" if i == 0 else ""]
		(row["desc"] as Label).text = item["desc"]

	var detail := _special_panel.get_node_or_null("Detail") as Label
	var buy := _special_panel.get_node_or_null("BuySpecial") as Button
	if _sel_special > 0:
		var item := NativeSpecialTable.at(_sel_special)
		if detail != null:
			detail.text = "%s\n%s\nPrice %d coins" % [
				item["name"], item["desc"], NativeSpecialTable.PRICES[_sel_special]]
		if buy != null:
			buy.text = "BUY %s (%d coins)" % [
				item["name"], NativeSpecialTable.PRICES[_sel_special]]
			buy.disabled = NativeGame.special_free_slot() < 0 \
				or NativeGame.coins < NativeSpecialTable.PRICES[_sel_special]
	elif detail != null:
		detail.text = ""
	if buy != null and _sel_special <= 0:
		buy.text = "SELECT AN ITEM"
		buy.disabled = true


func _cost(u: Dictionary, lvl: int) -> int:
	# Flat price lists (buddy tiers) override the growth formula.
	if u.has("prices"):
		var prices: Array = u["prices"]
		return int(prices[mini(lvl, prices.size() - 1)])
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


func _on_repair() -> void:
	var cost := _repair_cost()
	if NativeGame.coins < cost:
		return
	NativeGame.coins -= cost
	NativeGame.energy = NativeGame.max_energy()
	NativeGame.save()
	NativeAssets.play_sound(62)


func _on_continue() -> void:
	NativeGame.save()
	get_tree().change_scene_to_file("res://native/levels/star_map.tscn")
