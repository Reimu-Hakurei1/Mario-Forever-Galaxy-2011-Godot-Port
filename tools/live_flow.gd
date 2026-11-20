extends SceneTree

## Reproduce the real F5 flow with mouse-driven map clicks (windowed only,
## because the map logic lives in Draw events).
##   godot --path . -s tools/live_flow.gd -- --lev=2 --frames=4000 --savedir=_test_saves/live --shots=_test_saves/live_shots

const ENTER := 13

var savedir: String = "C:/Users/Alex/gm8tools/galaxy_port/_test_saves/live"
var limit: int = 4000
var shots: String = ""
var node_want: int = 2
var node_queue: Array = []
var visit := 0
var level_starts := 0
var in_level := false
var returned := false
var frames := 0
var room_frames := 0
var last_room := -1
var hold_key := 0
var hold_left := 0
var cool := 0
var intro_skipped := false
var map_touched := false
var click_phase := 0
var click_left := 0
var released_logged := false
var level_frame := -1
var level_room := -1
var done := false
var last_log := -1
var scene_path := ""
var start_map := -1
var sequence := false
var level_count := 0
var back_at := {}          # level index -> frame offset to return to map
var pending_click := -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
		elif a.begins_with("--lev="):
			node_want = int(a.substr(6))
		elif a.begins_with("--mapstart="):
			start_map = int(a.substr(11))
		elif a.begins_with("--nodes="):
			for p in a.substr(8).split(",", false):
				node_queue.append(int(p))
		elif a.begins_with("--scene="):
			scene_path = a.substr(8)
		elif a == "--sequence":
			sequence = true
		elif a.begins_with("--shots="):
			shots = a.substr(8).replace("\\", "/")
			DirAccess.make_dir_recursive_absolute(shots)
	DirAccess.make_dir_recursive_absolute(savedir)
	if not node_queue.is_empty():
		node_want = int(node_queue[0])
	if scene_path != "":
		var packed: PackedScene = load(scene_path)
		root.add_child(packed.instantiate())
	else:
		var game: Node = load("res://scenes/game.tscn").instantiate()
		root.add_child(game)


func _tap(key: int) -> void:
	if hold_left > 0 or cool > 0:
		return
	R.keyboard_key_press(null, key)
	hold_key = key
	hold_left = 2
	cool = 16


func _set_mouse(px: float, py: float) -> void:
	R.mouse_override = Vector2(px, py)


func _press(on: bool) -> void:
	if on:
		if not R.mouse_down.has(1):
			R.mouse_pressed[1] = true
			R.mouse_button = 1
			R.mouse_lastbutton = 1
		R.mouse_down[1] = true
	else:
		R.mouse_down.erase(1)


func _process(_delta: float) -> bool:
	if done:
		return true
	frames += 1
	room_frames += 1
	if hold_left > 0:
		hold_left -= 1
		if hold_left == 0:
			R.keyboard_key_release(null, hold_key)
	if cool > 0:
		cool -= 1
	if savedir != "" and R.working_directory != savedir:
		R.working_directory = savedir
		R._seed_user_files()
	var G = load("res://game/globals.gd")
	if R.game_running and R.room != last_room:
		var prev_room := last_room
		last_room = R.room
		room_frames = 0
		var meta: Dictionary = R.room_data.get("rooms", {}).get(str(R.room), {})
		print("ROOM %d %s frame=%d inst=%d lev=%s map=%s" % [R.room, meta.get("name", "?"),
			frames, R.instances.size(), str(G.aktualny_lev), str(R.aget(G.map_number, 0))])
		if start_map >= 0 and str(meta.get("name", "")).begins_with("room_map") \
				and not str(meta.get("name", "")).begins_with("room_map_indicator") \
				and int(R.aget(G.map_number, 0)) != start_map:
			var want := _find_map_room(start_map)
			print("MAP redirect map=%d -> room %d" % [start_map, want])
			if want >= 0:
				R.aset(G.map_number, 0, start_map)
				G.aktualny_lev = node_want
				R.pending_room = want
		var prev_meta: Dictionary = R.room_data.get("rooms", {}).get(str(prev_room), {})
		if str(prev_meta.get("name", "")) == "level_0000" and R.room != prev_room:
			level_room = -1
			level_frame = -1
			in_level = false
			click_phase = 0
			map_touched = false
			_press(false)
	if not R.game_running:
		return false
	if scene_path == "":
		if R.room == 59 and room_frames > 4 and not intro_skipped:
			intro_skipped = true
			R.pending_room = 51
		match R.room:
			51, 48, 49:
				_tap(ENTER)
			52, 53, 54, 55:
				_tap(ENTER)
			14, 4, 19, 22, 26, 30, 35, 43:
				_map_room(G)
			2:
				_level_room()
	else:
		_level_room()
	if frames >= limit:
		print("DONE frame=%d room=%d lev=%s" % [frames, R.room, str(G.aktualny_lev)])
		done = true
		quit()
		return true
	return false


func _find_map_room(map_index: int) -> int:
	var want := "room_map" + str(map_index + 1)
	var rooms: Dictionary = R.room_data.get("rooms", {})
	for key: Variant in rooms:
		if str(rooms[key].get("name", "")) == want:
			return int(key)
	return -1


func _map_room(G) -> void:
	if room_frames == 20 and not map_touched:
		map_touched = true
		G.aktualny_lev = node_want
		print("MAP touch lev=%d" % node_want)
	var node: Variant = R.aget(G.map_levid, G.aktualny_lev)
	var ui: Variant = R.get_obj_var(225, "g_kliknieto")
	if click_phase == 0:
		if room_frames > 60 and node != null:
			if start_map >= 0:
				R.aset(G.map_number, 0, start_map)
			R.aset2(G.map_complev, node_want, 0, 1)
			print("MAP force lev=%d map=%s klik=%s" % [node_want, str(R.aget(G.map_number, 0)), str(ui)])
			var cursor: Variant = R._as_inst(R.get_obj_var(225, "g_cursor"))
			if cursor != null:
				cursor.g_engagor = maxf(0.1, float(cursor.g_engagor))
			R.set_obj_var(225, "g_wybor_etapu_block", 1)
			click_phase = 1
			click_left = 400
	elif click_phase == 1:
		click_left -= 1
		if room_frames % 20 == 0:
			print("MAPF f=%d lev=%s klik=%s loot=%s eng=%.2f block=%s zm=%s" % [
				room_frames, str(G.aktualny_lev), str(R.get_obj_var(225, "g_kliknieto")),
				str(R.get_obj_var(227, "g_loot")), float(R.get_obj_var(227, "g_engagor")),
				str(R.get_obj_var(225, "g_wybor_etapu_block")), str(R.aget(G.map_zmien_etap, 0))])
		if click_left <= 0:
			print("MAP giveup room=%d" % R.room)


func _level_room() -> void:
	if not in_level:
		in_level = true
		level_room = R.room
		level_frame = frames
		level_starts += 1
		if level_starts < node_queue.size():
			node_want = int(node_queue[level_starts])
		var G = load("res://game/globals.gd")
		print("LEVEL START #%d frame=%d lev=%s map=%s ktory=%s help=%s pauza=%s" % [
			level_starts, frames, str(G.aktualny_lev), str(R.aget(G.map_number, 0)),
			str(G.ktory_juz_level), str(G.help), str(G.pauza)])
		var nz: Array = []
		for i in 30:
			if int(R.aget(G.pozycja, i)) != 0:
				nz.append(str(R.aget(G.pozycja, i)))
		print("  pozycja busy=%d %s" % [nz.size(), str(nz)])
		var con: Variant = _controller()
		if con != null:
			print("  con num=%s gnum0=%s lev0=%s se0=%s levtime0=%s ilosc=%s" % [
				str(con.get("g_num")), str(R.aget(con.get("g_num"), 0)),
				str(R.aget2(con.get("g_lev"), 0, 0)), str(R.aget2(con.get("g_sekwencus"), 0, 0)),
				str(R.aget2(con.get("g_levtime"), 0, 0)), str(con.get("g_ilosc_przeciwnikow"))])
	var t: int = frames - level_frame
	# Play like a human: advance tutorial dialogs and stir the ship.
	var G2 = load("res://game/globals.gd")
	if t % 20 == 0:
		_tap(int(G2.ster5))
	elif t % 37 == 0:
		var arrows: Array = [int(G2.ster1), int(G2.ster2), int(G2.ster3), int(G2.ster4)]
		_tap(int(arrows[(t / 37) % 4]))
	if sequence and level_starts == 1 and not returned and t >= 420:
		returned = true
		print("SEQ return to map at t=%d" % t)
		R.pending_room = 14
		return
	if t % 15 == 0:
		_dump(t)
	if shots != "" and t % 30 == 0:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(shots.path_join("t%04d.png" % t))


func _controller():
	for inst in R.instances:
		if int(inst.g_object_index) == 532:
			return inst
	return null


func _dump(t: int) -> void:
	var G = load("res://game/globals.gd")
	var by: Dictionary = {}
	var enemies: Array = []
	for inst in R.instances:
		var oi: int = int(inst.g_object_index)
		by[oi] = int(by.get(oi, 0)) + 1
		if oi not in [0, 3, 26, 136, 365, 217, 532, 220, 225, 229, 230, 231, 232, 233, 235]:
			enemies.append("%d/%d:(%.0f,%.0f)seq=%s,pos=%s" % [
				inst.g_id, oi, inst.x, inst.y,
				str(R.aget(inst.g_sekwencja, 0)),
				str(R.aget(inst.g_pozycja, 0))])
	var con: Variant = _controller()
	var extra := ""
	if con != null:
		extra = "periodtime=%.2f ilosc=%s end=%s" % [
			float(con.get("g_periodtime")), str(con.get("g_ilosc_przeciwnikow")),
			str(con.get("g_end_level"))]
	print("T=%d insts=%d by=%s ruch=(%.1f,%.1f,%.1f) %s" % [
		t, R.instances.size(), str(by), float(G.ruch1), float(G.ruch2), float(G.ruch3), extra])
	print("   pauza=%s help=%s zwolnij=%s speed=%s lev=%s map=%s" % [
		str(G.pauza), str(G.help), str(G.zwolnij_gre), str(R.room_speed),
		str(G.aktualny_lev), str(R.aget(G.map_number, 0))])
	for e in enemies:
		print("   " + e)
