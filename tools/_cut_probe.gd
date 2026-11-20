extends SceneTree
func _init() -> void:
	var inst = load("res://native/ui/cutscene.gd").new()
	inst.setup("opening")
	root.add_child(inst)
	for i in 60:
		await process_frame
	# Jump straight into phase-4 state 2 with spawn counter live.
	inst._anim_phase = 4
	inst._anim1_warning()
	inst._w_state = 2
	inst._w_off = 150.0
	inst._w_spawn = 0.0
	for i in 800:
		await process_frame
	print("PHASE=", inst._anim_phase, " WSTATE=", inst._w_state,
		" SPAWN=", inst._w_spawn, " BLANKER=", snappedf(inst._blanker,0.01),
		" RISERS=", inst._risers.size(), " Q=", snappedf(inst._w_q,0.1),
		" OFF=", snappedf(inst._w_off,0.1))
	quit()
