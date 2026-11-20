extends SceneTree
func _initialize() -> void:
	var bad := 0
	var files := []
	var dir := DirAccess.open("res://native")
	_scan(dir, files)
	for f in files:
		if f.ends_with(".gd") and load(f) == null:
			bad += 1
			print("FAIL ", f)
	print("PARSED ", files.size(), " bad=", bad)
	# boot main scene
	var ps = load("res://native/ui/title.tscn")
	if ps == null:
		print("FAIL title scene")
		bad += 1
	else:
		var inst = ps.instantiate()
		root.add_child(inst)
		print("TITLE_OK")
	await process_frame
	await process_frame
	print("FINAL_DONE bad=", bad)
	quit()

func _scan(d: DirAccess, out: Array) -> void:
	for f in d.get_files():
		out.append(d.get_current_dir() + "/" + f)
	for sub in d.get_directories():
		if d.change_dir(sub) == OK:
			_scan(d, out)
			d.change_dir("..")
