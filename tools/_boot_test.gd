extends SceneTree
func _init():
	var game = load("res://native/core/native_game.gd")
	print("BOOT_DONE help_table=", load("res://native/core/help_table.gd").TOPICS.size())
	quit()
