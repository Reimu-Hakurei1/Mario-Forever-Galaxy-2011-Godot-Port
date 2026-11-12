extends SceneTree

## Headless smoke sweep: force-loads every Galaxy room for --hold frames each and
## prints BEGIN/END markers so script errors in the log can be attributed to a room.
##   godot --headless --path . -s tools/sweep.gd -- --savedir=... --hold=120

var savedir: String = ""
var hold: int = 120
var frames: int = 0
var ids: Array = []
var idx: int = -1
var room_frames: int = 0
var stray: int = 0
var seen: bool = false
var started: bool = false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
			DirAccess.make_dir_recursive_absolute(savedir)
		elif a.begins_with("--hold="):
			hold = int(a.substr(7))
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _name_of(id: int) -> String:
	var meta: Dictionary = R.room_data.get("rooms", {}).get(str(id), {})
	return str(meta.get("name", "?"))


func _finish_phase(note: String) -> void:
	print("END %d %s inst=%d %s" % [ids[idx], _name_of(ids[idx]), R.instances.size(), note])
	idx += 1
	room_frames = 0
	stray = 0
	seen = false
	if idx < ids.size():
		R.pending_room = int(ids[idx])


func _process(_delta: float) -> bool:
	frames += 1
	if savedir != "" and R.working_directory != savedir:
		R.working_directory = savedir
		R._seed_user_files()
	if not R.game_running:
		return false
	if not started:
		started = true
		for k in R.room_data.get("rooms", {}).keys():
			ids.append(int(k))
		ids.sort()
		idx = 0
		R.pending_room = ids[0]
		return false
	if idx >= ids.size():
		print("SWEEP done rooms=%d frames=%d" % [ids.size(), frames])
		print("WARNINGS " + JSON.stringify(R.warnings))
		quit()
		return true
	if R.room == int(ids[idx]):
		stray = 0
		if not seen:
			seen = true
			print("BEGIN %d %s inst=%d" % [ids[idx], _name_of(ids[idx]), R.instances.size()])
		room_frames += 1
		if room_frames >= hold:
			_finish_phase("")
	else:
		if seen:
			# The room advanced on its own (title/intro/endings); that is the observation.
			_finish_phase("moved")
		else:
			stray += 1
			R.pending_room = int(ids[idx])
			if stray > 60:
				print("SKIP %d %s" % [ids[idx], _name_of(ids[idx])])
				_finish_phase("skipped")
	return false
