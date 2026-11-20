extends SceneTree
func _initialize() -> void:
	NativeGame.active_level = 5
	NativeGame.pending_level = NativeLevelTable.config_for(5)
	var arena = load("res://native/levels/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	# spawn one boss per tier sequentially, observe for ~900 frames each
	for tier in range(8):
		var boss = NativeBoss.new()
		boss.tier = tier
		boss.variant = ""
		arena.add_child(boss)
		await create_timer(0.2).timeout
		var bullets0 = get_nodes_in_group("enemy_bullets").size()
		var enemies0 = get_nodes_in_group("enemies").size()
		for i in 900:
			await physics_frame
		var bullets1 = get_nodes_in_group("enemy_bullets").size()
		var enemies1 = get_nodes_in_group("enemies").size()
		print("TIER ", tier, " boss_pos=", boss.position,
			" seq=", boss._seq, " sq2=", boss._sq2,
			" bullets=", bullets1 - bullets0,
			" enemies=", enemies1 - enemies0,
			" hp=", int(boss.health))
		boss.queue_free()
		await process_frame
	print("BOSS_PROBE_DONE")
	quit()
