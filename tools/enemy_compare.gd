extends SceneTree

## Compare enemy behaviour between F6 scene launch and full project flow.
##   godot --headless --path . -s tools/enemy_compare.gd -- --mode=scene --scene=res://stages/world_1/level_03_gombas_camp.tscn --frames=900 --savedir=_test_saves/ec_scene
##   godot --headless --path . -s tools/enemy_compare.gd -- --mode=game --frames=15500 --savedir=_test_saves/ec_game

const ENTER := 13
const RIGHT := 39
const FIRE := 32

var mode: String = "game"
var scene_path: String = ""
var savedir: String = "C:/Users/Alex/gm8tools/galaxy_port/_test_saves/enemy_compare"
var limit: int = 6000
var frames: int = 0
var room_frames: int = 0
var last_room: int = -1
var hold_key: int = 0
var hold_left: int = 0
var cool: int = 0
var intro_skipped := false
var map_jumped := false
var level_frame := -1
var level_room := 2
var force_map := -1
var force_lev := -1
var shot_dir := ""
var done := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			mode = a.substr(7)
		elif a.begins_with("--scene="):
			scene_path = a.substr(8)
		elif a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
		elif a.begins_with("--map="):
			force_map = int(a.substr(6))
		elif a.begins_with("--lev="):
			force_lev = int(a.substr(6))
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8).replace("\\", "/")
			DirAccess.make_dir_recursive_absolute(shot_dir)
	DirAccess.make_dir_recursive_absolute(savedir)
	if mode == "scene":
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
	if R.game_running and R.room != last_room:
		last_room = R.room
		room_frames = 0
		var meta: Dictionary = R.room_data.get("rooms", {}).get(str(R.room), {})
		print("ROOM %d %s frame=%d inst=%d" % [R.room, meta.get("name", "?"),
			frames, R.instances.size()])
	if not R.game_running:
		return false
	if mode == "game":
		if R.room == 59 and room_frames > 4 and not intro_skipped:
			intro_skipped = true
			R.pending_room = 51
		match R.room:
			51, 48, 49:
				_tap(ENTER)
			14, 4, 19, 22, 26, 30, 35, 43:
				if not map_jumped and room_frames > 120:
					var G = load("res://game/globals.gd")
					var target: Variant = 2
					if force_lev >= 0:
						R.aset(G.map_number, 0, force_map)
						G.aktualny_lev = force_lev
					else:
						var gve: Variant = null
						for inst in R.instances:
							if int(inst.g_object_index) == 220:
								var v: Variant = R.inst_get(inst.g_id, "map_gve")
								if v != null and int(v) > 0 and (gve == null or int(v) == 2):
									gve = v
									if int(v) == 2:
										break
						if gve != null and int(gve) > 0:
							G.aktualny_lev = int(gve)
						target = R.aget2(G.map_levelgo, R.aget(G.map_zmien_etap, 0), 0)
					print("MAP lev=%s mapno=%s target=%s" % [str(G.aktualny_lev),
						str(R.aget(G.map_number, 0)), str(target)])
					if target != null and int(target) >= 0:
						map_jumped = true
						level_room = int(target)
						R.pending_room = int(target)
	if R.room == level_room and room_frames > 60:
		R.keyboard_key_press(null, RIGHT)
		if room_frames % 10 == 0:
			_tap(FIRE)
	if R.room == level_room and level_frame < 0:
		seed(12345)
		level_frame = frames
	if R.room == level_room and level_frame >= 0:
		var G = load("res://game/globals.gd")
		# Headless never runs Draw events, so the tutorial overlay cannot animate
		# itself away; clear it so the level keeps stepping for the comparison.
		if force_lev >= 0:
			G.help = 0
			if R.eqv(null, G.pauza, 100):
				G.pauza = 0
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
	var con: GMInstance = null
	for inst in R.instances:
		if int(inst.g_object_index) == 532:
			con = inst
			break
	var extra := ""
	if con != null:
		var per: Variant = con.get("g_perioder")
		var rows := 0
		var cells := 0
		if per is Array:
			rows = per.size()
			for row in per:
				if row is Array:
					cells += row.size()
		extra = "periodtime=%.2f ilosc=%s per=%dx%d lev=%s map=%s" % [
			float(con.get("g_periodtime")), str(con.get("g_ilosc_przeciwnikow")),
			rows, cells, str(G.aktualny_lev), str(R.aget(G.map_number, 0))]
	print("T=%d insts=%d by=%s ruch=(%.1f,%.1f,%.1f) etap=%s %s scene=%s" % [
		t, R.instances.size(), str(by),
		float(G.ruch1), float(G.ruch2), float(G.ruch3),
		str(con.g_etap) if con else "-", extra, str(R.active_scene_path)])
	print("   pauza=%s help=%s zwolnij=%s run=%s speed=%s pending=%s end=%s napis_en=%s x42=%s" % [
		str(G.pauza), str(G.help), str(G.zwolnij_gre), str(R.game_running),
		str(R.room_speed), str(R.pending_room),
		str(con.get("g_end_level")) if con else "-",
		str(con.get("g_napis_en")) if con else "-",
		str(con.get("g_napisx42")) if con else "-"])
	if con != null and (t <= 1 or t == 300):
		var raw: Variant = con.get("g_perioder")
		var rawrow: Variant = raw[0] if raw is Array and raw.size() > 0 else []
		var ov := []
		for i in 8:
			ov.append(str(R.aget2(con.g_perioder, 0, i)))
		var rr := []
		for i in 8:
			rr.append(str(rawrow[i]) if rawrow is Array and rawrow.size() > i else "-")
		print("   WAVE tables=%d spawns=%d bind=%d ov=%s raw=%s" % [
			R.level_waves.tables.size(), R.level_waves.spawns.size(),
			R.level_waves.bindings.size(), str(ov), str(rr)])
	for e in enemies:
		print("   " + e)
