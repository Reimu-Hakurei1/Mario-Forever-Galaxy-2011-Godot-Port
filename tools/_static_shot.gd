extends SceneTree

## Static capture: renders a scene WITHOUT running its scripts' _ready
## redirects — shows the raw editor layout (original room sprites).
## godot --path . -s tools/_static_shot.gd -- --scene=res://... --out=x.png --frames=5

var scene_path := ""
var out := ""
var frames := 5


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene_path = a.substr(8)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
		elif a.begins_with("--keep-script="):
			pass
	call_deferred("_run")


func _run() -> void:
	var ps: PackedScene = load(scene_path)
	var inst = ps.instantiate()
	# strip runtime scripts so _ready redirects/logic don't fire —
	# keeps @tool editor visuals only
	_strip(inst)
	root.add_child(inst)
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(out)
	print("SHOT ", out, " err=", err)
	quit()


func _strip(n: Node) -> void:
	var s = n.get_script()
	if s != null and not (s is GDScript and s.source_code.begins_with("@tool")):
		n.set_script(null)
	for c in n.get_children():
		_strip(c)
