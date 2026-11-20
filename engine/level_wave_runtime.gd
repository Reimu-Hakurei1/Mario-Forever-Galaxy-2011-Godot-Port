extends RefCounted

var tables: Array = []
var spawns: Array = []
var bindings: Array = []
var pending_spawns: Array = []
var event_stack: Array = []
var tutorial_complete: bool = false
var added_roots: Dictionary = {}
var spawn_parents: Dictionary = {}
var instance_edits: Dictionary = {}
var room_spawn_counts: Dictionary = {}


func spawn_key(creator, object_index: int) -> String:
	var counts: Dictionary = creator.spawn_counts if is_instance_valid(creator) and creator is GMInstance else room_spawn_counts
	var parent: String = creator.spawn_key if is_instance_valid(creator) and creator is GMInstance and not creator.spawn_key.is_empty() else "room"
	var occurrence: int = int(counts.get(object_index, 0))
	counts[object_index] = occurrence + 1
	return "%s/%d:%d" % [parent, object_index, occurrence]


func is_removed(key: String) -> bool:
	for edit: Dictionary in instance_edits.get(key, []):
		if not edit.get("duplicate", false) and not edit.enabled:
			return true
	return false


func configure(data: Dictionary) -> void:
	tables = data.get("tables", [])
	spawns = data.get("spawns", [])
	bindings.clear()
	pending_spawns.clear()
	tutorial_complete = false
	added_roots.clear()
	spawn_parents.clear()
	room_spawn_counts.clear()
	instance_edits.clear()
	for edit: Dictionary in data.get("instances", []):
		instance_edits.get_or_add(str(edit.key), []).append(edit)
	if data.has("seed"):
		seed(int(data.seed))


func note_spawn(creator, inst) -> void:
	if is_instance_valid(creator):
		spawn_parents[inst.inst_id] = creator.inst_id


func blocks_completion(runtime, controller) -> bool:
	var stage: int = int(controller.g_etap)
	for rule: Dictionary in spawns:
		if int(rule.mode) == 1 and int(rule.stage) == stage and int(rule.spawned) < int(rule.count):
			return true
	for id in spawn_parents:
		var inst = runtime._as_inst(id)
		if inst == null or not inst.alive:
			continue
		var object_name: String = str(runtime.objects[int(inst.g_object_index)].name)
		if not added_roots.has(id) and not object_name.begins_with("o_enemy") and "boss" not in object_name:
			continue
		var ancestor: int = int(id)
		while ancestor in spawn_parents:
			if added_roots.get(ancestor, -1) == stage:
				return true
			ancestor = int(spawn_parents[ancestor])
	return false


func bind_controller(inst) -> void:
	for edit: Dictionary in tables:
		if edit.table not in ["num", "lev", "pozd", "levtime", "sekwencus", "kamik", "perioder", "sila_wrogow"]:
			continue
		var array = inst.get("g_" + str(edit.table))
		if array is Array:
			bindings.append({"array": array, "edit": edit})


func read_override(array: Variant, stage: int, index: int) -> Variant:
	var value: Variant = null
	var priority: int = -1
	for binding: Dictionary in bindings:
		var edit: Dictionary = binding.edit
		var activation: int = int(edit.activation)
		if activation == 1 and not tutorial_complete:
			continue
		if activation >= priority and is_same(array, binding.array) and int(edit.stage) == stage and index >= int(edit.first) and index <= int(edit.last):
			value = edit.value
			priority = activation
	return value


func begin_event(inst) -> void:
	event_stack.append(int(inst.g_object_index))


func end_event(runtime) -> void:
	event_stack.pop_back()
	if event_stack.is_empty():
		flush_spawns(runtime)


func assignment(runtime, oid: int, name: String, value: Variant) -> Variant:
	if oid == 532 and name == "g_ilosc_przeciwnikow" and 306 in event_stack:
		tutorial_complete = true
		for binding: Dictionary in bindings:
			if binding.edit.table == "num":
				var override: Variant = read_override(binding.array, 0, -1)
				if override != null:
					value = override
				break
	return value


func flush_spawns(runtime) -> void:
	var pending: Array = pending_spawns
	pending_spawns = []
	for inst in pending:
		if not is_instance_valid(inst) or not inst.alive:
			continue
		var original_kind: int = int(inst.g_rodzaj)
		for rule: Dictionary in spawns:
			if int(rule.mode) != 0 or int(rule.object) != int(inst.g_object_index):
				continue
			if int(rule.match_kind) >= 0 and original_kind != int(rule.match_kind):
				continue
			if int(rule.get("match_slot", -1)) >= 0:
				var creator = runtime._as_inst(spawn_parents.get(inst.inst_id, -4))
				if creator == null or int(creator.g_object_index) != 532 or added_roots.has(inst.inst_id):
					continue
				if int(creator.g_etap) != int(rule.match_stage) or int(runtime.inst_get(inst.inst_id, "pozycja")) != int(rule.match_slot):
					continue
			apply_spawn(runtime, inst, rule)
		apply_instance_edits(runtime, inst)


func apply_instance_edits(runtime, inst) -> void:
	var copy_index := 0
	var edits: Array = instance_edits.get(inst.spawn_key, []).duplicate()
	edits.sort_custom(func(a, b): return a.get("duplicate", false) and not b.get("duplicate", false))
	for edit: Dictionary in edits:
		if not edit.enabled:
			continue
		var target = inst
		if edit.get("duplicate", false):
			copy_index += 1
			var clone_key: String = inst.spawn_key + "/copy:%d" % copy_index
			if is_removed(clone_key):
				continue
			var id: int = runtime.next_inst
			runtime.next_inst += 1
			target = runtime._spawn_at(inst.position.x, inst.position.y, int(inst.g_object_index), id, clone_key)
			var copies: Dictionary = {inst.inst_id: target.inst_id}
			var descendants: Dictionary = {}
			for child in runtime.instances:
				if child.spawn_key.begins_with(target.spawn_key + "/"):
					descendants[child.spawn_key.trim_prefix(target.spawn_key)] = child.inst_id
			for child in runtime.instances:
				if child.spawn_key.begins_with(inst.spawn_key + "/") and not child.spawn_key.begins_with(target.spawn_key):
					var suffix: String = child.spawn_key.trim_prefix(inst.spawn_key)
					if descendants.has(suffix):
						copies[child.inst_id] = descendants[suffix]
			for source_id in copies:
				var source = runtime._as_inst(source_id)
				var copy = runtime._as_inst(copies[source_id])
				for property: Dictionary in source.get_property_list():
					var name: String = property.name
					if name.begins_with("g_") and name not in ["g_id", "g_object_index"]:
						copy.set(name, _copy_value(source.get(name), copies))
			spawn_parents[target.inst_id] = spawn_parents.get(inst.inst_id, -4)
			var controllers: Array = runtime.with_ids(null, 532)
			if not controllers.is_empty():
				added_roots[target.inst_id] = int(controllers[0].g_etap)
			if int(inst.g_object_index) == 12:
				runtime.member_set(target, "g_pozycja", 110)
		target.position += edit.offset
		target.g_xstart = target.position.x
		target.g_ystart = target.position.y
		target.scale = edit.scale
		target.rotation = -deg_to_rad(float(edit.angle))
		target.modulate = edit.color
		if int(edit.kind) >= 0:
			runtime.member_set(target, "g_rodzaj", int(edit.kind))
		if int(target.g_object_index) == 12:
			target.g_dox += edit.offset.x
			target.g_doy += edit.offset.y
		target.sync_visuals()


func _copy_value(value: Variant, ids: Dictionary) -> Variant:
	if value is Array:
		var result: Array = value.duplicate()
		for i in result.size():
			result[i] = _copy_value(result[i], ids)
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[_copy_value(key, ids)] = _copy_value(value[key], ids)
		return result
	if (value is int or value is float) and ids.has(value):
		return ids[value]
	return value


func apply_spawn(runtime, inst, rule: Dictionary) -> void:
	inst.position += rule.offset if int(rule.mode) == 0 else Vector2.ZERO
	inst.g_xstart = inst.position.x
	inst.g_ystart = inst.position.y
	if int(rule.kind) >= 0:
		runtime.member_set(inst, "g_rodzaj", int(rule.kind))
	if int(rule.sequence) >= 0:
		runtime.member_set(inst, "g_sekwencja", int(rule.sequence))
	if int(rule.kamikaze) >= 0:
		runtime.member_set(inst, "g_kamikaze", int(rule.kamikaze))
	if int(inst.g_object_index) == 12:
		if rule.override_target:
			inst.g_dox = rule.target.x
			inst.g_doy = rule.target.y
		elif int(rule.mode) == 0:
			inst.g_dox += rule.offset.x
			inst.g_doy += rule.offset.y
	inst.sync_visuals()


func step_extras(runtime, controller) -> void:
	var globals = load("res://game/globals.gd")
	if globals.pauza != 0 or controller.g_end_level != 0:
		return
	for rule: Dictionary in spawns:
		if int(rule.mode) != 1 or int(rule.stage) != int(controller.g_etap):
			continue
		if int(rule.spawned) >= int(rule.count):
			continue
		var due: float = float(rule.start) + int(rule.spawned) * float(rule.interval)
		if float(controller.g_periodtime) < due:
			continue
		var id = runtime.instance_create(controller, rule.position.x, rule.position.y, int(rule.object))
		var inst = runtime._as_inst(id)
		if inst != null:
			added_roots[inst.inst_id] = int(rule.stage)
			if int(inst.g_object_index) == 12:
				runtime.member_set(inst, "g_sekwencja", 100)
				inst.g_dox = rule.target.x
				inst.g_doy = rule.target.y
			apply_spawn(runtime, inst, rule)
		rule.spawned = int(rule.spawned) + 1
