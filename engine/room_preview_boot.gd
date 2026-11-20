extends Node2D

## Attached to every generated room scene. In the editor the scene stays a static
## preview; when it is run directly (F6 / --path <scene>) this boots the GameMaker
## runtime and jumps into the room the scene was generated from, once the normal
## boot/loading sequence has initialised the game globals.

var _target: int = -1
var _jumped: bool = false
var _acc: float = 0.0
var _savedir: String = ""
var _map: int = 0
var _lev: int = 2
var _minigame: int = 0
var _label: String = ""
var _has_map: bool = false
var _is_map_room: bool = false
var _map_click: bool = false


func _ready() -> void:
	# Only boot when this scene is the one that was launched. The viewer/play
	# tools instantiate room scenes as children, and editors preview statically.
	if Engine.is_editor_hint() or get_parent() != get_tree().root:
		return
	# Individual scenes launched directly (F6) also render at a steady 60 fps.
	Engine.max_fps = 60
	# Headless validation can redirect saves away from the player's real data.
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--savedir="):
			_savedir = a.substr(10).replace("\\", "/")
			DirAccess.make_dir_recursive_absolute(_savedir)
	var room_name: String = str(get_meta("gm_room", ""))
	_has_map = has_meta("gm_map")
	_is_map_room = room_name.begins_with("room_map") and not room_name.begins_with("room_map_indicator")
	var map_suffix := room_name.trim_prefix("room_map").trim_prefix("_indicator")
	_map = int(get_meta("gm_map", maxi(0, int(map_suffix) - 1)))
	_lev = int(get_meta("gm_lev", 2))
	_minigame = int(get_meta("gm_minigame", 0))
	_label = str(get_meta("gm_label", ""))
	R.scene_launch_path = scene_file_path.replace("\\", "/")
	R.scene_launch_key = R._scene_key(room_name, _map, _lev)
	# The preview nodes are plain sprite copies of the room; drop them so the
	# runtime's own renderer is the only thing drawing.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	R.boot(self)
	if _savedir != "":
		R.working_directory = _savedir
	_target = _find_room(room_name)
	print("ROOM_SCENE boot room='%s' target=%d map=%d lev=%d minigame=%d label='%s'" % [
		room_name, _target, _map, _lev, _minigame, _label])
	# Galaxy boots straight into room 0 (starter) and its creation code runs
	# script_init_game synchronously, so the globals are ready by now. There is
	# no room 1 to wait for; go to the requested room on the next step.
	_jump_to_target()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or R.root != self or not R.game_running:
		return
	if _savedir != "" and R.working_directory != _savedir:
		R.working_directory = _savedir
	if delta > 0.25:
		delta = 0.25
	var step_time: float = 1.0 / maxf(1.0, float(R.room_speed))
	# Same pacing policy as the full game: catch-up steps proportional to frame
	# debt so logic keeps real time when the renderer cannot hold room_speed.
	var max_steps: int
	if R.room_speed <= 60:
		max_steps = maxi(2, mini(8, int(ceil(delta / step_time)) + 1))
	else:
		max_steps = maxi(2, int(ceil(float(R.room_speed) / 30.0)))
	_acc += delta
	var n: int = 0
	while _acc >= step_time and n < max_steps:
		R.step()
		_acc -= step_time
		n += 1
		_jump_to_target()
		_navigate_map()
	if _acc > step_time * 8.0:
		_acc = 0.0


func _input(event: InputEvent) -> void:
	if R.root == self:
		R.handle_input(event)
		if _is_map_room and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_map_click = true


func _jump_to_target() -> void:
	# Room 0 already ran script_init_game inside R.boot, so lives/player/map
	# globals exist. Jump straight into the scene's room.
	if _jumped or _target < 0 or R.room == _target:
		_jumped = true
		return
	_jumped = true
	# Level rooms are shared: obj532 (o_przeciwnikor) builds the wave timeline from
	# map_number/aktualny_lev in its create event. Minigame rooms read the same globals
	# for their difficulty/reward tables. Plain room scenes (world maps, story) are
	# restored by their own room creation code, so leave the globals untouched there.
	var G = load("res://game/globals.gd")
	# Tagged scenes (generated levels and map rooms) carry their own map index;
	# the legacy shared level scene falls back to map 1 / FIRST_ENCONTER.
	if _has_map or _is_map_room or _target == 2:
		R.aset(G.map_number, 0, _map)
		G.aktualny_lev = _lev
	if _target == 2 or _minigame != 0:
		R.aset(G.map_zmien_etap, 0, 0)
	if _minigame == 10:
		G.nastaw_trening_zone = 1
	var entry_room := _target
	if _is_map_room:
		var suffix := "" if _map == 0 else str(_map + 1)
		entry_room = _find_room("room_map_indicator" + suffix)
	R.room_goto(self, entry_room)
	print("ROOM_SCENE jump target=%d name='%s' map=%d lev=%d" % [
		_target, R.room_get_name(self, _target), _map, _lev])


func _navigate_map() -> void:
	if not _map_click:
		return
	_map_click = false
	if not _is_map_room or R.room != _target:
		return
	var interfaces := R.with_ids(self, 225)
	if interfaces.is_empty():
		return
	var ui: GMInstance = interfaces[0]
	var cursor: GMInstance = R._as_inst(ui.g_cursor)
	var G = load("res://game/globals.gd")
	if cursor == null or ui.g_miedzyetap_size > 0.1 or ui.g_zoom_oglada_block != 0 or ui.g_wybor_etapu_block != 0 or cursor.g_loot != 0 or R.aget(G.map_zmien_etap, 0) != 0:
		return
	var px := float(R.mouse_x(self))
	var py := float(R.mouse_y(self))
	for control in [229, 230, 231, 232, 233, 235]:
		if R.place_meeting(cursor, px, py, control):
			return
	var target: Variant = R.instance_place(cursor, px, py, 220)
	if not target is GMInstance:
		return
	var node := int(target.g_map_gve)
	var gfx := int(R.aget(G.map_gfxlev, node))
	if gfx >= 100 or gfx == 89:
		return
	ui.g_kliknieto = 1
	if G.aktualny_lev == node:
		cursor.g_engagor = maxf(0.1, float(cursor.g_engagor))
		ui.g_wybor_etapu_block = 1
	else:
		G.map_backdoor_lev = G.aktualny_lev
		G.aktualny_lev = node
		cursor.g_loot = 1
		ui.g_nastaw_scroll = 0


func _find_room(room_name: String) -> int:
	if room_name.is_empty():
		return -1
	var rooms: Dictionary = R.room_data.get("rooms", {})
	for key: Variant in rooms:
		if str(rooms[key].get("name", "")) == room_name:
			return int(key)
	return -1
