extends SceneTree
func _init() -> void:
	var scene = load("res://native/levels/star_map.tscn")
	var inst = scene.instantiate()
	root.add_child(inst)
	await process_frame
	await process_frame
	# simulate: travel to a neighbor then check launchable states
	print("MAP_OK current=", NativeGame.map_current)
	quit()
