extends SceneTree

## Walk the real project flow (title -> save slots -> world map) and enter a level
## by clicking its node, then dump enemy/controller state like enemy_compare.gd.
##   godot --path . -s tools/map_click_probe.gd -- --savedir=_test_saves/real_copy --lev=0 --frames=3000 --shots=_test_saves/shots_click
## With no --lev the probe clicks the current level node (g_aktualny_lev).

const ENTER := 13

var savedir := ""
var want_lev := -1
var limit := 3000
var shot_dir := ""
var frames := 0
var room_frames := 0
var last_room := -1
var hold_key := 0
var hold_left := 0
var cool := 0
var clicked := false
var release_in := 0
var attempts := 0
var level_frame := -1
var level_room := -1
var done := false
var nodes_printed := false
var map_seen := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
		elif a.begins_with("--lev="):
			want_lev = int(a.substr(6))
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8).replace("\\", "/")
			DirAccess.make_dir_recursive_absolute(shot_dir)
	if savedir != "":
		DirAccess.make_dir_recursive_absolute(savedir)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _tap(key: int) -> void:
	if hold_left > 0 or cool > 0:
		return
	R.keyboard_key_press(null, key)
	hold_key = key
	hold_left = 2
	cool = 10


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
	if R.game_running and R.room != last_room:
		last_room = R.room
		room_frames = 0
		var meta: Dictionary = R.room_data.get("rooms", {}).get(str(R.room), {})
		print("ROOM %d %s frame=%d inst=%d" % [R.room, meta.get("name", "?"), frames, R.instances.size()])
	if not R.game_running:
		return false
	var G = load("res://game/globals.gd")
	var rname: String = str(R.room_data.get("rooms", {}).get(str(R.room), {}).get("name", ""))
	if not map_seen and rname.begins_with("room_map"):
		map_seen = true
		print("MAP ENTER room=%d mapno=%s lev=%s backdoor=%s speed=%s" % [R.room,
			str(R.aget(G.map_number, 0)), str(G.aktualny_lev),
			str(G.map_backdoor_lev), str(R.room_speed)])
	if R.room in [59, 52, 53, 54, 55] and room_frames > 4:
		_tap(ENTER)
	if R.room in [51, 48, 49] and room_frames > 150:
		_tap(ENTER)
	if rname.begins_with("room_map") and not clicked and room_frames > 90:
		if not nodes_printed and room_frames % 30 == 0:
			nodes_printed = true
			for inst in R.instances:
				if int(inst.g_object_index) == 220:
					var gve: int = int(R.inst_get(inst.g_id, "map_gve"))
					print("NODE gve=%d x=%.0f y=%.0f comp=%s" % [gve, inst.x, inst.y,
						str(R.aget2(G.map_complev, gve, 0))])
		if room_frames % 30 == 0:
			print("MAPF f=%d lev=%s comp=%s block=%s klik=%s size=%.2f loot=%s eng=%.2f" % [
				frames, str(G.aktualny_lev), str(R.aget2(G.map_complev, int(G.aktualny_lev), 0)),
				str(R.get_obj_var(225, "g_wybor_etapu_block")), str(R.get_obj_var(225, "g_kliknieto")),
				float(R.get_obj_var(225, "g_miedzyetap_size")), str(R.get_obj_var(227, "g_loot")),
				float(R.get_obj_var(227, "g_engagor"))])
		var block: Variant = R.get_obj_var(225, "g_wybor_etapu_block")
		if R.eqv(null, block, 1) and R.eqv(null, release_in, 0):
			# Slide the cursor off the node so the engage/fade launch can run.
			R.mouse_override = [R.aget(R.view_xview, 0) + 100.0, R.aget(R.view_yview, 0) + 100.0]
		if R.eqv(null, release_in, 0) and R.eqv(null, block, 0) and cool == 0 and not clicked:
			var want: int = want_lev if want_lev >= 0 else int(G.aktualny_lev)
			var cur: int = int(G.aktualny_lev)
			var target_lev := -1
			if cur == want:
				if R.eqv(null, R.aget2(G.map_complev, cur, 0), 0):
					target_lev = cur
				else:
					print("CANNOT LAUNCH completed non-castle level %d" % cur)
					clicked = true
			else:
				target_lev = _bfs_step(G, cur, want)
				if target_lev < 0:
					print("NO PATH %d -> %d" % [cur, want])
					clicked = true
			var node: GMInstance = null
			for inst in R.instances:
				if int(inst.g_object_index) == 220 and int(R.inst_get(inst.g_id, "map_gve")) == target_lev:
					node = inst
					break
			if target_lev >= 0 and node != null:
				R.mouse_override = [node.x, node.y]
				R.mouse_down[1] = true
				release_in = 8
				attempts += 1
				print("CLICK%d lev=%d at (%.0f,%.0f) frame=%d complev=%s akt=%s" % [attempts,
					target_lev, node.x, node.y, frames,
					str(R.aget2(G.map_complev, target_lev, 0)), str(G.aktualny_lev)])
			elif target_lev >= 0:
				print("NO NODE for lev=%d" % target_lev)
				clicked = true
		elif release_in > 0:
			release_in -= 1
			if release_in == 0:
				R.mouse_down.erase(1)
				cool = 90
				print("CLICK%d released block=%s klik=%s loot=%s eng=%.2f" % [attempts,
					str(R.get_obj_var(225, "g_wybor_etapu_block")),
					str(R.get_obj_var(225, "g_kliknieto")),
					str(R.get_obj_var(227, "g_loot")),
					float(R.get_obj_var(227, "g_engagor"))])
	if clicked and R.room != last_room:
		pass
	if rname.begins_with("level_") or rname.begins_with("room_level"):
		if level_room < 0:
			level_room = R.room
			level_frame = frames
			print("LEVEL room=%d frame=%d scene=%s map=%s lev=%s" % [R.room, frames,
				str(R.active_scene_path), str(R.aget(G.map_number, 0)), str(G.aktualny_lev)])
		if level_frame >= 0:
			if (frames - level_frame) % 15 == 0:
				_dump(frames - level_frame)
			if shot_dir != "" and (frames - level_frame) % 60 == 0:
				var img := root.get_viewport().get_texture().get_image()
				img.save_png(shot_dir.path_join("t%04d.png" % (frames - level_frame)))
	if frames >= limit:
		print("DONE frame=%d room=%d" % [frames, R.room])
		done = true
		quit()
		return true
	return false


func _bfs_step(G, from_lev: int, to_lev: int) -> int:
	var prev: Dictionary = {from_lev: -1}
	var queue: Array = [from_lev]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == to_lev:
			var step := cur
			while prev.get(step, -1) != from_lev and prev.get(step, -1) != -1:
				step = int(prev[step])
			return step
		for table in [G.map_nextlev, G.map_prevlev]:
			for k in 4:
				var nb: Variant = R.aget2(table, cur, k)
				if nb == null or int(nb) < 0 or int(nb) == cur:
					continue
				if prev.has(int(nb)):
					continue
				prev[int(nb)] = cur
				queue.append(int(nb))
	return -1


func _dump(t: int) -> void:
	var G = load("res://game/globals.gd")
	var by: Dictionary = {}
	var enemies: Array = []
	for inst in R.instances:
		var oi: int = int(inst.g_object_index)
		by[oi] = int(by.get(oi, 0)) + 1
		if oi == 12:
			enemies.append("%d rodz=%s seq=%s pos=%s kam=%s (%.0f,%.0f)->(%.0f,%.0f)" % [
				inst.g_id, str(R.inst_get(inst.g_id, "rodzaj")), str(R.aget(inst.g_sekwencja, 0)),
				str(R.aget(inst.g_pozycja, 0)), str(R.inst_get(inst.g_id, "kamikaze")),
				inst.x, inst.y, float(R.inst_get(inst.g_id, "dox")),
				float(R.inst_get(inst.g_id, "doy"))])
	var con: GMInstance = null
	for inst in R.instances:
		if int(inst.g_object_index) == 532:
			con = inst
			break
	var extra := ""
	if con != null:
		extra = "etap=%s periodtime=%.2f ilosc=%s zeg=%.1f boost=%.3f end=%s" % [
			str(con.get("g_etap")), float(con.get("g_periodtime")),
			str(con.get("g_ilosc_przeciwnikow")), float(con.get("g_zegarek")),
			float(con.get("g_periodbooster")), str(con.get("g_end_level"))]
	print("T=%d insts=%d by=%s ruch=(%.1f,%.1f,%.1f) %s" % [t, R.instances.size(),
		str(by), float(G.ruch1), float(G.ruch2), float(G.ruch3), extra])
	print("   pauza=%s help=%s run=%s speed=%s view=(%.0f,%.0f) lev=%s map=%s" % [
		str(G.pauza), str(G.help), str(R.game_running), str(R.room_speed),
		float(R.aget(R.view_xview, 0)), float(R.aget(R.view_yview, 0)),
		str(G.aktualny_lev), str(R.aget(G.map_number, 0))])
	for e in enemies:
		print("   " + e)
