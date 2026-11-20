extends CanvasLayer
## NativeNextMap — ports objects/ui/next_map_obj.gd (room 44), the
## inter-map flight briefing played between star maps. The hero ship and
## Toad's pod warp in under inertial steering, trade the original
## NEXT_MAP banter in two separate speech balloons, then the ship
## boosts off-screen while the scene darkens and hands off to the
## destination map. Set `destination` + `hero_index` before add_child.

const STARS := 90
const LOGICAL := Vector2(1024.0, 768.0)

var destination := 1          ## map index being flown to (1-based world)
var hero_index := 0           ## G.playernumber[0] — selects ship frame
var hero_name := ""

var _scale := 1.0
var _world := Control.new()
var _stars: Array[ColorRect] = []
var _ship: Control = null
var _ship_glow: TextureRect = null
var _ship_hull: TextureRect = null
var _exhaust: TextureRect = null
var _exhaust_frame := 0
var _toad: TextureRect = null
var _toad_frame := 0
var _ship_p := {"pos": Vector2.ZERO, "vel": Vector2.ZERO,
	"tar": Vector2.ZERO, "warp": 0.0, "iora": Vector2.ZERO,
	"iyor": 10.0, "ixor": 1.0, "phase": 0}
var _toad_p := {"pos": Vector2.ZERO, "vel": Vector2.ZERO,
	"tar": Vector2.ZERO, "warp": 0.0, "iora": Vector2.ZERO}
var _bg_vspeed := 0.0
var _phase := 0              ## 0 fly-in, 1 dialogue, 2 boost, 3 fade
var _line_idx := 0
var _line_chars := 0
var _line_hold := 0.0
var _lines: Array = []
var _boxes: Array = []       ## {root,label,speaker}
var _boost_t := 0.0
var _darken := 0.0
var _done := false


func _ready() -> void:
	layer = 20
	hero_name = "%s" % NativeGame.HEROES[clampi(hero_index,
		0, NativeGame.HEROES.size() - 1)]["name"]
	var vp := get_viewport().get_visible_rect().size
	_scale = minf(vp.x / LOGICAL.x, vp.y / LOGICAL.y)
	_world.custom_minimum_size = LOGICAL
	_world.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world.pivot_offset = LOGICAL * 0.5
	_world.scale = Vector2(_scale, _scale)
	_world.position = (vp - LOGICAL * _scale) * 0.5
	add_child(_world)
	_build_space()
	_build_speakers()
	_build_lines()
	NativeAssets.play_music("finishing")


func _build_space() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_world.add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in STARS:
		var s := ColorRect.new()
		var sz := rng.randf_range(1.0, 3.0)
		s.size = Vector2(sz, sz)
		s.color = Color(1, 1, 1, rng.randf_range(0.25, 0.9))
		s.position = Vector2(rng.randf() * LOGICAL.x,
			rng.randf() * LOGICAL.y)
		_world.add_child(s)
		_stars.append(s)
	# initial frame positions per next_map_obj step events
	_ship_p["pos"] = Vector2(512.0, 1100.0)
	_ship_p["tar"] = Vector2(512.0, 400.0)
	_ship_p["phase"] = 0
	_toad_p["pos"] = Vector2(620.0, 1000.0)
	_toad_p["tar"] = Vector2(180.0, 600.0)
	_ship = _make_ship()
	_world.add_child(_ship)
	_toad = _make_toad()
	_world.add_child(_toad)


func _make_ship() -> Control:
	var root := Control.new()
	root.size = Vector2(120, 120)
	_ship_glow = _tex(318, 0, Vector2(200, 200),
		Color(1.0, 0.4, 0.9, 0.5))
	_ship_glow.position = Vector2(-40, -40)
	root.add_child(_ship_glow)
	_ship_hull = _tex(543, 12 + hero_index, Vector2(140, 140),
		NativeGame.hero_tint)
	_ship_hull.position = Vector2(-10, -10)
	root.add_child(_ship_hull)
	_exhaust = _tex(6, 0, Vector2(120, 120), Color(1, 0.6, 0.2))
	_exhaust.position = Vector2(0, -60)
	_exhaust.pivot_offset = Vector2(60, 60)
	root.add_child(_exhaust)
	return root


func _make_toad() -> TextureRect:
	var t := _tex(511, 0, Vector2(90, 90), Color.WHITE)
	t.pivot_offset = Vector2(45, 45)
	return t


func _tex(sprite_id: int, frame: int, size: Vector2,
		mod := Color.WHITE) -> TextureRect:
	var tr := TextureRect.new()
	var tex := NativeAssets.sprite_frame(sprite_id, frame)
	if tex != null:
		tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = size
	tr.modulate = mod
	return tr


func _build_speakers() -> void:
	# hero box: upper-centre (anim obj draw (512,215)); toad box:
	# lower-left (draw (181,505)) — two independent balloons.
	_boxes.append(_speech_box(Vector2(212, 60), Vector2(600, 190), 0))
	_boxes.append(_speech_box(Vector2(30, 470), Vector2(460, 220), 1))


func _speech_box(pos: Vector2, size: Vector2, speaker: int) -> Dictionary:
	var root := PanelContainer.new()
	root.position = pos
	root.custom_minimum_size = size
	root.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.14, 0.92)
	sb.border_color = Color(0.9, 0.8, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	root.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(lbl)
	_world.add_child(root)
	return {"root": root, "label": lbl, "speaker": speaker,
		"scale": 0.0}


func _build_lines() -> void:
	_lines = NativeDialogueTable.NEXT_MAP.get(clampi(destination - 1,
		0, 6), [])
	if _lines.is_empty():
		_lines = ["1|SEE YOU SOON!"]


func _process(delta: float) -> void:
	var dt60 := delta * 60.0
	if _phase == 0:
		_physics(_ship_p, delta)
		_physics(_toad_p, delta)
		if _ship_p["phase"] == 1:
			_phase = 1
			_start_dialogue()
	elif _phase == 1:
		_dialogue_tick(delta)
	elif _phase == 2:
		_boost_tick(delta)
	elif _phase == 3:
		_darken += dt60 * 0.01
		if _darken >= 1.0:
			_finish()
	# stars always scroll; speed ramps during boost
	_bg_vspeed = maxf(_bg_vspeed + dt60 * 0.01, 1.0)
	if _phase == 2:
		_bg_vspeed += dt60 * 0.35
	for s in _stars:
		s.position.y += _bg_vspeed * delta
		if s.position.y > LOGICAL.y:
			s.position.y -= LOGICAL.y
	_update_visuals(dt60)


## o_next_map_*_set_speed: accel 360/axis toward target, cap 1200 px/s,
## warp slingshot past ±(5+warpdzielnik2) with /1.05+1 frame kick.
func _physics(p: Dictionary, delta: float) -> void:
	var pos: Vector2 = p["pos"]
	var vel: Vector2 = p["vel"]
	var tar: Vector2 = p["tar"]
	# axis-aligned accel toward target (original: iframes warped, speed
	# capped 1200, warp slingshot ±(5+warpdzielnik2) → v/1.05+1)
	var acc := Vector2(360.0, 360.0) * delta
	var to_tar := tar - pos
	if absf(to_tar.x) > 25.0:
		vel.x = clampf(vel.x + signf(to_tar.x) * acc.x, -1200, 1200)
	else:
		vel.x = move_toward(vel.x, 0.0, acc.x)
	if absf(to_tar.y) > 25.0:
		vel.y = clampf(vel.y + signf(to_tar.y) * acc.y, -1200, 1200)
	else:
		vel.y = move_toward(vel.y, 0.0, acc.y)
	# arrival damping — the original's slingshot decays past the target;
	# without it the ship orbits the waypoint forever
	var dist := to_tar.length()
	if dist < 120.0:
		var damp := pow(0.90, delta * 60.0)
		vel *= damp
	pos += vel * delta
	p["pos"] = pos
	p["vel"] = vel
	if dist < 30.0 and vel.length() < 250.0:
		p["phase"] = 1


func _start_dialogue() -> void:
	_boxes[0]["root"].visible = true
	_boxes[1]["root"].visible = true
	_boxes[0]["root"].modulate.a = 0.0
	_boxes[1]["root"].modulate.a = 0.0
	_line_idx = 0


func _dialogue_tick(delta: float) -> void:
	if _line_idx >= _lines.size():
		_phase = 2
		_boost_t = 0.0
		return
	var raw: String = _lines[_line_idx]
	var sp := 1 if raw.begins_with("1|") else 0
	var text := raw.substr(2) if raw.contains("|") else raw
	var box: Dictionary = _boxes[sp]
	var other: Dictionary = _boxes[1 - sp]
	# typewriter: 5 frames/char ≈ 12 cps, hold ~150f ≈ 2.5s after done
	var full := text.replace("#", "\n")
	var shown := ""
	if _line_chars < full.length():
		_line_hold += delta
		if _line_hold >= 0.085:
			_line_hold = 0.0
			_line_chars += 1
		shown = full.substr(0, _line_chars)
	else:
		shown = full
		_line_hold += delta
		if _line_hold >= 2.5:
			_line_hold = 0.0
			_line_chars = 0
			_line_idx += 1
			return
	box["label"].text = shown
	# balloon grows in while its line is active (dialogsize 0→1 at 0.2)
	var box_node: PanelContainer = box["root"]
	var k := minf(1.0, box["scale"] + delta * 5.0)
	box["scale"] = k
	box_node.modulate.a = k
	box_node.pivot_offset = box_node.size * 0.5
	box_node.scale = Vector2.ONE * (0.4 + 0.6 * k)
	# non-speaking box idles empty and fades (dialogsize *= 0.96)
	other["label"].text = ""
	other["scale"] = maxf(0.0, other["scale"] - delta * 2.0)
	other["root"].modulate.a = other["scale"] * 0.5


func _boost_tick(delta: float) -> void:
	_boost_t += delta
	# o_next_map_ship_step iyor boost: starts 10, decays /1.1 → negative,
	# ship rockets upward ~0.2f and off-screen; bg accelerates down.
	_ship_p["iyor"] = float(_ship_p["iyor"]) - delta * 60.0 * 0.1
	if _ship_p["iyor"] > 0.0:
		_ship_p["iyor"] = float(_ship_p["iyor"]) / 1.1
	else:
		_ship_p["iyor"] = float(_ship_p["iyor"]) * 1.1
	var p: Dictionary = _ship_p
	var pos: Vector2 = p["pos"]
	var vel: Vector2 = p["vel"]
	vel.y += float(p["iyor"]) * 60.0 * delta * 8.0
	vel.x *= pow(0.5, delta * 60.0)
	pos += vel * delta
	pos.y -= 60.0 * delta
	p["pos"] = pos
	p["vel"] = vel
	# exhaust flame flipbook
	_exhaust_frame = (_exhaust_frame + 1) % 5
	_exhaust.texture = NativeAssets.sprite_frame(6, _exhaust_frame)
	if pos.y < -1400.0 or _boost_t > 6.0:
		_phase = 3


func _update_visuals(dt60: float) -> void:
	var sp: Vector2 = _ship_p["pos"]
	_ship.position = sp - Vector2(60, 60)
	# banking: rotation from horizontal velocity
	var vx: float = _ship_p["vel"].x
	_ship.rotation = clampf(vx / 1200.0, -0.5, 0.5) * 0.6
	# boost stretch
	var stretch := 1.0 + maxf(0.0, _boost_t) * 0.15 if _phase == 2 else 1.0
	_ship.scale = Vector2(1.0, stretch)
	_ship_glow.modulate.a = 0.5 if _phase < 2 else 0.9
	_toad.position = _toad_p["pos"] - Vector2(45, 45)
	_toad.rotation = clampf(
		float(_toad_p["vel"].x) / 1200.0, -0.5, 0.5) * 0.5
	_toad_frame = (_toad_frame + 1) % 3
	if _toad_frame == 0:
		_toad.texture = NativeAssets.sprite_frame(511, 0)
	# darken overlay
	if _darken > 0.0:
		if not _world.has_node("Dark"):
			var d := ColorRect.new()
			d.name = "Dark"
			d.color = Color.BLACK
			d.set_anchors_preset(Control.PRESET_FULL_RECT)
			d.modulate.a = 0.0
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_world.add_child(d)
			_world.move_child(d, _world.get_child_count() - 1)
		(_world.get_node("Dark") as ColorRect).modulate.a = _darken


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _phase < 3:
			# skip: jump to boost/fade like the original's click-skip
			_phase = 2
			_boost_t = 0.0
		elif not _done:
			_darken = 1.0


func _finish() -> void:
	if _done:
		return
	_done = true
	# destination map index = transition target stored by star_map
	var dest: String = "res://native/levels/star_map.tscn"
	get_tree().change_scene_to_file(dest)
