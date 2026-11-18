extends SceneTree
var R = load("res://engine/r.gd")

var request: Dictionary = {}
var directory: String = ""
var game: Node2D
var frames := 0
var published := 0
var entered := false
var tutorial_done: Dictionary = {}
var busy := false
var parent_alive := true
var parent_checked := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview-request="):
			directory = argument.substr(18).replace("\\", "/").get_base_dir()
			request = JSON.parse_string(FileAccess.get_file_as_string(argument.substr(18)))
	if request.is_empty() or directory != OS.get_environment("GALAXY_PREVIEW_ROOT"):
		push_error("Preview requires its isolated launcher environment.")
		quit(2)
		return
	for name in ["HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "TEMP", "TMP"]:
		if not OS.get_environment(name).replace("\\", "/").begins_with(directory.replace("\\", "/") + "/"):
			push_error("Preview environment is not isolated: " + name)
			quit(2)
			return
	call_deferred("_boot")


func _boot() -> void:
	AudioServer.set_bus_mute(0, true)
	seed(int(request.seed))
	R.level_capture = load("res://engine/level_capture.gd").new()
	R.level_capture.capture_seed = int(request.seed)
	game = load(str(request.scene)).instantiate()
	root.add_child(game)
	game.set_process(false)
	R.working_directory = directory.path_join("saves")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0


func _process(_delta: float) -> bool:
	if game == null or busy:
		return false
	if FileAccess.file_exists(directory.path_join("stop")) or _parent_dead():
		quit()
		return true
	R.working_directory = directory.path_join("saves")
	if not entered:
		R.step()
		if R.room_get_name(null, R.room) == str(game.get_meta("gm_room", "")):
			entered = true
		return false
	var fire_skip := false
	var fire_key := 0
	if request.get("after_tutorial", false):
		for tutorial in R.with_ids(null, 306):
			if not tutorial_done.has(tutorial.inst_id):
				tutorial_done[tutorial.inst_id] = true
				var globals = load("res://game/globals.gd")
				R.aset(tutorial.g_sekwencja, 0, 3)
				R.aset(tutorial.g_zmienna, 4, 160)
				globals.pauza = 0
				globals.buttonfire = 1
				R.run_event(tutorial, 3, 0)
				globals.help = 0
				globals.buttonfire = 0
		var globals = load("res://game/globals.gd")
		# Topic dialogs (boss intro etc.) close only on real fire key presses.
		fire_skip = globals.help != 0 and frames % 2 == 0
		if fire_skip:
			fire_key = int(globals.ster5)
			R.keyboard_key_press(null, fire_key)
	R.step()
	if fire_skip:
		R.keyboard_key_release(null, fire_key)
	frames += 1
	if frames >= int(request.frame) and (published == 0 or frames % 6 == 0):
		busy = true
		_publish.call_deferred()
	return false


func _parent_dead() -> bool:
	if not request.has("parent_pid"):
		return false
	# OS.is_process_running reports false for live PIDs on this Windows build.
	if Time.get_ticks_msec() - parent_checked < 2000:
		return not parent_alive
	parent_checked = Time.get_ticks_msec()
	var output: Array = []
	OS.execute("tasklist", ["/FI", "PID eq %d" % int(request.parent_pid), "/NH"], output, true)
	parent_alive = output.size() > 0 and str(output[0]).contains(str(int(request.parent_pid)))
	return not parent_alive


func _publish() -> void:
	await RenderingServer.frame_post_draw
	var snapshot: Node2D = R.level_capture.snapshot(R, frames)
	snapshot.capture_seed = int(request.seed)
	var packed := PackedScene.new()
	var error := packed.pack(snapshot)
	var path := directory.path_join("state_%d.scn" % (published % 2))
	if error == OK:
		error = ResourceSaver.save(packed, path)
	var count := snapshot.get_child_count()
	snapshot.free()
	if error != OK:
		push_error("Could not save captured level: %s" % error)
		quit(1)
		return
	var output := FileAccess.open(directory.path_join("ready.tmp"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"path": path, "frame": frames, "serial": published, "objects": count, "room": R.room_get_name(null, R.room)}))
	output.close()
	DirAccess.rename_absolute(directory.path_join("ready.tmp"), directory.path_join("ready.json"))
	if request.has("screenshot"):
		root.get_texture().get_image().save_png(str(request.screenshot))
	published += 1
	print("LEVEL_CAPTURE frame=%d objects=%d" % [frames, count])
	if not request.get("play", false):
		quit()
	else:
		Engine.max_fps = 60
	busy = false
