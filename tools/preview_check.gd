extends SceneTree

var checked := 0
var preview_scenes := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check_directory(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		if not file.ends_with(".tscn"):
			continue
		var scene: PackedScene = load(path.path_join(file))
		if scene == null:
			failures += 1
			continue
		var room := scene.instantiate()
		checked += 1
		if room.get_node_or_null("Camera2D") == null:
			printerr("PREVIEW missing camera: ", path.path_join(file))
			failures += 1
		for child in room.get_children():
			if str(child.name).begins_with("WAVE_REPRESENTATION_PREVIEW_ONLY"):
				printerr("PREVIEW obsolete wave panel: ", path.path_join(file))
				failures += 1
			if child.name != "Waves":
				continue
			preview_scenes += 1
			var edits: Dictionary = child.collect_edits(room)
			if not edits.tables.is_empty() or not edits.spawns.is_empty():
				printerr("PREVIEW untouched scene changes original waves: ", path.path_join(file))
				failures += 1
			if child.get_node_or_null("Timing") == null or child.get_node_or_null("Enemies") == null:
				printerr("PREVIEW missing editable wave controls: ", path.path_join(file))
				failures += 1
		if room.get_meta("gm_room", "") == "level_0000" and room.get_node_or_null("Waves") == null:
			failures += 1
		room.free()
	for directory in DirAccess.get_directories_at(path):
		_check_directory(path.path_join(directory))


func _run() -> void:
	_check_directory("res://stages")
	print("PREVIEW_CHECK scenes=%d editable_wave_scenes=%d failures=%d" % [checked, preview_scenes, failures])
	quit(0 if failures == 0 else 1)
