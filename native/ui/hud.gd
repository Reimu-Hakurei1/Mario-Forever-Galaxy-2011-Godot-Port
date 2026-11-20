extends CanvasLayer
class_name NativeHUD
## NativeHUD — on-screen display (ports GameMaker `o_hud` / script_hud_drawe).
##
## Lays out the original sprite-based HUD at the same screen positions
## (view space 1024x768, o_hud sits at the view origin):
##   special bar + 4 item slots — top-left, slides in when items exist
##   overheat bar (sprite 483)             — drains right-to-left
##   5 weapon icons (sprites 424/456)      — cross cluster mid-left
##   score / coins digits                  — lower-left column
##   hull bar (sprite 15) + life icons     — bottom-left

const SLOT_COUNT := 4

# Original draw positions (screen px).
const SPECIAL_BAR_POS := Vector2(9, 100)
const SPECIAL_SLOT_X := 29.0
const SPECIAL_SLOT_Y := 150.0
const SPECIAL_SLOT_GAP := 34.0
const HEAT_POS := Vector2(5, 200)
const HEAT_W := 157.0
const WEAPON_POS := [Vector2(44, 316), Vector2(88, 288), Vector2(134, 316),
	Vector2(61, 364), Vector2(117, 364)]
const ENERGY_POS := Vector2(43, 674)
const LIFE_Y := 741.0

# Sprite-font digits — the original builds g_cyferki/g_cyferki2 via
# font_add_sprite(439/440, ord("+"), 0, -2): monospaced glyphs starting
# at '+' (frame = charcode - 43), advance = widest frame - 2px.
const DIGIT_SPR := 439
const DIGIT_GLOW_SPR := 440
const DIGIT_FIRST := 43
const DIGIT_COUNT := 10

var _special_slide := 0.0        # g_wysun_pasek_specjal (0..200)
var _fx_phase := 0.0             # g_efektspecjal (slot-0 pulse)

var _special_bar: TextureRect
var _special_bar_glow: TextureRect
var _special_slots: Array[TextureRect] = []
var _special_slot_glow: Array[TextureRect] = []
var _heat_bar: Control
var _heat_glow: Control
var _gun_icons: Array[TextureRect] = []
var _score_label: Label
var _coins_label: Label
var _digit_cell := 12.0
var _score_digits: Array = []    # [{glow, color}]
var _coin_digits: Array = []
var _energy_bar: TextureRect
var _life_icons: Array[TextureRect] = []
var _buffs_label: Label


func _ready() -> void:
	layer = 10
	_build()


func _build() -> void:
	# --- Special-item bar (slides in from the right when slots fill) ---
	_special_bar = _sprite_rect(NativeAssets.sprite_frame(240, 0), SPECIAL_BAR_POS)
	add_child(_special_bar)
	_special_bar_glow = _sprite_rect(NativeAssets.sprite_frame(241, 0), SPECIAL_BAR_POS)
	_special_bar_glow.modulate.a = 0.6
	add_child(_special_bar_glow)
	for i in SLOT_COUNT:
		var glow := _sprite_rect(null, Vector2.ZERO)
		glow.modulate.a = 0.7
		add_child(glow)
		_special_slot_glow.append(glow)
		var icon := _sprite_rect(null, Vector2.ZERO)
		add_child(icon)
		_special_slots.append(icon)

	# --- Overheat bar: sprite 483, 157x39 region at (5,200) ---
	_heat_glow = _clip_bar(NativeAssets.sprite_frame(483, 1))
	add_child(_heat_glow)
	_heat_bar = _clip_bar(NativeAssets.sprite_frame(483, 0))
	add_child(_heat_bar)

	# --- Weapon icons: 5 slots, sprite 424 (or 456 for 1000-series) ---
	for i in WEAPON_POS.size():
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = WEAPON_POS[i]
		add_child(icon)
		_gun_icons.append(icon)

	# --- Score / coins: sprite-font digits like the original ---
	# x = 152 - width("00000000") (8 monospaced cells), y = 504 / 584.
	_digit_cell = _digit_cell_width()
	var digit_x := 152.0 - 8.0 * _digit_cell
	for i in DIGIT_COUNT:
		_score_digits.append(_digit_pair(digit_x + i * _digit_cell, 504.0))
		_coin_digits.append(_digit_pair(digit_x + i * _digit_cell, 584.0))

	# --- Hull bar (sprite 15, x-stretched by energy fraction) ---
	_energy_bar = TextureRect.new()
	_energy_bar.texture = NativeAssets.sprite_frame(15, 0)
	_energy_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_energy_bar.stretch_mode = TextureRect.STRETCH_SCALE
	_energy_bar.position = ENERGY_POS
	_energy_bar.modulate.a = 0.7
	add_child(_energy_bar)

	# --- Life icons (sprites 462 base + 463 additive mask) ---
	for i in 8:
		var icon := _sprite_rect(NativeAssets.sprite_frame(462, 0), Vector2.ZERO)
		icon.visible = false
		add_child(icon)
		_life_icons.append(icon)

	# --- Bottom-center buff timers ---
	_buffs_label = _make_label("", 16)
	_buffs_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_buffs_label.position = Vector2(-200, -40)
	_buffs_label.custom_minimum_size = Vector2(400, 0)
	_buffs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_buffs_label)


func _process(delta: float) -> void:
	_fx_phase += delta * 600.0     # original: +10 per 60fps frame

	# Special bar slide: eases to 200 (hidden) when all slots empty,
	# decays toward 0 (visible) while any special is held.
	var any_special := false
	for id in NativeGame.special_slots:
		if id > 0:
			any_special = true
			break
	if any_special:
		_special_slide /= 1.0 + delta * 6.0
	else:
		_special_slide = minf(_special_slide + delta * 1200.0, 200.0)
	var slide := _special_slide
	_special_bar.position = SPECIAL_BAR_POS + Vector2(slide, 0)
	_special_bar_glow.position = SPECIAL_BAR_POS + Vector2(slide, 0)
	_special_bar.visible = slide < 190.0
	_special_bar_glow.visible = slide < 190.0

	# Slot icons — sprite 239 frames: icon id (+10 lit variant drawn
	# underneath), pulsing slot 0 like the original sin() scale.
	var pulse := 1.0 + 0.3 * sin(deg_to_rad(_fx_phase))
	for i in SLOT_COUNT:
		var id: int = NativeGame.special_slots[i] if i < NativeGame.special_slots.size() else 0
		var icon := NativeSpecialTable.at(id) if id > 0 else {}
		var frame: int = int(icon.get("icon", 0))
		var slot_pos := Vector2(SPECIAL_SLOT_X + slide + i * SPECIAL_SLOT_GAP, SPECIAL_SLOT_Y)
		var glow := _special_slot_glow[i]
		var slot := _special_slots[i]
		if frame <= 0:
			glow.visible = false
			slot.visible = false
			continue
		glow.visible = true
		slot.visible = true
		glow.texture = NativeAssets.sprite_frame(239, mini(frame + 10, 19))
		slot.texture = NativeAssets.sprite_frame(239, frame)
		var sc := pulse if i == 0 else 1.0
		for r in [glow, slot]:
			# origin (29,34): the draw pos marks that point on the sprite
			r.size = r.texture.get_size() * sc
			r.position = slot_pos - Vector2(29, 34) * sc

	# Overheat bar — drains toward the right edge as heat rises
	# (original samples sprite columns [xoff, end) at x+157*xoff).
	var heat_frac := clampf(NativeGame.overheating / maxf(NativeGame.overheat_max(), 1.0), 0.0, 1.0)
	for clip in [_heat_glow, _heat_bar]:
		var vis_w := HEAT_W * (1.0 - heat_frac)
		clip.position = Vector2(HEAT_POS.x + HEAT_W * heat_frac, HEAT_POS.y)
		clip.size = Vector2(vis_w, 39)
		var tex := clip.get_child(0) as TextureRect
		tex.position.x = -heat_frac * HEAT_W

	_set_digits(_score_digits, NativeGame.score)
	_set_digits(_coin_digits, NativeGame.coins)

	# Hull bar — sprite stretched on x by the energy fraction.
	var en_tex := _energy_bar.texture
	var frac := clampf(NativeGame.energy / maxf(NativeGame.max_energy(), 1.0), 0.0, 1.0)
	_energy_bar.size = Vector2(en_tex.get_width() * frac, en_tex.get_height())

	# Life icons — centered cluster at the bottom, one per life.
	var lives := NativeGame.lives
	for i in _life_icons.size():
		var icon := _life_icons[i]
		if i >= lives:
			icon.visible = false
			continue
		icon.visible = true
		var lx := 88.0 + i * 40.0 - (lives - 1) * 20.0
		icon.position = Vector2(lx - 18, LIFE_Y - 18)
		# dim spare lives like the original's unlit mask look
		icon.modulate.a = 1.0 if i < lives else 0.4

	# Powerup timers — shown only while a buff is running.
	var buffs: Array[String] = []
	if NativeGame.kill_streak >= 3 \
			and Time.get_ticks_msec() <= NativeGame.streak_expiry:
		buffs.append("STREAK x%d" % NativeGame.kill_streak)
	if NativeGame.booster_fire_time > 0.0:
		buffs.append("FLOWER %ds" % ceili(NativeGame.booster_fire_time))
	if NativeGame.booster_boom_time > 0.0:
		buffs.append("FIREBALLS %ds" % ceili(NativeGame.booster_boom_time))
	_buffs_label.text = "   ".join(buffs)
	_buffs_label.visible = not buffs.is_empty()
	_buffs_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))

	# Gun icons — sprite 424 frames are the standard catalog, 456 the
	# weapon-1000 series (frame = id - 1000), like the original HUD.
	for i in _gun_icons.size():
		var wid := NativeGame.weapons[i] if i < NativeGame.weapons.size() else -1
		var tex: Texture2D = null
		if wid >= 1000:
			tex = NativeAssets.sprite_frame(456, wid - 1000)
		elif wid >= 0:
			tex = NativeAssets.sprite_frame(424, wid)
		var icon := _gun_icons[i]
		icon.texture = tex
		if tex == null:
			icon.visible = false
			continue
		icon.visible = true
		var half := tex.get_size() * 0.25   # 0.5 scale, origin-centered
		icon.size = tex.get_size() * 0.5
		icon.position = WEAPON_POS[i] - half
		icon.modulate = Color.WHITE if wid >= 0 else Color(1, 1, 1, 0.18)


func _digit_cell_width() -> float:
	var max_w := 0
	for i in NativeAssets.sprite_frames(DIGIT_SPR).size():
		var t := NativeAssets.sprite_frame(DIGIT_SPR, i)
		if t != null:
			max_w = maxi(max_w, t.get_width())
	return maxf(1.0, max_w - 2.0)   # sep = -2


func _digit_pair(x: float, y: float) -> Dictionary:
	var glow := TextureRect.new()
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.position = Vector2(x, y)
	glow.modulate = Color(1, 1, 1, 0.55)
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	add_child(glow)
	var color := TextureRect.new()
	color.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	color.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	color.position = Vector2(x, y)
	add_child(color)
	return {"glow": glow, "color": color}


func _set_digits(pool: Array, value: int) -> void:
	var s := str(value)
	for i in pool.size():
		var pair: Dictionary = pool[i]
		var ch := s[i] if i < s.length() else " "
		var show := i < s.length()
		for r in [pair["glow"], pair["color"]]:
			r.visible = show
			if not show:
				continue
		var code := ch.unicode_at(0)
		var fi := code - DIGIT_FIRST
		if fi < 0 or fi >= NativeAssets.sprite_frames(DIGIT_SPR).size():
			pair["color"].visible = false
			pair["glow"].visible = false
			continue
		pair["color"].texture = NativeAssets.sprite_frame(DIGIT_SPR, fi)
		var gt := NativeAssets.sprite_frame(DIGIT_GLOW_SPR, fi)
		pair["glow"].texture = gt if gt != null else pair["color"].texture
		# glyphs draw at natural size, advance is the fixed cell width
		for r in [pair["glow"], pair["color"]]:
			var t: Texture2D = r.texture
			r.size = t.get_size() if t != null else Vector2.ZERO


func _sprite_rect(tex: Texture2D, pos: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = pos
	if tex != null:
		r.size = tex.get_size()
	return r


func _clip_bar(tex: Texture2D) -> Control:
	var clip := Control.new()
	clip.clip_contents = true
	clip.size = Vector2(HEAT_W, 39)
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.size = Vector2(HEAT_W, 39)
	clip.add_child(r)
	return clip


func _make_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	return l
