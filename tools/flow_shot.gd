extends SceneTree

## Enter a level through the full project flow (same path as F5) without touching the
## controls and save PNGs at chosen frames since level entry.
##   godot --path . -s tools/flow_shot.gd -- --map=0 --lev=4 --at=330,500,700 --outdir=_shots/f5 --savedir=_test_saves/flow_shot

const ENTER := 13

var force_map := 0
var force_lev := 4
var at: Array[int] = []
var outdir := "C:/Users/Alex/gm8tools/galaxy_port/_shots/f5"
var savedir := ""
var limit := 6000
var frames := 0
var room_frames := 0
var last_room := -1
var hold_key := 0
var hold_left := 0
var cool := 0
var intro_skipped := false
var map_jumped := false
var level_frame := -1
var level_room := -1
var tick_at: Array[int] = []
var level_tick := -1
var shot_room := -1
var shot_room_tick := 60
var room_tick := -1
var done := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			force_map = int(a.substr(6))
		elif a.begins_with("--lev="):
			force_lev = int(a.substr(6))
		elif a.begins_with("--at="):
			for s in a.substr(5).split(","):
				at.append(int(s))
		elif a.begins_with("--outdir="):
			outdir = a.substr(9).replace("\\", "/")
		elif a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
		elif a.begins_with("--ticks="):
			for s in a.substr(8).split(","):
				tick_at.append(int(s))
		elif a.begins_with("--shotroom="):
			var parts := a.substr(11).split("@")
			shot_room = int(parts[0])
			if parts.size() > 1:
				shot_room_tick = int(parts[1])
	DirAccess.make_dir_recursive_absolute(outdir)
	DirAccess.make_dir_recursive_absolute(savedir)
	seed(12345)
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
		room_tick = R.tick_count
		var meta: Dictionary = R.room_data.get("rooms", {}).get(str(R.room), {})
		print("ROOM %d %s frame=%d inst=%d" % [R.room, meta.get("name", "?"),
			frames, R.instances.size()])
	if not R.game_running:
		return false
	if R.room == 59 and room_frames > 4 and not intro_skipped:
		intro_skipped = true
		R.pending_room = 51
	match R.room:
		51, 48, 49:
			_tap(ENTER)
		14, 4, 19, 22, 26, 30, 35, 43:
			if not map_jumped and room_frames > 120:
				var G = load("res://game/globals.gd")
				R.aset(G.map_number, 0, force_map)
				G.aktualny_lev = force_lev
				var target: Variant = R.aget2(G.map_levelgo, force_lev, 0)
				print("MAP lev=%s mapno=%s target=%s" % [str(G.aktualny_lev),
					str(R.aget(G.map_number, 0)), str(target)])
				if target != null and int(target) >= 0:
					map_jumped = true
					level_room = int(target)
					R.pending_room = int(target)
	if shot_room >= 0 and R.room == shot_room and room_tick >= 0 \
			and R.tick_count - room_tick == shot_room_tick:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(outdir.path_join("room%d.png" % shot_room))
		print("ROOMSHOT room=%d frame=%d" % [R.room, frames])
		done = true
		quit()
		return true
	if level_room >= 0 and R.room == level_room:
		if level_frame < 0:
			level_frame = frames
			level_tick = R.tick_count
			print("LEVEL enter room=%d scene=%s" % [R.room, str(R.active_scene_path)])
		var t := frames - level_frame
		var tick_t := R.tick_count - level_tick
		if tick_at.size() > 0:
			if tick_t in tick_at:
				var img := root.get_viewport().get_texture().get_image()
				img.save_png(outdir.path_join("k%04d.png" % tick_t))
				var f := FileAccess.open(outdir.path_join("k%04d.state" % tick_t), FileAccess.WRITE)
				var rows := []
				for inst in R.instances:
					rows.append("%d,%d,%d,%d" % [int(inst.g_object_index),
						int(inst.position.x), int(inst.position.y),
						int(inst.image_index) if inst.get("image_index") != null else -1])
				rows.sort()
				f.store_string("\n".join(rows))
				f.close()
				print("SHOT k=%d frame=%d" % [tick_t, frames])
			if tick_t >= tick_at[tick_at.size() - 1]:
				done = true
				quit()
				return true
		elif t in at:
			var img := root.get_viewport().get_texture().get_image()
			img.save_png(outdir.path_join("t%04d.png" % t))
			var by := {}
			for inst in R.instances:
				by[int(inst.g_object_index)] = int(by.get(int(inst.g_object_index), 0)) + 1
			print("SHOT t=%d by=%s" % [t, str(by)])
			if t == at[at.size() - 1]:
				done = true
				quit()
				return true
	if frames >= limit:
		print("TIMEOUT frame=%d room=%d level_frame=%d" % [frames, R.room, level_frame])
		done = true
		quit()
		return true
	return false
