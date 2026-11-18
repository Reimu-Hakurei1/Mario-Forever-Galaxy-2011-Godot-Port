@tool
extends Node2D

@export var command: Dictionary = {}


func _draw() -> void:
	if command.is_empty():
		return
	if command.has("texture"):
		draw_set_transform_matrix(command.transform)
		draw_texture_rect(command.texture, command.rect, command.tiled, command.color)
		return
	draw_set_transform(command.origin)
	var data: Array = command.data
	match command.primitive:
		"rect":
			draw_rect(data[0].abs(), data[1], data[2])
		"circle":
			draw_circle(data[0], data[1], data[2], data[3], 1.0)
		"line":
			draw_line(data[0], data[1], data[2], data[3])
		"text":
			draw_set_transform_matrix(Transform2D(0.0, command.origin) * data[0])
			draw_string(data[1], data[2], data[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, data[4])
