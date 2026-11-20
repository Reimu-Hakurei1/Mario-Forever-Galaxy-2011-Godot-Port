extends SceneTree
## Boots the game and jumps straight into a level room, then reports spawns.

var R = load("res://engine/r.gd")
var frames := 0
var level_frame := -1
var target := -1
var lev := 4
var map := 0
var room := -1
var limit := 480
var dump := false
var shot_dir := ""
var reenter := -1
var reentered := false
var fire_skip := false
var fire_key := 0
var held_keys: Array = []
var skipping := {"0": true, "3": true, "26": true, "136": true, "365": true, "217": true,
	"532": true, "220": true, "225": true, "229": true, "230": true, "231": true,
	"232": true, "233": true, "235": true}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lev="):
			lev = int(a.substr(6))
		elif a.begins_with("--map="):
			map = int(a.substr(6))
		elif a.begins_with("--room="):
			room = int(a.substr(7))
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
		elif a == "--dump":
			dump = true
		elif a.begins_with("--reenter="):
			reenter = int(a.substr(10))
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8).replace("\\", "/")
			DirAccess.make_dir_recursive_absolute(shot_dir)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	var GL = load("res://game/globals.gd")
	# Topic dialogs close only on real key presses seen during Draw.
	if fire_skip:
		for k in held_keys:
			R.keyboard_key_release(null, int(k))
		held_keys.clear()
		fire_skip = false
	if R.game_running and GL.help != 0 and frames % 2 == 0:
		fire_key = int(GL.ster5)
		held_keys = [fire_key, int(GL.ster1), int(GL.ster2), int(GL.ster3), int(GL.ster4)]
		for k in held_keys:
			R.keyboard_key_press(null, int(k))
		fire_skip = true
	if R.game_running and R.working_directory != "_test_saves/flow_direct":
		R.working_directory = "_test_saves/flow_direct"
		R._seed_user_files()
	if frames == 20:
		var G = load("res://game/globals.gd")
		R.aset(G.map_number, 0, map)
		G.aktualny_lev = lev
		target = room if room >= 0 else int(R.aget2(G.map_levelgo, map, lev))
		print("JUMP map=%d lev=%d target=%d" % [map, lev, target])
		R.pending_room = target
	if R.room == target:
		if level_frame < 0:
			level_frame = frames
			print("ENTER room=%d scene=%s" % [R.room, str(R.active_scene_path)])
		var t := frames - level_frame
		if reenter >= 0 and not reentered and t >= reenter:
			reentered = true
			print("REENTER at t=%d insts=%d" % [t, R.instances.size()])
			level_frame = -1
			R.pending_room = target
			return false
		if t % 120 == 0 or (dump and t % 15 == 0):
			var by := {}
			for inst in R.instances:
				by[int(inst.g_object_index)] = int(by.get(int(inst.g_object_index), 0)) + 1
			var G = load("res://game/globals.gd")
			var con: GMInstance = null
			for inst in R.instances:
				if int(inst.g_object_index) == 532:
					con = inst
					break
			print("T=%d insts=%d by=%s ruch=(%.1f,%.1f,%.1f) etap=%s pt=%.2f il=%s map=%s lev=%s spd=%s pauza=%s end=%s" % [
				t, R.instances.size(), str(by), float(G.ruch1), float(G.ruch2), float(G.ruch3),
				str(con.g_etap) if con else "-",
				float(con.get("g_periodtime")) if con else -1.0,
				str(con.get("g_ilosc_przeciwnikow")) if con else "-",
				str(R.aget(G.map_number, 0)), str(G.aktualny_lev), str(R.room_speed),
				str(G.pauza), str(con.get("g_end_level")) if con else "-"])
			if con and t % 30 == 0:
				print("   INTRO pb=%.3f nx5=%.1f nx40=%.1f nx41=%.1f nx42=%.1f ne=%s pt=%.2f" % [
					float(con.get("g_periodbooster")), float(con.get("g_napisx5")),
					float(con.get("g_napisx40")), float(con.get("g_napisx41")),
					float(con.get("g_napisx42")), str(con.get("g_napis_en")),
					float(con.get("g_periodtime"))])
			if con:
				var et := int(con.g_etap)
				var row: Variant = R.aget(con.g_perioder, et)
				var raw5: Variant = row[5] if row is Array and row.size() > 5 else "n/a"
				var raw3: Variant = row[3] if row is Array and row.size() > 3 else "n/a"
				print("   PERIODER et=%d t3=%s t5=%s t10=%s t11=%s t20=%s t35=%s bindings=%d raw5=%s raw3=%s" % [
					et, str(R.aget2(con.g_perioder, et, 3)), str(R.aget2(con.g_perioder, et, 5)),
					str(R.aget2(con.g_perioder, et, 10)), str(R.aget2(con.g_perioder, et, 11)),
					str(R.aget2(con.g_perioder, et, 20)), str(R.aget2(con.g_perioder, et, 35)),
					R.level_waves.bindings.size(), str(raw5), str(raw3)])
			if dump:
				for inst in R.instances:
					var oi := int(inst.g_object_index)
					if str(oi) in skipping:
						continue
					print("   %d/%d:(%.0f,%.0f)seq=%s,pos=%s,dox=%s,doy=%s,rodzaj=%s,spr=%s,en=%s,ix=%.1f,pi=%s,pp=%.4f,ps=%s" % [
						inst.g_id, oi, inst.x, inst.y,
						str(R.aget(inst.g_sekwencja, 0)), str(R.aget(inst.g_pozycja, 0)),
						str(inst.get("g_dox")), str(inst.get("g_doy")),
						str(inst.get("g_rodzaj")), str(inst.get("g_sprite_index")),
						str(inst.get("g_energia")), float(inst.get("g_ixor")),
						str(inst.get("g_path_index")), float(inst.get("g_path_position")),
						str(inst.get("g_path_speed"))])
		if shot_dir != "" and t % 10 == 0:
			var img := root.get_viewport().get_texture().get_image()
			img.save_png(shot_dir.path_join("t%04d.png" % t))
		if t >= limit:
			print("WARNINGS " + JSON.stringify(R.warnings))
			quit()
			return true
	if frames > limit + 240:
		print("TIMEOUT room=%d" % R.room)
		quit()
		return true
	return false
