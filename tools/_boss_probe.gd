extends SceneTree
func _init() -> void:
	for key in ["0:10","0:16","1:14","2:30","3:36","3:5","4:6","5:2","5:26","5:57","6:7","6:8","7:26","4:20","4:29"]:
		var cfg = NativeLevelTable.config_for_key(key)
		var sb = cfg.get("stage_bosses", [])
		var to = cfg.get("talk_only", false)
		var wb = 0
		for w in cfg.get("waves", []):
			if w.has("bosses"): wb += 1
		print("%s mode=%s talk=%s stage_bosses=%s wave_bosses=%d" % [key, cfg.get("mode"), to, sb, wb])
	quit()
