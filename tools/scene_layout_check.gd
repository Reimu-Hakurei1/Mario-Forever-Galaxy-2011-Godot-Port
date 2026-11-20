extends SceneTree
var R = load("res://engine/r.gd")

const FIRST := "res://stages/world_1/level_02_first_enconter.tscn"
const SHARED := "res://stages/level_0000.tscn"
var failures: int = 0
var checks: int = 0
var copy_path: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SCENE_LAYOUT_CHECK " + label)


func _save_copy(node: Node) -> void:
	var packed := PackedScene.new()
	_check(packed.pack(node) == OK, "pack edited scene")
	_check(ResourceSaver.save(packed, copy_path) == OK, "save edited scene")
	ResourceLoader.load(copy_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--savedir="):
			copy_path = argument.substr(10).path_join("scene_layout_check.tscn")
	if copy_path.is_empty():
		push_error("An isolated --savedir is required")
		quit(2)
		return
	R.assets = R._json("res://data/assets.json")
	R.registry = R._json("res://game/registry.json")
	R.room_data = R._json("res://game/rooms.json")
	for object in R.registry.objects:
		R.objects[int(object.i)] = object
	R._init_sprites()
	var globals: GDScript = load("res://game/globals.gd")
	R.aset(globals.map_number, 0, 0)
	globals.aktualny_lev = 2
	var meta: Dictionary = R.room_data.rooms["2"]
	var original: Dictionary = meta.duplicate(true)
	var baseline: Dictionary = R._scene_layout(2, meta)
	_check(R.active_scene_path == FIRST, "F5 selects First Encounter rather than shared template")
	_check(R._level_scene_index.size() == 182, "all 182 map-specific scenes indexed")
	for key: String in R._level_scene_index:
		var parts: PackedStringArray = key.split(":")
		R.aset(globals.map_number, 0, int(parts[1]))
		globals.aktualny_lev = int(parts[2])
		_check(R._scene_path({"name": parts[0]}) == R._level_scene_index[key], "F5 identity " + key)
	R.aset(globals.map_number, 0, 0)
	globals.aktualny_lev = 2
	var identity: String = R._scene_key("level_0000", 0, 2)
	R.scene_launch_key = identity
	R.scene_launch_path = SHARED
	_check(R._scene_path(meta) == SHARED, "F6 shared scene uses the actual launched file")
	globals.aktualny_lev = 3
	_check(R._scene_path(meta).ends_with("level_03_gombas_camp.tscn"), "F6 override does not leak into next level")
	globals.aktualny_lev = 2
	R.scene_launch_path = ""
	_check(R._scene_path({"name": "title"}) == "res://stages/title.tscn", "generic rooms keep their layout")
	var node: Node2D = load(FIRST).instantiate()
	var player: Sprite2D = node.get_node("Objects_0/o_player_a_0")
	var group: Node2D = player.get_parent()
	player.position += Vector2(37, -19)
	group.position = Vector2(8, 13)
	var background: Node2D = node.get_node("Bg0_background0")
	background.position = Vector2(23, 17)
	background.set_meta("gm_hspeed", 0.75)
	var replacement: Texture2D = load(R.backgrounds[2].paths[0])
	background.get_child(0).texture = replacement
	_save_copy(node)
	R._level_scene_index[identity] = copy_path
	var full: Dictionary = R._scene_layout(2, meta)
	_check(full.instances.size() == baseline.instances.size(), "preview-only sprites never become duplicate gameplay objects")
	_check(Vector2(full.instances[0][0], full.instances[0][1]) == Vector2(baseline.instances[0][0], baseline.instances[0][1]) + Vector2(45, -6), "saved sprite and parent movement reaches F5 layout")
	_check(full.backgrounds[0].source_bg == 2, "saved background texture reaches F5 layout")
	_check(full.backgrounds[0].hspeed == 0.75, "saved background speed reaches F5 layout")
	_check(Vector2(full.backgrounds[0].xoffset, full.backgrounds[0].yoffset) == Vector2(baseline.backgrounds[0].xoffset, baseline.backgrounds[0].yoffset) + Vector2(23, 17), "saved background parent movement reaches F5 layout")
	R.scene_launch_path = copy_path
	R.scene_launch_key = identity
	var direct: Dictionary = R._scene_layout(2, meta)
	_check(full == direct, "F5 and F6 consume identical edited layouts")
	R.scene_backgrounds = full.scene_backgrounds
	R.room = 2
	R.bg_index[0] = 0
	R.bg_index[4] = 0
	_check(R._scene_background_texture(0) == replacement, "scripted background reset keeps edited artwork")
	_check(R._scene_background_texture(4) == replacement, "crossfade layer keeps edited artwork")
	R.bg_index[0] = 44
	_check(R._scene_background_texture(0) == R._bg_texture(44), "later stage background changes are preserved")
	var custom := GradientTexture2D.new()
	custom.gradient = Gradient.new()
	background.get_child(0).texture = custom
	_save_copy(node)
	var custom_layout: Dictionary = R._scene_layout(2, meta)
	R.scene_backgrounds = custom_layout.scene_backgrounds
	R.bg_index[0] = 0
	_check(R._scene_background_texture(0) is GradientTexture2D, "custom scene textures do not require a GameMaker asset ID")
	R.scene_backgrounds = baseline.scene_backgrounds
	_check(R._scene_background_texture(0) == R._bg_texture(0), "untouched scenes retain original background artwork")
	var duplicate: Sprite2D = player.duplicate()
	group.add_child(duplicate)
	duplicate.owner = node
	duplicate.position += Vector2(100, 0)
	_save_copy(node)
	var duplicated: Dictionary = R._scene_layout(2, meta)
	_check(duplicated.instances.size() == baseline.instances.size() + 1, "duplicated placed object is included")
	_check(duplicated.instances[0][3] != duplicated.instances[1][3], "duplicated object receives an independent instance ID")
	group.hide()
	background.hide()
	_save_copy(node)
	var hidden: Dictionary = R._scene_layout(2, meta)
	_check(hidden.instances.is_empty(), "hidden object group is not spawned")
	_check(hidden.backgrounds[0].visible == 0, "hidden background is disabled")
	node.free()
	R.scene_launch_path = ""
	R._level_scene_index[identity] = FIRST
	_check(meta == original, "source room data remains unchanged")
	DirAccess.remove_absolute(copy_path)
	print("SCENE_LAYOUT_CHECK checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
