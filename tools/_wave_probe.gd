extends SceneTree
func _init():
	# find stage keys containing the special spawns
	var lt = load("res://native/core/level_table.gd")
	var found := 0
	for i in 178:
		var cfg = lt.config_for(i)
		for w in cfg.get("waves", []):
			var p = str(w.get("pattern",""))
			if p in ["swarm_teams","drop","kamikaze_spikeys","castle_stream"] and w.get("script","") == "":
				if p == "swarm_teams" or (p == "drop"):
					print("LV", i, " ", p, " drop=", w.get("drop",""), " count=", w.get("count"))
					found += 1
	print("PROBE_DONE found=", found)
	quit()
