extends SceneTree
## Spawns each alternate boss variant (flame_cans, ufo_mega, fat_boy)
## for ~1200 frames and reports its state. Mirrors _boss_fight_probe.

func _initialize() -> void:
	NativeGame.active_level = 5
	NativeGame.pending_level = NativeLevelTable.config_for(5)
	var arena = load("res://native/levels/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	for v in NativeBoss.VARIANTS.keys():
		var boss = NativeBoss.new()
		boss.tier = 3
		boss.variant = v
		arena.add_child(boss)
		await create_timer(0.2).timeout
		var bullets0 := get_nodes_in_group("enemy_bullets").size()
		for i in 1200:
			await physics_frame
		var bullets1 := get_nodes_in_group("enemy_bullets").size()
		var cannons := 0
		if v == "fat_boy":
			cannons = boss._fb_cannons.size()
		var state := ""
		if v.begins_with("flame_cans"):
			state = "seq=%d lad=%.0f seq2=%d" % [boss._fc_seq, boss._ladowanie, boss._fc_sekwencer]
		elif v == "ufo_mega":
			state = "seq=%d strzal=%.0f delay=%.0f cracked=%s" % [boss._ufo_seq, boss._ufo_strzal, boss._ufo_delayshot, boss._ufo_cracked]
		elif v.begins_with("fat_boy"):
			state = "seq=%d dir=%.2f rockets=%.0f" % [boss._fb_seq, boss._fb_dir, boss._fb_rakieta]
		print("VARIANT ", v, " pos=", boss.position,
			" ", state,
			" cannons=", cannons,
			" bullets=", bullets1 - bullets0,
			" hp=", int(boss.health))
		boss.queue_free()
		await process_frame
	print("VARIANT_PROBE_DONE")
	quit()
