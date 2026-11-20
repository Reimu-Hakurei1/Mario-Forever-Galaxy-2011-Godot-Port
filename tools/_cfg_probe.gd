extends SceneTree
func _initialize() -> void:
	for key in ["0:10", "0:16", "1:14"]:
		var cfg = NativeLevelTable.config_for_key(key)
		print(key, " mode=", cfg.get("mode"), " talk_only=", cfg.get("talk_only"),
			" stage_bosses=", cfg.get("stage_bosses"), " waves=", cfg.get("waves", []).size())
	quit()
