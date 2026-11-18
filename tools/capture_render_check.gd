extends SceneTree

var path := ""
var output := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--snapshot="):
			path = arg.substr(11)
		elif arg.begins_with("--out="):
			output = arg.substr(6)
	call_deferred("_run")


func _run() -> void:
	if path.is_empty() or output.is_empty():
		quit(2)
		return
	var scene: Node2D = load(path).instantiate()
	root.add_child(scene)
	await process_frame
	await RenderingServer.frame_post_draw
	var sprites := 0
	var instances := 0
	var nodes: Array[Node] = [scene]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		nodes.append_array(node.get_children())
		if node is Sprite2D:
			sprites += 1
		if node.has_method("instance_edit"):
			instances += 1
	root.get_texture().get_image().save_png(output)
	print("CAPTURE_RENDER sprites=%d instances=%d" % [sprites, instances])
	quit()
