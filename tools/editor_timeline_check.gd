@tool
extends EditorScript

const COPY := "res://tools/_timeline_editor_check_copy.tscn"
const FIRST := "res://stages/world_1/level_02_first_enconter.tscn"
var failures: int = 0
var checks: int = 0
var tree: SceneTree
var timeline: HBoxContainer
var directories: Array[String] = []


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("EDITOR_TIMELINE_CHECK " + label)


func wait_until(condition: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await tree.create_timer(0.25).timeout
	return condition.call()


func button(text: String) -> Button:
	for child in timeline.get_children():
		if child is Button and child.text == text:
			return child
	return null


func find_timeline(node: Node) -> HBoxContainer:
	if node.name == "GalaxyTimeline":
		return node
	for child in node.get_children(true):
		var found := find_timeline(child)
		if found != null:
			return found
	return null


func instance_nodes(root: Node) -> Array:
	var result: Array = []
	for child in root.get_children():
		if child.has_method("instance_edit") and child.object_index == 12:
			result.append(child)
	return result


func _run() -> void:
	if "--timeline-editor-check" not in OS.get_cmdline_user_args():
		return
	if FileAccess.file_exists(COPY):
		push_error("Editor test copy already exists; refusing to overwrite it.")
		tree.quit(1)
		return
	tree = EditorInterface.get_base_control().get_tree()
	await tree.create_timer(2.0).timeout
	var source: Node2D = load(FIRST).instantiate()
	var packed := PackedScene.new()
	check(packed.pack(source) == OK, "pack isolated editor scene copy")
	check(ResourceSaver.save(packed, COPY) == OK, "create isolated editor scene copy")
	source.free()
	EditorInterface.open_scene_from_path(COPY)
	EditorInterface.set_main_screen_editor("2D")
	await tree.create_timer(2.0).timeout
	var scene: Node = EditorInterface.get_edited_scene_root()
	check(scene.scene_file_path == COPY, "editor opened the test copy")
	if scene.scene_file_path != COPY:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(COPY))
		tree.quit(1)
		return
	timeline = find_timeline(EditorInterface.get_base_control())
	check(timeline != null, "Galaxy timeline toolbar is present in the editor")
	if timeline == null:
		cleanup(scene)
		tree.quit(1)
		return
	check(timeline.visible, "timeline shows for a level scene")
	timeline.frame_input.value = 300
	timeline.tutorial.button_pressed = true
	button("Capture").emit_signal("pressed")
	directories.append(timeline.directory)
	check(await wait_until(func(): return not timeline.pin_button.disabled, 120.0), "capture worker published a frame")
	var preview: Node = scene.get_node_or_null("TimelinePreview")
	check(preview != null and preview.get_child_count() > 0, "captured frame is added to the open scene")
	if preview == null:
		cleanup(scene)
		tree.quit(1)
		return
	check(instance_nodes(preview).size() >= 3, "captured frame contains selectable enemy instances")
	check(timeline.status.text.begins_with("Frame"), "status reports the captured frame")
	timeline.base_button.button_pressed = true
	await tree.create_timer(0.5).timeout
	var viewport: SubViewport = EditorInterface.get_editor_viewport_2d()
	var base_data: PackedByteArray = viewport.get_texture().get_image().get_data()
	timeline.base_button.button_pressed = false
	await tree.create_timer(0.5).timeout
	var capture_data: PackedByteArray = viewport.get_texture().get_image().get_data()
	check(capture_data != base_data, "base layout toggle swaps the editor canvas between capture and original scene")
	timeline.base_button.button_pressed = true
	await tree.create_timer(0.5).timeout
	check(viewport.get_texture().get_image().get_data() == base_data, "base layout rendering is stable")
	timeline.base_button.button_pressed = false
	await tree.create_timer(0.5).timeout
	button("Keep editable frame").emit_signal("pressed")
	await tree.process_frame
	var captured: Node = scene.get_node_or_null("CapturedLevel")
	check(captured != null and captured.apply_edits, "pin keeps an editable CapturedLevel")
	check(scene.get_node_or_null("TimelinePreview") == null, "pin consumes the preview")
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var history: UndoRedo = undo.get_history_undo_redo(undo.get_object_history_id(scene))
	history.undo()
	check(scene.get_node_or_null("CapturedLevel") == null, "undo removes the kept frame")
	history.redo()
	captured = scene.get_node_or_null("CapturedLevel")
	check(captured != null, "redo restores the kept frame")
	var instances: Array = instance_nodes(captured)
	check(instances.size() >= 3, "kept frame has at least 3 enemy instances")
	if instances.size() < 3:
		cleanup(scene)
		tree.quit(1)
		return
	var moved_key: String = instances[0].source_key
	var deleted_key: String = instances[1].source_key
	var duplicated_key: String = instances[2].source_key
	instances[0].position += Vector2(30, 20)
	instances[1].enabled = false
	var clone: Node2D = instances[2].duplicate()
	clone.name = instances[2].name + "_copy"
	clone.position += Vector2(50, 0)
	captured.add_child(clone)
	clone.owner = scene
	for sub in clone.get_children():
		sub.owner = scene
	check(EditorInterface.save_scene() == OK, "native editor saves the pinned and edited scene")
	var saved: Node2D = (ResourceLoader.load(COPY, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	var saved_captured: Node = saved.get_node_or_null("CapturedLevel")
	check(saved_captured != null, "saved scene keeps the captured frame")
	var edits: Dictionary = saved_captured.snapshot_edits(saved) if saved_captured != null else {}
	var edit_list: Array = edits.get("instances", [])
	var found_move := false
	var found_delete := false
	var found_dup := false
	for edit: Dictionary in edit_list:
		if edit.key == moved_key and not edit.get("duplicate", false):
			found_move = edit.offset.is_equal_approx(Vector2(30, 20))
		if edit.key == deleted_key and not edit.enabled:
			found_delete = true
		if edit.key == duplicated_key and edit.get("duplicate", false):
			found_dup = true
	check(found_move, "saved scene records the moved instance")
	check(found_delete, "saved scene records the disabled instance")
	check(found_dup, "saved scene records the duplicated instance")
	saved.free()
	button("Capture").emit_signal("pressed")
	directories.append(timeline.directory)
	check(await wait_until(func(): return not timeline.pin_button.disabled, 120.0), "recapture published a frame")
	button("Keep editable frame").emit_signal("pressed")
	await tree.process_frame
	captured = scene.get_node_or_null("CapturedLevel")
	check(captured != null, "recapture replaces the kept frame")
	var recaptured: Dictionary = captured.snapshot_edits(scene) if captured != null else {}
	found_move = false
	found_delete = false
	found_dup = false
	for edit: Dictionary in recaptured.get("instances", []):
		if edit.key == moved_key and not edit.get("duplicate", false):
			found_move = edit.offset.is_equal_approx(Vector2(30, 20))
		if edit.key == deleted_key and not edit.enabled:
			found_delete = true
		if edit.key == duplicated_key and edit.get("duplicate", false):
			found_dup = true
	check(found_move, "recapture preserves the moved offset without compounding")
	check(found_delete, "recapture preserves the disabled instance")
	check(found_dup, "recapture preserves the duplicated instance")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(arg.substr(6))
	button("Stop").emit_signal("pressed")
	cleanup(scene)
	print("EDITOR_TIMELINE_CHECK checks=%d failures=%d" % [checks, failures])
	tree.quit(1 if failures else 0)


func cleanup(scene: Node) -> void:
	if timeline != null:
		button("Stop").emit_signal("pressed")
	if EditorInterface.get_edited_scene_root() == scene:
		EditorInterface.close_scene()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(COPY))
	for directory in directories:
		if not directory.is_empty():
			remove_tree(directory)


func remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := path.path_join(entry)
		if dir.current_is_dir():
			remove_tree(full)
		else:
			DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)