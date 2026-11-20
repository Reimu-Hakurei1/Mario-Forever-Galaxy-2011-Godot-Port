extends SceneTree
var R = load("res://engine/r.gd")

const FIRST := "res://stages/world_1/level_02_first_enconter.tscn"
var mode: String = "full"
var savedir: String = ""
var copy_path: String = ""
var output: String = ""
var frames: int = 0
var failures: int = 0
var ready_to_check: bool = false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			mode = argument.substr(7)
		elif argument.begins_with("--savedir="):
			savedir = argument.substr(10).replace("\\", "/")
		elif argument.begins_with("--out="):
			output = argument.substr(6)
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("SCENE_RUNTIME_CHECK " + label)


func _run() -> void:
	if savedir.is_empty() or mode not in ["full", "direct"]:
		push_error("An isolated --savedir and --mode=full|direct are required")
		quit(2)
		return
	copy_path = savedir.path_join("scene_runtime_check_%s.tscn" % mode)
	var source: Node2D = load(FIRST).instantiate()
	source.get_node("Objects_0/o_player_a_0").position += Vector2(37, -19)
	source.get_node("Objects_0").position = Vector2(8, 13)
	var assets: Dictionary = R._json("res://data/assets.json")
	source.get_node("Bg0_background0").get_child(0).texture = load(assets.backgrounds["2"].frames[0])
	var packed := PackedScene.new()
	_check(packed.pack(source) == OK, "pack test copy")
	_check(ResourceSaver.save(packed, copy_path) == OK, "save test copy")
	source.free()
	R.mouse_override = Vector2(512, 650)
	var game: Node = load(copy_path if mode == "direct" else "res://scenes/game.tscn").instantiate()
	root.add_child(game)
	if mode == "full":
		var globals: GDScript = load("res://game/globals.gd")
		R.aset(globals.map_number, 0, 0)
		globals.aktualny_lev = 2
		R.aset(globals.map_zmien_etap, 0, 0)
		R._level_scene_index[R._scene_key("level_0000", 0, 2)] = copy_path
		R.pending_room = 2
	ready_to_check = true


func _process(_delta: float) -> bool:
	if not ready_to_check:
		return false
	frames += 1
	if frames >= 90:
		_check(R.room == 2, "entered First Encounter")
		_check(R.active_scene_path == copy_path, "runtime selected the saved copy")
		var players: Array = R.with_ids(null, 0)
		_check(players.size() == 1, "one player, no preview duplicates")
		if players.size() == 1:
			_check(Vector2(players[0].g_xstart, players[0].g_ystart) == Vector2(461, 570), "runtime player starts at edited scene position")
		var rendered: Image = R._scene_background_texture(0).get_image()
		var expected: Image = (load(R.assets.backgrounds["2"].frames[0]) as Texture2D).get_image()
		rendered.convert(Image.FORMAT_RGBA8)
		expected.convert(Image.FORMAT_RGBA8)
		_check(rendered.get_size() == expected.get_size() and rendered.get_data() == expected.get_data(), "runtime renders the replacement background pixels")
		_check(R.with_ids(null, 532).size() == 1, "original wave controller is preserved")
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			var shot: Image = root.get_texture().get_image()
			if shot != null:
				shot.save_png(output)
		print("SCENE_RUNTIME_CHECK mode=%s frames=%d failures=%d scene=%s" % [mode, frames, failures, R.active_scene_path])
		DirAccess.remove_absolute(copy_path)
		quit(1 if failures else 0)
		return true
	return false
