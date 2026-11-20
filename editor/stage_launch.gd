extends Node

## Attached to every stages/*.tscn scene. Pressing F6 (run current scene)
## routes to the native arena with the stage's authored config.

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_launch_native.call_deferred()


func _launch_native() -> void:
	var map_idx := int(get_meta("gm_map", 0))
	var lev_idx := int(get_meta("gm_lev", 0))
	var key := "%d:%d" % [map_idx, lev_idx]
	var cfg := NativeLevelTable.config_for_key(key)
	if cfg.is_empty():
		# Fallback for test scenes without authored data
		cfg = {"waves": [], "background": 0, "music": "mixed_battle"}
	NativeGame.pending_level = cfg
	NativeGame.active_node = key
	var rank := NativeLevelTable.node_rank(key)
	if rank >= 0:
		NativeGame.active_level = rank
	get_tree().change_scene_to_file("res://native/levels/arena.tscn")
