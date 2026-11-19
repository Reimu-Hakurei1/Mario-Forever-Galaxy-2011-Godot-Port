extends CanvasLayer
class_name NativeHUD
## NativeHUD — on-screen display (ports GameMaker `o_hud`).
##
## Shows the values players actually watch: score, hull energy, lives,
## weapon heat, and coins. Built entirely in code so it stays a single
## readable file; swap in themed controls later without touching gameplay.

const MARGIN := 16

var _score_label: Label
var _energy_bar: ProgressBar
var _heat_bar: ProgressBar
var _lives_label: Label
var _coins_label: Label
var _buffs_label: Label          # active powerup timers (shield/overdrive)
var _special_label: Label        # the four G.specialslot items


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	# --- Top-left: score + lives + coins ---
	var top_left := VBoxContainer.new()
	top_left.position = Vector2(MARGIN, MARGIN)
	top_left.add_theme_constant_override("separation", 2)
	add_child(top_left)

	_score_label = _make_label("SCORE 0", 20)
	top_left.add_child(_score_label)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 16)
	top_left.add_child(stats)
	_lives_label = _make_label("x3", 16)
	stats.add_child(_lives_label)
	_coins_label = _make_label("o 0", 16)
	stats.add_child(_coins_label)

	# --- Top-right: hull energy + weapon heat bars ---
	var top_right := VBoxContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.position = Vector2(-MARGIN - 220, MARGIN)
	top_right.custom_minimum_size = Vector2(220, 0)
	top_right.add_theme_constant_override("separation", 4)
	add_child(top_right)

	_energy_bar = _make_bar(Color(0.2, 0.9, 0.3), "HULL")
	top_right.add_child(_energy_bar)
	_heat_bar = _make_bar(Color(0.9, 0.5, 0.1), "HEAT")
	top_right.add_child(_heat_bar)

	# Special-item ring — shows the four slots, slot 0 (X fires it)
	# marked with ▶. Hidden when the hero carries no specials.
	_special_label = _make_label("", 13)
	top_right.add_child(_special_label)

	# --- Bottom-center: active powerup timers ---
	_buffs_label = _make_label("", 16)
	_buffs_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_buffs_label.position = Vector2(-200, -40)
	_buffs_label.custom_minimum_size = Vector2(400, 0)
	_buffs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_buffs_label)


func _process(_delta: float) -> void:
	_score_label.text = "SCORE %d" % NativeGame.score
	_lives_label.text = "x%d" % NativeGame.lives
	_coins_label.text = "o %d" % NativeGame.coins

	_energy_bar.value = NativeGame.energy
	_energy_bar.max_value = NativeGame.max_energy()
	# Heat bar fills toward the overheat cap so players see the lockout
	# coming before it happens.
	_heat_bar.max_value = NativeGame.overheat_max()
	_heat_bar.value = NativeGame.overheating

	# Powerup timers — shown only while a buff is running so the bar
	# area stays clean during normal play.
	var buffs: Array[String] = []
	if NativeGame.kill_streak >= 3 \
			and Time.get_ticks_msec() <= NativeGame.streak_expiry:
		buffs.append("STREAK x%d" % NativeGame.kill_streak)
	if NativeGame.shield_time > 0.0:
		buffs.append("SHIELD %ds" % ceili(NativeGame.shield_time))
	if NativeGame.overdrive_time > 0.0:
		buffs.append("OVERDRIVE %ds" % ceili(NativeGame.overdrive_time))
	_buffs_label.text = "   ".join(buffs)
	_buffs_label.visible = not buffs.is_empty()
	if NativeGame.shield_time > 0.0:
		_buffs_label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	else:
		_buffs_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))

	# Special ring — rebuild the short text each frame (4 slots, cheap).
	var parts: Array[String] = []
	for i in NativeGame.special_slots.size():
		var id: int = NativeGame.special_slots[i]
		if id <= 0:
			continue
		var item := NativeSpecialTable.at(id)
		parts.append("%s%s" % ["▶" if i == 0 else " ", item["name"]])
	_special_label.text = "   ".join(parts)
	_special_label.visible = not parts.is_empty()


func _make_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	# Dark outline keeps text readable over any background.
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _make_bar(color: Color, caption: String) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 14)
	bar.show_percentage = false
	# Stylebox-less default look; tint via modulate on the fill.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 10)
	cap.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	cap.position = Vector2(4, -2)
	bar.add_child(cap)
	return bar
