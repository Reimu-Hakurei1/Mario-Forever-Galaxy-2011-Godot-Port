@tool
extends EditorPlugin

var _last: Node = null
var _acc: float = 0.0
var _shot: String = ""
var _shot_left: float = 0.0
var _frame_left: float = 0.0
var _cam_pos: Vector2 = Vector2.ZERO
var _room_size: Vector2 = Vector2(1024, 768)
var _open: String = ""
var _opened: bool = false
var _canvas_editor: Node
var _zoom_widget: Node
var _wave_check_requested: bool = false
var _wave_check: EditorScript
var _timeline_check_requested: bool = false
var _timeline_check: EditorScript
var _timeline: HBoxContainer


func _enter_tree() -> void:
	_timeline = load("res://addons/room_frame/level_timeline.gd").new()
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _timeline)
	var icon := EditorInterface.get_base_control().get_theme_icon("Node2D", "EditorIcons")
	add_custom_type("GalaxyWaves", "Node2D", preload("res://engine/level_waves.gd"), icon)
	add_custom_type("GalaxySpawnRule", "Node2D", preload("res://engine/level_spawn_rule.gd"), icon)
	add_custom_type("GalaxyWaveSetting", "Node", preload("res://engine/level_wave_setting.gd"), icon)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--editor-shot="):
			_shot = a.substr(14)
		elif a == "--wave-editor-check":
			_wave_check_requested = true
		elif a == "--timeline-editor-check":
			_timeline_check_requested = true
	for a in OS.get_cmdline_args():
		if a.ends_with(".tscn"):
			_open = a
	set_process(true)


func _exit_tree() -> void:
	if is_instance_valid(_timeline):
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _timeline)
		_timeline.queue_free()
	remove_custom_type("GalaxyWaves")
	remove_custom_type("GalaxySpawnRule")
	remove_custom_type("GalaxyWaveSetting")


func _find_editor_controls() -> void:
	_canvas_editor = EditorInterface.get_editor_viewport_2d()
	while _canvas_editor != null and _canvas_editor.get_class() != "CanvasItemEditor":
		_canvas_editor = _canvas_editor.get_parent()
	if _canvas_editor == null:
		return
	var nodes: Array[Node] = [_canvas_editor]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if node.get_class() == "EditorZoomWidget":
			_zoom_widget = node
			return
		nodes.append_array(node.get_children(true))


func _process(delta: float) -> void:
	if _shot_left > 0.0:
		_shot_left -= delta
		if _shot_left <= 0.0:
			var vp: SubViewport = EditorInterface.get_editor_viewport_2d()
			vp.get_texture().get_image().save_png(_shot)
			print("ROOM_FRAME shot saved ", _shot)
			get_tree().quit()
			return
	_acc += delta
	if _acc < 0.25:
		return
	_acc = 0.0
	if _wave_check_requested:
		_wave_check_requested = false
		_opened = true
		_wave_check = load("res://tools/editor_wave_check.gd").new()
		_wave_check.call_deferred("_run")
		return
	if _timeline_check_requested:
		_timeline_check_requested = false
		_opened = true
		_timeline_check = load("res://tools/editor_timeline_check.gd").new()
		_timeline_check.call_deferred("_run")
		return
	if _open != "" and not _opened:
		_opened = true
		EditorInterface.open_scene_from_path(_open)
		EditorInterface.set_main_screen_editor("2D")
		return
	var sc: Node = EditorInterface.get_edited_scene_root()
	if sc == null or not sc.has_meta("gm_room"):
		return
	if sc != _last:
		_last = sc
		var cam: Camera2D = sc.get_node_or_null("Camera2D")
		if cam == null:
			return
		_room_size = Vector2(cam.limit_right - cam.limit_left, cam.limit_bottom - cam.limit_top)
		if _room_size.x <= 0 or _room_size.y <= 0:
			return
		_cam_pos = Vector2(cam.limit_left, cam.limit_top) + _room_size / 2.0
		_find_editor_controls()
		_frame_left = 1.5
		if _shot != "":
			_shot_left = 3.0
	if _frame_left > 0.0:
		_frame_left -= 0.25
		if _canvas_editor == null or _zoom_widget == null:
			return
		var vp: SubViewport = EditorInterface.get_editor_viewport_2d()
		var zoom: float = maxf(0.05, minf(vp.size.x / _room_size.x, vp.size.y / _room_size.y) * 0.9)
		# The editor overwrites canvas_transform; update its zoom state instead.
		_zoom_widget.call("set_zoom", zoom)
		_zoom_widget.emit_signal("zoom_changed", zoom)
		_canvas_editor.call("center_at", _cam_pos)
