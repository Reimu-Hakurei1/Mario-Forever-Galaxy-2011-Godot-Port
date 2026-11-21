extends Node2D

## Canvas backdrop for the level editor: draws the chosen background tiled
## over the 1024x768 room plus a faint grid and the room border.

var bg_texture: Texture2D = null
var show_grid := true


func _draw() -> void:
	if bg_texture != null:
		var w := bg_texture.get_width()
		var h := bg_texture.get_height()
		if w > 0 and h > 0:
			var cols := int(ceil(1024.0 / w)) + 1
			var rows := int(ceil(768.0 / h)) + 1
			for y in rows:
				for x in cols:
					draw_texture(bg_texture, Vector2(x * w - 444.0, y * h))
	# grid
	if show_grid:
		for x in range(0, 1025, 64):
			draw_line(Vector2(x, 0), Vector2(x, 768), Color(1, 1, 1, 0.06))
		for y in range(0, 769, 64):
			draw_line(Vector2(0, y), Vector2(1024, y), Color(1, 1, 1, 0.06))
	# room border
	draw_rect(Rect2(0, 0, 1024, 768), Color(0.4, 0.8, 1.0, 0.9), false, 2.0)
