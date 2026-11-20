extends SceneTree
func _initialize() -> void:
	var bad := 0
	for f in ["res://native/core/dialogue_table.gd",
		"res://native/levels/castle.gd", "res://native/ui/next_map.gd",
		"res://native/levels/star_map.gd"]:
		if load(f) == null:
			bad += 1
			print("FAIL ", f)
		else:
			print("OK ", f)
	# verify dialogue mapping
	var D = load("res://native/core/dialogue_table.gd")
	for t in range(8):
		var l: Array = D.for_boss(t, "", "HERO")
		print("tier", t, " lines=", l.size(),
			" first=", (l[0] if l.size() > 0 else "-"))
	print("CHECK_DONE bad=", bad)
	quit()
