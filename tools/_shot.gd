extends SceneTree

## Screenshot any scene after it settles: godot --path . -s tools/_shot.gd -- --scene=res://... --out=/tmp/x.png [--frames=90]

var scene_path := ""
var out := ""
var frames := 90


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene_path = a.substr(8)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
	call_deferred("_run")


func _run() -> void:
	if scene_path.is_empty() or out.is_empty():
		print("need --scene and --out"); quit(2); return
	var ps: PackedScene = load(scene_path)
	if ps == null:
		print("LOAD FAIL ", scene_path); quit(2); return
	var inst = ps.instantiate()
	root.add_child(inst)
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("SHOT ", out, " err=", err, " size=", img.get_size())
	quit()
