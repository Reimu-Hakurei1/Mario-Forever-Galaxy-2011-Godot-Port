extends SceneTree
func _init():
	for key in ["7:5", "7:16", "2:11", "4:29"]:
		NativeGame.active_level = 50
		NativeGame.pending_level = NativeLevelTable.config_for_key(key)
		var arena = load("res://native/levels/arena.tscn").instantiate()
		root.add_child(arena)
		# fast-forward ~14s of game time at 60fps
		for i in 840:
			await physics_frame
		var kinds := {}
		var bosses := 0
		for n in get_nodes_in_group("enemies"):
			if n is NativeBoss: bosses += 1
			else: kinds[n.kind] = kinds.get(n.kind, 0) + 1
		print("STAGE ", key, " enemies=", kinds, " bosses=", bosses)
		arena.queue_free()
		await process_frame
		await process_frame
	print("STAGE_PROBE_DONE")
	quit()
