extends SceneTree
func _init():
	NativeGame.active_level = 5
	NativeGame.pending_level = NativeLevelTable.config_for(5)
	var arena = load("res://native/levels/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	await create_timer(1.0).timeout
	var enemies = get_nodes_in_group("enemies").size() if has_method("get_nodes_in_group") else 0
	print("SMOKE enemies_in_tree=", enemies)
	quit()
