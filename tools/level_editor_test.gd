extends SceneTree

## Headless smoke test for the custom level editor: builds a level programmatically,
## saves it, and verifies the generated files exist.
##   godot --headless --path . -s tools/level_editor_test.gd


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	var ps: PackedScene = load("res://editor/level_editor.tscn")
	var ed = ps.instantiate()
	root.add_child(ed)
	await process_frame
	await process_frame
	ed.level_name = "test_level"
	for i in 6:
		var s: Dictionary = ed._default_spawn(Vector2(150 + i * 140, 150 + (i % 3) * 120))
		s["start"] = 2.0
		s["count"] = 10
		s["interval"] = 0.2
		ed.spawns.append(s)
	ed._save_level()
	print("EDITOR_TEST scene_path=%s room_id=%d" % [ed.scene_path, ed.room_id])
	print("EDITOR_TEST scene_exists=%s" % [FileAccess.file_exists(ed.scene_path)])
	print("EDITOR_TEST rooms_json=%s" % [FileAccess.file_exists("res://game/rooms.json")])
	# verify the scene loads and exposes wave edits
	var sps: PackedScene = load(ed.scene_path)
	var inst = sps.instantiate()
	var waves = inst.get_node_or_null("Waves")
	print("EDITOR_TEST waves=%s enemies=%d" % [waves != null, waves.get_node("Enemies").get_child_count() if waves else -1])
	if waves != null:
		var edits: Dictionary = waves.collect_edits(inst)
		print("EDITOR_TEST spawns=%d tables=%d" % [edits.spawns.size(), edits.tables.size()])
	inst.free()
	quit()
