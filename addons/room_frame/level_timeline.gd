@tool
extends HBoxContainer

var frame_input: SpinBox
var tutorial: CheckBox
var status: Label
var pin_button: Button
var base_button: CheckBox
var directory := ""
var worker_pid := -1
var serial := -1
var scene: Node2D
var preview: Node2D
var elapsed := 0.0
var capture_started := 0
var worker_alive := true
var worker_checked := 0


func _ready() -> void:
	name = "GalaxyTimeline"
	var label := Label.new()
	label.text = "Galaxy frame"
	add_child(label)
	frame_input = SpinBox.new()
	frame_input.min_value = 1
	frame_input.max_value = 36000
	frame_input.value = 600
	frame_input.tooltip_text = "Logic frames from room entry. Capture seeks from the start using the current unsaved scene."
	add_child(frame_input)
	_button("Capture", start.bind(false))
	_button("Play", start.bind(true))
	_button("Stop", stop)
	pin_button = _button("Keep editable frame", pin)
	pin_button.disabled = true
	pin_button.tooltip_text = "Keep native instance nodes in this scene. Move, rotate, scale, tint, disable or duplicate an instance root; save normally. Ctrl+Z undoes replacement."
	tutorial = CheckBox.new()
	tutorial.text = "After tutorial"
	tutorial.button_pressed = true
	tutorial.tooltip_text = "Complete First Encounter's input tutorial before previewing combat; this does not change gameplay."
	add_child(tutorial)
	base_button = CheckBox.new()
	base_button.text = "Base layout"
	base_button.tooltip_text = "Show original editable backgrounds, placed objects and wave controls instead of the captured frame."
	add_child(base_button)
	status = Label.new()
	add_child(status)


func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	add_child(button)
	return button


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.25:
		return
	elapsed = 0.0
	var current := EditorInterface.get_edited_scene_root()
	visible = current is Node2D and current.has_meta("gm_room")
	if current != scene:
		stop()
		_restore_rendering()
		scene = current if visible else null
		status.text = ""
	if not visible:
		return
	if not directory.is_empty():
		var ready := directory.path_join("ready.json")
		if FileAccess.file_exists(ready):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ready))
			if data is Dictionary and int(data.serial) != serial:
				var packed: PackedScene = ResourceLoader.load(str(data.path), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
				if packed != null:
					_clear_preview()
					preview = packed.instantiate()
					preview.name = "TimelinePreview"
					preview.set_meta("_edit_lock_", true)
					scene.add_child(preview, false, Node.INTERNAL_MODE_BACK)
					serial = int(data.serial)
					frame_input.value = int(data.frame)
					status.text = "Frame %d" % int(data.frame)
					pin_button.disabled = false
		if _worker_dead():
			worker_pid = -1
			if serial < 0:
				status.text = "Capture failed; see " + directory.path_join("worker.log")
		elif serial < 0 and capture_started > 0:
			status.text = "Seeking (%ds)" % ((Time.get_ticks_msec() - capture_started) / 1000)
	_update_rendering()


func start(play: bool) -> void:
	if not is_instance_valid(scene):
		return
	stop()
	var packed := PackedScene.new()
	if packed.pack(scene) != OK:
		status.text = "Could not pack the open scene."
		return
	directory = ProjectSettings.globalize_path("res://.godot/level_previews/%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		status.text = "Could not create isolated preview folder."
		directory = ""
		return
	var input := directory.path_join("input.tscn")
	if ResourceSaver.save(packed, input) != OK:
		status.text = "Could not save the preview copy."
		directory = ""
		return
	var pinned := scene.get_node_or_null("CapturedLevel")
	var random_seed: int = pinned.capture_seed if pinned != null and pinned.has_method("snapshot_edits") else 12345
	var request := {"scene": input, "seed": random_seed, "frame": int(frame_input.value), "after_tutorial": tutorial.button_pressed, "play": play, "parent_pid": OS.get_process_id()}
	var file := FileAccess.open(directory.path_join("request.json"), FileAccess.WRITE)
	if file == null:
		status.text = "Could not write the preview request."
		directory = ""
		return
	file.store_string(JSON.stringify(request))
	file.close()
	var environment: Dictionary = {}
	for key in ["HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "TEMP", "TMP", "GALAXY_PREVIEW_ROOT"]:
		environment[key] = {"exists": OS.has_environment(key), "value": OS.get_environment(key)}
		var value := directory if key == "GALAXY_PREVIEW_ROOT" else directory.path_join(key)
		DirAccess.make_dir_recursive_absolute(value)
		OS.set_environment(key, value)
	DirAccess.make_dir_recursive_absolute(directory.path_join("saves"))
	var args := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--windowed", "--position", "-16000,-16000", "--audio-driver", "Dummy", "--log-file", directory.path_join("worker.log"), "--script", "res://tools/level_preview_worker.gd", "--", "--preview-request=" + directory.path_join("request.json"), "--savedir=" + directory.path_join("saves")])
	worker_pid = OS.create_process(OS.get_executable_path(), args)
	worker_alive = true
	worker_checked = 0
	for key in environment:
		if environment[key].exists:
			OS.set_environment(key, environment[key].value)
		else:
			OS.unset_environment(key)
	serial = -1
	capture_started = Time.get_ticks_msec()
	status.text = "Seeking..." if worker_pid > 0 else "Could not start the preview worker."
	base_button.button_pressed = false


func _worker_dead() -> bool:
	if worker_pid <= 0:
		return false
	# OS.is_process_running reports false for live PIDs on this Windows build.
	if Time.get_ticks_msec() - worker_checked < 2000:
		return not worker_alive
	worker_checked = Time.get_ticks_msec()
	var output: Array = []
	OS.execute("tasklist", ["/FI", "PID eq %d" % worker_pid, "/NH"], output, true)
	worker_alive = output.size() > 0 and str(output[0]).contains(str(worker_pid))
	return not worker_alive


func stop() -> void:
	if not directory.is_empty() and not _worker_dead():
		var file := FileAccess.open(directory.path_join("stop"), FileAccess.WRITE)
		if file != null:
			file.close()
	worker_pid = -1
	directory = ""
	_clear_preview()
	if pin_button != null:
		pin_button.disabled = true
	_restore_rendering()


func _clear_preview() -> void:
	if is_instance_valid(preview):
		preview.get_parent().remove_child(preview)
		preview.queue_free()
	preview = null


func pin() -> void:
	if not is_instance_valid(preview) or not is_instance_valid(scene):
		return
	var captured := preview
	preview = null
	scene.remove_child(captured)
	stop()
	captured.name = "CapturedLevel"
	# Detach from the temporary preview .scn so saving embeds the nodes instead
	# of instancing a file that is deleted with the preview folder.
	captured.scene_file_path = ""
	captured.apply_edits = true
	captured.remove_meta("_edit_lock_")
	var previous := scene.get_node_or_null("CapturedLevel")
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Keep editable Galaxy frame", UndoRedo.MERGE_DISABLE, scene)
	undo.add_undo_method(scene, "remove_child", captured)
	if previous != null:
		undo.add_do_method(scene, "remove_child", previous)
		undo.add_undo_method(scene, "add_child", previous)
		undo.add_undo_method(self, "_set_owners", previous, scene)
		undo.add_undo_reference(previous)
	undo.add_do_method(scene, "add_child", captured, true)
	undo.add_do_method(self, "_set_owners", captured, scene)
	undo.add_do_reference(captured)
	undo.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(captured)
	status.text = "Editable frame kept; save the scene."
	_update_rendering()


func _set_owners(node: Node, owner_root: Node) -> void:
	node.owner = owner_root
	for child in node.get_children():
		_set_owners(child, owner_root)


func _update_rendering() -> void:
	if not is_instance_valid(scene):
		return
	var captured := scene.get_node_or_null("CapturedLevel")
	var shown: Node = preview if is_instance_valid(preview) else captured
	var show_capture := shown != null and not base_button.button_pressed
	for child in scene.get_children(true):
		if child is CanvasItem and not child is Camera2D:
			RenderingServer.canvas_item_set_visible(child.get_canvas_item(), child.visible and (child == shown if show_capture else child != captured and child != preview))


func _restore_rendering() -> void:
	if is_instance_valid(scene):
		for child in scene.get_children(true):
			if child is CanvasItem:
				RenderingServer.canvas_item_set_visible(child.get_canvas_item(), child.visible)


func _exit_tree() -> void:
	stop()
