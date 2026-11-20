extends Node2D

## Small ring drawn under editor markers so spawn positions stay visible
## even when the enemy preview sprite is small or missing.

var ring_color: Color = Color(1, 0.6, 0.2)


func _draw() -> void:
	draw_arc(Vector2.ZERO, 14.0, 0, TAU, 24, ring_color, 2.0)
