extends SceneTree

## Headless room-flow probe: boots the game, logs every room change and any
## runtime warning, and exits after --frames steps.
##   godot --headless --path . --script res://tools/probe.gd -- --frames=3000

var frames: int = 0
var savedir: String = ""
var limit: int = 3000
var last_room: int = -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
			DirAccess.make_dir_recursive_absolute(savedir)
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if savedir != "" and R.working_directory != savedir:
		R.working_directory = savedir
	if R.game_running and R.room != last_room:
		last_room = R.room
		var meta: Dictionary = R.room_data.get("rooms", {}).get(str(R.room), {})
		print("ROOM %d %s frame=%d inst=%d" % [R.room, meta.get("name", "?"),
			frames, R.instances.size()])
	if frames >= limit:
		print("WARNINGS " + JSON.stringify(R.warnings))
		quit()
		return true
	return false
