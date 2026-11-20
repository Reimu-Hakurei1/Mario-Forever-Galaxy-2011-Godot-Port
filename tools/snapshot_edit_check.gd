extends SceneTree
var R = load("res://engine/r.gd")

const FIRST := "res://stages/world_1/level_02_first_enconter.tscn"
var savedir := ""
var mode := "full"
var copy_path := ""
var failures := 0
var checks := 0
var game: Node
var frames := 0
var entered := false
var tutorial_done: Dictionary = {}
var target_frame := 300
var moved_key := ""
var deleted_key := ""
var duplicated_key := ""
var moved_offset := Vector2(30, 20)
var slot_positions: Dictionary = {}
var dump := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--savedir="):
			savedir = arg.substr(10).replace("\\", "/")
		elif arg.begins_with("--mode="):
			mode = arg.substr(7)
		elif arg == "--dump":
			dump = true
	if savedir.is_empty() or mode not in ["full", "direct"]:
		quit(2)
		return
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SNAPSHOT_EDIT_CHECK " + label)


func _run() -> void:
	copy_path = savedir.path_join("snapshot_edit_%s.tscn" % mode)
	var source: Node2D = load(FIRST).instantiate()
	var formation: Node2D = source.get_node("Waves/Enemies/Formation")
	for slot in range(formation.get_child_count()):
		slot_positions[slot] = formation.get_child(slot).position
	var snapshot_path := savedir.path_join("state_0.scn")
	if not FileAccess.file_exists(snapshot_path):
		push_error("SNAPSHOT_EDIT_CHECK missing captured state; run capture worker first")
		quit(2)
		return
	var captured: Node2D = load(snapshot_path).instantiate()
	captured.scene_file_path = ""
	target_frame = int(captured.capture_frame)
	captured.name = "CapturedLevel"
	captured.apply_edits = true
	source.add_child(captured)
	captured.owner = source
	for child in captured.get_children():
		child.owner = source
		for sub in child.get_children():
			sub.owner = source
	var instances: Array = []
	for child in captured.get_children():
		if child.has_method("instance_edit") and child.object_index == 12:
			instances.append(child)
	check(instances.size() >= 3, "captured scene has at least 3 enemy instances")
	if instances.size() < 3:
		quit(1)
		return
	var mover: Node2D = instances[0]
	var deleter: Node2D = instances[1]
	var duplicator: Node2D = instances[2]
	moved_key = mover.source_key
	deleted_key = deleter.source_key
	duplicated_key = duplicator.source_key
	mover.position += moved_offset
	deleter.enabled = false
	var clone: Node2D = duplicator.duplicate()
	clone.name = duplicator.name + "_copy"
	clone.position += Vector2(50, 0)
	captured.add_child(clone)
	clone.owner = source
	for sub in clone.get_children():
		sub.owner = source
	var edits: Dictionary = captured.snapshot_edits(source)
	if dump:
		print("DUMP pre-pack children=", captured.get_child_count(), " edits=", edits.get("instances", []).size())
		for edit: Dictionary in edits.get("instances", []):
			print("DUMP pre-pack edit ", edit.key, " dup=", edit.get("duplicate", false), " enabled=", edit.enabled, " offset=", edit.offset)
	check(edits.has("instances"), "snapshot_edits produces instance list")
	var edit_list: Array = edits.get("instances", [])
	var found_move := false
	var found_delete := false
	var found_dup := false
	for edit: Dictionary in edit_list:
		if edit.key == moved_key and not edit.get("duplicate", false):
			found_move = edit.offset.is_equal_approx(moved_offset)
		if edit.key == deleted_key and not edit.enabled:
			found_delete = true
		if edit.key == duplicated_key and edit.get("duplicate", false):
			found_dup = true
	check(found_move, "moved instance offset recorded")
	check(found_delete, "deleted instance marked disabled")
	check(found_dup, "duplicated instance marked as duplicate")
	var packed := PackedScene.new()
	check(packed.pack(source) == OK, "pack snapshot-edited scene")
	check(ResourceSaver.save(packed, copy_path) == OK, "save snapshot-edited scene")
	var capture_seed := int(captured.capture_seed)
	source.free()
	seed(capture_seed)
	R.mouse_override = Vector2(512, 650)
	game = load(copy_path if mode == "direct" else "res://scenes/game.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	if mode == "full":
		var globals = load("res://game/globals.gd")
		R.aset(globals.map_number, 0, 0)
		globals.aktualny_lev = 2
		R.aset(globals.map_zmien_etap, 0, 0)
		R._level_scene_index[R._scene_key("level_0000", 0, 2)] = copy_path
		R.pending_room = 2


func _process(_delta: float) -> bool:
	if game == null:
		return false
	if not entered:
		R.step()
		if R.room == 2:
			entered = true
		return false
	for tutorial in R.with_ids(null, 306):
		if not tutorial_done.has(tutorial.inst_id):
			tutorial_done[tutorial.inst_id] = true
			var globals = load("res://game/globals.gd")
			R.aset(tutorial.g_sekwencja, 0, 3)
			R.aset(tutorial.g_zmienna, 4, 160)
			globals.pauza = 0
			globals.buttonfire = 1
			R.run_event(tutorial, 3, 0)
			globals.help = 0
			globals.buttonfire = 0
	R.step()
	frames += 1
	if frames >= target_frame:
		_verify()
		print("SNAPSHOT_EDIT_CHECK mode=%s checks=%d failures=%d" % [mode, checks, failures])
		quit(1 if failures else 0)
		return true
	return false


func _verify() -> void:
	check(R.active_scene_path == copy_path, "selected snapshot-edited scene")
	if dump:
		var cap: Node = game.get_node_or_null("CapturedLevel")
		if cap != null:
			print("DUMP loaded children=", cap.get_child_count())
			for child in cap.get_children():
				if child.has_method("instance_edit"):
					print("DUMP loaded node ", child.name, " key=", child.source_key, " enabled=", child.enabled, " pos=", child.position)
		print("DUMP edits keys: ", R.level_waves.instance_edits.keys())
		for key in R.level_waves.instance_edits:
			print("DUMP edit ", key, " -> ", R.level_waves.instance_edits[key])
		for inst in R.instances:
			if inst.alive and int(inst.g_object_index) == 12:
				print("DUMP enemy ", inst.spawn_key, " poz=", R.aget(inst.g_pozycja, 0), " dox=", inst.g_dox, " doy=", inst.g_doy, " xstart=", inst.g_xstart, " ystart=", inst.g_ystart)
	var moved_found := false
	var deleted_found := false
	var dup_count := 0
	for inst in R.instances:
		if not inst.alive or int(inst.g_object_index) != 12:
			continue
		if inst.spawn_key == moved_key:
			moved_found = true
			var slot: int = int(R.aget(inst.g_pozycja, 0))
			if slot_positions.has(slot):
				var base: Vector2 = slot_positions[slot]
				check(Vector2(inst.g_dox, inst.g_doy).distance_to(base + moved_offset) < 2.0, "moved instance formation target has offset applied")
				check(absf(inst.g_ystart - (-400.0 + moved_offset.y)) < 2.0, "moved instance spawn position has offset applied")
		if inst.spawn_key == deleted_key:
			deleted_found = true
		if inst.spawn_key.begins_with(duplicated_key + "/copy:"):
			dup_count += 1
	check(moved_found, "moved instance exists at runtime")
	check(not deleted_found, "deleted instance does not exist at runtime")
	check(dup_count >= 1, "duplicated instance exists at runtime")