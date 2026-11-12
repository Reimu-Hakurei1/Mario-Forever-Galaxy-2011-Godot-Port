extends SceneTree

## Render the live runtime to a PNG, for visual comparison with the original game.
##   godot --path . -s tools/shot.gd -- --room=19 --out=shot.png --frames=120 [--lev=2]
## Or boot a generated room scene the same way F6 does:
##   godot --path . -s tools/shot.gd -- --scene=res://scenes/levels/level_0000.tscn --out=shot.png

var frames: int = 0
var wait: int = 120
var room_id: int = -1
var lev: int = -1
var out_path: String = "shot.png"
var scene_path: String = ""
var press_z: bool = false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			room_id = int(a.substr(7))
		elif a.begins_with("--frames="):
			wait = int(a.substr(9))
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--lev="):
			lev = int(a.substr(6))
		elif a.begins_with("--scene="):
			scene_path = a.substr(8)
		elif a == "--press-z":
			press_z = true
	var game: Node = load(scene_path if scene_path != "" else "res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8 and room_id >= 0:
		if lev >= 0:
			var G = load("res://gen/globals.gd")
			G.aktualny_lev = lev
		R.pending_room = room_id
	if frames >= 20 and press_z and frames % 60 < 2:
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		ev.pressed = (frames % 60 == 0)
		R.handle_input(ev)
	if frames >= wait:
		var img := root.get_texture().get_image()
		img.save_png(out_path)
		print("SHOT %s room=%d frame=%d tick=%d inst=%d" % [out_path, R.room, frames,
			R.tick_count, R.instances.size()])
		quit()
		return true
	return false
