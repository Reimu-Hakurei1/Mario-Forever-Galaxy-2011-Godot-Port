@tool
extends Node2D

@export var show_enemy_controls: bool = true:
	set(value):
		show_enemy_controls = value
		_update_preview()
@export_multiline var instructions: String = "Where Enemies/Formation exists, move its sprites to edit individual stage-0 formation slots. These are resting targets, not a timeline; arrivals and row motion run during gameplay. Hidden type-wide controls retain their edits. Other scenes still use per-type controls. Edit Values under Timing or add a Spawn Rule in Add timed spawns mode. Period units are not seconds. F6 runs the animated level."


func _ready() -> void:
	_update_preview()


func _update_preview() -> void:
	if Engine.is_editor_hint():
		var enemies := get_node_or_null("Enemies")
		if enemies != null:
			enemies.visible = show_enemy_controls


func collect_edits(scene_root: Node2D) -> Dictionary:
	var result: Dictionary = {"tables": [], "spawns": []}
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node.has_method("wave_edits"):
			result.tables.append_array(node.wave_edits())
		if node.has_method("spawn_edit"):
			var edit: Dictionary = node.spawn_edit(scene_root)
			if not edit.is_empty():
				result.spawns.append(edit)
		pending.append_array(node.get_children())
	return result
