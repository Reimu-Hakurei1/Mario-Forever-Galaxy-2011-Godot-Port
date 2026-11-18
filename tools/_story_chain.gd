extends SceneTree
var R = load("res://engine/r.gd")

## Scratch probe: plays the story rooms in their real sequence (52 -> 55) and
## saves frames per room so the run can be compared with the original game.

var game: Node2D
var outdir := ""
var savedir := ""
var frame := 0
var entered := false
var last_room := -1
var room_offsets: Dictionary = {}
var want := {"52": [], "53": [200, 204, 208, 212, 216, 220, 224, 228, 232, 236, 240, 244, 248, 252, 256, 260], "54": [300, 304, 308, 312, 316, 320, 324, 328, 332, 336], "55": []}
var max_frames := 14000
var done_rooms: Dictionary = {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--savedir="):
			savedir = arg.substr(10).replace("\\", "/")
		elif arg.begins_with("--outdir="):
			outdir = arg.substr(9).replace("\\", "/")
		elif arg.begins_with("--frames="):
			max_frames = int(arg.substr(9))
	if savedir.is_empty() or outdir.is_empty():
		quit(2)
		return
	if not OS.get_environment("APPDATA").replace("\\", "/").begins_with(outdir):
		push_error("probe requires isolated env under outdir")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(outdir)
	call_deferred("_boot")


func _boot() -> void:
	AudioServer.set_bus_mute(0, true)
	seed(12345)
	game = load("res://stages/room_animation_1.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	R.working_directory = savedir
	DirAccess.make_dir_recursive_absolute(savedir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("BOOT done")


func _process(_delta: float) -> bool:
	if game == null:
		return false
	R.working_directory = savedir
	R.step()
	frame += 1
	if not entered and R.room == 52:
		entered = true
		print("ENTERED frame=%d" % frame)
	if entered:
		if R.room != last_room:
			last_room = R.room
			room_offsets[last_room] = 0
			print("ROOM %d at frame=%d" % [last_room, frame])
		room_offsets[last_room] = int(room_offsets.get(last_room, 0)) + 1
		var key := str(last_room)
		if want.has(key) and int(room_offsets[last_room]) in want[key]:
			_shot("chain_%s_%d" % [key, int(room_offsets[last_room])])
		if last_room >= 55 and int(room_offsets[last_room]) > 60:
			print("CHAIN_END frame=%d" % frame)
			quit()
			return true
	if frame > max_frames:
		print("CHAIN_TIMEOUT room=%d" % R.room)
		quit()
		return true
	return false


func _shot(label: String) -> void:
	root.get_texture().get_image().save_png(outdir.path_join(label + ".png"))
