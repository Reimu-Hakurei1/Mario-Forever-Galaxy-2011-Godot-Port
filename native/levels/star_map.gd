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
const MAX_LEVELS := 80           # 8 worlds x 10 (NativeLevelTable)

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
			if _node_rank.has(key):
				var idx: int = _node_rank[key]
				var btn := _make_node(idx, m, n)
				btn.position = pos - Vector2(NODE_SIZE, NODE_SIZE) / 2
				_world.add_child(btn)
				_nodes.append(btn)
				_node_centers[idx] = btn.position + Vector2(NODE_SIZE / 2, NODE_SIZE / 2)
			else:
				# Connector/path node — a dim star, not a level.
				var dot := ColorRect.new()
				dot.color = Color(0.35, 0.35, 0.45, 0.8)
				dot.size = Vector2(10, 10)
				dot.position = pos - Vector2(5, 5)
				_world.add_child(dot)
	_build_ship_cursor()
	if count > 0:
		_build_map_decor()


## True when every playable node of a map is behind the frontier.
func _map_cleared(m: int) -> bool:
	for i in NativeLevelTable.level_count():
		if NativeLevelTable.world_of(i) == m \
				and i > NativeGame.level_index:
			return false
	return true


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


## Connect consecutive nodes in each world row with a dim path line —
## the Galaxy map's flight lanes between stars.
func _draw_paths(_start_x: float, _start_y: float, _per_world: int) -> void:
	pass   # authored node adjacency isn't extracted; nodes stand alone


## The player's ship parked on the frontier node — pulses gently to
## invite the next flight, like the Galaxy map cursor.
func _build_ship_cursor() -> void:
	var total := NativeLevelTable.level_count()
	if total == 0 or NativeGame.level_index >= total:
		return    # campaign complete — no frontier to mark
	var idx := NativeGame.level_index
	var center: Vector2 = _node_centers.get(idx, Vector2.ZERO)
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


## One level node — a star button showing world/level and lock state.
func _make_node(idx: int, w: int, l: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.text = "%d-%d" % [w + 1, l + 1]
	btn.add_theme_font_size_override("font_size", 13)

	var unlocked: bool = idx <= NativeGame.level_index
	if unlocked:
		# Unlocked = world accent; the frontier node pulses gold.
		btn.modulate = Color(1.0, 0.85, 0.35) if idx == NativeGame.level_index \
			else Color(WORLD_COLORS[w]) * 0.85
	else:
		btn.modulate = Color(0.25, 0.25, 0.3)
	btn.disabled = not unlocked
	btn.tooltip_text = NativeLevelTable.config_for(idx).get("label", "")

	if unlocked:
		btn.pressed.connect(_on_level_pressed.bind(idx))
	return btn


func _on_level_pressed(idx: int) -> void:
	NativeGame.active_level = idx
	NativeGame.pending_level = NativeLevelTable.config_for(idx)
	# Minigame nodes (card game/shop/gun range) don't start a run.
	if str(NativeGame.pending_level.get("mode", "")) != "minigame":
		NativeGame.reset_run()
	# Entering a new world's first level plays the inter-map briefing
	# (objects/ui/next_map_obj.gd) before the flight — only on the
	# frontier node, not when replaying old levels.
	var world := NativeLevelTable.world_of(idx)
	var first_of_map := idx == 0 \
		or NativeLevelTable.world_of(idx - 1) != world
	if first_of_map and idx == NativeGame.level_index \
			and str(NativeGame.pending_level.get("mode", "")) != "minigame":
		var lines: Array = NativeDialogueTable.NEXT_MAP.get(world, [])
		if not lines.is_empty():
			var talk := NativeBossDialogue.new()
			add_child(talk)
			talk.finished.connect(func():
				if is_instance_valid(talk):
					talk.queue_free()
				_fade_to_arena())
			talk.play(lines)
			return
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


## Snap the camera onto the frontier (highest unlocked) node.
func _center_on_frontier() -> void:
	if _cam == null:
		return
	var idx: int = mini(NativeGame.level_index, _node_centers.size() - 1)
	_cam.position = _node_centers.get(idx, Vector2(512, 384))


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
	var idx: int = mini(NativeGame.level_index, _node_centers.size() - 1)
	var target: Vector2 = _node_centers.get(idx, _cam.position)
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
	if _nodes.size() > NativeGame.level_index:
		var frontier: Button = _nodes[NativeGame.level_index]
		var s := 1.0 + sin(Time.get_ticks_msec() / 300.0) * 0.08
		frontier.scale = Vector2(s, s)
	# Ship cursor bob — gentle hover over the frontier node.
	if _ship_cursor != null:
		_ship_cursor.position.y = _cursor_base_y \
			+ sin(Time.get_ticks_msec() / 400.0) * 4.0
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
