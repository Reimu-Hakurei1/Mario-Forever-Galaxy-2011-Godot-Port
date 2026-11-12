extends SceneTree

## Scratch: windowed playthrough that screenshots each milestone into --outdir.

const ENTER := 13

var frames: int = 0
var savedir: String = ""
var outdir: String = ""
var limit: int = 12000
var last_room: int = -1
var room_frames: int = 0
var hold_left: int = 0
var hold_key: int = 0
var cool: int = 0
var intro_shot: bool = false
var map_jumped: bool = false
var shots: Dictionary = {}
var paused_once: int = 0
var done: bool = false
var story_seen: bool = false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
		elif a.begins_with("--outdir="):
			outdir = a.substr(9).replace("\\", "/")
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
	root.add_child(load("res://scenes/game.tscn").instantiate())


func _shot(tag: String) -> void:
	if shots.has(tag):
		return
	shots[tag] = true
	var img := root.get_texture().get_image()
	var p := "%s/%02d_%s.png" % [outdir, shots.size(), tag]
	img.save_png(p)
	print("SHOT %s room=%d frame=%d" % [p, R.room, frames])


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
	Engine.max_fps = 0
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
	if not R.game_running:
		return false
	if R.room != last_room:
		last_room = R.room
		room_frames = 0
		print("ROOM %d frame=%d" % [R.room, frames])
	var G = load("res://gen/globals.gd")
	match R.room:
		52, 53, 54, 55:
			story_seen = true
			if room_frames % 300 == 30:
				shots.erase("story")
				var img := root.get_texture().get_image()
				var p := "%s/story_r%d_f%05d.png" % [outdir, R.room, room_frames]
				img.save_png(p)
				print("SHOT %s" % p)
				print("STATE view=%s bg=%s" % [str([R.view_xview[0], R.view_yview[0], R.view_wview[0], R.view_hview[0]]), str(R.bg_visible)])
				for inst in R.instances:
					if int(inst.g_object_index) in [547, 549, 560]:
						print("OBJ %d pos=%s seq=%s depth=%s" % [inst.g_object_index, str(inst.position), str(inst.g_sekwencja), str(inst.g_depth)])
		59:
			if room_frames % 30 == 0:
				var img := root.get_texture().get_image()
				img.save_png("%s/intro_f%05d.png" % [outdir, room_frames])
		51:
			if story_seen and room_frames == 30:
				_shot("story_end_title")
				_finish()
			if room_frames == 120:
				_shot("title")
			if room_frames > 130:
				_tap(ENTER)
		48, 49:
			if room_frames == 60:
				_shot("menu_%d" % R.room)
			if room_frames > 70:
				_tap(ENTER)
		14, 4, 19, 22, 26, 30, 35, 43:
			if room_frames == 100:
				_shot("map_%d" % R.room if not map_jumped else "map_return")
			if not map_jumped and room_frames > 120:
				for inst in R.instances:
					if int(inst.g_object_index) == 220:
						var v: Variant = R.inst_get(inst.g_id, "map_gve")
						if v != null and int(v) == 2:
							G.aktualny_lev = 2
				var target: Variant = R.aget2(G.map_levelgo, R.aget(G.map_zmien_etap, 0), 0)
				if target != null and int(target) >= 0:
					map_jumped = true
					R.pending_room = int(target)
			if map_jumped and room_frames > 160:
				_finish()
		2:
			_drive_level(G)
	if frames >= limit:
		_finish()
	return false


func _drive_level(G) -> void:
	if room_frames == 150:
		_shot("level_start")
	var dirs := [int(G.ster1), int(G.ster2), int(G.ster3), int(G.ster4)]
	for d in dirs:
		R.keyboard_key_release(null, d)
	R.keyboard_key_release(null, int(G.ster5))
	R.keyboard_key_release(null, int(G.ster9))
	var seq: int = -1
	for t in R.instances:
		if int(t.g_object_index) == 306:
			seq = int(R.aget(t.g_sekwencja, 0))
	if int(G.help) != 0:
		if not shots.has("tutorial_prompt_%d" % int(G.help)) and shots.size() < 30:
			if room_frames % 200 == 0 or int(G.pauza) == 100:
				_shot("tutorial_prompt_%d" % int(G.help))
		if room_frames % 4 < 2:
			R.keyboard_key_press(null, int(G.ster5))
		return
	if seq == 1:
		R.keyboard_key_press(null, dirs[(room_frames / 30) % 4])
		return
	if seq == 3:
		R.keyboard_key_press(null, int(G.ster5))
		return
	var px: float = 0.0
	for p in R.instances:
		if int(p.g_object_index) == 0:
			px = p.position.x
	var tx: float = px
	var bd: float = 1e9
	var n12 := 0
	for e in R.instances:
		if int(e.g_object_index) == 12:
			n12 += 1
			if e.position.y > 0 and e.position.x > 0 and e.position.x < 1024 and absf(e.position.x - px) < bd:
				bd = absf(e.position.x - px)
				tx = e.position.x
	if n12 >= 8:
		_shot("wave_fight")
		if paused_once == 0:
			paused_once = room_frames
	if paused_once > 0 and room_frames - paused_once in [40, 41]:
		R.keyboard_key_press(null, int(G.ster9))
	if paused_once > 0 and room_frames - paused_once == 90:
		_shot("pause")
	if paused_once > 0 and room_frames - paused_once in [130, 131]:
		R.keyboard_key_press(null, int(G.ster9))
	if int(R.get_obj_var(532, "g_end_level")) == 1:
		if not shots.has("level_completed_a"):
			_shot("level_completed_a")
			paused_once = -1000000
		elif room_frames % 120 == 0:
			_shot("level_completed_b")
	if tx < px - 12:
		R.keyboard_key_press(null, dirs[2])
	elif tx > px + 12:
		R.keyboard_key_press(null, dirs[3])
	if room_frames % 6 < 3:
		R.keyboard_key_press(null, int(G.ster5))


func _finish() -> void:
	print("DONE frame=%d room=%d shots=%d" % [frames, R.room, shots.size()])
	print("WARNINGS " + JSON.stringify(R.warnings))
	done = true
	quit()
