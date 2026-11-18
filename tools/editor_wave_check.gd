@tool
extends EditorScript

const COPY := "res://tools/_wave_editor_check_copy.tscn"
var failures: int = 0
var checks: int = 0


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("EDITOR_WAVE_CHECK " + label)


func _run() -> void:
	if "--wave-editor-check" not in OS.get_cmdline_user_args():
		return
	if FileAccess.file_exists(COPY):
		push_error("Editor test copy already exists; refusing to overwrite it.")
		return
	var tree: SceneTree = EditorInterface.get_base_control().get_tree()
	await tree.create_timer(2.0).timeout
	var source: Node2D = load("res://stages/world_1/level_02_first_enconter.tscn").instantiate()
	var packed := PackedScene.new()
	check(packed.pack(source) == OK, "pack isolated editor scene copy")
	check(ResourceSaver.save(packed, COPY) == OK, "create isolated editor scene copy")
	source.free()
	EditorInterface.open_scene_from_path(COPY)
	EditorInterface.set_main_screen_editor("2D")
	await tree.create_timer(2.0).timeout
	var scene: Node = EditorInterface.get_edited_scene_root()
	check(scene.scene_file_path == COPY, "editor opened the test copy: " + scene.scene_file_path)
	if scene.scene_file_path != COPY:
		tree.quit(1)
		return
	var enemy: Node2D = scene.get_node("Waves/Enemies/Formation/Slot_00")
	EditorInterface.edit_node(enemy)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(enemy)
	await tree.process_frame
	var properties: Array[Node] = [EditorInterface.get_inspector()]
	var edited: bool = false
	while not properties.is_empty():
		var property: Node = properties.pop_back()
		if property is EditorProperty and property.get_edited_property() == &"enemy_kind":
			property.emit_changed(&"enemy_kind", 2)
			edited = true
			break
		properties.append_array(property.get_children(true))
	check(edited, "enemy type property is editable in the native Inspector")
	await tree.process_frame
	check(enemy.enemy_kind == 2, "Inspector commits the enemy type edit")
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var history: UndoRedo = undo.get_history_undo_redo(undo.get_object_history_id(enemy))
	history.undo()
	check(enemy.enemy_kind == -1, "Inspector edit can be undone")
	history.redo()
	check(enemy.enemy_kind == 2, "Inspector edit can be redone")
	undo.create_action("Move wave control", UndoRedo.MERGE_DISABLE, enemy)
	undo.add_do_property(enemy, &"position", enemy.position + Vector2(24, 16))
	undo.add_undo_property(enemy, &"position", enemy.position)
	undo.commit_action()
	check(EditorInterface.save_scene() == OK, "native editor saves the edited scene")
	var saved: Node2D = (ResourceLoader.load(COPY, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	var edits: Dictionary = saved.get_node("Waves").collect_edits(saved)
	check(edits.spawns.size() == 1, "saved scene contains one enemy override")
	if edits.spawns.size() == 1:
		check(edits.spawns[0].kind == 2 and edits.spawns[0].offset == Vector2(24, 16), "saved type and moved position survive reloading")
	check(saved.get_node("Waves/Enemies/Formation/Slot_00").get_child_count() == 0, "editor artwork is not serialized as duplicate runtime enemies")
	saved.free()
	for property: Dictionary in enemy.get_property_list():
		if property.name == "object_index":
			check(property.hint == PROPERTY_HINT_ENUM and "boss_1:169" in property.hint_string, "object selector lists named bosses")
			check(property.usage & PROPERTY_USAGE_READ_ONLY != 0, "original control keeps its source object identity")
	var added: Node2D = load("res://engine/level_spawn_rule.gd").new()
	added.mode = 1
	added.object_index = 169
	scene.get_node("Waves/Enemies").add_child(added)
	await tree.process_frame
	await tree.process_frame
	check(added._preview_sprites.size() > 0, "new boss control displays its object artwork")
	added.object_index = 251
	await tree.process_frame
	await tree.process_frame
	check(added._preview_object == 251 and added._preview_sprites.size() > 0, "changing added boss type refreshes artwork")
	added.object_index = 999999
	check(not added._get_configuration_warnings().is_empty(), "invalid object index produces an editor warning")
	added.object_index = 251
	added.start_period = 199
	added.count = 2
	added.interval_periods = 1
	check(not added._get_configuration_warnings().is_empty(), "schedule beyond the original clock produces a warning")
	added.free()
	await tree.create_timer(2.0).timeout
	check(enemy is Sprite2D and enemy.texture != null and enemy.is_visible_in_tree(), "edited formation sprite renders and is selectable in the native editor")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			EditorInterface.get_base_control().get_viewport().get_texture().get_image().save_png(arg.substr(6))
	if EditorInterface.get_edited_scene_root() == scene:
		check(EditorInterface.close_scene() == OK, "close only the editor test scene")
		check(DirAccess.remove_absolute(ProjectSettings.globalize_path(COPY)) == OK, "remove only the editor test copy")
	print("EDITOR_WAVE_CHECK checks=%d failures=%d" % [checks, failures])
	tree.quit(1 if failures else 0)
