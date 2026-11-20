extends Node2D

## Main scene: boots the GameMaker runtime and drives fixed logic ticks at room_speed.

var acc: float = 0.0
var _savedir: String = ""


func _ready() -> void:
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--savedir="):
			_savedir = a.substr(10).replace("\\", "/")
			DirAccess.make_dir_recursive_absolute(_savedir)
	# Boot the runtime - it will check pending_stage_room internally
	R.boot(self)
	# If a stage room was requested, load it after boot
	# R.boot does NOT clear pending_stage_room, so we check it here
	if R.pending_stage_room != "":
		var room_name := R.pending_stage_room
		R.pending_stage_room = ""
		_load_stage_room.call_deferred(room_name)


func _load_stage_room(room_name: String) -> void:
	# Load rooms.json to find the room index by name
	var rooms_text: String = FileAccess.get_file_as_string("res://game/rooms.json")
	var rooms_data: Dictionary = JSON.parse_string(rooms_text) as Dictionary
	if rooms_data.is_empty():
		print("StageLaunch: failed to load rooms.json")
		return
	var rooms: Dictionary = rooms_data.get("rooms", {})
	for idx in rooms.keys():
		var room: Dictionary = rooms[idx]
		if room.get("name", "") == room_name:
			R.room_order.clear()
			R.room_order.append(int(idx))
			R._load_room(int(idx))
			break


func _process(delta: float) -> void:
	if not R.game_running:
		return
	# Headless validation can redirect saves away from the player's real data.
	if _savedir != "" and R.working_directory != _savedir:
		R.working_directory = _savedir
	if delta > 0.25:
		delta = 0.25
	var step_time: float = 1.0 / maxf(1.0, float(R.room_speed))
	# Normal rooms advance a single step per frame, like GM8 does when it cannot
	# keep up. Only the 1000 Hz system rooms need real catch-up, otherwise a slow
	# frame would replay several expensive steps and make the slowdown compound.
	var max_steps: int = 1 if R.room_speed <= 60 else maxi(2, int(ceil(float(R.room_speed) / 30.0)))
	acc += delta
	var n := 0
	var t0 := Time.get_ticks_usec()
	while acc >= step_time and n < max_steps:
		R.step()
		acc -= step_time
		n += 1
	R.perf_step_usec = Time.get_ticks_usec() - t0
	# One rendered draw covers one step; only high-speed rooms need the rest.
	if n > 1 and R.room_speed > 60:
		R.draw_state_passes(n - 1)
	if acc > step_time * 4.0:
		acc = 0.0


func _input(event: InputEvent) -> void:
	R.handle_input(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		R.game_end(null)
