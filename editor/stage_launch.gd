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
	# Write the target room to a temp file; main.gd will read it on boot
	var temp_path := "user://stage_launch_room.txt"
	var f := FileAccess.open(temp_path, FileAccess.WRITE)
	if f:
		f.store_string(room_name)
		f.close()
	# Wait one frame then change scene to avoid loading issues
	await get_tree().process_frame
	var main_scene: PackedScene = load("res://scenes/game.tscn")
	var instance: Node = main_scene.instantiate()
	get_tree().root.add_child(instance)
	queue_free()
