extends SceneTree

## Headless flow tour: intro -> title -> save select -> hero -> map -> first level.
## Saves stay inside --savedir; the shipped skipper/settings are seeded there by boot.

const ENTER := 13
const RIGHT := 39
const FIRE := 16

var frames: int = 0
var savedir: String = ""
var limit: int = 20000
var last_room: int = -1
var room_frames: int = 0
var hold_key: int = 0
var hold_left: int = 0
var cool: int = 0
var intro_skipped: bool = false
var map_jumped: bool = false
var level_reported: bool = false
var level_x0: float = 0.0
var done: bool = false

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
			DirAccess.make_dir_recursive_absolute(savedir)
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
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

func _holds_key(key: int) -> bool:
	return hold_left > 0 and hold_key == key

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
	if R.room == 59 and room_frames > 4 and not intro_skipped:
		intro_skipped = true
		print("SKIP intro animations -> title")
		R.pending_room = 51
		return false
	match R.room:
		51, 48, 49:
			_tap(ENTER)
		14, 4, 19, 22, 26, 30, 35, 43:
			if not map_jumped and room_frames > 120:
				var G = load("res://gen/globals.gd")
				# The map screen only sets global.aktualny_lev when the cursor touches a
				# level node; jumping straight to map_levelgo[0] left it 0, which has no
				# perioder config and instantly "completed" the empty level.
				var gve: Variant = null
				for inst in R.instances:
					if int(inst.g_object_index) == 220:
						var v: Variant = R.inst_get(inst.g_id, "map_gve")
						# Level 2 is configured on every map, so it always spawns content.
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
				for inst in R.instances:
					if int(inst.g_object_index) == 0:
						level_x0 = inst.position.x
				print("LEVEL start x=%.1f inst=%d" % [level_x0, R.instances.size()])
			if room_frames > 60:
				R.keyboard_key_press(null, RIGHT)
				if room_frames % 10 == 0:
					_tap(FIRE)
			if room_frames % 120 == 0:
				var G = load("res://gen/globals.gd")
				for inst in R.instances:
					if int(inst.g_object_index) == 0:
						print("LEVEL x=%.1f y=%.1f frame=%d energia=%s zycia=%s inst=%d" % [
							inst.position.x, inst.position.y, frames, str(G.energia),
							str(G.zycia), R.instances.size()])
	if frames % 300 == 0:
		print("STATE frame=%d room=%d inst=%d rf=%d" % [frames, R.room,
			R.instances.size(), room_frames])
	if frames >= limit:
		print("DONE frame=%d room=%d" % [frames, R.room])
		print("WARNINGS " + JSON.stringify(R.warnings))
		done = true
		quit()
		return true
	return false
