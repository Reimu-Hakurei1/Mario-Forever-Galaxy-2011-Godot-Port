extends SceneTree
func _initialize() -> void:
	NativeGame.active_level = 5
	NativeGame.pending_level = NativeLevelTable.config_for(5)
	var arena = load("res://native/levels/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	for v in ["burst","debris","spark","muzzle","falling","kaboom"]:
		var e = NativeExplosion.new()
		e.variant = v
		e.global_position = Vector2(512, 300)
		arena.add_child(e)
	# kill an enemy to exercise enemy._spawn_explosion + FALLER variant
	var en = NativeEnemy.new()
	en.kind = NativeEnemy.Kind.FALLER
	en.global_position = Vector2(512, 300)
	arena.add_child(en)
	await process_frame
	en.take_damage(99999)
	for i in 120:
		await physics_frame
	print("FX_DONE explosions=", get_nodes_in_group("").size())
	quit()
