extends SceneTree
var R = load("res://engine/r.gd")

## Dump a representative mid-combat snapshot of the live level (room 2) so the
## editor scene can show the enemies/waves the game actually renders.
##   godot --path . -s tools/preview_dump.gd -- --lev=2 --frames=240 --out=preview.json

var frames := 0
var wait := 240
var lev := 2
var out_path := "preview.json"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="): wait = int(a.substr(9))
		elif a.begins_with("--lev="): lev = int(a.substr(6))
		elif a.begins_with("--out="): out_path = a.substr(6)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 8:
		var G = load("res://game/globals.gd")
		G.aktualny_lev = lev
		R.pending_room = 2
	if frames == 30:
		R.keyboard_key_press(null, 39)
	if frames > 30 and frames % 12 == 0:
		R.keyboard_key_press(null, 16)
		R.keyboard_key_release(null, 16)
	if frames >= wait:
		var rows: Array = []
		for inst in R.instances:
			if not inst.alive or not inst.has_draw: continue
			var sidx: int = int(R.inst_get(inst.g_id, "sprite_index"))
			var sub: int = int(R.inst_get(inst.g_id, "image_index"))
			var smeta: Dictionary = R.sprites.get(sidx, {})
			var sname: String = str(smeta.get("name", ""))
			if sname == "": continue
			var tex := "res://images/sprites/%s.%d.%d.png" % [sname, sidx, sub]
			if not ResourceLoader.exists(tex): continue
			var vis: Variant = R.inst_get(inst.g_id, "visible")
			if vis != null and not bool(vis): continue
			rows.append({"obj": sname, "sub": sub, "sidx": sidx, "x": inst.x, "y": inst.y,
				"depth": int(R.inst_get(inst.g_id, "depth"))})
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows))
		f.close()
		print("PREVIEW dumped %d sprites -> %s" % [rows.size(), out_path])
		quit()
		return true
	return false