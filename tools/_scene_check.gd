extends SceneTree
const SCENES := [
	"res://native/ui/title.tscn",
	"res://native/ui/options.tscn",
	"res://native/ui/shop.tscn",
	"res://native/ui/hero_select.tscn",
	"res://native/ui/card_game.tscn",
	"res://native/ui/ending.tscn",
	"res://native/ui/game_over.tscn",
	"res://native/ui/intro.tscn",
	"res://native/levels/star_map.tscn",
	"res://native/levels/arena.tscn",
	"res://native/levels/castle.tscn",
]
func _init():
	call_deferred("_run")
func _run() -> void:
	for path in SCENES:
		var ps = load(path)
		if ps == null:
			print("FAIL load ", path); continue
		var inst = ps.instantiate()
		root.add_child(inst)
		await process_frame
		await process_frame
		var pv = inst.get_node_or_null("Preview")
		print(path.get_file(), " root=", inst.name, " preview_left=", pv != null, " children=", inst.get_child_count())
		inst.queue_free()
		await process_frame
	print("SCENE_CHECK_DONE")
	quit()
