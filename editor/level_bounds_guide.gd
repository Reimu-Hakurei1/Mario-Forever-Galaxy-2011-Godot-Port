@tool
extends Node2D

## Editor-only guide showing the playable area (1024x768) for level scenes.
## This node is ignored at runtime and only visible in the editor.

func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	# Draw a semi-transparent rectangle showing the level bounds
	var rect := ColorRect.new()
	rect.color = Color(1, 1, 1, 0.1)
	rect.size = Vector2(1024, 768)
	rect.position = Vector2(0, 0)
	add_child(rect)
	# Add a border
	var border := ReferenceRect.new()
	border.border_color = Color(1, 1, 0, 0.5)
	border.border_width = 2.0
	border.size = Vector2(1024, 768)
	border.position = Vector2(0, 0)
	add_child(border)
