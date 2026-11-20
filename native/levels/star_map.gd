extends Control
## NativeStarMap — level select screen (ports the GameMaker `room_map*` rooms).
##
## The original shows the Mushroom Kingdom galaxy map with level nodes the
## ship flies between. This native version lays out the campaign as a grid:
## one row per world, one node per level. Cleared levels glow, the current
## level pulses, locked levels are dimmed. Clicking an unlocked node stages
## its config in NativeGame.pending_level and enters the arena.
##
## Progression lives in NativeGame.level_index (highest unlocked) and
## NativeGame.active_level (level being played) — both survive scene
## changes because they are static class state.

const NODE_SIZE := 56.0
const NODE_GAP := 14.0
const ROW_HEIGHT := 84.0
const MARGIN := 60.0

## Display names for each world row — the Galaxy map names its regions.
const WORLD_NAMES := [
	"COMET COAST", "STARDUST HOLLOW", "VOID MAW", "NEBULA DRIFT",
	"METEOR BELT", "STARFORGE", "OBSIDIAN REACH", "MUSHROOM KINGDOM",
]

## Per-world accent colours — the Galaxy map tints each region.
const WORLD_COLORS := [
	Color(1.0, 0.75, 0.3),    # W1 gold
	Color(0.4, 0.9, 1.0),     # W2 ice
	Color(0.7, 0.5, 1.0),     # W3 violet
	Color(0.4, 1.0, 0.6),     # W4 green
	Color(1.0, 0.5, 0.4),     # W5 ember
	Color(1.0, 0.9, 0.4),     # W6 yellow
	Color(0.9, 0.4, 0.8),     # W7 magenta
	Color(1.0, 0.45, 0.35),   # W8 red — final world
]

var _nodes: Array = []           # Button per level, index = level id
var _ship_cursor: Sprite2D = null
var _cursor_base_y := 0.0

# Camera pan/zoom — the original map screen lets you drag a view pad
# and scroll to inspect distant stars. Here: hold RIGHT mouse to drag,
# wheel to zoom, release returns the camera to the frontier node.
var _world: Node2D = null
var _cam: Camera2D = null
var _panning := false
var _cam_tween: Tween = null
var _node_centers: Dictionary = {}   # level idx -> world-space node center


func _ready() -> void:
	_build_backdrop()

	# World container — everything positional (labels, nodes, paths,
	# ship cursor) lives here so the camera can pan/zoom it as one layer.
	# Header, stats, options and backdrop stay screen-fixed.
	_world = Node2D.new()
	add_child(_world)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(1.35, 1.35)
	_world.add_child(_cam)

	_build_header()
	_build_grid()
	_maybe_map_transition()
	_cam.make_current()
	_center_on_frontier()


## Deep-space backdrop: a generated starfield over a dim galaxy image.
## Stars are random pixels baked into one ImageTexture — cheap and it
## gives the map the "fly between stars" feel of the original.
func _build_backdrop() -> void:
	# Galaxy plate underneath (falls back to flat space color).
	var tex := NativeAssets.background(48)
	if tex == null:
		tex = NativeAssets.background(0)
	if tex != null:
		var plate := Sprite2D.new()
		plate.texture = tex
		plate.centered = false
		plate.scale = Vector2(1024.0 / tex.get_width(), 768.0 / tex.get_height())
		plate.modulate = Color(0.5, 0.5, 0.65)
		plate.z_index = -100
		add_child(plate)
	else:
		var bg := ColorRect.new()
		bg.color = Color(0.03, 0.04, 0.12)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)

	# Starfield — random dots baked into a single texture.
	var img := Image.create(1024, 768, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 220:
		var x := randi() % 1024
		var y := randi() % 768
		var bright := randf()
		var c := Color(1, 1, 1, 0.3 + bright * 0.7)
		img.set_pixel(x, y, c)
		if bright > 0.92:   # a few brighter stars get a plus-shape
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.x < 1024 and p.y >= 0 and p.y < 768:
					img.set_pixel(p.x, p.y, c)
	var stars := TextureRect.new()
	stars.texture = ImageTexture.create_from_image(img)
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.stretch_mode = TextureRect.STRETCH_SCALE
	stars.z_index = -99
	add_child(stars)


func _build_header() -> void:
	var title := Label.new()
	title.text = "MARIO GALAXY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 6)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 18
	title.offset_bottom = 70
	add_child(title)

	var stats := Label.new()
	stats.name = "Stats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	stats.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	stats.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stats.offset_top = 70
	stats.offset_bottom = 96
	add_child(stats)

	# Options shortcut — overlay, same as the title screen's.
	var opts := Button.new()
	opts.text = "OPTIONS"
	opts.custom_minimum_size = Vector2(140, 40)
	opts.add_theme_font_size_override("font_size", 16)
	opts.position = Vector2(884, 20)
	opts.pressed.connect(func(): add_child(load("res://native/ui/options.tscn").instantiate()))
	add_child(opts)


## Authored galaxy map — node positions come straight from the
## original's room_map* instance placements (data/levels/native/
## map_nodes.json). Each of the 8 maps gets a region in the world
## container; playable nodes (those with an extracted stage schedule)
## become level buttons ranked by NativeLevelTable, connector nodes
## render as dim markers. Regions are laid out left-to-right so the
## existing camera pan/zoom covers the whole galaxy.
const MAP_REGION_W := 980.0
const MAP_REGION_H := 1080.0
const MAP_GAP := 60.0

var _map_nodes: Dictionary = {}    # map idx -> [[x,y],...] authored coords
var _node_rank: Dictionary = {}    # "m:n" -> playable level index
var _node_pos: Dictionary = {}     # "m:n" -> world-space base center
var _orbit_nodes: Array = []       # [{key, base, btn|dot}] — 20px orbit
var _lanes: Array = []             # [{line, a, b}] orbiting flight lanes
var _promien := 0.0                # shared orbit phase (g_promien += 0.05/f)
var _node_btns: Dictionary = {}    # "m:n" -> node Button
var _map_meta: Dictionary = {}     # "m:n" -> {name, map_nextlev, ...}


func _load_map_data() -> void:
	if not _map_nodes.is_empty():
		return
	var path := "res://data/levels/native/map_nodes.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			for k in parsed:
				var arr: Array = []
				for p in parsed[k]:
					arr.append(Vector2(float(p[0]), float(p[1])))
				_map_nodes[int(k)] = arr
	for i in NativeLevelTable.level_count():
		_node_rank[NativeLevelTable.stage_key(i)] = i
	var mpath := "res://data/levels/native/map_meta.json"
	if FileAccess.file_exists(mpath):
		var mparsed = JSON.parse_string(FileAccess.get_file_as_string(mpath))
		if typeof(mparsed) == TYPE_DICTIONARY:
			_map_meta = mparsed


func _build_grid() -> void:
	_load_map_data()
	var count := NativeLevelTable.level_count()
	for m in NativeLevelTable.WORLDS:
		var origin := Vector2(m * (MAP_REGION_W + MAP_GAP) + 40,
			120 + (MAP_REGION_H - 900) / 2)
		# Region label — the original names each map (MAP 1..8).
		var wl := Label.new()
		wl.text = "MAP %d %s%s" % [m + 1, WORLD_NAMES[m],
			" ✓" if _map_cleared(m) else ""]
		wl.add_theme_font_size_override("font_size", 16)
		wl.add_theme_color_override("font_color", WORLD_COLORS[m])
		wl.position = origin + Vector2(0, -34)
		_world.add_child(wl)
		var pts: Array = _map_nodes.get(m, [])
		if pts.is_empty():
			continue
		# Normalize authored coords into the region, keeping aspect.
		var minp: Vector2 = pts[0]
		var maxp: Vector2 = pts[0]
		for p in pts:
			minp = minp.min(p)
			maxp = maxp.max(p)
		var span: Vector2 = maxp - minp
		var scale := minf((MAP_REGION_W - 80) / maxf(span.x, 1.0),
			(MAP_REGION_H - 80) / maxf(span.y, 1.0))
		for n in pts.size():
			var rel: Vector2 = (pts[n] - minp) * scale
			var pos: Vector2 = origin + rel + Vector2(40, 40)
			var key := "%d:%d" % [m, n]
			var rank := int(_node_rank.get(key, -1))
			if rank >= 0 or _is_waypoint(key):
				var btn := _make_node(key, rank, m, n)
				btn.position = pos - Vector2(NODE_SIZE, NODE_SIZE) / 2
				_world.add_child(btn)
				_nodes.append(btn)
				_node_btns[key] = btn
				var center := btn.position + Vector2(NODE_SIZE / 2, NODE_SIZE / 2)
				if rank >= 0:
					_node_centers[rank] = center
				_node_pos[key] = center
				_orbit_nodes.append({"key": key, "base": center, "btn": btn})
			else:
				# Connector/path node — a dim star, not a destination.
				var dot := ColorRect.new()
				dot.color = Color(0.35, 0.35, 0.45, 0.8)
				dot.size = Vector2(10, 10)
				dot.position = pos - Vector2(5, 5)
				_world.add_child(dot)
				_node_pos[key] = pos
				_orbit_nodes.append({"key": key, "base": pos, "dot": dot})
	_draw_flight_lanes()
	_build_ship_cursor()
	if count > 0:
		_build_map_decor()


## True when every playable node of a map is behind the frontier —
## the original's G.map_completed, set by the map's boss/exit node.
func _map_cleared(m: int) -> bool:
	var exit_key := NativeLevelTable.map_exit(m)
	return exit_key != "" and NativeGame.map_done.has(exit_key)


## Map secrets — the original's hidden map goodies (o_map_goodie_*)
## and loot panels (o_map_panel_loot_2): twinkling galactic sprites
## and pulsing panels scattered between the level nodes. Decorative
## only; they need efekty >= 1 like the original's G.efekty check.
var _decor: Array = []   # {sprite, base_pos, phase, kind}

func _build_map_decor() -> void:
	if NativeGame.efekty < 1:
		return
	# Twinkling goodie sprites scattered at region edges — the original's
	# hidden map goodies (o_map_goodie_*).
	var spots := [
		Vector2(120, 260), Vector2(1060, 420), Vector2(2140, 300),
		Vector2(3220, 500), Vector2(4300, 350), Vector2(5380, 480),
		Vector2(6460, 320), Vector2(7540, 420),
	]
	for i in spots.size():
		var sid: int = 255 if i % 2 == 0 else 256
		var tex := NativeAssets.sprite_frame(sid, 0)
		if tex == null:
			continue
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.offset = -NativeAssets.sprite_origin(sid)
		sp.scale = Vector2(0.8, 0.8)
		sp.position = spots[i]
		_world.add_child(sp)
		_decor.append({"sprite": sp, "base": spots[i],
			"phase": randf() * TAU, "kind": "goodie"})


## Flight lanes — the original draws dotted paths between linked map
## nodes (script_map_algo, sprite 250 stretched between node orbits).
## Links come from the extracted map_nextlev adjacency: each node's
## outgoing edges to sibling node indices in the same map. Lanes glow
## once both endpoints are unlocked, dim otherwise.
func _draw_flight_lanes() -> void:
	for key in _map_meta:
		var meta: Dictionary = _map_meta[key]
		var nxt: Dictionary = meta.get("map_nextlev", {})
		var a: Vector2 = _node_pos.get(key, Vector2.ZERO)
		if a == Vector2.ZERO:
			continue
		var parts: PackedStringArray = str(key).split(":")
		var map_idx := str(parts[0])
		for _dir in nxt:
			var target := str(nxt[_dir])
			# 0 = no link (the original checks nextlev > 0).
			if target == "0" or target == "-1" or target == "":
				continue
			var bkey := "%s:%s" % [map_idx, target]
			var b: Vector2 = _node_pos.get(bkey, Vector2.ZERO)
			if b == Vector2.ZERO or b == a:
				continue
			var line := Line2D.new()
			line.points = PackedVector2Array([a, b])
			var touches_current: bool = key == NativeGame.map_current \
				or bkey == NativeGame.map_current
			var both_cleared: bool = _node_cleared(key) and _node_cleared(bkey)
			if touches_current and _current_done():
				# Live lane out of the completed current node — the
				# original draws these bright (sprite 250 glow).
				line.default_color = Color(1.0, 0.85, 0.4, 0.9)
				line.width = 3.0
			elif both_cleared:
				line.default_color = Color(0.5, 0.7, 1.0, 0.5)
			else:
				line.default_color = Color(0.25, 0.25, 0.35, 0.6)
			line.width = 2.0
			_world.add_child(line)
			_lanes.append({"line": line, "a": key, "b": bkey})


## Connect consecutive nodes in each world row with a dim path line —
## the Galaxy map's flight lanes between stars.
func _draw_paths(_start_x: float, _start_y: float, _per_world: int) -> void:
	pass   # authored node adjacency isn't extracted; nodes stand alone


## The player's ship parked on the current map node — pulses gently to
## invite the next flight, like the Galaxy map cursor.
func _build_ship_cursor() -> void:
	if NativeGame.map_current == "":
		NativeGame.map_current = "0:0"
	var center: Vector2 = _node_pos.get(NativeGame.map_current, Vector2.ZERO)
	if center == Vector2.ZERO:
		return
	var tex := NativeAssets.sprite_frame(543, 1)   # upright ship frame
	if tex == null:
		return
	_ship_cursor = Sprite2D.new()
	_ship_cursor.texture = tex
	_ship_cursor.offset = -NativeAssets.sprite_origin(543)
	_ship_cursor.scale = Vector2(0.28, 0.28)
	_cursor_base_y = center.y
	_ship_cursor.position = center
	_world.add_child(_ship_cursor)


## --- Graph progression (G.aktualny_lev / map_complev / nextlev) ---
##
## The ship is parked on NativeGame.map_current. While that node is
## incomplete only it can be launched; once cleared, every lane
## neighbour (nextlev + prevlev, undirected like the original's cursor
## flight) becomes selectable. Waypoint nodes — hot spots, lock gates,
## start points — are pre-completed in the extracted data so their
## lanes are live immediately; clicking one just repositions the ship.

func _is_waypoint(key: String) -> bool:
	return NativeLevelTable.node_rank(key) < 0 \
		and not NativeLevelTable.node_neighbors(key).is_empty()


func _current_done() -> bool:
	var cur := NativeGame.map_current
	if cur == "":
		return true
	return NativeGame.map_done.has(cur) \
		or NativeLevelTable.node_precompleted(cur)


func _node_selectable(key: String) -> bool:
	var clickable := NativeLevelTable.is_stage_node(key) or _is_waypoint(key)
	if not clickable:
		return false
	if key == NativeGame.map_current:
		return true
	if not _current_done():
		return false
	return NativeLevelTable.node_neighbors(NativeGame.map_current).has(key)


## Node was cleared — stage nodes live in map_done; waypoint/special
## nodes count as done via their extracted complev flag.
func _node_cleared(key: String) -> bool:
	return NativeGame.map_done.has(key) \
		or NativeLevelTable.node_precompleted(key)


## Inter-map transition — clearing a map's exit node sets
## NativeGame.map_transition; the original runs the next_map_obj
## briefing (room 44) then warps to the next map's entry node.
func _maybe_map_transition() -> void:
	var m := NativeGame.map_transition
	if m < 0 or m > 7:
		return
	NativeGame.map_transition = -1
	NativeGame.map_current = "%d:0" % m
	NativeGame.save()
	var lines: Array = NativeDialogueTable.NEXT_MAP.get(m, [])
	if lines.is_empty():
		return
	var talk := NativeBossDialogue.new()
	add_child(talk)
	talk.play(lines)


## One map node — a star button. Stage nodes show their rank colour;
## waypoint nodes (hot spots/lock gates) are smaller dim stars.
func _make_node(key: String, rank: int, w: int, l: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.size = Vector2(NODE_SIZE, NODE_SIZE)
	var meta: Dictionary = _map_meta.get(key, {})
	var stage_label := ""
	if rank >= 0:
		stage_label = NativeLevelTable.config_for_key(key).get("label", "")
	var node_name := str(meta.get("name", "")).replace("_", " ") \
		.replace("#", " ")
	btn.text = node_name if node_name != "" else ("%d-%d" % [w + 1, l + 1])
	btn.add_theme_font_size_override("font_size", 11)

	var selectable := _node_selectable(key)
	var cleared := _node_cleared(key)
	if key == NativeGame.map_current:
		# Parked ship node — gold pulse like the original's current star.
		btn.modulate = Color(1.0, 0.85, 0.35)
	elif selectable:
		# Frontier — a lane neighbour of the completed current node.
		btn.modulate = Color(WORLD_COLORS[w]) * (1.0 if not cleared else 0.55)
	elif cleared:
		btn.modulate = Color(WORLD_COLORS[w]) * 0.45
	else:
		btn.modulate = Color(0.25, 0.25, 0.3)
	btn.disabled = not selectable
	var tip := stage_label if stage_label != "" else btn.text
	btn.tooltip_text = tip

	if selectable:
		btn.pressed.connect(_on_node_pressed.bind(key))
	return btn


func _on_node_pressed(key: String) -> void:
	if not _node_selectable(key):
		return
	var rank := NativeLevelTable.node_rank(key)
	if rank < 0:
		# Waypoint — fly the cursor there; lanes beyond it open up.
		NativeGame.map_current = key
		NativeGame.save()
		_fly_cursor_to(key)
		return
	NativeGame.active_level = rank
	NativeGame.active_node = key
	NativeGame.map_current = key
	NativeGame.pending_level = NativeLevelTable.config_for_key(key)
	# Minigame nodes (card game/shop/gun range) don't start a run.
	if str(NativeGame.pending_level.get("mode", "")) != "minigame":
		NativeGame.reset_run()
	_fly_cursor_to(key, _enter_level)


## Glide the ship cursor along the lane to the node, then continue —
## the original's node-to-node flight.
## Orbiting draw position — the original offsets every node by
## (20·sin(promien/5), 20·cos(promien)) each frame (part_7 map draw).
func _orbit_pos(key: String) -> Vector2:
	var base: Vector2 = _node_pos.get(key, Vector2.ZERO)
	return base + Vector2(sin(_promien / 5.0) * 20.0,
		cos(_promien) * 20.0)


func _fly_cursor_to(key: String, then: Callable = Callable()) -> void:
	var target: Vector2 = _orbit_pos(key)
	_cursor_base_y = target.y
	if _ship_cursor == null:
		if then.is_valid():
			then.call()
		return
	if _cam_tween != null and _cam_tween.is_running():
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.tween_property(_ship_cursor, "position", target, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if then.is_valid():
		_cam_tween.tween_callback(then)


## Flight complete — enter the staged level. Inter-map briefings are
## handled by _maybe_map_transition on arrival, since lanes never cross
## map regions (the original's next_map_obj runs between map rooms).
func _enter_level() -> void:
	_fade_to_arena()


## Fade to black, then swap scenes — the Galaxy map "flies" transition.
func _fade_to_arena() -> void:
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.modulate.a = 0.0
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.add_child(fade)
	add_child(layer)
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func():
		var cfg: Dictionary = NativeGame.pending_level
		var mode := str(cfg.get("mode", "arena"))
		var scene := "res://native/levels/arena.tscn"
		if mode == "castle":
			scene = "res://native/levels/castle.tscn"
		elif mode == "minigame":
			# Original map_minigame routing: 1/3 card game,
			# 2 shop, 10 training (plays as a normal stage).
			match int(cfg.get("minigame", 0)):
				1, 3:
					scene = "res://native/ui/card_game.tscn"
				2:
					scene = "res://native/ui/shop.tscn"
		get_tree().change_scene_to_file(scene))


## Snap the camera onto the node the ship is parked on.
func _center_on_frontier() -> void:
	if _cam == null:
		return
	_cam.position = _node_pos.get(NativeGame.map_current, Vector2(512, 384))


## Right-drag pans the map view; mouse wheel zooms; releasing the button
## glides the camera back to the frontier node — the original's pad
## behaviour (hold to inspect, release to return).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_panning = event.pressed
			if not _panning:
				_return_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(_cam.zoom.x * 1.15)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(_cam.zoom.x / 1.15)
	elif event is InputEventMouseMotion and _panning and _cam != null:
		# Dragging moves the camera opposite the cursor, scaled by zoom.
		_cam.position -= event.relative / _cam.zoom.x


func _set_zoom(z: float) -> void:
	var clamped := clampf(z, 0.8, 2.2)
	_cam.zoom = Vector2(clamped, clamped)


## Glide back to the frontier node after a pan.
func _return_camera() -> void:
	if _cam_tween != null and _cam_tween.is_running():
		_cam_tween.kill()
	var target: Vector2 = _node_pos.get(NativeGame.map_current, _cam.position)
	_cam_tween = create_tween()
	_cam_tween.tween_property(_cam, "position", target, 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	# Refresh the stats line and pulse the frontier node.
	var stats := get_node_or_null("Stats") as Label
	if stats != null:
		stats.text = "SCORE %d    BEST %d    COINS %d    LIVES x%d" % [
			NativeGame.score, NativeGame.best_score,
			NativeGame.coins, NativeGame.lives]
	# Pulse the node the ship is parked on.
	var current_btn: Button = _node_btns.get(NativeGame.map_current)
	if current_btn != null:
		var s := 1.0 + sin(Time.get_ticks_msec() / 300.0) * 0.08
		current_btn.scale = Vector2(s, s)
	# Ship cursor orbit+bob handled in the orbit block below.
	# Node orbits — every map node circles its anchor on a 20px radius
	# (g_promien += 0.05/frame in the original's map draw).
	_promien += _delta * 60.0 * 0.05
	for n in _orbit_nodes:
		var off := Vector2(sin(_promien / 5.0) * 20.0,
			cos(_promien) * 20.0)
		var p: Vector2 = n["base"] + off
		if n.has("btn"):
			(n["btn"] as Button).position = \
				p - Vector2(NODE_SIZE, NODE_SIZE) / 2
		else:
			(n["dot"] as ColorRect).position = p - Vector2(5, 5)
	for l in _lanes:
		(l["line"] as Line2D).set_point_position(0, _orbit_pos(l["a"]))
		(l["line"] as Line2D).set_point_position(1, _orbit_pos(l["b"]))
	# Ship cursor — parked on the orbiting current node when idle.
	if _ship_cursor != null and NativeGame.map_current != "":
		var idle := _cam_tween == null or not _cam_tween.is_running()
		if idle:
			_ship_cursor.position = _orbit_pos(NativeGame.map_current) \
				+ Vector2(0, sin(Time.get_ticks_msec() / 400.0) * 4.0)
	# Map decor — goodies twinkle on Lissajous paths, panels pulse
	# (ports the sin-based drift in o_map_goodie_* / map_panel_loot_2).
	var t := Time.get_ticks_msec() / 1000.0
	for d in _decor:
		var sp: Sprite2D = d["sprite"]
		var ph: float = d["phase"]
		if d["kind"] == "goodie":
			sp.position = d["base"] + Vector2(
				sin(t / 5.0 + ph) * 10.0 + sin(t / 5.0 + ph * 2.0) * 20.0,
				sin(t + ph) * 20.0 + sin(t + ph * 2.0) * 20.0)
			sp.modulate.a = 0.55 + sin(t * 2.0 + ph) * 0.35
		else:
			var pulse: float = 1.0 + abs(sin(t * 3.0 + ph)) * 0.25
			sp.scale = Vector2(0.55, 0.55) * pulse
			sp.modulate.a = 0.6 + sin(t * 2.5 + ph) * 0.3
