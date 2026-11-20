@tool
extends Node2D

@export_storage var source_keys: Array[String] = []
@export_storage var inherited_edits: Array = []
@export var capture_frame: int = 0
@export var capture_seed: int = 12345
@export var apply_edits: bool = false


func snapshot_edits(scene_root: Node2D) -> Dictionary:
	if not apply_edits:
		return {}
	var edits: Array = inherited_edits.duplicate(true)
	var by_key: Dictionary = {}
	for child in get_children():
		if child.has_method("instance_edit"):
			by_key[child.source_key] = child
	var present: Dictionary = {}
	for child in get_children():
		if not child.has_method("instance_edit"):
			continue
		var edit: Dictionary = child.instance_edit(scene_root)
		var key: String = edit.key
		var cut: int = key.find("/copy:")
		var base_key: String = key.substr(0, cut) if cut >= 0 else ""
		if cut >= 0 and by_key.has(base_key):
			if edit.enabled:
				var base: Node2D = by_key[base_key]
				edit.key = base_key
				edit.offset = child.position - base.position
				edit.duplicate = true
			else:
				edit.duplicate = false
		else:
			edit["duplicate"] = present.has(key)
		present[key] = true
		edits.append(edit)
	for key in source_keys:
		if not present.has(key):
			edits.append({"key": key, "enabled": false, "duplicate": false})
	return {"seed": capture_seed, "instances": edits}
