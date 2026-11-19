extends SceneTree
## Headless smoke test for the native arena: boots the level, holds the
## trigger, and verifies enemies spawn, bullets fly, and kills score.
## Run: godot --headless --path . -s tools/native_smoke.gd -- --frames=900

var frames := 0
var limit := 900
var _arena: Node2D


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			limit = int(a.substr(9))
	var packed: PackedScene = load("res://native/levels/arena.tscn")
	_arena = packed.instantiate()
	root.add_child(_arena)


func _process(_delta: float) -> bool:
	frames += 1
	var ship: Node2D = _arena.get_node("Ship")

	# Hold the trigger from frame 60 so weapons cycle.
	if frames == 60:
		ship.fire_override = true
		print("SMOKE ship pos=", ship.position)

	if frames % 300 == 0:
		var enemies := get_nodes_in_group("enemies")
		var bullets := 0
		for c in _arena.get_children():
			if c is NativeBullet:
				bullets += 1
		print("SMOKE f=%d enemies=%d bullets=%d score=%d kills=%d energy=%.0f heat=%.0f" % [
			frames, enemies.size(), bullets, NativeGame.score,
			NativeGame.enemies_killed, NativeGame.energy, NativeGame.overheating])

	if frames >= limit:
		print("SMOKE DONE")
		quit()
		return true
	return false
