extends SceneTree
func _initialize() -> void:
	for key in ["7:5", "7:16", "2:11", "4:29", "0:12", "6:22"]:
		var cfg = NativeLevelTable.config_for_key(key)
		var summary := []
		for w in cfg.get("waves", []):
			summary.append("%s x%d %s" % [str(w.get("kinds", w.get("kind","?"))), int(w.get("count",0)), str(w.get("pattern",""))])
		print(key, " waves=", summary.slice(0, 8))
		print("   bosses=", cfg.get("stage_bosses"))
	quit()
