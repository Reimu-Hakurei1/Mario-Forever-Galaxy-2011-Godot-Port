extends SceneTree
var R = load("res://engine/r.gd")

## Headless flow tour with audio logging: intro -> title -> save -> hero -> map -> level.
##   godot --headless --path . -s tools/audio_tour.gd -- --savedir=<iso> --frames=6000

const ENTER := 13
const RIGHT := 39
const FIRE := 16

var frames: int = 0
var savedir: String = "C:/Users/Alex/gm8tools/galaxy_port/_test_saves/audio_tour"
var limit: int = 6000
var last_room: int = -1
var room_frames: int = 0
var hold_key: int = 0
var hold_left: int = 0
var cool: int = 0
var intro_skipped: bool = false
var map_jumped: bool = false
var level_reported: bool = false
var done: bool = false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
	DirAccess.make_dir_recursive_absolute(savedir)
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	R.trace_room_goto = true


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
	R.debug_audio = true
	if R.room == 59 and room_frames > 4 and not intro_skipped:
		intro_skipped = true
		print("SKIP intro animations -> title")
		R.pending_room = 51
	match R.room:
		51, 48, 49:
			_tap(ENTER)
		14, 4, 19, 22, 26, 30, 35, 43:
			if not map_jumped and room_frames > 120:
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
				print("MAP lev=%d mapno=%d levelgo=%s -> room %s" % [G.aktualny_lev,
					R.aget(G.map_number, 0), str(G.map_levelgo), str(target)])
				if target != null and int(target) >= 0:
					map_jumped = true
					R.pending_room = int(target)
		2:
			if not level_reported:
				level_reported = true
				print("LEVEL start inst=%d" % R.instances.size())
			if room_frames > 60:
				R.keyboard_key_press(null, RIGHT)
				if room_frames % 10 == 0:
					_tap(FIRE)
	if frames % 60 == 0:
		var mp: AudioStreamPlayer = R.music_player
		var wp: AudioStreamPlayer = R.wap_player
		print("AUDIO frame=%d room=%d c=%s(%.2f,%s) wap=%s(%.2f,%s) sfx=%d" % [
			frames, R.room,
			str(mp.stream.resource_path) if mp and mp.stream else "-",
			mp.get_playback_position() if mp else -1.0, mp.playing if mp else false,
			str(wp.stream.resource_path) if wp and wp.stream else "-",
			wp.get_playback_position() if wp else -1.0, wp.playing if wp else false,
			_active_sfx()])
	if frames >= limit:
		print("DONE frame=%d room=%d" % [frames, R.room])
		done = true
		quit()
		return true
	return false


func _active_sfx() -> int:
	var n := 0
	for p in R.sfx_players:
		if p.playing:
			n += 1
	return n
