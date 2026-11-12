extends SceneTree

## Single-room headless probe with a heartbeat, for isolating a hang.
##   godot --headless --path . -s tools/one.gd -- --room=55 --frames=600

var frames: int = 0
var limit: int = 600
var room_id: int = 55
var started: bool = false
var verbose: bool = false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			room_id = int(a.substr(7))
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
		elif a == "--verbose":
			verbose = true
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if not R.game_running:
		return false
	if not started:
		started = true
		R.debug_load = true
		R.debug_draw = verbose
		R.pending_room = room_id
		print("PROBE booted, forcing room %d" % room_id)
		return false
	if R.room != room_id:
		R.pending_room = room_id
		print("PROBE waiting room=%d frame=%d" % [R.room, frames])
		return false
	if frames % 10 == 0:
		printerr("TICK frame=%d room=%d tick=%d inst=%d" % [frames, R.room, R.tick_count,
			R.instances.size()])
	if frames >= limit:
		print("PROBE done")
		quit()
		return true
	return false
