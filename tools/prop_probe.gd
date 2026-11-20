extends SceneTree
var R = load("res://engine/r.gd")

## Isolated propagation probe: boot the game, force a room, dump placed instance
## positions so editor->game edits can be verified.
##   godot --headless --path . -s tools/prop_probe.gd -- --room=starter --obj=5 --savedir=<dir>

var frames: int = 0
var limit: int = 150
var room_arg: String = ""
var savedir: String = ""
var obj_filter: int = -1
var started: bool = false
var settled: int = 0
var dumped: bool = false
var target: int = -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			room_arg = a.substr(7)
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
		elif a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
		elif a.begins_with("--obj="):
			obj_filter = int(a.substr(6))
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if not R.game_running:
		return false
	if not started:
		started = true
		if savedir != "":
			DirAccess.make_dir_recursive_absolute(savedir)
			R.working_directory = savedir
		var t: Variant = int(room_arg) if room_arg.is_valid_int() else room_arg
		target = R._resolve_room(t)
		R.pending_room = target
		print("PROP booted target=%d arg=%s" % [target, room_arg])
		return false
	if savedir != "" and R.working_directory != savedir:
		R.working_directory = savedir
	if R.room != target:
		R.pending_room = target
		return false
	settled += 1
	if settled >= 30 and not dumped:
		dumped = true
		var n: int = 0
		for inst in R.instances:
			if not inst.alive:
				continue
			var oi: int = int(inst.g_object_index)
			if obj_filter >= 0 and oi != obj_filter:
				continue
			print("INST obj=%d id=%d x=%.2f y=%.2f" % [oi, inst.inst_id, inst.x, inst.y])
			n += 1
		print("PROP room=%d count=%d" % [R.room, n])
	if frames >= limit:
		quit()
		return true
	return false