extends SceneTree
var R = load("res://engine/r.gd")

## Scratch probe: plays 52 -> 55 once and saves CapturedLevel snapshots for the
## story room scenes so the editor pins use frames from the real sequence.

var game: Node2D
var outdir := ""
var savedir := ""
var pindir := ""
var frame := 0
var entered := false
var last_room := -1
var room_offsets: Dictionary = {}
var want := {
	"52": [900],
	"53": [240, 700],
	"54": [300],
	"55": [300, 1200],
}
var max_frames := 40000
var saved: Dictionary = {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--savedir="):
			savedir = arg.substr(10).replace("\\", "/")
		elif arg.begins_with("--outdir="):
			outdir = arg.substr(9).replace("\\", "/")
		elif arg.begins_with("--pindir="):
			pindir = arg.substr(9).replace("\\", "/")
		elif arg.begins_with("--frames="):
			max_frames = int(arg.substr(9))
	if savedir.is_empty() or outdir.is_empty() or pindir.is_empty():
		quit(2)
		return
	if not OS.get_environment("APPDATA").replace("\\", "/").begins_with(outdir):
		push_error("probe requires isolated env under outdir")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(outdir)
	DirAccess.make_dir_recursive_absolute(pindir)
	call_deferred("_boot")


func _boot() -> void:
	AudioServer.set_bus_mute(0, true)
	seed(12345)
	R.level_capture = load("res://engine/level_capture.gd").new()
	R.level_capture.capture_seed = 12345
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
		var off := int(room_offsets[last_room])
		if want.has(key) and off in want[key] and not saved.has("%s_%d" % [key, off]):
			saved["%s_%d" % [key, off]] = true
			_pin(key, off)
		if last_room >= 55 and off > 1400 and saved.has("55_1200"):
			print("PIN_END frame=%d saved=%d" % [frame, saved.size()])
			quit()
			return true
	if frame > max_frames:
		print("PIN_TIMEOUT room=%d saved=%d" % [R.room, saved.size()])
		quit()
		return true
	return false


func _pin(key: String, off: int) -> void:
	root.get_texture().get_image().save_png(outdir.path_join("pin_%s_%d.png" % [key, off]))
	var snapshot: Node2D = R.level_capture.snapshot(R, frame)
	snapshot.capture_seed = 12345
	var packed := PackedScene.new()
	var err := packed.pack(snapshot)
	var path := pindir.path_join("room_%s_%d.scn" % [key, off])
	if err == OK:
		err = ResourceSaver.save(packed, path)
	var count := snapshot.get_child_count()
	snapshot.free()
	print("PIN room=%s off=%d frame=%d children=%d err=%d path=%s" % [key, off, frame, count, err, path])
