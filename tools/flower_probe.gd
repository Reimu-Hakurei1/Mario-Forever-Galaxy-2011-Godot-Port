extends SceneTree

## Spawn the fire-flower and mushroom pickups in a level scene and screenshot them.
##   godot --path . -s tools/flower_probe.gd

var frames := 0
var done := false


func _initialize() -> void:
	var packed: PackedScene = load("res://stages/world_1/level_06_enemy_wall.tscn")
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	if done:
		return true
	frames += 1
	if frames == 30:
		R.instance_create(null, 400, 400, 298)
		R.instance_create(null, 520, 400, 295)
		R.instance_create(null, 640, 400, 299)
		R.instance_create(null, 760, 400, 301)
		var slot: Variant = R.obj_var_raw(0, "g_bron_etapowa")
		R.aset(slot, 0, 1200)
		R.aset(slot, 1, 1200)
	if frames == 80:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("res://_test_saves/flower_shot.png")
		print("SAVED ", img.get_size())
		done = true
		quit()
	return false
