extends Node2D

## Main scene: boots the GameMaker runtime and drives fixed logic ticks at room_speed.

var acc: float = 0.0
var _savedir: String = ""
var _ff_objs: Dictionary = {}
var _fftest: bool = false
var _fftest_frame: int = 0
var _perf: bool = false
var _perf_acc: Dictionary = {}
var _perf_frames: int = 0
var _spawn_spec: Array = []
var _spawn_pending: Array = []


func _ready() -> void:
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--savedir="):
			_savedir = a.substr(10).replace("\\", "/")
			DirAccess.make_dir_recursive_absolute(_savedir)
		elif a.begins_with("--room="):
			R.pending_stage_room = a.substr(7)
		elif a.begins_with("--map="):
			R.pending_stage_map = int(a.substr(6))
		elif a.begins_with("--lev="):
			R.pending_stage_lev = int(a.substr(6))
		elif a == "--fftest":
			_fftest = true
		elif a == "--perf":
			_perf = true
		elif a.begins_with("--maxfps="):
			Engine.max_fps = int(a.substr(9))
		elif a == "--trace":
			R.trace_room_goto = true
		elif a.begins_with("--spawn="):
			var sp := a.substr(8).split(":")
			_spawn_spec.append([int(sp[0]), int(sp[1]) if sp.size() > 1 else 50])
	# Direct room boots (--room) skip the title screen, which is what normally
	# loads key bindings from settings.ini. Seed the shipped defaults so input
	# checks don't see unbound (0) keys, which keyboard_check treats as pressed.
	if R.pending_stage_room != "":
		if G.ster1 == 0: G.ster1 = 38
		if G.ster2 == 0: G.ster2 = 40
		if G.ster3 == 0: G.ster3 = 37
		if G.ster4 == 0: G.ster4 = 39
		if G.ster5 == 0: G.ster5 = 16
		if G.ster6 == 0: G.ster6 = 17
		if G.ster7 == 0: G.ster7 = 90
		if G.ster8 == 0: G.ster8 = 88
		if G.ster9 == 0: G.ster9 = 80
	R.boot(self)


## Object indices that only exist while a cutscene plays (o_anim_*, o_the_end_*).
func _cutscene_objs() -> Dictionary:
	if _ff_objs.is_empty():
		for k in R.objects:
			var s := str(R.objects[k].get("script", ""))
			if s.contains("objects/effects/anim_") or s.contains("objects/ui/ending"):
				_ff_objs[int(k)] = true
	return _ff_objs


## True while FIRE is held during a world-ending/ending cutscene.
func _cutscene_ff() -> bool:
	if int(G.ster5) <= 0 or not R.keyboard_check(null, int(G.ster5)):
		return false
	var objs := _cutscene_objs()
	for inst in R.instances:
		if inst.alive and objs.has(int(inst.g_object_index)):
			return true
	return false


func _process(delta: float) -> void:
	if not R.game_running:
		return
	# Headless validation can redirect saves away from the player's real data.
	if _savedir != "" and R.working_directory != _savedir:
		R.working_directory = _savedir
	if delta > 0.25:
		delta = 0.25
	var ff := _cutscene_ff()
	var step_time: float = 1.0 / maxf(1.0, float(R.room_speed))
	# Steps are cheap (~sub-ms even with hundreds of instances); the expensive
	# part is rendering. Allow catch-up steps proportional to the frame debt so
	# logic keeps real-time speed when the renderer can't hold room_speed,
	# instead of slipping into slow motion. Capped to avoid spiral-of-death.
	var max_steps: int
	if R.room_speed <= 60:
		max_steps = maxi(2, mini(8, int(ceil(delta / step_time)) + 1))
	else:
		max_steps = maxi(2, int(ceil(float(R.room_speed) / 30.0)))
	if ff:
		max_steps = maxi(max_steps, 8)
	acc += delta * (2.0 if ff else 1.0)
	var n := 0
	var t0 := Time.get_ticks_usec()
	while acc >= step_time and n < max_steps:
		R.step()
		acc -= step_time
		n += 1
	R.perf_step_usec = Time.get_ticks_usec() - t0
	if acc > step_time * 8.0:
		acc = 0.0
	if _fftest:
		_fftest_frame += 1
		if _fftest_frame == 120:
			G.ster5 = 32
			R.keys_down[32] = true
		elif _fftest_frame == 240:
			R.keys_down.erase(32)
		elif _fftest_frame % 60 == 0:
			print("FFTEST frame=%d ticks=%d ff=%s room=%d" % [_fftest_frame, R.tick_count, str(ff), R.room])
		if _fftest_frame >= 360:
			get_tree().quit()
	if not _spawn_spec.is_empty() and R.tick_count >= 30 and not R.instances.is_empty():
		var _sctx0 = R.instances[0]
		# Spread creation over several frames so the one-time spawn cost does not
		# poison the fps measurement (and mimics waves arriving gradually).
		_spawn_pending = []
		for spec in _spawn_spec:
			var cols := int(ceil(sqrt(float(spec[1]) * 16.0 / 9.0)))
			var rows := int(ceil(float(spec[1]) / float(cols)))
			for i in spec[1]:
				_spawn_pending.append([spec[0], 60.0 + (i % cols) * (900.0 / max(1, cols - 1)), 60.0 + (i / cols) * (640.0 / max(1, rows - 1))])
		_spawn_spec.clear()
	if not _spawn_pending.is_empty() and not R.instances.is_empty():
		var _sctx = R.instances[0]
		for i in mini(25, _spawn_pending.size()):
			var p: Array = _spawn_pending[0]
			_spawn_pending.remove_at(0)
			R.instance_create(_sctx, p[1], p[2], p[0])
	if _perf:
		_perf_frames += 1
		var vals := [R.perf_step_usec, R.perf_begin_usec, R.perf_keys_usec, R.perf_logic_usec, R.perf_motion_usec, R.perf_anim_usec, R.perf_end_usec, R.perf_drawlogic_usec, R.perf_vis_usec, R.perf_views_usec, R.perf_draw_usec]
		var names := ["step", "begin", "keys", "logic", "motion", "anim", "end", "drawlg", "vis", "views", "draw"]
		for i in names.size():
			_perf_acc[names[i]] = _perf_acc.get(names[i], 0) + vals[i]
		_perf_acc["cmds"] = _perf_acc.get("cmds", 0) + R.draw_cmd_count
		R.draw_cmd_count = 0
		R.perf_draw_usec = 0
		if _perf_frames % 60 == 0:
			var parts: Array = []
			for k in names:
				parts.append("%s=%.0f" % [k, float(_perf_acc[k]) / _perf_frames])
			parts.append("cmds=%.0f" % (float(_perf_acc["cmds"]) / _perf_frames))
			print("PERF inst=%d ticks=%d fps=%.0f " % [R.instances.size(), R.tick_count, Engine.get_frames_per_second()] + " ".join(parts))
			for inst in R.instances:
				if int(inst.g_object_index) == 532:
					print("  CTRL ptime=%.1f end=%s etap=%s sched=%s pauza=%s" % [
						float(inst.get("g_periodtime")), str(inst.get("g_end_level")),
						str(inst.get("g_etap")),
						str(R.aget2(inst.g_perioder, int(inst.get("g_etap")), int(inst.get("g_periodtime")))),
						str(G.pauza)])
			_perf_acc.clear()


func _input(event: InputEvent) -> void:
	R.handle_input(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		R.game_end(null)
