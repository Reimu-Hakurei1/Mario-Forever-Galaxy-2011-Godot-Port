extends SceneTree
## Passive observer: boots the real game, sends NO input. Logs room changes,
## enemy census and enemy disappearances so a human can play while we watch.
var R = load("res://engine/r.gd")
var frames := 0
var last_room := -1
var room_frames := 0
var seen := {}
var level_room := -1
var log_path := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--log="):
			log_path = a.substr(6)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	if log_path != "":
		var f := FileAccess.open(log_path, FileAccess.WRITE)
		if f:
			f.store_string("watch start\n")
			f.close()

func _w(s: String) -> void:
	print(s)
	if log_path != "":
		var f := FileAccess.open(log_path, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
			f.store_line(s)
			f.close()

func _process(_d: float) -> bool:
	frames += 1
	room_frames += 1
	if R.game_running and R.room != last_room:
		last_room = R.room
		room_frames = 0
		seen.clear()
		var G = load("res://game/globals.gd")
		var meta: Dictionary = R.room_data.get("rooms", {}).get(str(R.room), {})
		_w("ROOM %d %s frame=%d inst=%d lev=%s map=%s scene=%s" % [R.room,
			meta.get("name", "?"), frames, R.instances.size(), str(G.aktualny_lev),
			str(R.aget(G.map_number, 0)), str(R.active_scene_path)])
	if not R.game_running:
		return false
	_track()
	return false

func _track() -> void:
	var cur := {}
	for inst in R.instances:
		if inst == null or not inst.alive:
			continue
		var o: Dictionary = R.objects.get(int(inst.g_object_index), {})
		if str(o.get("category", "")) not in ["enemies", "bosses"]:
			continue
		cur[inst.g_id] = {"obj": int(inst.g_object_index), "x": inst.position.x, "y": inst.position.y,
			"seq": R.aget(inst.g_sekwencja, 0), "path": inst.g_path_index,
			"ppos": float(inst.g_path_position)}
	for id in seen.keys():
		if not cur.has(id):
			var old: Dictionary = seen[id]
			_w("ENEMY_GONE id=%d obj=%d last=(%.0f,%.0f) seq=%s path=%s ppos=%.3f room=%d" % [
				id, int(old.obj), float(old.x), float(old.y), str(old.seq),
				str(old.path), float(old.ppos), R.room])
	seen = cur
	if room_frames % 120 == 0:
		var G = load("res://game/globals.gd")
		var con = null
		for inst in R.instances:
			if int(inst.g_object_index) == 532:
				con = inst
				break
		_w("CENSUS room=%d t=%d enemies=%d ilosc=%s periodtime=%.2f etap=%s lev=%s" % [
			R.room, room_frames, cur.size(),
			str(con.get("g_ilosc_przeciwnikow")) if con else "-",
			float(con.get("g_periodtime")) if con else -1.0,
			str(con.g_etap) if con else "-", str(G.aktualny_lev)])
