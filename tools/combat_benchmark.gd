extends SceneTree
var R = load("res://engine/r.gd")

var game: Node
var frame := 0
var count := 120
var savedir := ""
var output := ""
var started := false
var samples: Array = []
var steps: Array = []
var last_time := 0
var spawn_ms := 0.0
var events_enabled := true
var enemy_kind := 0
var finish_frame := 421


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--savedir="):
			savedir = arg.substr(10).replace("\\", "/")
		elif arg.begins_with("--count="):
			count = int(arg.substr(8))
		elif arg.begins_with("--out="):
			output = arg.substr(6)
		elif arg.begins_with("--kind="):
			enemy_kind = int(arg.substr(7))
		elif arg == "--no-event-profile":
			events_enabled = false
		elif arg.begins_with("--frames="):
			finish_frame = int(arg.substr(9))
	if savedir.is_empty() or not OS.get_environment("APPDATA").replace("\\", "/").contains("isolated"):
		quit(2)
		return
	call_deferred("_boot")


func _boot() -> void:
	game = load("res://stages/world_1/level_02_first_enconter.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	R.working_directory = savedir
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	AudioServer.set_bus_mute(0, true)


func _process(_delta: float) -> bool:
	if game == null:
		return false
	R.working_directory = savedir
	if not started:
		R.step()
		if R.room == 2:
			_setup()
		return false
	var now := Time.get_ticks_usec()
	if frame > 60:
		samples.append(float(now - last_time) / 1000.0)
	last_time = now
	var globals = load("res://game/globals.gd")
	globals.pauza = 0
	globals.energia = 1000000
	var t := Time.get_ticks_usec()
	R.step()
	steps.append(float(Time.get_ticks_usec() - t) / 1000.0)
	frame += 1
	if frame == 61:
		R.profile_event_usec.clear()
		R.profile_event_calls.clear()
	if frame % 120 == 0:
		print("BENCH_PROGRESS frame=%d enemies=%d instances=%d" % [frame, R.instance_number(null, 12), R.instances.size()])
	if frame % 30 == 0:
		print("STEP us=%d drawlg=%d logic=%d motion=%d end=%d vis=%d views=%d draw=%d cmds=%d" % [
			R.perf_step_usec, R.perf_drawlogic_usec, R.perf_logic_usec, R.perf_motion_usec,
			R.perf_end_usec, R.perf_vis_usec, R.perf_views_usec, R.perf_draw_usec, R.draw_cmd_count])
	if frame == finish_frame:
		_finish.call_deferred()
		game = null
	return false


func _setup() -> void:
	var globals = load("res://game/globals.gd")
	globals.pauza = 0
	globals.help = 0
	seed(12345)
	for controller in R.with_ids(null, 532):
		controller.g_periodtime = 0
		controller.has_step = false
	for tutorial in R.with_ids(null, 306).duplicate():
		R.instance_destroy(tutorial)
	var t := Time.get_ticks_usec()
	for i in count:
		var id: int = R.instance_create(null, 45 + (i % 15) * 54, 40 + (i / 15) * 32, 12)
		var inst = R._as_inst(id)
		inst.g_rodzaj = enemy_kind
		R.aset(inst.g_sekwencja, 0, 2)
		R.aset(inst.g_pozycja, 0, i % 30)
		inst.g_dox = inst.position.x
		inst.g_doy = inst.position.y
	spawn_ms = float(Time.get_ticks_usec() - t) / 1000.0
	R.profile_events = events_enabled
	started = true
	last_time = Time.get_ticks_usec()


func _finish() -> void:
	await RenderingServer.frame_post_draw
	var events: Array = []
	for key in R.profile_event_usec:
		events.append({"object": int(key) / 100000, "event": int(key) % 100000, "ms": float(R.profile_event_usec[key]) / 1000.0, "calls": R.profile_event_calls[key]})
	events.sort_custom(func(a, b): return a.ms > b.ms)
	samples.sort()
	steps.sort()
	var result := {"count": count, "kind": enemy_kind, "remaining_enemies": R.instance_number(null, 12), "frames": samples.size(), "median_ms": samples[samples.size() / 2], "p95_ms": samples[int(samples.size() * 0.95)], "step_median_ms": steps[steps.size() / 2], "spawn_ms": spawn_ms, "events": events.slice(0, 12)}
	print("COMBAT_BENCHMARK " + JSON.stringify(result))
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
		root.get_texture().get_image().save_png(output.get_basename() + ".png")
	quit()
