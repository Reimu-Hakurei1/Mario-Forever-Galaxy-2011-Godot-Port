extends Node

## Attached to every stages/*.tscn scene. When running the GameMaker
## runtime (main scene = scenes/game.tscn), these scenes should launch
## the specific room they represent. The metadata/gm_room holds the
## room name that maps to a level JSON file.

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# The GameMaker runtime boots through R.boot in main.gd.
	# For F6/current-scene execution on a stage, we need to set the
	# target room so the runtime loads it instead of the default.
	_launch_room.call_deferred()


func _launch_room() -> void:
	var room_name: String = get_meta("gm_room", "")
	if room_name == "":
		return
	# Write the target room to a temp file; main.gd will read it on boot
	var temp_path := "user://stage_launch_room.txt"
	var f := FileAccess.open(temp_path, FileAccess.WRITE)
	if f:
		f.store_string(room_name)
		f.close()
	# Change to the main game scene, which will load the requested room
	get_tree().change_scene_to_file("res://scenes/game.tscn")
