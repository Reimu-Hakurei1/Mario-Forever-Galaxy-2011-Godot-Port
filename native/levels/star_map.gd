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


func _ready() -> void:
	_build_backdrop()

	_build_header()
	_build_grid()


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


func _build_grid() -> void:
	var worlds := NativeLevelTable.WORLDS
	var per_world := NativeLevelTable.LEVELS_PER_WORLD
	var grid_w := per_world * (NODE_SIZE + NODE_GAP) - NODE_GAP
	var start_x := (1024.0 - grid_w) / 2.0
	var start_y := 120.0

	for w in worlds:
		# World label on the left of each row — name + number.
		var wl := Label.new()
		wl.text = "W%d %s" % [w + 1, WORLD_NAMES[w]]
		wl.add_theme_font_size_override("font_size", 14)
		wl.add_theme_color_override("font_color", WORLD_COLORS[w])
		wl.position = Vector2(start_x - 90, start_y + w * ROW_HEIGHT + NODE_SIZE / 2 - 10)
		add_child(wl)

		for l in per_world:
			var idx := w * per_world + l
			var btn := _make_node(idx, w, l)
			btn.position = Vector2(
				start_x + l * (NODE_SIZE + NODE_GAP),
				start_y + w * ROW_HEIGHT)
			add_child(btn)
			_nodes.append(btn)

	_draw_paths(start_x, start_y, per_world)
	_build_ship_cursor(start_x, start_y, per_world)


## Connect consecutive nodes in each world row with a dim path line —
## the Galaxy map's flight lanes between stars.
func _draw_paths(start_x: float, start_y: float, per_world: int) -> void:
	for w in NativeLevelTable.WORLDS:
		var unlocked_color: Color = WORLD_COLORS[w] * 0.55
		var locked_color := Color(0.2, 0.2, 0.28)
		for l in per_world - 1:
			var a_idx := w * per_world + l
			var b_idx := a_idx + 1
			var line := Line2D.new()
			var y := start_y + w * ROW_HEIGHT + NODE_SIZE / 2.0
			line.points = PackedVector2Array([
				Vector2(start_x + l * (NODE_SIZE + NODE_GAP) + NODE_SIZE, y),
				Vector2(start_x + (l + 1) * (NODE_SIZE + NODE_GAP), y),
			])
			# The lane glows once both ends are unlocked.
			line.default_color = unlocked_color \
				if b_idx <= NativeGame.level_index else locked_color
			line.width = 3.0
			add_child(line)


## The player's ship parked on the frontier node — pulses gently to
## invite the next flight, like the Galaxy map cursor.
func _build_ship_cursor(start_x: float, start_y: float, _per_world: int) -> void:
	if NativeGame.level_index >= _nodes.size():
		return    # campaign complete — no frontier to mark
	var idx := NativeGame.level_index
	var w := NativeLevelTable.world_of(idx)
	var l := NativeLevelTable.level_of(idx)
	var tex := NativeAssets.sprite_frame(543, 1)   # upright ship frame
	if tex == null:
		return
	_ship_cursor = Sprite2D.new()
	_ship_cursor.texture = tex
	_ship_cursor.offset = -NativeAssets.sprite_origin(543)
	_ship_cursor.scale = Vector2(0.28, 0.28)
	_cursor_base_y = start_y + w * ROW_HEIGHT + NODE_SIZE / 2.0
	_ship_cursor.position = Vector2(
		start_x + l * (NODE_SIZE + NODE_GAP) + NODE_SIZE / 2.0,
		_cursor_base_y)
	add_child(_ship_cursor)


## One level node — a star button showing world/level and lock state.
func _make_node(idx: int, w: int, _l: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.text = "%d-%d" % [w + 1, _l + 1]
	btn.add_theme_font_size_override("font_size", 13)

	var unlocked: bool = idx <= NativeGame.level_index
	if unlocked:
		# Unlocked = world accent; the frontier node pulses gold.
		btn.modulate = Color(1.0, 0.85, 0.35) if idx == NativeGame.level_index \
			else Color(WORLD_COLORS[w]) * 0.85
	else:
		btn.modulate = Color(0.25, 0.25, 0.3)
	btn.disabled = not unlocked

	if unlocked:
		btn.pressed.connect(_on_level_pressed.bind(idx))
	return btn


func _on_level_pressed(idx: int) -> void:
	NativeGame.active_level = idx
	NativeGame.pending_level = NativeLevelTable.config_for(idx)
	NativeGame.reset_run()
	get_tree().change_scene_to_file("res://native/levels/arena.tscn")


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
