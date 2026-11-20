extends SceneTree
var R = load("res://engine/r.gd")

## Scratch probe: boots a story (room_animation) scene and saves frames.

var game: Node2D
var outdir := ""
var savedir := ""
var frames := 0
var entered := false
var scene_path := "res://stages/room_animation_1.tscn"
var room_name := "room_animation_1"
var marks := [1, 30, 60, 120, 240, 360, 480, 600, 720, 900, 1080, 1260, 1500]
var shots: Dictionary = {}
var max_frames := 1500
var storybg := false
var extra_marks := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--savedir="):
			savedir = arg.substr(10).replace("\\", "/")
		elif arg.begins_with("--outdir="):
			outdir = arg.substr(9).replace("\\", "/")
		elif arg.begins_with("--scene="):
			scene_path = arg.substr(8)
		elif arg.begins_with("--room="):
			room_name = arg.substr(7)
		elif arg.begins_with("--frames="):
			max_frames = int(arg.substr(9))
		elif arg == "--storybg":
			storybg = true
		elif arg.begins_with("--marks="):
			extra_marks = arg.substr(8)
	if savedir.is_empty() or outdir.is_empty():
		quit(2)
		return
	if not extra_marks.is_empty():
		marks = []
		for part in extra_marks.split(","):
			marks.append(int(part))
	if not OS.get_environment("APPDATA").replace("\\", "/").begins_with(outdir):
		push_error("probe requires isolated env under outdir")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(outdir)
	call_deferred("_boot")


func _boot() -> void:
	AudioServer.set_bus_mute(0, true)
	seed(12345)
	game = load(scene_path).instantiate()
	root.add_child(game)
	game.set_process(false)
	if storybg:
		# Replay the art that room_animation_1 installs for the whole intro chain.
		R.background_replace_alpha(null, 0, "./gfx/cutscene/background.png", 1)
		R.background_replace_alpha(null, 2, "./gfx/cutscene/background1.png", 1)
		R.background_replace_alpha(null, 4, "./gfx/cutscene/background2.png", 1)
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
	frames += 1
	if not entered:
		if R.room_get_name(null, R.room) == room_name:
			entered = true
			print("ENTERED frame=%d" % frames)
	if entered and (frames == 5 or frames == 120):
		print("BGDBG frame=%d" % frames)
		for k in R.backgrounds:
			print("  bg[%s] name=%s paths=%s has_tex=%s" % [k, str(R.backgrounds[k].get("name", "")), str(R.backgrounds[k].get("paths", [])), str(R.backgrounds[k].get("tex") != null)])
		for k in R.scene_backgrounds:
			print("  scene_bg[%s] source=%s tex=%s" % [k, str(R.scene_backgrounds[k].get("source")), str(R.scene_backgrounds[k].get("texture").resource_path if R.scene_backgrounds[k].get("texture") else "")])
		for i in 8:
			print("  slot%d idx=%d vis=%s x=%.1f y=%.1f a=%.2f" % [i, int(R.bg_index[i]), str(R.bg_visible[i]), float(R.bg_x[i]), float(R.bg_y[i]), float(R.bg_alpha[i])])
	if entered:
		for m in marks:
			if frames == int(m) and not shots.has(frames):
				shots[frames] = true
				_shot("story_%d" % frames)
		if frames > max_frames:
			print("PROBE_END frames=%d shots=%d" % [frames, shots.size()])
			quit()
			return true
	if frames > 2000:
		print("PROBE_TIMEOUT entered=%s" % str(entered))
		quit()
		return true
	return false


func _shot(label: String) -> void:
	root.get_texture().get_image().save_png(outdir.path_join(label + ".png"))
