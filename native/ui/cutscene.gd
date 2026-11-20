extends Control
## NativeCutscene — the original's room_animation_* story cinematics.
##
## The legacy anim_1..4 rooms play pre-rendered story cards (data/a/
## txt_*.png dialogue, toad_*/anim_obj_*/hero* character art,
## background*.png backdrops) as timed image sequences. This scene
## reproduces that presentation: full-screen cards crossfading on a
## fixed beat. Any key/click skips the whole sequence.

signal finished

## Scene to open when the sequence ends (empty = just free).
var next_scene := ""

const IMG_DIR := "res://data/a/"
const BEAT := 3.2               # seconds per card
const ANIM1_DATA := "res://data/levels/native/anim_1_slaves.json"
const ANIM3_DATA := "res://data/levels/native/anim_3_slaves.json"
const ANIM4_DATA := "res://data/levels/native/anim_4_slaves.json"
const ANIM2_KOKO := "res://data/levels/native/anim_2_koko.json"

# The four legacy sequences. "opening" is special-cased: it plays the
# real room_animation_1 choreography (spiral text crawl, parallax
# sprite parade, letter zoom — objects/effects/anim_1.gd) before the
# dialogue cards, which approximate anim_2/3.
const SEQUENCES := {
	"opening": [
		"toad_0.png", "txt_11.png", "txt_12.png",
		"toad_1.png", "toad_2.png", "toad_3.png",
		"toad_4.png", "toad_5.png", "toad_6.png",
		"background2.png",
		"anim_obj_0.png", "anim_obj_1.png", "anim_obj_2.png",
		"anim_obj_5.png", "anim_obj_7.png", "anim_obj_8.png",
		"anim_obj_9.png",
	],
	"mid": [
		"background.png",
		"toad_0_1.png", "anim_obj_17.png", "anim_obj_18.png",
		"toad_1_1.png", "anim_obj_19.png",
		"toad_2_1.png", "anim_obj_20.png",
		"toad_3_1.png", "toad_4_1.png",
		"toad_5_1.png", "toad_6_1.png",
	],
	"finale": [
		"background2.png",
		"hero_0.png", "hero_1.png", "hero_2.png", "hero_3.png",
		"hero1_obj_0.png", "hero1_obj_1.png", "hero1_obj_2.png",
		"hero1_obj_3.png", "hero1_obj_4.png",
		"hero2_obj_0.png", "hero2_obj_1.png", "hero2_obj_2.png",
		"hero2_obj_3.png", "hero2_obj_4.png",
		"anim_metroid_0.png", "anim_metroid_1.png", "anim_metroid_2.png",
		"anim_metroid_3.png", "anim_metroid_4.png",
		"anim_metroid_5.png", "anim_metroid_6.png", "anim_metroid_7.png",
		"anim_metroid_8.png", "anim_metroid_9.png", "anim_metroid_10.png",
		"txt_13.png",
	],
}

var _sequence := "opening"
var _layer_a: TextureRect
var _layer_b: TextureRect
var _front := true

# --- room_animation_1 choreography state (objects/effects/anim_1.gd) ---
var _anim1 := false
var _anim_kind := "anim1"       # "anim1" opening or "anim3" mid story
var _anim_phase := 0        # 0 spiral text, 1 scroll whoosh, 2 letter zoom, 3 toad reveal
var _slave_by_idx := {}
var _parade: Control
var _boom_pending: Array = []   # [[at_frame, slave_idx]] disband timeline
var _anim_end_at := -1.0        # frame at which the cinematic hands off
var _pan_goal := 0.0
var _booms: Array = []          # [{rect, t}] explosion sprites

# --- room_animation_4 finale choreography (objects/effects/anim_4.gd) ---
var _a4_phase := 0
var _a4_timer := 0.0
var _speed_paralaxu := -0.75
var _przesow := 1.0
var _przesow2 := 0.0
var _blanker_a4 := 0.0
var _scie_hero := 1.0
var _heart_a := 0.0            # g_dodatek_heart
var _heart2 := 0.0             # g_dodatek2_heart
var _a4_heart: TextureRect
var _a4_blue: ColorRect
var _a4_heroes: Array = []     # [{rect, file}] phases 7-11
var _a4_koko: Array = []       # diving sprites phases 2+
var _a4_over := false

# --- room_animation_2 boss reveal (objects/effects/anim_2.gd +
#     anim_bowser.gd + anim_bowser_2.gd) ---
var _a2_phase := 0
var _a2_timer := 0.0
var _a2_f := 0.0
var _a2_boss: TextureRect
var _a2_boss_y := 1400.0
var _a2_iyor := 10.0
var _a2_dialogue: Array = []
var _a2_dlg_idx := 0
var _a2_dlg_char := 0.0
var _a2_dlg_label: Label
var _a2_army: Array = []
var _a2_clouds: Array = []
var _a2_over := false
var _anim_frame := 0.0
var _anim_speed := 0.0
var _napis_y := 0.0
var _blanker := 1.0
var _sciemnij_list := 0.0
var _list_od_peach := 0.0
var _dim: ColorRect
var _txt_cards: Array = []
var _letter: TextureRect
var _slaves: Array = []     # {rect, x, y, div, idx}
var _bg_strip: TextureRect
var _bg2_strip: TextureRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layer_a = _make_layer()
	_layer_b = _make_layer()
	add_child(_layer_a)
	add_child(_layer_b)
	match _sequence:
		"opening":
			_play_anim1()
		"mid":
			_play_anim3()
		"finale":
			_play_anim4()
		"anim2":
			_play_anim2()
		_:
			var cards: Array = SEQUENCES.get(_sequence, [])
			_play(cards)


func setup(seq: String) -> void:
	_sequence = seq


func _make_layer() -> TextureRect:
	var r := TextureRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.modulate.a = 0.0
	return r


func _tex(file: String) -> Texture2D:
	var img := Image.new()
	if img.load(IMG_DIR + file) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed \
			or event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_skip()


func _skip() -> void:
	set_process_input(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_finish)


func _finish() -> void:
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
	queue_free()


func _play(cards: Array, then := "") -> void:
	var idx := 0
	while idx < cards.size() and is_inside_tree():
		var tex := _tex(cards[idx])
		idx += 1
		if tex == null:
			continue
		var back: TextureRect = _layer_b if _front else _layer_a
		var front: TextureRect = _layer_a if _front else _layer_b
		back.texture = tex
		back.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(back, "modulate:a", 1.0, 0.6)
		if front.texture != null:
			tw.tween_property(front, "modulate:a", 0.0, 0.6)
		_front = not _front
		await get_tree().create_timer(BEAT).timeout
	if not is_inside_tree():
		return
	# Fade out and finish.
	var fade := create_tween().set_parallel()
	fade.tween_property(_layer_a, "modulate:a", 0.0, 0.5)
	fade.tween_property(_layer_b, "modulate:a", 0.0, 0.5)
	await fade.finished
	# Chain into the next cinematic room (the original's room order is
	# anim_1 → anim_2 → anim_3 → anim_4 → map, rooms 52-55 → 51).
	if then == "anim2":
		_play_anim2()
	elif then == "anim3":
		_play_anim3()
	elif then == "anim4":
		_play_anim4()
	elif then != "":
		_finish()
		return
	else:
		_finish()


## --- room_animation_1 (objects/effects/anim_1.gd) ---
## The original opening cinematic: 57-sprite parallax parade scrolling
## on four background layers, ten txt_* cards spiralling into centre
## screen, then Peach's letter (anim_obj_6) zooming in over ~22s.
## Timings below are the script's own frame counters at 60fps.

func _sprite_node(file: String) -> TextureRect:
	var r := TextureRect.new()
	r.texture = _tex(file)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if r.texture != null:
		r.custom_minimum_size = r.texture.get_size()
		r.size = r.texture.get_size()
	return r


func _play_anim1() -> void:
	_anim1 = true
	_anim_kind = "anim1"
	_slave_by_idx.clear()
	# Backdrop — background1.png dimmed, like the original's bg layers.
	var bg := _sprite_node("background1.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(1, 1, 1, 0.4)
	add_child(bg)
	# Parallax strips — the 16px background.png tile scrolling at
	# anim_speed fractions (bg_hspeed 1-4 in the original).
	_bg_strip = _sprite_node("background.png")
	_bg_strip.stretch_mode = TextureRect.STRETCH_TILE
	_bg_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_strip.modulate = Color(1, 1, 1, 0.25)
	add_child(_bg_strip)
	_bg2_strip = _sprite_node("background.png")
	_bg2_strip.stretch_mode = TextureRect.STRETCH_TILE
	_bg2_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg2_strip.modulate = Color(0.6, 0.7, 1.0, 0.12)
	_bg2_strip.position.x = 16
	add_child(_bg2_strip)
	# The sprite parade — extracted g_slave spawn table, inside a
	# container so the disband sequence can pan the camera.
	_parade = Control.new()
	_parade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_parade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_parade)
	_spawn_parade(ANIM1_DATA)
	# The ten spiral text cards — sprites 552-561 = txt_1..txt_10.
	for i in 10:
		var r := _sprite_node("txt_%d.png" % (i + 1))
		r.position = Vector2(512 - r.size.x / 2, 1400)
		r.modulate.a = 0.0
		add_child(r)
		_txt_cards.append(r)
	# Peach's letter + blanker (shared with anim_3).
	_spawn_letter_dim()


## Spawn the g_slave parade from an extracted JSON table into _parade.
func _spawn_parade(path: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return
	_slave_by_idx.clear()
	for s in data.get("slaves", []):
		var file := str(s.get("sprite", ""))
		if file == "" or file == "null" or file.begins_with("sprite_"):
			continue
		var r := _sprite_node(file)
		if r.texture == null:
			continue
		var x := _eval_num(s.get("x"), 512.0)
		var y := _eval_num(s.get("y"), 384.0)
		# GM sprites are centre-origin; smaller tiers pre-scale.
		var sc := 1.0
		var xs := _eval_num(s.get("image_xscale"), 0.0)
		var ys := _eval_num(s.get("image_yscale"), 0.0)
		if xs > 0 and ys > 0:
			sc = xs
		elif str(s.get("smaller", "")) == "1":
			sc = 0.5
		elif str(s.get("smaller", "")) == "2":
			sc = 0.25
		r.scale = Vector2(sc, sc)
		r.position = Vector2(x, y) - r.size * sc / 2.0
		var depth := _eval_num(s.get("depth"), 0.0)
		r.z_index = int(depth / 100.0)
		if str(s.get("visible", "1")) == "0":
			r.modulate.a = 0.0
		_parade.add_child(r)
		var entry := {
			"rect": r, "x": x, "y": y,
			"idx": int(s.get("idx", 0)),
			"div": _slave_div(file, s),
			"anim_obj_5": file == "anim_obj_5.png",
			"anim_obj_2": file == "anim_obj_2.png",
			"hidden": str(s.get("visible", "1")) == "0",
		}
		_slaves.append(entry)
		_slave_by_idx[entry["idx"]] = entry


## Peach's letter sprite + blanker overlay shared by anim_1/anim_3.
func _spawn_letter_dim() -> void:
	_letter = _sprite_node("anim_obj_6.png")
	_letter.position = Vector2(512, 384) - _letter.size / 2.0
	_letter.pivot_offset = _letter.size / 2.0
	_letter.scale = Vector2.ZERO
	add_child(_letter)
	_dim = ColorRect.new()
	_dim.color = Color.BLACK
	_dim.modulate.a = _blanker
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)


## room_animation_3 (objects/effects/anim_3.gd) — the mid-story scene.
## Starts directly in the letter-zoom phase (sekwencja=2), then reveals
## a toad crowd along the bottom and runs the building-disband
## explosion timeline before handing off to the dialogue cards.
func _play_anim3() -> void:
	_anim1 = true
	_anim_kind = "anim3"
	_anim_phase = 3
	_anim_frame = 0.0
	_anim_speed = 0.0
	_blanker = 1.0
	var bg := _sprite_node("background1.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(1, 1, 1, 0.4)
	add_child(bg)
	_bg_strip = _sprite_node("background.png")
	_bg_strip.stretch_mode = TextureRect.STRETCH_TILE
	_bg_strip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_strip.modulate = Color(1, 1, 1, 0.25)
	add_child(_bg_strip)
	_parade = Control.new()
	_parade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_parade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_parade)
	_spawn_parade(ANIM3_DATA)
	_spawn_letter_dim()
	# The original enters sekwencja=2 with blanker=1, so the letter-zoom
	# block self-cancels on the first frame (blanker>=1 → sekwencja=3).
	# Go straight to the reveal: toad row + disband timeline.
	_anim3_enter_reveal()


## Best-effort numeric eval for the few expression-valued spawn coords.
func _eval_num(v, fallback: float) -> float:
	if v == null:
		return fallback
	var s := str(v).strip_edges()
	if s.contains("random"):
		return fallback
	# Handle simple "(a +/- b)" and "a +/- b" forms.
	s = s.strip_edges().trim_prefix("(").trim_suffix(")")
	var parts := s.split("+")
	if parts.size() == 1:
		parts = s.split("-")
		if parts.size() == 2:
			return float(parts[0]) - float(parts[1])
	if parts.size() == 2:
		return float(parts[0]) + float(parts[1])
	return float(s) if s.is_valid_float() else fallback


## Scroll-speed divisor from ev_3_2: anim_obj_2 sprites run 1.8x,
## smaller tier 1 → /2.2, tier 2 → /3, everything else full speed.
func _slave_div(file: String, s: Dictionary) -> float:
	if file == "anim_obj_2.png":
		return 1.8
	match str(s.get("smaller", "0")):
		"1": return 2.2
		"2": return 3.0
	return 1.0


func _process(delta: float) -> void:
	if not _anim1:
		return
	# Original logic runs per frame; run it at 60fps equivalent.
	_anim_frame += delta * 60.0
	_anim_speed_tick()
	_scroll_slaves()
	_scroll_backgrounds()
	_tick_booms()
	if _anim_kind == "anim4" and _anim1:
		_anim4_tick(delta)
	if _anim_kind == "anim2" and _anim1:
		_anim2_tick()
	if _anim_kind != "anim4" and _anim_kind != "anim2":
		match _anim_phase:
			0: _anim1_spiral()
			1: _anim1_whoosh()
			2: _anim1_letter()
			3: _anim3_reveal()
			_: pass


func _anim_speed_tick() -> void:
	# ev_3_2 scroll controller — every phase moves the parade.
	if _anim_kind == "anim4":
		return
	if _anim_phase == 0 and _anim_speed > -2.0:
		_anim_speed -= 0.02


func _scroll_slaves() -> void:
	var a4 := _anim_kind == "anim4"
	for s in _slaves:
		var r: TextureRect = s["rect"]
		var spd := _anim_speed
		if a4:
			# anim_4: front layer at anim_speed, back layer (idx>=100)
			# at anim_speed/2 + paralax — no smaller-divisor, no wrap.
			spd = _anim_speed if int(s["idx"]) < 100 \
				else _anim_speed / 2.0 + _speed_paralaxu
			s["x"] = float(s["x"]) + spd
		else:
			s["x"] = float(s["x"]) + spd / float(s["div"])
		var x: float = s["x"]
		var idx: int = s["idx"]
		if a4:
			s["x"] = x
			r.position = Vector2(x, s["y"]) - r.size * r.scale / 2.0
			continue
		# Wrap rules verbatim from ev_3_2.
		if x <= -500.0 and idx < 22:
			x = 2000.0 if s["anim_obj_5"] else 1100.0
		elif x <= -300.0 and idx >= 46:
			x = 1200.0
		s["x"] = x
		var y: float = s["y"]
		r.position = Vector2(x, y) - r.size * r.scale / 2.0


func _scroll_backgrounds() -> void:
	if _anim_speed == 0.0:
		return   # keep manual pan offsets (anim_3 camera moves)
	if _bg_strip != null:
		_bg_strip.position.x = fmod(_bg_strip.position.x + _anim_speed / 3.0, 16.0) - 16.0
	if _bg2_strip != null:
		_bg2_strip.position.x = fmod(_bg2_strip.position.x + _anim_speed, 16.0) - 16.0


## Phase 0 — the ten txt cards spiral up the screen (ev_8_0 sekwencja 0).
func _anim1_spiral() -> void:
	_blanker = maxf(0.0, _blanker / 1.03)
	_dim.modulate.a = _blanker
	_napis_y += 0.35
	var done := true
	for i in _txt_cards.size():
		var card: TextureRect = _txt_cards[i]
		var y := 600.0 - _napis_y + i * 50.0 + i * i
		card.position = Vector2(512 - card.size.x / 2, y - card.size.y / 2)
		var a: float = card.modulate.a
		if y < 500.0 and y > 300.0 and a < 1.0:
			a = minf(1.0, a + 0.01)
		elif y <= 300.0 and a > 0.0:
			a = maxf(0.0, a - 0.01)
		card.modulate.a = a
		if i == 9 and not (y < 280.0 and a <= 0.0):
			done = false
	if done and _blanker <= 0.01:
		_anim_phase = 1
		_anim_frame = 0.0


## Phase 1 — scroll whoosh: anim_speed ramps to -50 over 300f then
## decays; the parade blurs past (ev_8_0 sekwencja 1).
func _anim1_whoosh() -> void:
	if _anim_frame < 300.0 and _anim_speed > -50.0:
		_anim_speed -= 0.15
	elif _anim_speed >= -0.01:
		_anim_speed = 0.0
		_anim_phase = 2
		_anim_frame = 0.0
		return
	_anim_speed /= 1.03


## Phase 2 — Peach's letter zooms from 0 to full over ~22s with a
## -300°→0° unroll (ev_8_0 sekwencja 2), then fades to the cards.
func _anim1_letter() -> void:
	if _anim_frame >= 100.0:
		_list_od_peach = minf(1.0, _list_od_peach + 0.01)
	_letter.scale = Vector2(_list_od_peach, _list_od_peach)
	_letter.rotation = deg_to_rad(-300.0 + _list_od_peach * 300.0)
	_letter.modulate.a = 1.0 - _sciemnij_list
	if _anim_frame > 1300.0:
		_sciemnij_list = minf(1.0, _sciemnij_list + 0.01)
	if _anim_frame > 1350.0:
		_blanker += 0.01
	_dim.modulate.a = _blanker
	if _blanker >= 1.0:
		if _anim_kind == "anim3":
			_anim3_enter_reveal()
		else:
			_anim1_done()


func _anim1_done() -> void:
	_anim1 = false
	_free_cinematic()
	# Cards approximate the interstitial dialogue; then anim_2's boss
	# reveal and Bowser's awakening speech.
	_play(SEQUENCES["opening"], "anim2")


func _anim2_done() -> void:
	_anim1 = false
	_free_cinematic()
	_play(SEQUENCES["mid"], "anim3")


func _anim3_done() -> void:
	_anim1 = false
	_free_cinematic()
	_play(SEQUENCES["finale"], "anim4")


func _free_cinematic() -> void:
	for c in _txt_cards:
		c.queue_free()
	_txt_cards.clear()
	if is_instance_valid(_parade):
		_parade.queue_free()
	_slaves.clear()
	_slave_by_idx.clear()
	if is_instance_valid(_letter):
		_letter.queue_free()
	if is_instance_valid(_dim):
		_dim.queue_free()
	if is_instance_valid(_bg_strip):
		_bg_strip.queue_free()
	if is_instance_valid(_bg2_strip):
		_bg2_strip.queue_free()
	# anim_4 extras.
	for h in _a4_heroes:
		(h["rect"] as TextureRect).queue_free()
	_a4_heroes.clear()
	for k in _a4_koko:
		(k["rect"] as TextureRect).queue_free()
	_a4_koko.clear()
	if is_instance_valid(_a4_heart):
		_a4_heart.queue_free()
	if is_instance_valid(_a4_blue):
		_a4_blue.queue_free()
	if is_instance_valid(_a4_dim):
		_a4_dim.queue_free()
	_booms.clear()


## anim_3 sekwencja 2→3 transition: hide slave 21, array the toad row
## along the bottom (slaves 22-30 at the scripted x positions), scatter
## 15 random toads (31-45), then start the disband timeline.
func _anim3_enter_reveal() -> void:
	_anim_phase = 3
	_anim_frame = 0.0
	_blanker = 1.0
	_hide_slave(21)
	var row := {
		22: Vector2(650, 716), 23: Vector2(250, 711), 24: Vector2(800, 711),
		25: Vector2(0, 711), 26: Vector2(1024, 711), 27: Vector2(1224, 711),
		28: Vector2(-200, 711), 29: Vector2(-500, 711), 30: Vector2(-700, 711),
	}
	for idx in row:
		_place_slave(idx, row[idx])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 15:
		var idx := 31 + i
		if _slave_by_idx.has(idx):
			var s: Dictionary = _slave_by_idx[idx]
			_move_slave(s, Vector2(rng.randf() * 1024.0, float(s["y"])))
			s["rect"].modulate.a = 1.0
	# Building-disband explosion timeline (ev_3_2 milestones, frames
	# after niszcz_budynki): slave -> approx frame offset.
	_boom_pending = [
		[50, 23], [120, 30], [280, 24], [350, 29], [380, 28],
		[420, 27], [440, 26], [520, 25], [750, 22],
	]
	_anim_end_at = 750.0 + 140.0


func _hide_slave(idx: int) -> void:
	if _slave_by_idx.has(idx):
		(_slave_by_idx[idx]["rect"] as TextureRect).modulate.a = 0.0


func _place_slave(idx: int, pos: Vector2) -> void:
	if _slave_by_idx.has(idx):
		_move_slave(_slave_by_idx[idx], pos)


func _move_slave(s: Dictionary, pos: Vector2) -> void:
	s["x"] = pos.x
	s["y"] = pos.y
	var r: TextureRect = s["rect"]
	r.position = Vector2(pos.x, pos.y) - r.size * r.scale / 2.0
	r.modulate.a = 1.0


## anim_3 sekwencja 3 — blanker fades, disband explosions run, camera
## pans to each target like view_xview chasing g_bulding_goto_boom.
func _anim3_reveal() -> void:
	_blanker = maxf(0.0, _blanker / 1.01)
	_dim.modulate.a = _blanker
	# Disband timeline.
	while not _boom_pending.is_empty() and _anim_frame >= float(_boom_pending[0][0]) + 60.0:
		var idx: int = _boom_pending.pop_front()[1]
		if _slave_by_idx.has(idx):
			var s: Dictionary = _slave_by_idx[idx]
			_boom(Vector2(s["x"], s["y"]))
			(s["rect"] as TextureRect).modulate.a = 0.0
			# Camera pans so the target sits at screen x ~612.
			_pan_goal = -(float(s["x"]) - 612.0)
	# Ease the parade (and background layers, like the panned camera)
	# toward the pan goal.
	if _parade != null and absf(_parade.position.x - _pan_goal) > 0.5:
		var dx := move_toward(_parade.position.x, _pan_goal, 6.0) - _parade.position.x
		_parade.position.x += dx
		if _bg_strip != null:
			_bg_strip.position.x += dx
		if _bg2_strip != null:
			_bg2_strip.position.x += dx
	if _anim_frame >= _anim_end_at:
		_anim3_done()


## Explosion flash at a parade position — sprite 14 like NativeExplosion.
func _boom(pos: Vector2) -> void:
	var frames := NativeAssets.sprite_frames(14)
	if frames.is_empty():
		return
	var r := TextureRect.new()
	r.texture = frames[0]
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sz := r.texture.get_size() * 2.0
	r.custom_minimum_size = sz
	r.size = sz
	r.pivot_offset = sz / 2.0
	r.position = pos - sz / 2.0
	r.z_index = 500
	add_child(r)
	_booms.append({"rect": r, "t": 0.0})


func _tick_booms() -> void:
	for b in _booms.duplicate():
		b["t"] = float(b["t"]) + 1.0
		var r: TextureRect = b["rect"]
		var k: float = float(b["t"]) / 30.0
		if k >= 1.0 or not is_instance_valid(r):
			r.queue_free()
			_booms.erase(b)
			continue
		r.scale = Vector2.ONE * (0.3 + k * 1.3)
		r.modulate.a = 1.0 - k


## --- room_animation_4 finale (objects/effects/anim_4.gd) ---
## Castle battlefield scroll → caption cards → camera pan → creatures
## dive → fat-boy squadron explodes → fade to blue heart beat → the
## four heroes fly in one by one → converge and depart.

func _play_anim4() -> void:
	_anim1 = true
	_anim_kind = "anim4"
	_anim_phase = 0
	_anim_frame = 0.0
	_anim_speed = 3.0          # g_ustaw_speed forces anim_speed=3
	_speed_paralaxu = -0.75
	_przesow = 1.0
	_przesow2 = 0.0
	_blanker = 1.0
	_blanker_a4 = 0.0
	_scie_hero = 1.0
	_heart_a = 0.0
	_heart2 = 0.0
	_a4_phase = 0
	_a4_timer = 0.0
	_a4_over = false
	# Backdrop.
	var bg := _sprite_node("background1.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(1, 1, 1, 0.4)
	bg.name = "a4_bg"
	add_child(bg)
	# Two-layer parallax parade (idx 0-11 front, 100-114 back).
	_parade = Control.new()
	_parade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_parade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_parade)
	_spawn_parade(ANIM4_DATA)
	# Blanker overlays — _dim for the entry fade, _a4_dim for g_blanker.
	_dim = ColorRect.new()
	_dim.color = Color.BLACK
	_dim.modulate.a = _blanker
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_a4_blue = ColorRect.new()
	_a4_blue.color = Color(0, 0, 0.4)
	_a4_blue.modulate.a = 0.0
	_a4_blue.set_anchors_preset(Control.PRESET_FULL_RECT)
	_a4_blue.visible = false
	add_child(_a4_blue)
	# txt_13 "heart" caption for phase 6.
	_a4_heart = _sprite_node("txt_13.png")
	_a4_heart.position = Vector2(512, 384) - _a4_heart.size / 2.0
	_a4_heart.pivot_offset = _a4_heart.size / 2.0
	_a4_heart.modulate.a = 0.0
	_a4_heart.visible = false
	add_child(_a4_heart)
	# Entry fade-in like the other rooms (g_blanker_blank decays).
	set_process(true)


func _anim4_tick(_delta: float) -> void:
	if _a4_over:
		return
	# Entry fade — g_blanker_blank decays like the sibling rooms.
	_blanker = maxf(0.0, _blanker / 1.05)
	if is_instance_valid(_dim):
		_dim.modulate.a = _blanker
	_a4_timer += 1.0   # approx one frame per process tick at 60fps
	# Phase 0→1: caption objects slide in at 200f (objects 562-564 ≈
	# txt_11/txt_12/anim_obj_7 sprites entering from the left).
	if _a4_phase == 0 and _a4_timer > 200.0:
		_a4_phase = 1
		_a4_timer = 0.0
		for i in 3:
			var file: String = ["txt_11.png", "txt_12.png", "anim_obj_7.png"][i]
			var r := _sprite_node(file)
			var x := -100.0 - i * 100.0
			var y := 650.0 - i * 32.0
			r.position = Vector2(x, y) - r.size / 2.0
			_parade.add_child(r)
			_slaves.append({"rect": r, "x": x, "y": y, "idx": 50,
				"div": 1.0, "anim_obj_5": false, "anim_obj_2": false})
	# Phase 1: camera pans right while captions scroll; at 100f the
	# diving creatures spawn (obj 550 "koko", dokodleci distances).
	if _a4_phase == 1:
		if _przesow2 > 100.0 and _przesow > 0.0:
			_przesow = maxf(0.0, _przesow - 0.002)
		_przesow2 += _przesow
		_parade.position.x = -_przesow2
		if _speed_paralaxu < 0.0:
			_speed_paralaxu /= 1.05
		if _a4_timer > 100.0:
			_a4_phase = 2
			_a4_timer = 0.0
			var koko := [
				[600, 0.2, 200], [700, 0.2, 300], [900, 0.4, 200],
				[800, 0.1, 350], [500, 0.3, 100], [400, 0.25, 100],
				[800, 0.25, 250], [850, 0.1, 50],
			]
			for i in koko.size():
				var r := _sprite_node("anim_metroid_%d.png" % (i % 11))
				var s: float = koko[i][1]
				r.scale = Vector2(s, s)
				r.position = Vector2(koko[i][0], -300) - r.size * s / 2.0
				r.z_index = 400
				add_child(r)
				_a4_koko.append({"rect": r, "y": -300.0,
					"v": 2.0 + float(koko[i][2]) / 300.0})
	# Phase 2 (200f) → phase 3.
	if _a4_phase == 2 and _a4_timer > 200.0:
		_a4_phase = 3
		_a4_timer = 0.0
	# Phase 3: at 300f the fat-boy squadron (slaves 108-114) is destroyed
	# in a centre-screen explosion with a radial-blur shake.
	if _a4_phase == 3:
		if _a4_timer > 300.0:
			_a4_phase = 4
			_a4_timer = 0.0
			for i in range(108, 115):
				_hide_slave(i)
			_boom(Vector2(512, 384))
			_shake = 200.0
	# Phase 4: blanker fades in, paralax decays; at blanker>=1.1 the
	# hero fade runs, then everything hides → phase 5.
	if _a4_phase == 4:
		if _a4_timer > 400.0:
			_blanker_a4 = minf(1.2, _blanker_a4 + 0.01)
		_speed_paralaxu /= 1.01
		_a4_dim_tick()
		if _blanker_a4 >= 1.1:
			_scie_hero = maxf(0.0, _scie_hero - 0.01)
			if _scie_hero <= 0.0:
				_a4_phase = 5
				_a4_timer = 0.0
				for s in _slaves:
					(s["rect"] as TextureRect).modulate.a = 0.0
	# Phase 5 (60f) → phase 6 blue heart beat.
	if _a4_phase == 5 and _a4_timer > 60.0:
		_a4_phase = 6
		_a4_timer = 0.0
		_heart_a = 1.0
		_heart2 = 1.0
		_a4_blue.visible = true
		_a4_heart.visible = true
	# Phase 6: blue wash + beating txt_13 for ~600f.
	if _a4_phase == 6:
		_a4_blue.modulate.a = _heart2
		_a4_heart.modulate.a = _heart_a
		var hs := 0.8 - _heart2
		_a4_heart.scale = Vector2(hs, hs)
		_heart2 = maxf(0.0, _heart2 - 0.0005)
		if _a4_timer > 500.0:
			_heart_a /= 1.3
			_heart2 /= 1.3
		if _a4_timer > 600.0:
			_a4_phase = 7
			_a4_timer = 0.0
			_heart_a = 0.0
			_heart2 = 0.0
			_a4_blue.visible = false
			_a4_heart.visible = false
	# Phases 7-10: heroes fly across one at a time (sprites 523-526).
	if _a4_phase >= 7 and _a4_phase <= 10:
		_a4_hero_tick()
	# Phase 11: all four converge and depart → cinematic over.
	if _a4_phase == 11:
		_a4_hero_tick()
	# Diving creatures keep falling throughout.
	for k in _a4_koko.duplicate():
		k["y"] = float(k["y"]) + float(k["v"])
		var r: TextureRect = k["rect"]
		r.position.y = float(k["y"]) - r.size.y * r.scale.y / 2.0
		if float(k["y"]) > 820.0:
			r.queue_free()
			_a4_koko.erase(k)


var _shake := 0.0
var _a4_dim: ColorRect


func _a4_dim_tick() -> void:
	if _a4_dim == null:
		_a4_dim = ColorRect.new()
		_a4_dim.color = Color.BLACK
		_a4_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_a4_dim.z_index = 800
		add_child(_a4_dim)
	_a4_dim.modulate.a = clampf(_blanker_a4, 0.0, 1.0)
	# Radial-blur shake approximation: jitter the parade while _shake>0.
	if _shake > 0.0:
		_parade.position.x += randf_range(-_shake, _shake) * 0.02
		_parade.position.y = randf_range(-_shake, _shake) * 0.02
		_shake = maxf(0.0, _shake - 8.0)


## Hero fly-in (phases 7-10) and convergence (phase 11) — the draw_sprite_ext
## choreography from ev_8_0 verbatim.
func _a4_hero_tick() -> void:
	# timer += 2 per frame in the original; our _a4_timer counts frames.
	if _a4_phase <= 10:
		_a4_timer += 1.0   # extra +1 to approximate timer+=2
		_heart2 += 2.0
		if _a4_timer < 60.0 and _heart_a < 1.0:
			_heart_a += 0.05
		if _a4_timer > 60.0:
			_heart_a /= 1.15
		if not _a4_heroes.is_empty():
			var h: Dictionary = _a4_heroes[0]
			var r: TextureRect = h["rect"]
			var spec: Array = h["spec"]
			r.position = Vector2(spec[0] + spec[2] * _heart2,
				spec[1]) - r.size * r.scale / 2.0
			r.scale = Vector2.ONE * (1.0 + _heart2 / 300.0)
			r.modulate.a = _heart_a
		if _a4_timer > 100.0 and _heart_a < 0.01:
			for h in _a4_heroes:
				(h["rect"] as TextureRect).queue_free()
			_a4_heroes.clear()
			_heart_a = 0.0
			_heart2 = 0.0
			if _a4_phase == 10:
				_a4_phase = 11
				_a4_timer = 0.0
				_a4_spawn_converge()
			else:
				_a4_phase += 1
				_a4_timer = 0.0
				_a4_spawn_flyin(_a4_phase)
		return
	# Phase 11 — four heroes converge then fly off.
	_heart2 += 1.0
	if _a4_timer < 60.0 and _heart_a < 1.0:
		_heart_a += 0.02
	if _a4_timer > 260.0:
		_heart_a /= 1.05
	for h in _a4_heroes:
		var r: TextureRect = h["rect"]
		var spec: Array = h["spec"]   # [base_x_expr_sign, y, dir]
		var x: float
		var s := 1.0 + _heart2 / 1700.0
		match int(h["slot"]):
			0: x = 512.0 + _heart2 / 11.0      # hero_0 right-down
			1: x = 300.0 - _heart2 / 11.0      # hero_1 left-up
			2: x = 700.0 + _heart2 / 11.0      # hero_2 right-up
			_: x = 512.0 + _heart2 / 11.0      # hero_3 right-down
		var y: float = [500.0, 350.0, 400.0, 250.0][int(h["slot"])]
		r.position = Vector2(x, y) - r.size * s / 2.0
		r.scale = Vector2(s, s)
		r.modulate.a = _heart_a
	if _a4_timer > 260.0 and _heart_a <= 0.01:
		_anim4_done()


func _a4_spawn_flyin(phase: int) -> void:
	# Phases 7-10 map to hero_0..hero_3 alternating left/right entries.
	var file: String = "hero_%d.png" % (phase - 7)
	var r := _sprite_node(file)
	r.modulate.a = 0.0
	add_child(r)
	var left := (phase == 7 or phase == 10)
	var sx := 300.0 if left else 700.0
	var dir := 1.0 if left else -1.0
	var y := 400.0
	_a4_heroes.append({"rect": r, "slot": phase - 7,
		"spec": [sx, y, dir]})


func _a4_spawn_converge() -> void:
	for i in 4:
		var r := _sprite_node("hero_%d.png" % i)
		r.modulate.a = 0.0
		add_child(r)
		_a4_heroes.append({"rect": r, "slot": i, "spec": [0, 0, 0]})


func _anim4_done() -> void:
	_a4_over = true
	_anim1 = false
	_free_cinematic()
	# The finale cards already played between anim_3 and anim_4.
	_finish()


## --- room_animation_2: Bowser's ship reveal + awakening speech ---
## ev_8_0 phases 0-4 choreograph the boss ascent/descent; ev_3_0
## phases 5-11 cover the dialogue wait, the 35-ship army dive and the
## blur/blink outro. Sprite approximations: boss hull = sprite 328,
## army = anim_metroid strips (the original's obj-550 "koko").

const A2_DIALOGUE := [
	"HAHAHAHA!!!#WELL WELL WELL#I HAVE#FINALLY#AWAKENED.",
	"TIME TO RUN#INTO SOME#PARTY.",
	"PREPARE TO#TAKE OFF#MY ARMY!",
	"HAHAHA!#I HOPE THEY#WILL BE#GLAD TO#SEE ME!",
	"BUAHAHA!",
]

func _play_anim2() -> void:
	_anim1 = true
	_anim_kind = "anim2"
	_anim_phase = 0
	_a2_phase = 0
	_a2_timer = 0.0
	_a2_f = 0.0
	_a2_over = false
	_a2_boss_y = 1400.0
	_a2_iyor = 10.0
	_a2_dialogue = A2_DIALOGUE
	_a2_dlg_idx = 0
	_a2_dlg_char = 0.0
	_blanker = 1.0
	# Backdrop + entry blanker.
	var bg := _sprite_node("background1.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.6, 0.6, 0.8, 0.5)
	bg.name = "a2_bg"
	add_child(bg)
	# Cloud layers — four descending bands like bg_y[1..4].
	for i in 4:
		var c := ColorRect.new()
		c.color = Color(0.75, 0.75, 0.85).lerp(Color(0.4, 0.4, 0.55), i / 3.0)
		c.position = Vector2(-50, -120.0 * (i + 1))
		c.size = Vector2(1124, 130)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		_a2_clouds.append({"rect": c, "y": -120.0 * (i + 1), "div": 8.0 - i})
	# Boss ship — sprite 328 hull, rises from below with engine shake.
	var frames := NativeAssets.sprite_frames(328)
	if not frames.is_empty():
		_a2_boss = TextureRect.new()
		_a2_boss.texture = frames[0]
		_a2_boss.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_a2_boss.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_a2_boss.custom_minimum_size = _a2_boss.texture.get_size()
		_a2_boss.size = _a2_boss.texture.get_size()
		_a2_boss.pivot_offset = _a2_boss.size / 2.0
		_a2_boss.position = Vector2(512, _a2_boss_y) - _a2_boss.size / 2.0
		_a2_boss.z_index = 300
		add_child(_a2_boss)
	# Dialogue label — typewriter like anim_bowser_2's draw_text.
	_a2_dlg_label = Label.new()
	_a2_dlg_label.position = Vector2(212, 214)
	_a2_dlg_label.add_theme_font_size_override("font_size", 22)
	_a2_dlg_label.add_theme_color_override("font_color", Color.WHITE)
	_a2_dlg_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_a2_dlg_label.add_theme_constant_override("shadow_offset_x", 2)
	_a2_dlg_label.add_theme_constant_override("shadow_offset_y", 2)
	_a2_dlg_label.visible = false
	add_child(_a2_dlg_label)
	_dim = ColorRect.new()
	_dim.color = Color.BLACK
	_dim.modulate.a = _blanker
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)


func _anim2_tick() -> void:
	if _a2_over:
		return
	_a2_f += 1.0
	_a2_timer += 1.0
	# Cloud bands descend with the accelerating chmurk speed (ev_8_0 p0).
	if _a2_phase == 0:
		var chm := minf(4.0, _a2_f * 0.02)
		for cl in _a2_clouds:
			cl["y"] = float(cl["y"]) + chm / float(cl["div"])
			(cl["rect"] as ColorRect).position.y = float(cl["y"])
			if float(cl["y"]) > 900.0:
				(cl["rect"] as ColorRect).visible = false
		# Random birds crossing the top every ~6 frames.
		if int(_a2_f) % 6 == 0:
			var r := _sprite_node("anim_metroid_%d.png" % (randi() % 11))
			r.position = Vector2(randf() * 1100.0 - 50.0, -80.0)
			r.scale = Vector2(0.4, 0.4)
			r.z_index = 250
			add_child(r)
			_a2_army.append({"rect": r, "x": r.position.x, "y": -80.0,
				"v": randf_range(1.5, 3.0)})
	# Boss ascent — iyor grows each frame (anim_bowser ev_8_0).
	if _a2_phase <= 1 and is_instance_valid(_a2_boss):
		_a2_boss_y -= _a2_iyor
		_a2_iyor += 1.0
		_a2_boss.position = Vector2(512, _a2_boss_y) - _a2_boss.size / 2.0
		_shake = 6.0
		if _a2_boss_y < -2200.0:
			_a2_boss.visible = false
	# p0 → p1 once the boss has cleared the top and ~100f pass.
	if _a2_phase == 0 and _a2_boss_y < -2200.0 and _a2_timer > 100.0:
		_a2_phase = 1
		_a2_timer = 0.0
		_blanker = 1.0
	# p1 (100f) → boss re-enters left and crosses (p2/p3 simplified
	# into one glide), then descends to centre (p4).
	if _a2_phase == 1 and _a2_timer > 100.0:
		_a2_phase = 2
		_a2_timer = 0.0
		_blanker = 1.0
		if is_instance_valid(_a2_boss):
			_a2_boss.visible = true
			_a2_boss_y = 384.0
			_a2_boss.position = Vector2(-400, _a2_boss_y) - _a2_boss.size / 2.0
	if _a2_phase == 2:
		_blanker = maxf(0.0, _blanker / 1.05)
		_a2_boss.position.x += 4.0   # crosses left→right
		if _a2_timer > 250.0:
			_a2_phase = 3
			_a2_timer = 0.0
			_blanker = 1.0
	if _a2_phase == 3:
		_blanker = maxf(0.0, _blanker / 1.05)
		# Descend to screen centre (512, 384) like ev_8_0 p4→p5.
		var target := Vector2(512, 384) - _a2_boss.size / 2.0
		_a2_boss.position = _a2_boss.position.lerp(target, 0.02)
		if _a2_timer > 160.0:
			_a2_phase = 4
			_a2_timer = 0.0
			_blanker = 1.0
	# p4 (150f) → phase 6: Bowser's awakening dialogue.
	if _a2_phase == 4:
		_blanker = maxf(0.0, _blanker / 1.05)
		if _a2_timer > 150.0:
			_a2_phase = 6
			_a2_timer = 0.0
	# p6: typewriter dialogue — 5f/char, # = line break, 150f hold.
	if _a2_phase == 6:
		_blanker = maxf(0.0, _blanker / 1.05)
		if _a2_dlg_idx < _a2_dialogue.size():
			_a2_dlg_label.visible = true
			var line: String = _a2_dialogue[_a2_dlg_idx]
			var shown := line.substr(0, int(_a2_dlg_char))
			_a2_dlg_label.text = shown.replace("#", "\n")
			_a2_dlg_char += 0.2   # ~5 frames per char
			if _a2_dlg_char >= line.length():
				_a2_dlg_char = line.length()
				_a2_dlg_hold += 1.0
				if _a2_dlg_hold > 150.0:
					_a2_dlg_idx += 1
					_a2_dlg_char = 0.0
					_a2_dlg_hold = 0.0
					_a2_dlg_label.text = ""
		else:
			_a2_phase = 7
			_a2_timer = 0.0
			_a2_dlg_label.visible = false
			if is_instance_valid(_a2_boss):
				_a2_boss.visible = false
			_spawn_a2_army()
	# p7 (450f): army dive + camera drift; then three 60f blur blips
	# (p8/p9/p10) and the 600f outro (p11).
	if _a2_phase == 7:
		_blanker = maxf(0.0, _blanker / 1.05)
		if _a2_timer > 450.0:
			_a2_phase = 8
			_a2_timer = 0.0
			_blanker = 1.0
	if _a2_phase == 8 and _a2_timer > 60.0:
		_a2_phase = 9
		_a2_timer = 0.0
		_blanker = 1.0
	if _a2_phase == 9 and _a2_timer > 60.0:
		_a2_phase = 10
		_a2_timer = 0.0
		_blanker = 1.0
	if _a2_phase == 10 and _a2_timer > 60.0:
		_a2_phase = 11
		_a2_timer = 0.0
		_blanker = 1.0
	if _a2_phase == 11:
		_blanker = maxf(0.0, _blanker / 1.05)
		if _a2_timer > 600.0:
			# blanker2 fade-out then hand off.
			_blanker = minf(1.0, _blanker + 0.01)
			if _blanker >= 1.0:
				_anim2_done()
	# Ambient motion: birds/army dive, clouds keep sinking, shake.
	for k in _a2_army.duplicate():
		k["y"] = float(k["y"]) + float(k.get("v", 2.0))
		var r: TextureRect = k["rect"]
		r.position = Vector2(float(k["x"]), float(k["y"]))
		if float(k["y"]) > 820.0:
			r.queue_free()
			_a2_army.erase(k)
	if _a2_phase >= 7:
		for cl in _a2_clouds:
			if (cl["rect"] as ColorRect).visible:
				cl["y"] = float(cl["y"]) + 0.5
				(cl["rect"] as ColorRect).position.y = float(cl["y"])
	if is_instance_valid(_dim):
		_dim.modulate.a = clampf(_blanker, 0.0, 1.0)
	if _shake > 0.0:
		if _parade != null:
			_parade.position.x += randf_range(-_shake, _shake) * 0.02
		_shake = maxf(0.0, _shake - 1.0)


var _a2_dlg_hold := 0.0


## The 35-ship army dive from anim_2 ev_3_0 phase 7 (anim_2_koko.json).
func _spawn_a2_army() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ANIM2_KOKO))
	if typeof(data) != TYPE_DICTIONARY:
		return
	for k in data.get("koko", []):
		var i := _a2_army.size()
		var r := _sprite_node("anim_metroid_%d.png" % (i % 11))
		var s: float = float(k.get("xs", 1.0))
		r.scale = Vector2(s, s)
		r.position = Vector2(float(k["x"]), float(k["y"])) - r.size * s / 2.0
		r.z_index = int(-float(k.get("depth", 0)) / 100.0)
		add_child(r)
		# iyor ≈ descent speed; deep spawns take proportionally longer.
		_a2_army.append({"rect": r, "x": float(k["x"]),
			"y": float(k["y"]), "v": maxf(1.0, float(k.get("iyor", 10.0)) / 8.0)})
