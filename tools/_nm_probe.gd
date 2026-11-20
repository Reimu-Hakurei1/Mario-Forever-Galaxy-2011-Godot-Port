extends SceneTree
func _initialize() -> void:
	var s = load("res://native/ui/next_map.gd")
	var n = s.new()
	n.destination = 2
	n.hero_index = 0
	root.add_child(n)
	await process_frame
	await process_frame
	n.set_process(false)
	print("READY boxes=", n._boxes.size(), " pos=", n._ship_p["pos"])
	var dt := 1.0 / 60.0
	for i in 1200:
		n._physics(n._ship_p, dt)
		n._physics(n._toad_p, dt)
		if n._ship_p["phase"] == 1:
			break
	print("FLY ship_phase=", n._ship_p["phase"], " pos=", n._ship_p["pos"])
	n._phase = 1
	n._start_dialogue()
	var guard := 0
	while n._phase == 1 and guard < 30000:
		n._dialogue_tick(dt)
		guard += 1
	print("DIALOGUE done lines=", n._line_idx, " iters=", guard,
		" phase=", n._phase)
	for i in 900:
		n._boost_tick(dt)
		if n._phase == 3:
			break
	print("BOOST phase=", n._phase, " shipy=", n._ship_p["pos"].y)
	quit()
