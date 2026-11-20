extends Node

## Attached to every stages/*.tscn scene. When running the GameMaker
## runtime (main scene = scenes/game.tscn), these scenes launch the
## specific room they represent by reading gm_room metadata and
## forcing R to load that room instead of the default first_room.

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_launch_room.call_deferred()


func _launch_room() -> void:
	var room_name: String = get_meta("gm_room", "")
	if room_name == "":
		return
	# Set a global override for the room name and map/level indices
	R.pending_stage_room = room_name
	R.pending_stage_map = int(get_meta("gm_map", 0))
	R.pending_stage_lev = int(get_meta("gm_lev", 0))
	# Wait one frame then instantiate the main game scene
	await get_tree().process_frame
	var main_scene: PackedScene = load("res://scenes/game.tscn")
	var instance: Node = main_scene.instantiate()
	get_tree().root.add_child(instance)
	queue_free()
