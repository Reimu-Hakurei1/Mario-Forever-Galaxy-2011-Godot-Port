@tool
extends Node

@export_enum("num", "lev", "pozd", "levtime", "sekwencus", "kamik", "perioder", "sila_wrogow") var table: String = "lev"
@export_range(0, 100, 1) var stage: int = 0
@export_range(-1, 10000, 1) var first_index: int = 0
@export_range(-1, 10000, 1) var last_index: int = 0
@export var value: float = 0.0
@export var force_override: bool = false
@export_multiline var source_expression: String = ""
@export_enum("Level start", "After movement and firing tutorial") var activation: int = 0
@export_storage var source_value: float = 0.0
@export_storage var source_key: String = ""


func wave_edits() -> Array:
	if not force_override and value == source_value:
		return []
	var warnings: PackedStringArray = _get_configuration_warnings()
	if not warnings.is_empty():
		push_error("Invalid wave setting %s: %s" % [name, "; ".join(warnings)])
		return []
	return [{"table": table, "stage": stage, "first": first_index,
		"last": maxi(first_index, last_index), "value": value, "activation": activation}]


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if last_index < first_index:
		warnings.append("Last Index must not precede First Index.")
	if table in ["num", "levtime", "sila_wrogow"] and value < 0:
		warnings.append("This table requires a nonnegative value.")
	if table == "lev" and value < -1:
		warnings.append("Use -1 for the original random-remaining rule, or a nonnegative enemy type.")
	if table == "pozd" and (value < -1 or value > 29):
		warnings.append("Formation slots are -1 (first free slot) or 0 through 29.")
	return warnings
