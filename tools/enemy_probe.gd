extends SceneTree
var frames := 0
func _initialize() -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 8:
		var G = load("res://game/globals.gd")
		G.aktualny_lev = 2
		R.pending_room = 2
	if frames == 30:
		R.keyboard_key_press(null, 39)
	if frames == 400: R.keyboard_key_press(null, 32)
	if frames == 410: R.keyboard_key_release(null, 32)
	if frames > 200 and frames % 100 == 0:
		var counts := {}
		for inst in R.instances:
			if inst.alive:
				counts[inst.g_object_index] = int(counts.get(inst.g_object_index, 0)) + 1
		var sp = null
		for inst in R.instances:
			if inst.alive and inst.g_object_index == 532:
				sp = inst
		var pt = -1.0
		var et = -1
		var extra = ""
		if sp != null:
			pt = float(R.inst_get(sp.g_id, "periodtime"))
			et = int(R.inst_get(sp.g_id, "etap"))
			var G = load("res://game/globals.gd")
			extra = "pauza=%s end=%s napisx42=%s has_step=%s" % [str(G.pauza), str(R.inst_get(sp.g_id, "end_level")), str(R.inst_get(sp.g_id, "napisx42")), str(sp.has_step)]
		print("CHAIN frame=%d counts=%s periodtime=%.2f etap=%d %s" % [frames, str(counts), pt, et, extra])
	if frames >= 1500:
		quit(); return true
	return false
