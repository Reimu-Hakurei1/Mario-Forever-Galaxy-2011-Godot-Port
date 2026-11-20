extends SceneTree
var R = load("res://engine/r.gd")
var frames := 0
var mode := "full"
var dumped := false
var intro_skipped := false
var map_jumped := false
var room_frames := 0
var last_room := -1
var hold_left := 0
var hold_key := 0
var cool := 0
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
	var path := "res://scenes/game.tscn"
	if mode == "scene":
		path = "res://stages/level_0000.tscn"
	var game: Node = load(path).instantiate()
	root.add_child(game)
func _process(_d: float) -> bool:
	frames += 1
	room_frames += 1
	if R.game_running and R.room != last_room:
		last_room = R.room
		room_frames = 0
	if hold_left > 0:
		hold_left -= 1
		if hold_left == 0:
			R.keyboard_key_release(null, hold_key)
	if cool > 0:
		cool -= 1
	if mode == "flow":
		if R.room == 59 and room_frames > 4 and not intro_skipped:
			intro_skipped = true
			R.pending_room = 51
		elif R.room in [51, 48, 49]:
			if hold_left == 0 and cool == 0:
				R.keyboard_key_press(null, 13)
				hold_key = 13
				hold_left = 2
				cool = 16
				# reuse hold var for enter
		elif R.room == 14 and not map_jumped and room_frames > 120:
			var G = load("res://game/globals.gd")
			var gve: Variant = null
			for inst in R.instances:
				if int(inst.g_object_index) == 220:
					var v: Variant = R.inst_get(inst.g_id, "map_gve")
					if v != null and int(v) == 2:
						gve = v
						break
					if v != null and int(v) > 0 and gve == null:
						gve = v
			if gve != null and int(gve) > 0:
				G.aktualny_lev = int(gve)
			var target: Variant = R.aget2(G.map_levelgo, R.aget(G.map_zmien_etap, 0), 0)
			if target != null and int(target) >= 0:
				map_jumped = true
				R.pending_room = int(target)
		elif R.room == 2 and room_frames > 60:
			if hold_left == 0:
				R.keyboard_key_press(null, 39)
				hold_key = 39
				hold_left = 1
	if mode == "full" and frames == 8:
		var G = load("res://game/globals.gd")
		R.aset(G.map_number, 0, 0)
		G.aktualny_lev = 2
		R.aset(G.map_zmien_etap, 0, 0)
		R.pending_room = 2
	if frames >= 20 and frames % 60 < 2:
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		ev.pressed = (frames % 60 == 0)
		R.handle_input(ev)
	if frames % 1000 == 0:
		var n12 := 0
		var verbose := frames == 7000
		var lines := []
		var player = null
		for inst in R.instances:
			if not inst.alive: continue
			var oi := int(inst.g_object_index)
			if oi == 0: player = inst
			if oi == 12:
				n12 += 1
				if verbose and n12 <= 12:
					lines.append("obj12 x=%.0f y=%.0f path=%d pos=%.2f seq=%s spd=%s" % [
						inst.position.x, inst.position.y, int(inst.g_path_index),
						float(inst.g_path_position), str(R.inst_get(inst.g_id,"sekwencja")),
						str(R.inst_get(inst.g_id,"path_speed"))])
		print("MODE=%s frame=%d tick=%d obj12count=%d" % [mode, frames, R.tick_count, n12])
		var G2 = load("res://game/globals.gd")
		print("GLOBALS mapno=%s lev=%s zmien=%s pauza=%s fps=%d" % [
			str(R.aget(G2.map_number,0)), str(G2.aktualny_lev), str(R.aget(G2.map_zmien_etap,0)),
			str(G2.pauza), Engine.get_frames_per_second()])
		var sp = null
		var tut = null
		var n146 := 0
		var n147 := 0
		for inst in R.instances:
			if not inst.alive: continue
			var oi := int(inst.g_object_index)
			if oi == 532: sp = inst
			if oi == 306: tut = inst
			if oi == 146: n146 += 1
			if oi == 147: n147 += 1
		print("WAVE help=%s periodtime=%s etap=%s n146=%d n147=%d tutseq=%s" % [
			str(G2.help),
			str(R.inst_get(sp.g_id,"periodtime")) if sp != null else "-",
			str(R.inst_get(sp.g_id,"etap")) if sp != null else "-",
			n146, n147,
			str(R.aget(tut.g_sekwencja,0)) if tut != null else "none"])
		if player != null:
			print("PLAYER x=%.0f y=%.0f" % [player.position.x, player.position.y])
		for l in lines: print(l)
		if verbose:
			var img := root.get_texture().get_image()
			img.save_png("C:/Users/Alex/gm8tools/shots/cmp_%s.png" % mode)
	if frames >= 7010:
		quit(); return true
	return false