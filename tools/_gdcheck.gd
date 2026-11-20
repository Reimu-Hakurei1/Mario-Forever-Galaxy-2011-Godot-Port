extends SceneTree
func _init() -> void:
	var files := [
		"res://native/ui/next_map.gd",
		"res://native/ui/cutscene.gd",
		"res://native/levels/star_map.gd",
		"res://native/ui/boss_dialogue.gd",
	]
	var bad := 0
	for f in files:
		var s = load(f)
		if s == null:
			bad += 1
			print("FAIL_LOAD ", f)
		else:
			print("OK ", f)
	print("CHECK_DONE bad=", bad)
	quit()
