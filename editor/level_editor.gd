extends Control

## Custom level editor for the Mario Forever Galaxy Godot port.
##
## Build a level by picking a base stage (which supplies the original wave
## timeline, music and win condition), optionally clearing that timeline, then
## placing timed enemy spawns and tuning wave-table values. Saving writes:
##   - res://stages/custom/<name>.tscn   (the editable level scene)
##   - a cloned entry in game/rooms.json  (so the runtime can load the room)
##   - a room_create alias in game/registry.json (reuses the level_0000 boot code)
## Pressing Playtest launches the saved scene, which boots the game straight
## into the custom room.
##
## Controls: wheel = zoom, middle-drag = pan, right-click = delete spawn,
## Delete = delete selected, Esc = back to select mode, double-click an item
## in the list to center the view on it.
##
## Run with:  godot --path . editor/level_editor.tscn

const ROOM_W := 1024.0
const ROOM_H := 768.0
const VIEW_CENTER := Vector2(512, 384)
const CUSTOM_DIR := "res://stages/custom"
const ROOM_CODE_PART := 2            # game/room_code/room_2.gd creates HUD/controller
const FIRST_ROOM_ID := 100
const SNAP := 8.0

const KIND_LIST := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
	18, 19, 20, 21, 22, 23, 24, 50, 51, 52, 53, 54, 55, 56]
const KIND_NAMES := {
	0: "goomba", 1: "goomba_panzer", 2: "turtle", 3: "turtle_hammer",
	4: "turtle_bomerang", 5: "blue_kamikaze", 6: "berserker", 7: "green_killer",
	8: "panzer_killer", 9: "deadly_star", 10: "cyber_turtle", 11: "canon_turtle",
	12: "laser_turtle", 13: "lakitu", 14: "chest", 15: "chest_2",
	16: "asteroid", 17: "asteroid_2", 18: "small_asteroid", 19: "dummy",
	20: "dummy_2", 21: "big_asteroid", 22: "big_block", 23: "big_block_2",
	24: "asteroid_3", 50: "pipe_plant", 51: "blocker", 52: "castle_cannon",
	53: "flame_cannon", 54: "rotary_cannon", 55: "point", 56: "pipe_plant_2",
}
const TABLE_NAMES := ["num", "lev", "pozd", "levtime", "sekwencus", "kamik", "perioder", "sila_wrogow"]

# dark editor theme
const C_BG := Color(0.09, 0.10, 0.13)
const C_TOOLBAR := Color(0.13, 0.14, 0.18)
const C_PANEL := Color(0.15, 0.16, 0.21)
const C_PANEL2 := Color(0.20, 0.21, 0.27)
const C_BORDER := Color(0.32, 0.34, 0.42)
const C_TEXT := Color(0.90, 0.91, 0.94)
const C_DIM := Color(0.58, 0.60, 0.66)
const C_ACCENT := Color(1.0, 0.62, 0.22)
const C_GOOD := Color(0.40, 0.85, 0.50)

var _assets: Dictionary = {}
var _catalog: Dictionary = {}
var _bases: Array = []          # {label,map,lev,path}
var _bgs: Array = []            # {key,name,texture}
var _kind_tex: Dictionary = {}  # kind -> Texture2D palette icon

var level_name := "my_level"
var base_map := 0
var base_lev := 2
var base_label := ""
var bg_key := "0"
var bg_hspeed := 0.0
var bg_vspeed := 0.0
var blank_waves := true
var player_pos := Vector2(416, 576)

var spawns: Array = []          # spawn rule dictionaries
var timings: Array = []         # wave table dictionaries
var scene_path := ""
var room_id := -1

var _items: Array = []          # [{type, index}] unified selectable list
var _sel := -1
var _tool := "select"           # "select" | "spawn"
var _pending_kind := 0

# canvas view state
var _zoom := 1.0
var _view_center := VIEW_CENTER
var _panning := false
var _pan_last := Vector2.ZERO
var _mouse_world := Vector2.ZERO
var _snap := true

var _status: Label
var _item_list: ItemList
var _inspector: VBoxContainer
var _viewport: SubViewport
var _svc: SubViewportContainer
var _level_view: Node2D
var _marker_root: Node2D
var _player_marker: Node2D
var _ghost: Node2D
var _ghost_sprite: Sprite2D
var _timeline: Control
var _name_edit: LineEdit
var _base_opt: OptionButton
var _bg_opt: OptionButton
var _hspeed_spin: SpinBox
var _vspeed_spin: SpinBox
var _blank_check: CheckBox
var _open_opt: OptionButton
var _snap_check: CheckBox
var _grid_check: CheckBox
var _zoom_lbl: Label
var _palette_grid: GridContainer
var _palette_btns: Dictionary = {}
var _drag_idx := -1
var _drag_offset := Vector2.ZERO
var _hint: Label


func _ready() -> void:
	_load_data()
	_build_ui()
	_new_level()


func _load_data() -> void:
	var f := FileAccess.open("res://data/assets.json", FileAccess.READ)
	if f != null:
		_assets = JSON.parse_string(f.get_as_text())
	f = FileAccess.open("res://levels/enemy_editor_catalog.json", FileAccess.READ)
	if f != null:
		_catalog = JSON.parse_string(f.get_as_text())
	# Background choices: every imported background id with its first frame.
	for bk in _assets.get("backgrounds", {}):
		var frames: Array = _assets["backgrounds"][bk].get("frames", [])
		if frames.is_empty():
			continue
		var tex: Texture2D = load(str(frames[0]))
		_bgs.append({"key": str(bk), "name": str(_assets["backgrounds"][bk].get("name", bk)), "texture": tex})
	_bgs.sort_custom(func(a, b): return int(a.key) < int(b.key))
	# Palette icons: first preview layer of each enemy kind.
	for k in KIND_LIST:
		var layers := _spawn_layers({"kind": k, "object": 12})
		if not layers.is_empty():
			_kind_tex[k] = load(str(layers[0].texture))
	_scan_bases()


func _scan_bases() -> void:
	_bases.clear()
	_scan_dir("res://stages")
	_bases.sort_custom(func(a, b): return str(a.label) < str(b.label))


func _scan_dir(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_scan_dir(dir_path.path_join(sub))
	for fn in d.get_files():
		if not fn.ends_with(".tscn"):
			continue
		var path := dir_path.path_join(fn)
		var txt := FileAccess.get_file_as_string(path)
		if txt == "":
			continue
		var room := _tag(txt, "gm_room")
		if room != "level_0000":
			continue
		_bases.append({
			"label": _tag(txt, "gm_label"),
			"map": int(_tag(txt, "gm_map")),
			"lev": int(_tag(txt, "gm_lev")),
			"path": path,
		})


func _tag(txt: String, prop: String) -> String:
	var key := "metadata/" + prop
	var i := txt.find(key)
	if i < 0:
		return ""
	var eq := txt.find("=", i)
	var nl := txt.find("\n", eq)
	var line := txt.substr(eq + 1, nl - eq - 1).strip_edges()
	return line.trim_prefix("\"").trim_suffix("\"")


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	# ---- root: dark themed vertical layout
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 4)
	add_child(root_vbox)

	# ---- top toolbar
	var toolbar := PanelContainer.new()
	toolbar.add_theme_stylebox_override("panel", _sb(C_TOOLBAR, C_BORDER, 0, 0))
	root_vbox.add_child(toolbar)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	toolbar.add_child(trow)
	var title := Label.new()
	title.text = "GALAXY LEVEL EDITOR"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", C_ACCENT)
	trow.add_child(title)
	trow.add_child(_vsep())
	trow.add_child(_tbtn("Select", _set_select_tool))
	trow.add_child(_tbtn("New", _new_level))
	trow.add_child(_tbtn("Open", _open_level))
	trow.add_child(_tbtn("Save", _save_level, true))
	trow.add_child(_tbtn("Play", _playtest, true))
	trow.add_child(_vsep())
	trow.add_child(_lbl("Zoom"))
	trow.add_child(_tbtn("-", func(): _zoom_step(1.0 / 1.25)))
	_zoom_lbl = _lbl("100%")
	_zoom_lbl.custom_minimum_size = Vector2(44, 0)
	_zoom_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trow.add_child(_zoom_lbl)
	trow.add_child(_tbtn("+", func(): _zoom_step(1.25)))
	trow.add_child(_tbtn("Fit", _fit_view))
	trow.add_child(_tbtn("Player", func(): _center_on(player_pos)))
	trow.add_child(_vsep())
	_snap_check = CheckBox.new()
	_snap_check.text = "Snap"
	_snap_check.button_pressed = true
	_snap_check.toggled.connect(func(v): _snap = v)
	trow.add_child(_snap_check)
	_grid_check = CheckBox.new()
	_grid_check.text = "Grid"
	_grid_check.button_pressed = true
	_grid_check.toggled.connect(func(v): _level_view.show_grid = v; _level_view.queue_redraw())
	trow.add_child(_grid_check)
	trow.add_child(_vsep())
	_open_opt = OptionButton.new()
	_open_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open_opt.tooltip_text = "Saved custom levels"
	trow.add_child(_open_opt)
	_refresh_open_list()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(spacer)

	# ---- main row: palette | canvas | inspector
	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 4)
	root_vbox.add_child(main)

	# left: level settings + enemy palette + items
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 4)
	main.add_child(left)

	var settings := _section("LEVEL")
	left.add_child(settings)
	settings.add_child(_lbl("Name"))
	_name_edit = LineEdit.new()
	_name_edit.text_changed.connect(func(t): level_name = t; _refresh_items())
	settings.add_child(_name_edit)
	settings.add_child(_lbl("Base stage (wave timeline / music / win condition)"))
	_base_opt = OptionButton.new()
	for b in _bases:
		_base_opt.add_item("%s  (map %d lev %d)" % [b.label if b.label != "" else b.path.get_file(), b.map, b.lev])
	_base_opt.item_selected.connect(_on_base_selected)
	settings.add_child(_base_opt)
	settings.add_child(_lbl("Background"))
	_bg_opt = OptionButton.new()
	for b in _bgs:
		_bg_opt.add_item("%s (%s)" % [b.name, b.key])
	_bg_opt.item_selected.connect(_on_bg_selected)
	settings.add_child(_bg_opt)
	var hrow := HBoxContainer.new()
	hrow.add_child(_lbl("Scroll X"))
	_hspeed_spin = SpinBox.new()
	_hspeed_spin.min_value = -4.0
	_hspeed_spin.max_value = 4.0
	_hspeed_spin.step = 0.05
	_hspeed_spin.value_changed.connect(func(v): bg_hspeed = v; _refresh_bg())
	hrow.add_child(_hspeed_spin)
	hrow.add_child(_lbl("Scroll Y"))
	_vspeed_spin = SpinBox.new()
	_vspeed_spin.min_value = -4.0
	_vspeed_spin.max_value = 4.0
	_vspeed_spin.step = 0.05
	_vspeed_spin.value_changed.connect(func(v): bg_vspeed = v; _refresh_bg())
	hrow.add_child(_vspeed_spin)
	settings.add_child(hrow)
	_blank_check = CheckBox.new()
	_blank_check.text = "Blank level — remove base waves"
	_blank_check.button_pressed = true
	_blank_check.toggled.connect(func(v): blank_waves = v; _apply_blank_preset())
	settings.add_child(_blank_check)

	var pal := _section("ENEMIES — click, then click canvas")
	pal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(pal)
	var pscroll := ScrollContainer.new()
	pscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pal.add_child(pscroll)
	_palette_grid = GridContainer.new()
	_palette_grid.columns = 5
	_palette_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pscroll.add_child(_palette_grid)
	_build_palette()

	var items_panel := _section("ITEMS")
	left.add_child(items_panel)
	_item_list = ItemList.new()
	_item_list.custom_minimum_size = Vector2(0, 96)
	_item_list.item_selected.connect(_on_item_selected)
	_item_list.item_activated.connect(_on_item_activated)
	items_panel.add_child(_item_list)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 4)
	drow.add_child(_tbtn("Delete", _delete_selected))
	drow.add_child(_tbtn("+ Wave", _add_timing_row))
	items_panel.add_child(drow)

	# center: canvas + timeline
	var center := PanelContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(center)
	var cvbox := VBoxContainer.new()
	cvbox.add_theme_constant_override("separation", 2)
	center.add_child(cvbox)
	_svc = SubViewportContainer.new()
	_svc.stretch = true
	_svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_svc.custom_minimum_size = Vector2(480, 360)
	cvbox.add_child(_svc)
	_svc.gui_input.connect(_on_viewport_input)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(ROOM_W), int(ROOM_H))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_svc.add_child(_viewport)
	_level_view = Node2D.new()
	_level_view.set_script(load("res://editor/level_view.gd"))
	_viewport.add_child(_level_view)
	_marker_root = Node2D.new()
	_level_view.add_child(_marker_root)
	_ghost = Node2D.new()
	_ghost.visible = false
	_level_view.add_child(_ghost)
	_ghost_sprite = Sprite2D.new()
	_ghost_sprite.centered = false
	_ghost_sprite.modulate = Color(1, 1, 1, 0.55)
	_ghost.add_child(_ghost_sprite)
	_timeline = Control.new()
	_timeline.set_script(load("res://editor/wave_timeline.gd"))
	_timeline.editor = self
	cvbox.add_child(_timeline)

	# right: inspector
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(290, 0)
	main.add_child(right)
	var ipanel := _section("PROPERTIES")
	ipanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(ipanel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ipanel.add_child(scroll)
	_inspector = VBoxContainer.new()
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inspector)

	# ---- status bar
	var status_bar := PanelContainer.new()
	status_bar.add_theme_stylebox_override("panel", _sb(C_TOOLBAR, C_BORDER, 0, 0))
	root_vbox.add_child(status_bar)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 8)
	status_bar.add_child(srow)
	_hint = _lbl("Wheel: zoom · Middle-drag: pan · Right-click: delete · Esc: select")
	_hint.add_theme_color_override("font_color", C_DIM)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(_hint)
	_status = _lbl("")
	_status.add_theme_color_override("font_color", C_ACCENT)
	_status.custom_minimum_size = Vector2(280, 0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	srow.add_child(_status)

	_apply_theme_recursive(root_vbox)


# ------------------------------------------------------------- theme

func _sb(bg: Color, border: Color = C_BORDER, radius: int = 4, bw: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


func _apply_theme_recursive(n: Node) -> void:
	if (n is PanelContainer or n is Panel) and not n.has_theme_stylebox_override("panel"):
		n.add_theme_stylebox_override("panel", _sb(C_PANEL))
	elif n is Button:
		var b := n as Button
		var accent: bool = b.get_meta("accent", false)
		var pressed_bg := C_ACCENT.darkened(0.45) if accent else C_ACCENT.darkened(0.55)
		var pressed_border := C_ACCENT if accent else C_BORDER.lightened(0.2)
		b.add_theme_stylebox_override("normal", _sb(C_PANEL2))
		b.add_theme_stylebox_override("hover", _sb(C_PANEL2.lightened(0.10)))
		b.add_theme_stylebox_override("pressed", _sb(pressed_bg, pressed_border))
		b.add_theme_stylebox_override("hover_pressed", _sb(pressed_bg.lightened(0.08), pressed_border))
		b.add_theme_stylebox_override("focus", _sb(Color(0, 0, 0, 0), C_ACCENT, 4, 1))
		b.add_theme_stylebox_override("disabled", _sb(C_PANEL.darkened(0.3)))
		b.add_theme_color_override("font_color", C_TEXT)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", C_DIM)
		b.add_theme_font_size_override("font_size", 12)
	elif n is Label and not n.has_theme_color_override("font_color"):
		n.add_theme_color_override("font_color", C_TEXT)
	elif n is LineEdit:
		n.add_theme_stylebox_override("normal", _sb(C_BG))
		n.add_theme_stylebox_override("focus", _sb(C_BG, C_ACCENT))
		n.add_theme_color_override("font_color", C_TEXT)
		n.add_theme_color_override("font_placeholder_color", C_DIM)
	elif n is OptionButton:
		n.add_theme_color_override("font_color", C_TEXT)
		n.add_theme_color_override("font_selected_color", Color.WHITE)
		n.add_theme_stylebox_override("normal", _sb(C_BG))
		n.add_theme_stylebox_override("focus", _sb(C_BG, C_ACCENT))
		n.add_theme_stylebox_override("hover", _sb(C_PANEL2))
		n.add_theme_stylebox_override("pressed", _sb(C_PANEL2.lightened(0.1)))
		# dark dropdown popup
		var pop: PopupMenu = n.get_popup()
		if pop != null:
			pop.add_theme_stylebox_override("panel", _sb(C_PANEL2, C_BORDER, 4, 1))
			pop.add_theme_color_override("font_color", C_TEXT)
			pop.add_theme_color_override("font_hover_color", Color.WHITE)
	elif n is SpinBox:
		n.add_theme_color_override("font_color", C_TEXT)
		n.add_theme_color_override("font_selected_color", Color.WHITE)
		n.add_theme_stylebox_override("normal", _sb(C_BG))
		n.add_theme_stylebox_override("focus", _sb(C_BG, C_ACCENT))
		n.add_theme_stylebox_override("hover", _sb(C_PANEL2))
		n.add_theme_stylebox_override("pressed", _sb(C_PANEL2.lightened(0.1)))
	elif n is ItemList:
		n.add_theme_stylebox_override("panel", _sb(C_BG))
		n.add_theme_stylebox_override("focus", _sb(C_BG, C_ACCENT))
		n.add_theme_stylebox_override("selected", _sb(C_ACCENT.darkened(0.55), C_ACCENT, 3, 1))
		n.add_theme_stylebox_override("selected_focus", _sb(C_ACCENT.darkened(0.5), C_ACCENT, 3, 1))
		n.add_theme_color_override("font_color", C_TEXT)
		n.add_theme_color_override("font_selected_color", Color.WHITE)
	elif n is ScrollBar:
		n.add_theme_stylebox_override("scroll", _sb(C_BG, C_BORDER, 3, 0))
		n.add_theme_stylebox_override("grabber", _sb(C_PANEL2.lightened(0.15), C_BORDER, 3, 0))
		n.add_theme_stylebox_override("grabber_highlight", _sb(C_PANEL2.lightened(0.3), C_ACCENT, 3, 1))
		n.add_theme_stylebox_override("grabber_pressed", _sb(C_ACCENT.darkened(0.5), C_ACCENT, 3, 1))
		n.add_theme_stylebox_override("increment", _sb(C_PANEL2, C_BORDER, 0, 0))
		n.add_theme_stylebox_override("increment_highlight", _sb(C_PANEL2.lightened(0.2), C_ACCENT, 0, 0))
		n.add_theme_stylebox_override("increment_pressed", _sb(C_ACCENT.darkened(0.5), C_ACCENT, 0, 0))
		n.add_theme_stylebox_override("decrement", _sb(C_PANEL2, C_BORDER, 0, 0))
		n.add_theme_stylebox_override("decrement_highlight", _sb(C_PANEL2.lightened(0.2), C_ACCENT, 0, 0))
		n.add_theme_stylebox_override("decrement_pressed", _sb(C_ACCENT.darkened(0.5), C_ACCENT, 0, 0))
	elif n is CheckBox:
		n.add_theme_color_override("font_color", C_TEXT)
		n.add_theme_color_override("font_hover_color", Color.WHITE)
		n.add_theme_color_override("font_pressed_color", Color.WHITE)
		n.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	elif n is Separator or n is HSeparator or n is VSeparator:
		n.add_theme_color_override("font_color", C_BORDER)
	for c in n.get_children(true):
		_apply_theme_recursive(c)


func _section(title_text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(C_PANEL, C_BORDER, 5, 1))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	p.add_child(vb)
	var l := Label.new()
	l.text = title_text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", C_ACCENT)
	vb.add_child(l)
	return p


func _tbtn(t: String, cb: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = t
	if accent:
		b.set_meta("accent", true)
	b.pressed.connect(cb)
	return b


func _vsep() -> VSeparator:
	var s := VSeparator.new()
	s.add_theme_constant_override("separation", 4)
	return s


func _zoom_step(f: float) -> void:
	_zoom = clampf(_zoom * f, 0.3, 4.0)
	_apply_view()


func _fit_view() -> void:
	var s := _svc.size
	if s.x <= 0 or s.y <= 0:
		return
	_zoom = clampf(minf(s.x / ROOM_W, s.y / ROOM_H) * 0.96, 0.3, 4.0)
	_view_center = VIEW_CENTER
	_apply_view()


func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _btn(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.pressed.connect(cb)
	return b


func _build_palette() -> void:
	for k in KIND_LIST:
		var b := Button.new()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(56, 52)
		b.tooltip_text = _kind_name(k)
		var tex: Texture2D = _kind_tex.get(k)
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.set_anchors_preset(Control.PRESET_FULL_RECT)
			tr.offset_top = 4
			tr.offset_bottom = 22
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tr)
		var l := Label.new()
		l.text = _kind_name(k).left(9)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 9)
		l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_top = -16
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		b.pressed.connect(_on_palette_pick.bind(k, b))
		_palette_grid.add_child(b)
		_palette_btns[k] = b
	# preselect first enemy
	if KIND_LIST.size() > 0:
		_on_palette_pick(KIND_LIST[0], _palette_btns[KIND_LIST[0]])


func _on_palette_pick(kind: int, btn: Button) -> void:
	_pending_kind = kind
	_tool = "spawn"
	for k in _palette_btns:
		_palette_btns[k].button_pressed = (_palette_btns[k] == btn)
	if _hint != null:
		_hint.text = "Placing %s — click the canvas. Right-click deletes, Esc cancels." % _kind_name(kind)
	if _status != null:
		_status.text = "Placing: " + _kind_name(kind)


func _set_select_tool() -> void:
	_tool = "select"
	for k in _palette_btns:
		_palette_btns[k].button_pressed = false
	if _hint != null:
		_hint.text = "Wheel: zoom · Middle-drag: pan · Right-click: delete · Esc: select"
	if _status != null:
		_status.text = "Select mode"


# ------------------------------------------------------------- level data

func _new_level() -> void:
	level_name = "my_level"
	base_map = 0
	base_lev = 2
	base_label = ""
	bg_key = "0"
	bg_hspeed = 0.0
	bg_vspeed = 0.0
	blank_waves = true
	player_pos = Vector2(416, 576)
	spawns.clear()
	timings.clear()
	scene_path = ""
	room_id = -1
	_zoom = 1.0
	_view_center = VIEW_CENTER
	_apply_view()
	if _bases.size() > 0:
		_base_opt.select(0)
		_on_base_selected(0)
	if _bgs.size() > 0:
		_bg_opt.select(0)
		_on_bg_selected(0)
	_name_edit.text = level_name
	_blank_check.set_pressed_no_signal(true)
	_hspeed_spin.value = 0.0
	_vspeed_spin.value = 0.0
	_apply_blank_preset()
	_refresh_all()
	_status.text = "New level. Pick an enemy below, then click the canvas to place it."


func _on_base_selected(idx: int) -> void:
	if idx < 0 or idx >= _bases.size():
		return
	var b: Dictionary = _bases[idx]
	base_map = int(b.map)
	base_lev = int(b.lev)
	base_label = str(b.label)
	_apply_blank_preset()
	_refresh_items()


func _on_bg_selected(idx: int) -> void:
	if idx < 0 or idx >= _bgs.size():
		return
	bg_key = str(_bgs[idx].key)
	_refresh_bg()


func _bg_texture() -> Texture2D:
	for b in _bgs:
		if b.key == bg_key:
			return b.texture
	return _bgs[0].texture if _bgs.size() > 0 else null


func _apply_blank_preset() -> void:
	# Remove any previous auto-generated blank rows, then re-add if enabled.
	timings = timings.filter(func(t): return not t.get("auto_blank", false))
	if blank_waves:
		timings.append({"table": "num", "stage": 0, "first": -1, "last": -1,
			"value": 0.0, "activation": 0, "auto_blank": true})
		timings.append({"table": "perioder", "stage": 0, "first": 0, "last": 199,
			"value": 0.0, "activation": 0, "auto_blank": true})
	_refresh_items()


func _add_timing_row() -> void:
	timings.append({"table": "lev", "stage": 0, "first": 0, "last": 0,
		"value": 0.0, "activation": 0})
	_refresh_items()
	_select_last()


func _default_spawn(pos: Vector2) -> Dictionary:
	return {
		"mode": 1, "object": 12, "match_kind": -1, "kind": _pending_kind,
		"sequence": 100, "kamikaze": -1, "stage": 0,
		"start": 10.0, "count": 1, "interval": 1.0,
		"pos": pos, "target": Vector2(440, 128), "override_target": true,
	}


func _spawn_layers(s: Dictionary) -> Array:
	var kind: int = int(s.get("kind", -1))
	var obj: int = int(s.get("object", 12))
	if obj == 12 and kind >= 0 and _catalog.has(str(kind)):
		return _catalog[str(kind)]
	var o: Dictionary = _catalog.get("_objects", {}).get(str(obj), {})
	return o.get("layers", [])


# ------------------------------------------------------------- markers

func _refresh_bg() -> void:
	_level_view.bg_texture = _bg_texture()
	_level_view.queue_redraw()


func _refresh_all() -> void:
	_refresh_bg()
	_rebuild_markers()
	_refresh_items()
	_refresh_inspector()
	_update_ghost()
	if _timeline != null:
		_timeline.queue_redraw()


func _rebuild_markers() -> void:
	for c in _marker_root.get_children():
		c.queue_free()
	_player_marker = _make_marker(player_pos, _player_sprite(), "PLAYER", Color(0.4, 1, 0.4))
	_marker_root.add_child(_player_marker)
	for i in spawns.size():
		var s: Dictionary = spawns[i]
		var marker := _make_marker(s.pos, _spawn_sprite(s),
			"%s x%d @%.0f" % [_kind_name(int(s.kind)), int(s["count"]), float(s["start"])],
			Color(1, 0.6, 0.2))
		marker.set_meta("item", _item_ref("spawn", i))
		_marker_root.add_child(marker)
	if _timeline != null:
		_timeline.queue_redraw()


func _make_marker(pos: Vector2, sprite: Texture2D, text: String, color: Color) -> Node2D:
	var m := Node2D.new()
	m.position = pos
	if sprite != null:
		var sp := Sprite2D.new()
		sp.texture = sprite
		sp.centered = false
		m.add_child(sp)
	var l := Label.new()
	l.text = text
	l.position = Vector2(-40, 24)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color.BLACK)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	m.add_child(l)
	var ring := Node2D.new()
	ring.set_script(load("res://editor/marker_ring.gd"))
	ring.ring_color = color
	m.add_child(ring)
	return m


func _player_sprite() -> Texture2D:
	var o: Dictionary = _catalog.get("_objects", {}).get("0", {})
	var layers: Array = o.get("layers", [])
	if layers.is_empty():
		return null
	return load(str(layers[0].texture))


func _spawn_sprite(s: Dictionary) -> Texture2D:
	var layers := _spawn_layers(s)
	if layers.is_empty():
		return null
	return load(str(layers[0].texture))


func _kind_name(kind: int) -> String:
	return str(KIND_NAMES.get(kind, "kind_%d" % kind)).replace("_", " ")


# ------------------------------------------------------------- item list

func _item_ref(type: String, index: int) -> Dictionary:
	return {"type": type, "index": index}


func _rebuild_items() -> void:
	_items.clear()
	for i in spawns.size():
		_items.append(_item_ref("spawn", i))
	for i in timings.size():
		_items.append(_item_ref("timing", i))
	_items.append(_item_ref("player", 0))


func _refresh_items() -> void:
	_rebuild_items()
	_item_list.clear()
	for it in _items:
		_item_list.add_item(_item_text(it))
	if _sel >= 0 and _sel < _items.size():
		_item_list.select(_sel)


func _item_text(it: Dictionary) -> String:
	if it.type == "spawn":
		var s: Dictionary = spawns[it.index]
		return "ENEMY  %s x%d  start=%.0f int=%.2f  (%d,%d)" % [
			_kind_name(int(s.kind)), int(s["count"]), float(s["start"]),
			float(s["interval"]), int(s.pos.x), int(s.pos.y)]
	if it.type == "timing":
		var t: Dictionary = timings[it.index]
		return "WAVE   %s st%d [%d..%d] = %s" % [
			str(t.table), int(t.stage), int(t.first), int(t["last"]),
			str(t.value)]
	return "PLAYER start (%d,%d)" % [int(player_pos.x), int(player_pos.y)]


func _select_last() -> void:
	_sel = _items.size() - 1
	_item_list.select(_sel)
	_refresh_inspector()


func _on_item_selected(idx: int) -> void:
	_sel = idx
	_refresh_inspector()


func _on_item_activated(idx: int) -> void:
	# double-click / Enter: center the view on the item
	if idx < 0 or idx >= _items.size():
		return
	var it: Dictionary = _items[idx]
	if it.type == "spawn":
		_center_on(spawns[it.index].pos)
	elif it.type == "player":
		_center_on(player_pos)


func _select_spawn_index(spawn_i: int) -> void:
	_sel = _item_index_of("spawn", spawn_i)
	if _sel >= 0:
		_item_list.select(_sel)
		_refresh_inspector()


func _selected() -> Dictionary:
	if _sel < 0 or _sel >= _items.size():
		return {}
	var it: Dictionary = _items[_sel]
	if it.type == "spawn":
		return spawns[it.index]
	if it.type == "timing":
		return timings[it.index]
	return {"type": "player"}


func _delete_selected() -> void:
	if _sel < 0 or _sel >= _items.size():
		return
	var it: Dictionary = _items[_sel]
	if it.type == "spawn":
		spawns.remove_at(it.index)
		_status.text = "Deleted spawn."
	elif it.type == "timing":
		timings.remove_at(it.index)
		_status.text = "Deleted timing row."
	else:
		_status.text = "The player start can't be deleted."
		return
	_sel = -1
	_refresh_all()


# ------------------------------------------------------------- inspector

func _refresh_inspector() -> void:
	for c in _inspector.get_children():
		c.queue_free()
	var sel := _selected()
	if sel.is_empty():
		_inspector.add_child(_lbl("Select an item to edit its properties."))
		_apply_theme_recursive(_inspector)
		return
	var it: Dictionary = _items[_sel]
	if it.type == "spawn":
		_build_spawn_inspector(sel)
	elif it.type == "timing":
		_build_timing_inspector(sel)
	else:
		_build_player_inspector()
	_apply_theme_recursive(_inspector)


func _field_row(parent: VBoxContainer, text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(110, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)


func _spin(parent: VBoxContainer, text: String, val: float, lo: float, hi: float, step: float, cb: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.value_changed.connect(cb)
	_field_row(parent, text, s)
	return s


func _check(parent: VBoxContainer, text: String, val: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = val
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


func _build_spawn_inspector(s: Dictionary) -> void:
	_inspector.add_child(_lbl("ENEMY SPAWN"))
	var kind_opt := OptionButton.new()
	for k in KIND_LIST:
		kind_opt.add_item("%d %s" % [k, _kind_name(k)])
	kind_opt.select(KIND_LIST.find(int(s.kind)))
	kind_opt.item_selected.connect(func(i):
		s.kind = KIND_LIST[i]
		_on_data_changed())
	_field_row(_inspector, "Type", kind_opt)

	_spin(_inspector, "Object", float(s.object), 0, 999, 1, func(v): s.object = int(v); _on_data_changed())
	_spin(_inspector, "Stage", float(s.stage), 0, 10, 1, func(v): s.stage = int(v); _on_data_changed())
	_spin(_inspector, "Start period", float(s.start), 0, 199, 0.1, func(v): s.start = v; _on_data_changed())
	_spin(_inspector, "Count", float(s["count"]), 1, 999, 1, func(v): s["count"] = int(v); _on_data_changed())
	_spin(_inspector, "Interval", float(s.interval), 0.01, 100, 0.01, func(v): s.interval = v; _on_data_changed())
	var kam := OptionButton.new()
	kam.add_item("default (-1)")
	kam.add_item("no (0)")
	kam.add_item("yes (1)")
	kam.select(int(s.kamikaze) + 1)
	kam.item_selected.connect(func(i): s.kamikaze = i - 1; _on_data_changed())
	_field_row(_inspector, "Kamikaze", kam)
	_spin(_inspector, "Sequence", float(s.sequence), -1, 300, 1, func(v): s.sequence = int(v); _on_data_changed())
	_inspector.add_child(_lbl("Arrival target"))
	_spin(_inspector, "Target X", s.target.x, -2000, 3000, 1, func(v): s.target.x = v; _on_data_changed())
	_spin(_inspector, "Target Y", s.target.y, -2000, 3000, 1, func(v): s.target.y = v; _on_data_changed())
	_check(_inspector, "Override arrival target", bool(s.override_target), func(v): s.override_target = v; _on_data_changed())
	_inspector.add_child(_lbl("Spawn position: drag the marker on the canvas"))


func _build_timing_inspector(t: Dictionary) -> void:
	_inspector.add_child(_lbl("WAVE TABLE VALUE"))
	var top := OptionButton.new()
	for tn in TABLE_NAMES:
		top.add_item(tn)
	top.select(TABLE_NAMES.find(str(t.table)))
	top.item_selected.connect(func(i): t.table = TABLE_NAMES[i]; _on_data_changed())
	_field_row(_inspector, "Table", top)
	_spin(_inspector, "Stage", float(t.stage), 0, 10, 1, func(v): t.stage = int(v); _on_data_changed())
	_spin(_inspector, "First index", float(t.first), -1, 10000, 1, func(v): t.first = int(v); _on_data_changed())
	_spin(_inspector, "Last index", float(t["last"]), -1, 10000, 1, func(v): t["last"] = int(v); _on_data_changed())
	_spin(_inspector, "Value", float(t.value), -10000, 10000, 0.01, func(v): t.value = v; _on_data_changed())
	var act := OptionButton.new()
	act.add_item("level start")
	act.add_item("after tutorial")
	act.select(int(t.activation))
	act.item_selected.connect(func(i): t.activation = i; _on_data_changed())
	_field_row(_inspector, "Applies", act)
	if t.get("auto_blank", false):
		_inspector.add_child(_lbl("(auto-added by 'Blank level' — uncheck to remove)"))


func _build_player_inspector() -> void:
	_inspector.add_child(_lbl("PLAYER START"))
	_spin(_inspector, "X", player_pos.x, 0, ROOM_W, 1, func(v): player_pos.x = v; _on_data_changed())
	_spin(_inspector, "Y", player_pos.y, 0, ROOM_H, 1, func(v): player_pos.y = v; _on_data_changed())
	_inspector.add_child(_lbl("Drag the green marker on the canvas."))


func _on_data_changed() -> void:
	_rebuild_markers()
	_refresh_items()
	_update_ghost()


# ------------------------------------------------------------- canvas view

func _apply_view() -> void:
	_level_view.scale = Vector2(_zoom, _zoom)
	_level_view.position = VIEW_CENTER - _view_center * _zoom
	if _zoom_lbl != null:
		_zoom_lbl.text = "%d%%" % roundi(_zoom * 100)


func _center_on(world: Vector2) -> void:
	_view_center = world
	_apply_view()


func _viewport_px(event: InputEvent) -> Vector2:
	var p: Vector2 = event.position
	var s := _svc.size
	if s.x <= 0 or s.y <= 0:
		return p
	return Vector2(p.x * ROOM_W / s.x, p.y * ROOM_H / s.y)


func _view_to_world(vp: Vector2) -> Vector2:
	return (vp - VIEW_CENTER) / _zoom + _view_center


func _snap_pos(v: Vector2) -> Vector2:
	if not _snap:
		return v
	return Vector2(roundf(v.x / SNAP) * SNAP, roundf(v.y / SNAP) * SNAP)


func _update_ghost() -> void:
	if _ghost == null:
		return
	var show := _tool == "spawn"
	_ghost.visible = show
	if not show:
		return
	_ghost.position = _snap_pos(_mouse_world)
	var layers := _spawn_layers({"kind": _pending_kind, "object": 12})
	if not layers.is_empty():
		var tex: Texture2D = _kind_tex.get(_pending_kind)
		if tex == null:
			tex = load(str(layers[0].texture))
		_ghost_sprite.texture = tex
		_ghost_sprite.offset = Vector2.ZERO


# ------------------------------------------------------------- canvas input

func _on_viewport_input(event: InputEvent) -> void:
	# middle-mouse drag pans the view
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_panning = event.pressed
		_pan_last = _viewport_px(event)
		return
	if event is InputEventMouseMotion:
		var vp := _viewport_px(event)
		_mouse_world = _view_to_world(vp)
		if _panning:
			_view_center -= (vp - _pan_last) / _zoom
			_pan_last = vp
			_apply_view()
			return
		if _drag_idx >= 0:
			var it: Dictionary = _items[_drag_idx]
			var pos: Vector2 = _snap_pos(_mouse_world - _drag_offset)
			pos.x = clampf(pos.x, 0, ROOM_W)
			pos.y = clampf(pos.y, 0, ROOM_H)
			if it.type == "spawn":
				spawns[it.index].pos = pos
			elif it.type == "player":
				player_pos = pos
			_rebuild_markers()
			_refresh_items()
			_refresh_inspector()
			return
		_update_ghost()
		return
	# wheel zooms around the cursor
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var vp := _viewport_px(event)
		var world_under := _view_to_world(vp)
		var factor := 1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
		_zoom = clampf(_zoom * factor, 0.3, 4.0)
		_view_center = world_under - (vp - VIEW_CENTER) / _zoom
		_apply_view()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_world = _view_to_world(_viewport_px(event))
		var pos := _snap_pos(_mouse_world)
		if event.pressed:
			# clicking an existing marker always selects it, even in place mode
			var hit := _hit_marker(_mouse_world)
			var hit_type: String = str(hit.get("type", ""))
			if hit_type == "" and _tool == "spawn":
				pos.x = clampf(pos.x, 0, ROOM_W)
				pos.y = clampf(pos.y, 0, ROOM_H)
				spawns.append(_default_spawn(pos))
				_rebuild_items()
				_sel = _items.size() - 2  # spawn is second-to-last (player last)
				_refresh_all()
				_item_list.select(_sel)
				_refresh_inspector()
				return
			if hit_type == "player":
				_sel = _items.size() - 1
				_drag_idx = _sel
				_drag_offset = player_pos - pos
			elif hit_type == "spawn":
				_sel = _item_index_of("spawn", int(hit.index))
				_drag_idx = _sel
				_drag_offset = spawns[hit.index].pos - pos
			else:
				_sel = -1
				_refresh_inspector()
			_item_list.select(_sel)
			_refresh_inspector()
		else:
			_drag_idx = -1
		return
	# right-click deletes the spawn under the cursor
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_mouse_world = _view_to_world(_viewport_px(event))
		var hit := _hit_marker(_mouse_world)
		if str(hit.get("type", "")) == "spawn":
			var si := int(hit.index)
			if si >= 0 and si < spawns.size():
				spawns.remove_at(si)
				_sel = -1
				_refresh_all()
				_status.text = "Deleted spawn (right-click)."
		return


func _hit_marker(pos: Vector2) -> Dictionary:
	var radius := 24.0 / _zoom
	if player_pos.distance_to(pos) < radius:
		return {"type": "player", "index": 0}
	for i in range(spawns.size() - 1, -1, -1):
		if spawns[i].pos.distance_to(pos) < radius:
			return {"type": "spawn", "index": i}
	return {}


func _item_index_of(type: String, index: int) -> int:
	for i in _items.size():
		if _items[i].type == type and _items[i].index == index:
			return i
	return -1


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# don't steal keys while typing in a text field
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is SpinBox or focus is TextEdit:
		return
	match event.keycode:
		KEY_DELETE, KEY_BACKSPACE:
			_delete_selected()
		KEY_ESCAPE:
			_set_select_tool()


# ------------------------------------------------------------- open

func _refresh_open_list() -> void:
	_open_opt.clear()
	var d := DirAccess.open(CUSTOM_DIR)
	if d == null:
		return
	var files: Array = []
	for f in d.get_files():
		if str(f).ends_with(".tscn"):
			files.append(str(f))
	files.sort()
	for f in files:
		_open_opt.add_item(f)


func _open_level() -> void:
	var idx := _open_opt.selected
	if idx < 0:
		_status.text = "No saved levels yet."
		return
	_load_scene(CUSTOM_DIR.path_join(_open_opt.get_item_text(idx)))


func _load_scene(path: String) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		_status.text = "Could not load " + path
		return
	var inst := ps.instantiate()
	level_name = inst.get_meta("gm_label", path.get_file().get_basename()).to_lower()
	level_name = level_name.replace(" ", "_")
	base_map = int(inst.get_meta("gm_map", 0))
	base_lev = int(inst.get_meta("gm_lev", 2))
	base_label = str(inst.get_meta("gm_label", ""))
	room_id = -1
	scene_path = path
	player_pos = Vector2(416, 576)
	spawns.clear()
	timings.clear()
	blank_waves = false
	var waves := inst.get_node_or_null("Waves")
	var enemies_node := waves.get_node_or_null("Enemies") if waves != null else null
	if enemies_node != null:
		for en in enemies_node.get_children():
			if en.get("mode") == null:
				continue
			spawns.append({
					"mode": int(en.mode), "object": int(en.object_index),
					"match_kind": int(en.match_enemy_kind), "kind": int(en.enemy_kind),
					"sequence": int(en.arrival_sequence), "kamikaze": int(en.kamikaze),
					"stage": int(en.stage), "start": float(en.start_period),
					"count": int(en.count), "interval": float(en.interval_periods),
					"pos": en.position, "target": en.arrival_target,
					"override_target": bool(en.override_arrival_target),
				})
	var timing := waves.get_node_or_null("Timing") if waves != null else null
	if timing != null:
		var stack: Array = [timing]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			stack.append_array(n.get_children())
			if n.get("table") != null:
				timings.append({
					"table": str(n.table), "stage": int(n.stage),
					"first": int(n.first_index), "last": int(n.last_index),
					"value": float(n.value), "activation": int(n.activation),
				})
	var objs := inst.get_node_or_null("Objects_0")
	if objs != null:
		for c in objs.get_children():
			if int(c.get_meta("gm_object_index", -1)) == 0:
				player_pos = c.position
				break
	# background + scroll speeds from the Bg* node metadata
	for c in inst.get_children():
		if str(c.name).begins_with("Bg") and c.get_child_count() > 0:
			if int(c.get_meta("gm_background_slot", -1)) == 0:
				bg_hspeed = float(c.get_meta("gm_hspeed", 0.0))
				bg_vspeed = float(c.get_meta("gm_vspeed", 0.0))
			var sp := c.get_child(0)
			if sp is Sprite2D and sp.texture != null:
				var p: String = sp.texture.resource_path
				for bk in _assets.get("backgrounds", {}):
					for fr in _assets["backgrounds"][bk].get("frames", []):
						if str(fr) == p:
							bg_key = str(bk)
							break
				break
			break
	inst.free()
	_name_edit.text = level_name
	_select_base_by_values()
	_select_bg_by_key()
	_blank_check.set_pressed_no_signal(blank_waves)
	_hspeed_spin.value = bg_hspeed
	_vspeed_spin.value = bg_vspeed
	_apply_blank_preset()
	_zoom = 1.0
	_view_center = VIEW_CENTER
	_apply_view()
	_set_select_tool()
	_refresh_all()
	_status.text = "Loaded " + path.get_file()


func _select_base_by_values() -> void:
	for i in _bases.size():
		if int(_bases[i].map) == base_map and int(_bases[i].lev) == base_lev:
			_base_opt.select(i)
			return


func _select_bg_by_key() -> void:
	for i in _bgs.size():
		if _bgs[i].key == bg_key:
			_bg_opt.select(i)
			return


# ------------------------------------------------------------- save

func _save_level() -> void:
	var clean := level_name.strip_edges().to_lower()
	clean = clean.replace(" ", "_")
	var out := ""
	for ch in clean:
		var c := ch.unicode_at(0)
		out += ch if (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or ch == "_" else "_"
	clean = out
	if clean.is_empty():
		clean = "my_level"
	level_name = clean
	_name_edit.text = clean
	var room_name := "custom_" + clean
	DirAccess.make_dir_recursive_absolute(CUSTOM_DIR)
	scene_path = CUSTOM_DIR.path_join(clean + ".tscn")

	room_id = _register_room(room_name)
	if room_id < 0:
		_status.text = "ERROR: could not register room in game/rooms.json"
		return
	_build_scene(room_name)
	_refresh_open_list()
	_status.text = "Saved %s  (room %s #%d)" % [scene_path, room_name, room_id]


func _register_room(room_name: String) -> int:
	var rf := FileAccess.open("res://game/rooms.json", FileAccess.READ)
	if rf == null:
		return -1
	var rooms: Dictionary = JSON.parse_string(rf.get_as_text())
	rf.close()
	var rdict: Dictionary = rooms.get("rooms", {})
	# reuse existing id for this room name
	for k in rdict:
		if str(rdict[k].get("name", "")) == room_name:
			return int(k)
	# clone room 2 (the shared level room)
	var template: Dictionary = rdict.get("2", {})
	if template.is_empty():
		return -1
	var id := -1
	for cand in range(FIRST_ROOM_ID, FIRST_ROOM_ID + 200):
		if not rdict.has(str(cand)):
			id = cand
			break
	if id < 0:
		return -1
	var clone: Dictionary = template.duplicate(true)
	clone["name"] = room_name
	rdict[str(id)] = clone
	rooms["rooms"] = rdict
	var wf := FileAccess.open("res://game/rooms.json", FileAccess.WRITE)
	wf.store_string(JSON.stringify(rooms))
	wf.close()

	# alias room creation to the shared level boot code (room_2)
	var gf := FileAccess.open("res://game/registry.json", FileAccess.READ)
	var reg: Dictionary = JSON.parse_string(gf.get_as_text())
	gf.close()
	reg.get_or_add("room_create", {})[str(id)] = [ROOM_CODE_PART, "room_2"]
	var gw := FileAccess.open("res://game/registry.json", FileAccess.WRITE)
	gw.store_string(JSON.stringify(reg))
	gw.close()
	return id


func _build_scene(room_name: String) -> void:
	var root := Node2D.new()
	root.name = room_name
	root.set_meta("gm_room", room_name)
	root.set_meta("gm_map", base_map)
	root.set_meta("gm_lev", base_lev)
	root.set_meta("gm_minigame", 0)
	root.set_meta("gm_label", level_name.to_upper())
	root.set_meta("gm_bg_colour", 0)
	root.set_script(load("res://engine/room_preview_boot.gd"))

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.position = Vector2(512, 384)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(ROOM_W)
	cam.limit_bottom = int(ROOM_H)
	root.add_child(cam)

	var tex: Texture2D = _bg_texture()
	_add_bg_layer(root, "Bg0_background0", 0, -444.0, tex)
	_add_bg_layer(root, "Bg1_background0", 1, -222.0, tex)

	for gname in ["Objects_-10000000", "Objects_-1000000", "Objects_0"]:
		var g := Node2D.new()
		g.name = gname
		var depth: float = {"Objects_-10000000": -10000000.0, "Objects_-1000000": -1000000.0, "Objects_0": 0.0}[gname]
		g.z_index = int(depth / 10000.0)
		g.set_meta("gm_depth", depth)
		root.add_child(g)
		if gname == "Objects_0":
			_add_player(g, room_name)

	var waves := Node2D.new()
	waves.name = "Waves"
	waves.set_script(load("res://engine/level_waves.gd"))
	root.add_child(waves)
	var timing := Node.new()
	timing.name = "Timing"
	waves.add_child(timing)
	var custom := Node.new()
	custom.name = "Custom"
	timing.add_child(custom)
	for i in timings.size():
		custom.add_child(_make_timing_node(timings[i], i))
	var enemies := Node2D.new()
	enemies.name = "Enemies"
	waves.add_child(enemies)
	for i in spawns.size():
		enemies.add_child(_make_spawn_node(spawns[i], i))

	# register in levels/index.json so _scene_path finds the scene by room name
	# even when the stages/ filesystem scan has not picked up the new file yet.
	# Text-level insert keeps the file's original formatting (JSON.stringify
	# would re-sort keys and rewrite every entry).
	var xpath := "res://levels/index.json"
	var xtxt := FileAccess.get_file_as_string(xpath).replace("\r\n", "\n")
	if xtxt.find("\"name\": \"%s\"" % room_name) < 0:
		var entry := ",\n {\n  \"name\": \"%s\",\n  \"scene\": \"%s\",\n" % [room_name, scene_path] + \
			"  \"data\": \"\",\n  \"width\": 1024,\n  \"height\": 768,\n  \"fps\": 60\n }\n"
		var close := xtxt.rfind("]")
		if close >= 0:
			var head := xtxt.substr(0, close).rstrip(" \t\n")
			xtxt = head + entry + "]\n"
			var xw := FileAccess.open(xpath, FileAccess.WRITE)
			xw.store_string(xtxt)
			xw.close()

	var packed := PackedScene.new()
	_claim_ownership(root, root)
	add_child(root)  # pack() only serializes children of in-tree nodes
	packed.pack(root)
	remove_child(root)
	var err := ResourceSaver.save(packed, scene_path)
	root.free()
	if err != OK:
		_status.text = "ERROR saving scene: %s" % error_string(err)
		return
	# make sure the runtime scene index rescans stages/ for the new file
	var r_script = load("res://engine/r.gd")
	r_script._level_scenes_indexed = false
	r_script._level_scene_index.clear()
	r_script._scene_index.clear()


func _claim_ownership(node: Node, scene_root: Node) -> void:
	for c in node.get_children():
		c.owner = scene_root
		_claim_ownership(c, scene_root)


func _add_bg_layer(root: Node, bname: String, slot: int, xoff: float, tex: Texture2D) -> void:
	var bg := Node2D.new()
	bg.name = bname
	bg.z_index = -4080 + slot
	bg.set_meta("gm_foreground", false)
	bg.set_meta("gm_background_slot", slot)
	bg.set_meta("gm_hspeed", bg_hspeed if slot == 0 else bg_hspeed * 0.5)
	bg.set_meta("gm_vspeed", bg_vspeed)
	root.add_child(bg)
	var sp := Sprite2D.new()
	sp.name = "t0_0"
	sp.texture = tex
	sp.centered = false
	sp.position = Vector2(xoff, 0)
	bg.add_child(sp)


func _add_player(group: Node, room_name: String) -> void:
	var sp := Sprite2D.new()
	sp.name = room_name + "_player"
	sp.texture = _player_sprite()
	sp.position = player_pos
	sp.rotation = -PI / 2.0
	sp.scale = Vector2(1, 1)
	sp.offset = Vector2(-48, -74)
	sp.centered = false
	sp.set_meta("gm_object", "o_player_a")
	sp.set_meta("gm_object_index", 0)
	sp.set_meta("gm_id", 900000 + room_id)
	sp.set_meta("gm_visible", true)
	sp.set_meta("gm_sprite_index", 543)
	sp.set_meta("gm_preview_only", false)
	sp.set_meta("gm_position", player_pos)
	sp.set_meta("gm_empty_draw_event", false)
	group.add_child(sp)


func _make_timing_node(t: Dictionary, i: int) -> Node:
	var n := Node.new()
	n.name = "Timing_%02d" % i
	n.set_script(load("res://engine/level_wave_setting.gd"))
	n.table = str(t.table)
	n.stage = int(t.stage)
	n.first_index = int(t.first)
	n.last_index = int(t["last"])
	n.value = float(t.value)
	n.force_override = true
	n.activation = int(t.activation)
	n.source_key = "custom:%s:%d" % [level_name, i]
	return n


func _make_spawn_node(s: Dictionary, i: int) -> Node2D:
	var n := Node2D.new()
	n.name = "spawn_%02d" % i
	n.set_script(load("res://engine/level_spawn_rule.gd"))
	n.mode = 1
	n.object_index = int(s.object)
	n.match_enemy_kind = -1
	n.enemy_kind = int(s.kind)
	n.arrival_sequence = int(s.sequence)
	n.kamikaze = int(s.kamikaze)
	n.stage = int(s.stage)
	n.start_period = float(s.start)
	n.count = int(s["count"])
	n.interval_periods = float(s.interval)
	n.position = s.pos
	n.source_position = s.pos
	n.arrival_target = s.target
	n.override_arrival_target = bool(s.override_target)
	n.show_name = false
	n.preview_layers = _spawn_layers(s)
	n.source_key = "custom:%s:spawn:%d" % [level_name, i]
	n.source_description = "Custom level spawn"
	return n


# ------------------------------------------------------------- playtest

func _playtest() -> void:
	if scene_path == "":
		_save_level()
		if scene_path == "":
			return
	var r_script = load("res://engine/r.gd")
	r_script._level_scenes_indexed = false
	r_script._level_scene_index.clear()
	r_script._scene_index.clear()
	get_tree().change_scene_to_file(scene_path)
