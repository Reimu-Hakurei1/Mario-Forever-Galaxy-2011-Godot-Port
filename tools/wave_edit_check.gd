extends SceneTree
var R = load("res://engine/r.gd")

const FIRST := "res://stages/world_1/level_02_first_enconter.tscn"
var savedir: String = ""
var copy_path: String = ""
var mode: String = "full"
var output: String = ""
var frames: int = 0
var failures: int = 0
var checks: int = 0
var tested: bool = false
var game: Node


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--savedir="):
			savedir = arg.substr(10).replace("\\", "/")
		elif arg.begins_with("--mode="):
			mode = arg.substr(7)
		elif arg.begins_with("--out="):
			output = arg.substr(6)
	call_deferred("_run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("WAVE_EDIT_CHECK " + label)


func _run() -> void:
	if savedir.is_empty() or mode not in ["full", "direct"]:
		quit(2)
		return
	copy_path = savedir.path_join("wave_edit_check_%s.tscn" % mode)
	var source: Node2D = load(FIRST).instantiate()
	var after: Node = source.get_node("Waves/Timing/After_Tutorial")
	after.get_node("Enemy_Budget_0_-1_-1").value = 3
	after.get_node("Spawn_Rate_0_0_0").value = 100
	after.get_node("Timed_Event_0_45_45").value = 0
	var formation: Node2D = source.get_node("Waves/Enemies/Formation")
	check(formation.get_child_count() == 30, "scene contains thirty individually selectable formation sprites")
	for slot in range(30):
		var sprite: Sprite2D = formation.get_node("Slot_%02d" % slot)
		check(sprite.texture != null and sprite.position == Vector2(60 + 80 * (slot % 10), [64, 128, 196][slot / 10]), "formation sprite uses source position and texture")
	var enemy: Node2D = formation.get_node("Slot_00")
	enemy.enemy_kind = 2
	enemy.arrival_sequence = 2
	enemy.position += Vector2(24, 16)
	var boss: Node2D = load("res://engine/level_spawn_rule.gd").new()
	boss.name = "Added_Boss"
	boss.mode = 1
	boss.object_index = 169
	boss.position = Vector2(420, 170)
	boss.start_period = 2.0
	source.get_node("Waves/Enemies").add_child(boss)
	boss.owner = source
	var packed := PackedScene.new()
	check(packed.pack(source) == OK, "pack edited wave scene")
	check(ResourceSaver.save(packed, copy_path) == OK, "save edited wave scene")
	source.free()
	R.mouse_override = Vector2(512, 650)
	game = load(copy_path if mode == "direct" else "res://scenes/game.tscn").instantiate()
	root.add_child(game)
	if mode == "full":
		var globals = load("res://game/globals.gd")
		R.aset(globals.map_number, 0, 0)
		globals.aktualny_lev = 2
		R.aset(globals.map_zmien_etap, 0, 0)
		R._level_scene_index[R._scene_key("level_0000", 0, 2)] = copy_path
		R.pending_room = 2


func exercise() -> void:
	check(R.active_scene_path == copy_path, "selected saved wave scene")
	var controllers: Array = R.with_ids(null, 532)
	check(controllers.size() == 1, "one original controller")
	if controllers.is_empty():
		return
	var controller = controllers[0]
	var globals = load("res://game/globals.gd")
	check(controller.g_ilosc_przeciwnikow == 0, "tutorial budget does not activate early")
	check(R.aget2(controller.g_levtime, 0, 0) == 2, "original timing before tutorial")
	check(R.with_ids(null, 169).is_empty(), "added boss does not spawn immediately")
	controller.g_end_level = 1
	check(controller.g_end_level == 0, "pending added wave prevents premature completion")
	var tutorial = R._spawn_at(0, 0, 306, R.next_inst)
	R.next_inst += 1
	R.aset(tutorial.g_sekwencja, 0, 3)
	R.aset(tutorial.g_zmienna, 4, 160)
	globals.pauza = 0
	globals.buttonfire = 1
	R.run_event(tutorial, 3, 0)
	check(R.level_waves.tutorial_complete, "original tutorial completion activates edits")
	check(controller.g_ilosc_przeciwnikow == 3, "edited budget survives hard-coded tutorial reset")
	check(R.aget(controller.g_num, 0) == 3, "budget array reads the scene override")
	check(R.aget2(controller.g_levtime, 0, 0) == 100, "edited timing survives tutorial array rewrite")
	check(R.aget2(controller.g_perioder, 0, 45) == 0, "timed event can be disabled")
	check(controller.g_levtime[0][0] == 2, "original wave tables are not mutated")
	globals.help = 0
	globals.buttonfire = 0
	globals.pauza = 0
	controller.g_periodtime = 1.1
	controller.g_periodtick = 1
	controller.g_zegarek = 0
	R.run_event(controller, 3, 0)
	var enemies: Array = R.with_ids(null, 12)
	check(enemies.size() == 1, "one enemy at the edited spawn rate")
	if not enemies.is_empty():
		var enemy = enemies[0]
		check(enemy.g_rodzaj == 2, "saved enemy type overrides the caller assignment")
		check(R.aget(enemy.g_sekwencja, 0) == 2, "saved arrival sequence overrides the caller assignment")
		check(Vector2(enemy.g_dox, enemy.g_doy) == Vector2(84, 80), "moving the enemy control moves its formation target")
		check(enemy.position.y == -384, "moving the enemy control moves its spawn position")
	check(controller.g_ilosc_przeciwnikow == 2, "one spawn consumes one edited budget entry")
	controller.g_periodtime = 2.1
	globals.pauza = 100
	R.level_waves.step_extras(R, controller)
	check(R.with_ids(null, 169).is_empty(), "pause stops added boss scheduling")
	globals.pauza = 0
	R.run_event(controller, 3, 0)
	var untouched_slot_found := false
	for other in R.with_ids(null, 12):
		if int(R.inst_get(other.inst_id, "pozycja")) == 1:
			untouched_slot_found = true
			check(other.g_rodzaj == 0 and Vector2(other.g_dox, other.g_doy) == Vector2(140, 64), "editing slot zero does not change slot one")
	check(untouched_slot_found, "second original formation slot spawns normally")
	var bosses: Array = R.with_ids(null, 169)
	check(bosses.size() == 1, "added timed boss runs its original Create event")
	if not bosses.is_empty():
		check(Vector2(bosses[0].g_xstart, bosses[0].g_ystart) == Vector2(420, 170), "boss uses scene position")
	R.level_waves.step_extras(R, controller)
	check(R.with_ids(null, 169).size() == 1, "completed timed spawn does not repeat")
	controller.g_end_level = 1
	check(controller.g_end_level == 0, "living added boss prevents completion")
	globals.help = 0
	globals.pauza = 100


func check_completion_and_schedule() -> void:
	var controller = R.with_ids(null, 532)[0]
	var bosses: Array = R.with_ids(null, 169)
	if not bosses.is_empty():
		var child = R._as_inst(R.instance_create(bosses[0], 450, -100, 251))
		R.instance_destroy(bosses[0])
		check(R.level_waves.blocks_completion(R, controller), "boss child keeps the added encounter active")
		R.instance_destroy(child)
		check(not R.level_waves.blocks_completion(R, controller), "finished encounter releases completion despite decorative effects")
		controller.g_end_level = 1
		check(controller.g_end_level == 1, "original completion is restored after the added encounter")
		controller.g_end_level = 0
	var rule: Dictionary
	for candidate: Dictionary in R.level_waves.spawns:
		if int(candidate.mode) == 1:
			rule = candidate.duplicate(true)
			break
	rule.object = 12
	rule.stage = 1
	rule.start = 3.0
	rule.count = 2
	rule.interval = 0.5
	rule.spawned = 0
	R.level_waves.spawns.append(rule)
	var globals = load("res://game/globals.gd")
	globals.pauza = 0
	controller.g_periodtime = 3.0
	var before: int = R.with_ids(null, 12).size()
	R.level_waves.step_extras(R, controller)
	check(R.with_ids(null, 12).size() == before, "other-stage additions do not spawn")
	rule.stage = 0
	controller.g_periodtime = 2.99
	R.level_waves.step_extras(R, controller)
	check(R.with_ids(null, 12).size() == before, "timed enemy does not spawn early")
	controller.g_periodtime = 3.0
	R.level_waves.step_extras(R, controller)
	check(R.with_ids(null, 12).size() == before + 1, "first timed enemy spawns when due")
	controller.g_periodtime = 3.49
	R.level_waves.step_extras(R, controller)
	check(R.with_ids(null, 12).size() == before + 1, "interval prevents clustered additions")
	controller.g_periodtime = 3.5
	R.level_waves.step_extras(R, controller)
	check(R.with_ids(null, 12).size() == before + 2, "second timed enemy respects interval")
	controller.g_periodtime = 4.0
	R.level_waves.step_extras(R, controller)
	check(R.with_ids(null, 12).size() == before + 2, "timed enemy count is bounded")
	R.level_waves.configure({})
	check(R.level_waves.bindings.is_empty() and R.level_waves.added_roots.is_empty(), "room reconfiguration clears wave overrides and encounters")
	check(R.aget2(controller.g_levtime, 0, 0) == 2, "removing scene overrides restores untouched source arrays")
	globals.pauza = 100


func _process(_delta: float) -> bool:
	if game == null:
		return false
	frames += 1
	if not tested and R.room == 2:
		tested = true
		exercise()
	if frames >= 90:
		check(tested, "entered the target level")
		if not output.is_empty():
			root.get_texture().get_image().save_png(output)
		if tested:
			check_completion_and_schedule()
		print("WAVE_EDIT_CHECK mode=%s checks=%d failures=%d" % [mode, checks, failures])
		DirAccess.remove_absolute(copy_path)
		quit(1 if failures else 0)
		return true
	return false
