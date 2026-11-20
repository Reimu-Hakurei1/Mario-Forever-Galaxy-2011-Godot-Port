extends RefCounted

var owner_node: Node2D
var blend: int = 0
var records: Dictionary = {}
var capture_seed: int = 12345


func begin(node: Node2D, clear: bool = true, mode: int = 0) -> void:
	owner_node = node
	blend = mode
	if clear:
		records[node.get_instance_id()] = []


func end() -> void:
	owner_node = null


func texture(tex: Texture2D, transform: Transform2D, rect: Rect2, color: Color, region: Rect2 = Rect2(), tiled: bool = false) -> void:
	if owner_node == null or tex == null:
		return
	var local := Transform2D(0.0, -owner_node.position) * transform
	records.get_or_add(owner_node.get_instance_id(), []).append({"texture": tex, "transform": local, "rect": rect, "color": color, "region": region, "tiled": tiled, "blend": blend})


func primitive(kind: String, data: Array) -> void:
	if owner_node != null:
		records.get_or_add(owner_node.get_instance_id(), []).append({"primitive": kind, "data": data, "origin": -owner_node.position, "blend": blend})


func snapshot(runtime, frame: int) -> Node2D:
	var result := Node2D.new()
	result.name = "CapturedLevel"
	result.set_script(load("res://engine/level_snapshot.gd"))
	result.capture_frame = frame
	var backdrop := Polygon2D.new()
	backdrop.name = "RoomColor"
	var view := Rect2(float(runtime.view_xview[0]), float(runtime.view_yview[0]), float(runtime.view_wview[0]), float(runtime.view_hview[0]))
	backdrop.polygon = PackedVector2Array([view.position, Vector2(view.end.x, view.position.y), view.end, Vector2(view.position.x, view.end.y)])
	backdrop.color = runtime.room_bg_colour
	backdrop.z_index = -4096
	result.add_child(backdrop)
	backdrop.owner = result
	var keys: Array[String] = []
	var nodes: Array[Node] = [runtime.root]
	var living_records: Dictionary = {}
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		var children := node.get_children()
		children.reverse()
		nodes.append_array(children)
		if records.has(node.get_instance_id()):
			living_records[node.get_instance_id()] = records[node.get_instance_id()]
		if not node is Node2D or not node.is_visible_in_tree() or not records.has(node.get_instance_id()):
			continue
		var commands: Array = records[node.get_instance_id()]
		if commands.is_empty():
			continue
		var group := Node2D.new()
		group.name = "Layer_%s" % node.get_instance_id()
		group.transform = runtime.root.global_transform.affine_inverse() * node.global_transform
		group.modulate = node.modulate
		var depth: int = node.z_index
		var ancestor: Node = node
		while ancestor is CanvasItem and ancestor.z_as_relative:
			ancestor = ancestor.get_parent()
			if ancestor is CanvasItem:
				depth += ancestor.z_index
				group.modulate *= ancestor.modulate
		group.z_index = clampi(depth, -4096, 4096)
		group.set_meta("_edit_group_", true)
		if node is GMInstance:
			if not node.alive:
				continue
			group.name = "%s_%d" % [str(runtime.objects[int(node.g_object_index)].name).trim_prefix("o_"), node.inst_id]
			group.set_script(load("res://engine/level_snapshot_instance.gd"))
			group.source_key = node.spawn_key
			group.object_index = int(node.g_object_index)
			group.source_position = group.position
			for edit: Dictionary in runtime.level_waves.instance_edits.get(node.spawn_key, []):
				if not edit.get("duplicate", false) and edit.get("enabled", true):
					group.source_position -= edit.offset
			group.original_kind = int(node.g_rodzaj)
			keys.append(node.spawn_key)
		result.add_child(group)
		group.owner = result
		for command: Dictionary in commands:
			var item: Node2D
			if command.has("texture") and not command.tiled:
				var sprite := Sprite2D.new()
				var tex: Texture2D = command.texture
				if command.region.has_area():
					var atlas := AtlasTexture.new()
					atlas.atlas = tex
					atlas.region = command.region
					tex = atlas
				sprite.texture = tex
				sprite.centered = false
				sprite.transform = command.transform * Transform2D(0.0, command.rect.position)
				sprite.scale *= command.rect.size / tex.get_size()
				sprite.modulate = command.color
				item = sprite
			else:
				item = Node2D.new()
				item.set_script(load("res://engine/level_capture_primitive.gd"))
				item.command = command
			if int(command.blend) != 0:
				var material := CanvasItemMaterial.new()
				material.blend_mode = 2 if int(command.blend) == 2 else 1
				item.material = material
			group.add_child(item)
			item.owner = result
	result.source_keys = keys
	for key in runtime.level_waves.instance_edits:
		if key not in keys:
			result.inherited_edits.append_array(runtime.level_waves.instance_edits[key])
	records = living_records
	return result
