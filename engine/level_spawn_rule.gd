@tool
extends Node2D

@export_enum("Edit original spawns", "Add timed spawns") var mode: int = 0:
	set(value):
		mode = value
		notify_property_list_changed()
@export var object_index: int = 12
@export var match_enemy_kind: int = -1
@export_range(-1, 29, 1) var match_formation_slot: int = -1
@export_range(0, 100, 1) var match_formation_stage: int = 0
@export var show_name: bool = true:
	set(value):
		show_name = value
		queue_redraw()
@export var enemy_kind: int = -1
@export var arrival_sequence: int = -1
@export_enum("Original:-1", "No:0", "Yes:1") var kamikaze: int = -1
@export_range(0, 100, 1) var stage: int = 0
@export_range(0, 199, 0.01) var start_period: float = 1.0
@export_range(1, 1000, 1) var count: int = 1
@export_range(0.01, 10000, 0.01) var interval_periods: float = 1.0
@export var arrival_target: Vector2 = Vector2(440, 128)
@export var override_arrival_target: bool = false
@export_multiline var source_description: String = ""
@export_storage var source_position: Vector2 = Vector2.ZERO
@export_storage var preview_layers: Array = []
@export_storage var source_key: String = ""
var _textures: Dictionary = {}
var _preview_kind: int = -999
var _preview_object: int = -999
var _preview_sprites: Array[Sprite2D] = []
static var _enemy_catalog: Dictionary = {}


func _ready() -> void:
	set_process(Engine.is_editor_hint())


func _process(_delta: float) -> void:
	var kind: int = enemy_kind if enemy_kind >= 0 else match_enemy_kind
	if kind != _preview_kind or object_index != _preview_object:
		_preview_kind = kind
		_preview_object = object_index
		_refresh_preview()
		queue_redraw()


func _refresh_preview() -> void:
	for sprite in _preview_sprites:
		sprite.free()
	_preview_sprites.clear()
	var layers: Array = preview_layers
	var kind: int = enemy_kind if enemy_kind >= 0 else match_enemy_kind
	var catalog: Dictionary = _catalog()
	if object_index == 12:
		layers = catalog.get(str(maxi(kind, 0)), preview_layers)
	else:
		var object: Dictionary = catalog._objects.get(str(object_index), {})
		if source_key.get_slice(":", 0) != object.get("name", ""):
			layers = object.get("layers", [])
	var native: Variant = self
	var primary: bool = native is Sprite2D
	if primary:
		native.texture = null
	for layer: Dictionary in layers:
		var path: String = str(layer.texture)
		if not _textures.has(path):
			_textures[path] = load(path)
		var texture: Texture2D = _textures[path]
		if texture == null:
			continue
		if primary and float(layer.sx) == 1.0 and float(layer.sy) == 1.0 and float(layer.rotation) == 0.0 and int(layer.get("blend", 0)) == 0:
			native.texture = texture
			native.centered = false
			native.offset = Vector2(float(layer.x) - float(layer.ox), float(layer.y) - float(layer.oy))
			primary = false
			continue
		primary = false
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = Vector2(layer.x, layer.y)
		sprite.rotation = float(layer.rotation)
		sprite.scale = Vector2(layer.sx, layer.sy)
		sprite.centered = false
		sprite.offset = Vector2(-float(layer.ox), -float(layer.oy))
		if int(layer.get("blend", 0)) != 0:
			var material := CanvasItemMaterial.new()
			material.blend_mode = int(layer.blend)
			sprite.material = material
		add_child(sprite, false, Node.INTERNAL_MODE_BACK)
		_preview_sprites.append(sprite)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var native: Variant = self
	if _preview_sprites.is_empty() and not (native is Sprite2D and native.texture != null):
		draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.65, 0.15), false, 2.0)
	if show_name:
		draw_string(ThemeDB.fallback_font, Vector2(-32, 50), str(name).replace("_", " "), HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


static func _catalog() -> Dictionary:
	if _enemy_catalog.is_empty():
		var file := FileAccess.open("res://data/levels/enemy_editor_catalog.json", FileAccess.READ)
		if file != null:
			_enemy_catalog = JSON.parse_string(file.get_as_text())
	return _enemy_catalog


func _validate_property(property: Dictionary) -> void:
	if property.name == "object_index":
		var choices := PackedStringArray()
		var objects: Dictionary = _catalog()._objects
		for id in objects:
			choices.append("%s:%s" % [str(objects[id].name).trim_prefix("o_"), id])
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(choices)
		if mode == 0:
			property.usage |= PROPERTY_USAGE_READ_ONLY
	if mode == 0 and property.name in ["stage", "start_period", "count", "interval_periods"]:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	if mode == 1 and property.name == "match_enemy_kind":
		property.usage &= ~PROPERTY_USAGE_EDITOR


func spawn_edit(scene_root: Node2D) -> Dictionary:
	if not _catalog()._objects.has(str(object_index)):
		push_error("Unknown spawn object index: %d" % object_index)
		return {}
	var offset: Vector2 = scene_root.global_transform.affine_inverse() * global_position - source_position
	if mode == 1 and (count < 1 or interval_periods <= 0 or start_period < 0 or start_period + (count - 1) * interval_periods >= 200):
		push_error("Added spawns must fit within the original period clock (0 to below 200).")
		return {}
	if mode == 0 and offset.is_zero_approx() and enemy_kind < 0 and arrival_sequence < 0 and kamikaze < 0 and not override_arrival_target:
		return {}
	return {"mode": mode, "object": object_index, "match_kind": match_enemy_kind,
		"match_slot": match_formation_slot, "match_stage": match_formation_stage,
		"kind": enemy_kind, "sequence": arrival_sequence, "kamikaze": kamikaze,
		"offset": offset, "target": arrival_target, "override_target": override_arrival_target,
		"position": scene_root.global_transform.affine_inverse() * global_position,
		"stage": stage, "start": start_period, "count": count, "interval": interval_periods, "spawned": 0}


func _get_configuration_warnings() -> PackedStringArray:
	if not _catalog()._objects.has(str(object_index)):
		return PackedStringArray(["Choose an existing object from Object Index."])
	if mode == 1 and start_period + (count - 1) * interval_periods >= 200:
		return PackedStringArray(["The last added spawn must be before period 200, where the original clock stops."])
	if mode == 1 and object_index == 12 and arrival_sequence < 0:
		return PackedStringArray(["Set Arrival Sequence for added enemies (100 is the standard arrival path)."])
	return PackedStringArray()
