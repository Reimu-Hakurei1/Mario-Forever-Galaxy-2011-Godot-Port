extends SceneTree

## Scratch: embed a captured snapshot scene into a room scene and save it.

var scene_path := ""
var snap_path := ""
var frame := 0
var capture_seed := 12345
var strip_placeholder := true


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene_path = a.substr(8)
		elif a.begins_with("--snap="):
			snap_path = a.substr(7)
		elif a.begins_with("--frame="):
			frame = int(a.substr(8))
		elif a.begins_with("--seed="):
			capture_seed = int(a.substr(7))
		elif a == "--keep-placeholder":
			strip_placeholder = false
	if scene_path.is_empty() or snap_path.is_empty():
		print("PIN_USAGE missing args")
		quit(2)
		return
	var root: Node2D = load(scene_path).instantiate()
	var old := root.get_node_or_null("CapturedLevel")
	if old != null:
		root.remove_child(old)
		old.free()
	if strip_placeholder:
		var ep := root.get_node_or_null("EditorPreview")
		if ep != null:
			for child in ep.get_children():
				ep.remove_child(child)
				child.free()
	var packed_snap: PackedScene = ResourceLoader.load(snap_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if packed_snap == null:
		print("PIN_FAIL snapshot load")
		quit(1)
		return
	var snap: Node2D = packed_snap.instantiate()
	snap.name = "CapturedLevel"
	snap.scene_file_path = ""
	snap.capture_frame = frame
	snap.capture_seed = capture_seed
	snap.apply_edits = true
	root.add_child(snap)
	_set_owner(snap, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err == OK:
		err = ResourceSaver.save(packed, scene_path)
	print("PIN_DONE err=%d scene=%s children=%d" % [err, scene_path, snap.get_child_count()])
	quit(0 if err == OK else 1)


func _set_owner(node: Node, owner_root: Node) -> void:
	node.owner = owner_root
	for child in node.get_children():
		_set_owner(child, owner_root)
