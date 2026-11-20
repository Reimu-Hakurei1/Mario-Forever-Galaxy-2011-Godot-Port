extends SceneTree

## Enter the same level twice in one session (title -> map -> level -> map -> level)
## and dump formation-slot state, to check whether globals that the original resets at
## boot leak across level entries in the F5 flow.
##   godot --headless --path . -s tools/reenter_probe.gd -- --lev=6 --map=0 --savedir=_test_saves/reenter

const ENTER := 13

var limit := 4000
var frames := 0
var room_frames := 0
var last_room := -1
var hold_key := 0
var hold_left := 0
var cool := 0
var force_map := 0
var force_lev := 6
var savedir := ""
var phase := 0
var done := false
var level_room := -1
var in_level := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			force_map = int(a.substr(6))
		elif a.begins_with("--lev="):
			force_lev = int(a.substr(6))
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
		elif a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
			DirAccess.make_dir_recursive_absolute(savedir)
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
	if not R.game_running:
		return false
	var G = load("res://game/globals.gd")
	if R.room != last_room:
		last_room = R.room
		room_frames = 0
		var meta: Dictionary = R.room_data.get("rooms", {}).get(str(R.room), {})
		print("ROOM %d %s frame=%d inst=%d" % [R.room, str(meta.get("name", "?")), frames, R.instances.size()])
	var rname: String = str(R.room_data.get("rooms", {}).get(str(R.room), {}).get("name", ""))
	in_level = rname.begins_with("level_") or rname.begins_with("room_level")
	if R.room == 59 and room_frames > 4:
		R.pending_room = 51
	if R.room in [51, 48, 49]:
		_tap(ENTER)
	if rname == "room_map" and not in_level:
		if phase == 0 and room_frames > 30:
			phase = 1
			print("MAP1 frame=%d lev=%s" % [frames, str(G.aktualny_lev)])
			R.aset(G.map_number, 0, force_map)
			G.aktualny_lev = force_lev
			R.pending_room = int(R.aget2(G.map_levelgo, force_lev, 0))
		elif phase == 2 and room_frames > 30:
			phase = 3
			print("MAP2 frame=%d lev=%s poz=%s" % [frames, str(G.aktualny_lev), _pozstr(G)])
			R.aset(G.map_number, 0, force_map)
			G.aktualny_lev = force_lev
			R.pending_room = int(R.aget2(G.map_levelgo, force_lev, 0))
	if in_level:
		if level_room < 0:
			level_room = R.room
			print("LEVEL room=%d scene=%s" % [R.room, str(R.active_scene_path)])
		if phase == 1 and room_frames == 90:
			print("ENTRY1 t=90 poz=%s" % _pozstr(G))
			_dump(90)
		if phase == 1 and room_frames == 900:
			_dump(900)
			phase = 2
			R.pending_room = 14
		if phase == 3 and room_frames == 90:
			print("ENTRY2 t=90 poz=%s" % _pozstr(G))
			_dump(90)
		if phase == 3 and room_frames == 900:
			_dump(900)
			done = true
			quit()
			return true
	if frames >= limit:
		print("DONE frame=%d room=%d phase=%d" % [frames, R.room, phase])
		done = true
		quit()
		return true
	return false


func _pozstr(G) -> String:
	var out := PackedStringArray()
	for i in 30:
		var v: Variant = R.aget(G.pozycja, i)
		out.append("0" if R.eqv(null, v, 0) == 1 else "1")
	return "".join(out)


func _dump(t: int) -> void:
	var G = load("res://game/globals.gd")
	var n12 := 0
	var seqs := {}
	var rows := {}
	for inst in R.instances:
		if int(inst.g_object_index) != 12:
			continue
		n12 += 1
		var s: String = str(R.aget(inst.g_sekwencja, 0))
		seqs[s] = int(seqs.get(s, 0)) + 1
		var p: String = str(R.aget(inst.g_pozycja, 0))
		rows[p] = int(rows.get(p, 0)) + 1
	print("DUMP t=%d enemies=%d seq=%s pos=%s ruch=(%.1f,%.1f,%.1f)" % [
		t, n12, str(seqs), str(rows), float(G.ruch1), float(G.ruch2), float(G.ruch3)])
