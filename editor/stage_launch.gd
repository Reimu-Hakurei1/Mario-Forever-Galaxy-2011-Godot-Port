extends Node

## Attached to every stages/*.tscn scene. Those scenes are static editor
## layouts of the original GameMaker rooms — when one is played (F6 / run
## scene) this script hands off to the matching native Godot scene so the
## level actually runs. In the editor it does nothing.

const ARENA := "res://native/levels/arena.tscn"
const CASTLE := "res://native/levels/castle.tscn"
const STAR_MAP := "res://native/levels/star_map.tscn"
const TITLE := "res://native/ui/title.tscn"
const INTRO := "res://native/ui/intro.tscn"
const HERO_SELECT := "res://native/ui/hero_select.tscn"
const SHOP := "res://native/ui/shop.tscn"
const CARD_GAME := "res://native/ui/card_game.tscn"
const ENDING := "res://native/ui/ending.tscn"
const CUTSCENE := "res://native/ui/cutscene.gd"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Defer — change_scene_to_file can't run while _ready is still
	# adding this scene's children.
	_launch.call_deferred()


func _launch() -> void:
	# Stage scenes carry their original room coords as metadata —
	# gm_map/gm_lev are the authoritative world/node indices.
	var gm_map := int(get_meta("gm_map", -1))
	var gm_lev := int(get_meta("gm_lev", -1))
	if gm_map >= 0 and gm_lev >= 0:
		_launch_level(gm_map, gm_lev)
		return
	var path := scene_file_path
	var world := -1
	var level := -1
	for part in path.split("/"):
		if part.begins_with("world_"):
			world = part.trim_prefix("world_").to_int() - 1
		elif part.begins_with("level_"):
			var digits := ""
			for ch in part.trim_prefix("level_"):
				if ch.is_valid_int():
					digits += ch
				else:
					break
			if digits != "":
				level = digits.to_int()
	if world >= 0 and level >= 0:
		_launch_level(world, level)
		return
	_launch_named(path.get_file())


## stages/world_N/level_MM_name.tscn -> native key "(N-1):MM".
func _launch_level(world: int, level: int) -> void:
	var key := "%d:%d" % [world, level]
	var cfg: Dictionary = NativeLevelTable.config_for_key(key)
	if cfg.is_empty():
		# Waypoint / non-playable node — no authored stage behind it.
		get_tree().change_scene_to_file(STAR_MAP)
		return
	var rank := NativeLevelTable.node_rank(key)
	if rank >= 0:
		NativeGame.active_level = rank
	NativeGame.active_node = key
	NativeGame.pending_level = cfg
	var mode := str(cfg.get("mode", ""))
	if mode != "minigame" and not bool(cfg.get("training", false)):
		NativeGame.cashsuck_coins = NativeGame.coins
	if mode != "minigame":
		NativeGame.reset_run()
	var scene := ARENA
	if mode == "castle":
		scene = CASTLE
	elif mode == "minigame":
		match int(cfg.get("minigame", 0)):
			1, 3:
				scene = CARD_GAME
			2:
				scene = SHOP
	get_tree().change_scene_to_file(scene)


## Root-level menu/cinematic scenes -> their native UI equivalents.
func _launch_named(file: String) -> void:
	match file:
		"title.tscn", "starter.tscn", "room0.tscn", "level_0000.tscn", \
		"room_savegame.tscn", "room_samplerizer.tscn":
			get_tree().change_scene_to_file(TITLE)
		"room_map.tscn", "room_map2.tscn", "room_map3.tscn", \
		"room_map4.tscn", "room_map5.tscn", "room_map6.tscn", \
		"room_map7.tscn", "room_map8.tscn", \
		"room_map_indicator.tscn", "room_map_indicator2.tscn", \
		"room_map_indicator3.tscn", "room_map_indicator4.tscn", \
		"room_map_indicator5.tscn", "room_map_indicator6.tscn", \
		"room_map_indicator7.tscn", "room_map_indicator8.tscn", \
		"room_new_map_sequence.tscn", "room_warp_1.tscn":
			get_tree().change_scene_to_file(STAR_MAP)
		"room_animation_1.tscn":
			_play_cutscene("opening", INTRO)
		"room_animation_2.tscn":
			_play_cutscene("anim2", TITLE)
		"room_animation_3.tscn":
			_play_cutscene("mid", TITLE)
		"room_animation_4.tscn":
			_play_cutscene("finale", TITLE)
		"room_choose_hero.tscn":
			get_tree().change_scene_to_file(HERO_SELECT)
		"room_shop.tscn":
			get_tree().change_scene_to_file(SHOP)
		"card_game_1.tscn", "card_game_2.tscn":
			get_tree().change_scene_to_file(CARD_GAME)
		"room_the_end_1.tscn", "room_the_end_2.tscn", \
		"room_the_end_3.tscn":
			get_tree().change_scene_to_file(ENDING)
		_:
			get_tree().change_scene_to_file(TITLE)


func _play_cutscene(seq: String, next: String) -> void:
	var cs = load(CUTSCENE).new()
	cs.setup(seq)
	cs.next_scene = next
	get_tree().root.add_child(cs)
