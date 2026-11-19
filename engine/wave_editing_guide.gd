@tool
extends Node2D

## Editor-only guide for wave editing zones.
## Shows visual regions for enemy spawn areas and timing controls.

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	# Add visual guides for common spawn zones
	_add_spawn_zone("Top_Spawn", Vector2(0, 0), Vector2(1024, 200), Color(1, 0, 0, 0.1))
	_add_spawn_zone("Center_Spawn", Vector2(0, 200), Vector2(1024, 400), Color(0, 1, 0, 0.1))
	_add_spawn_zone("Bottom_Spawn", Vector2(0, 400), Vector2(1024, 368), Color(0, 0, 1, 0.1))
	
	# Add labels
	_add_label("Enemy Spawns", Vector2(10, 10), Color.YELLOW)
	_add_label("Wave Timing", Vector2(10, 30), Color.CYAN)

func _add_spawn_zone(name: String, pos: Vector2, size: Vector2, color: Color) -> void:
	var rect := ColorRect.new()
	rect.name = name
	rect.color = color
	rect.position = pos
	rect.size = size
	add_child(rect)
	var border := ReferenceRect.new()
	border.border_color = Color(color.r, color.g, color.b, 0.5)
	border.border_width = 1.0
	border.position = pos
	border.size = size
	add_child(border)

func _add_label(text: String, pos: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
