@tool
extends Node2D

@export_storage var source_key: String = ""
@export_storage var object_index: int = -1
@export_storage var source_position: Vector2
@export_storage var original_kind: int = -1
@export var enemy_kind: int = -1
@export var enabled: bool = true


func instance_edit(scene_root: Node2D) -> Dictionary:
	var relative: Transform2D = scene_root.global_transform.affine_inverse() * global_transform
	return {"key": source_key, "object": object_index, "offset": relative.origin - source_position,
		"scale": relative.get_scale(), "angle": -rad_to_deg(relative.get_rotation()),
		"color": modulate, "kind": enemy_kind, "enabled": enabled}
