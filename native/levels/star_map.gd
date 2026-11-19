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

var _nodes: Array = []           # Button per level, index = level id


func _ready() -> void:
	# Deep-space backdrop — flat color keeps the nodes readable.
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_header()
	_build_grid()


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


func _build_grid() -> void:
	var worlds := NativeLevelTable.WORLDS
	var per_world := NativeLevelTable.LEVELS_PER_WORLD
	var grid_w := per_world * (NODE_SIZE + NODE_GAP) - NODE_GAP
	var start_x := (1024.0 - grid_w) / 2.0
	var start_y := 120.0

	for w in worlds:
		# World label on the left of each row.
		var wl := Label.new()
		wl.text = "WORLD %d" % (w + 1)
		wl.add_theme_font_size_override("font_size", 14)
		wl.add_theme_color_override("font_color", Color(0.6, 0.7, 1.0))
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


## One level node — a star button showing world/level and lock state.
func _make_node(idx: int, _w: int, _l: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.size = Vector2(NODE_SIZE, NODE_SIZE)
	btn.text = "%d-%d" % [_w + 1, _l + 1]
	btn.add_theme_font_size_override("font_size", 13)

	var unlocked: bool = idx <= NativeGame.level_index
	if unlocked:
		# Unlocked = warm gold; the frontier level pulses to invite a click.
		btn.modulate = Color(1.0, 0.85, 0.35) if idx == NativeGame.level_index \
			else Color(0.75, 0.8, 1.0)
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
		stats.text = "SCORE %d    COINS %d    LIVES x%d" % [
			NativeGame.score, NativeGame.coins, NativeGame.lives]
	if _nodes.size() > NativeGame.level_index:
		var frontier: Button = _nodes[NativeGame.level_index]
		var s := 1.0 + sin(Time.get_ticks_msec() / 300.0) * 0.08
		frontier.scale = Vector2(s, s)
