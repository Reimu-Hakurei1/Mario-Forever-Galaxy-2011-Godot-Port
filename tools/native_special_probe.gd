extends SceneTree
## Headless probe for the special-items system: boots the arena, grants
## every special, rotates the ring, and fires each one to verify the
## effects land (heals, bolts, novas, chrono clear).
## Run: godot --headless --path . -s tools/native_special_probe.gd -- --frames=300

var frames := 0
var limit := 300
var _arena: Node2D
var _phase := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			limit = int(a.substr(9))
	var packed: PackedScene = load("res://native/levels/arena.tscn")
	_arena = packed.instantiate()
	root.add_child(_arena)
	# Fresh hero 0 loadout gives specials [1,2,3,4]; top up to all 9.
	NativeGame.apply_hero()
	for i in range(1, 10):
		NativeGame.add_special(i)
	print("SPECIAL slots=", NativeGame.special_slots)


func _process(_delta: float) -> bool:
	frames += 1
	var ship: Node2D = _arena.get_node("Ship")

	# Damage the ship first so heal specials have something to mend.
	if frames == 30:
		NativeGame.damage_player(40.0)
		print("SPECIAL pre-damage energy=%.0f" % NativeGame.energy)

	# Cycle through firing each special via the same entry point the
	# X key uses — call _use_special directly on the active slot.
	if frames == 60:
		for i in 4:
			print("SPECIAL fire id=%d" % NativeGame.special_slots[i])
			ship._use_special(NativeGame.special_slots[i])
		print("SPECIAL post-fire energy=%.0f heal_rate=%.1f heal_left=%.1f bullets=%d" % [
			NativeGame.energy, NativeGame.special_heal_rate,
			NativeGame.special_heal_left, _count_bullets()])

	if frames == 120:
		# Rotation check: next should move slot1's item to the front.
		var before: int = NativeGame.special_slots[1]
		NativeGame.rotate_special(1)
		print("SPECIAL rotate next first=%d expected=%d slots=%s" % [
			NativeGame.special_slots[0], before, str(NativeGame.special_slots)])
		NativeGame.rotate_special(-1)
		print("SPECIAL rotate back first=%d" % NativeGame.special_slots[0])

	if frames == 150:
		print("SPECIAL heal-tick energy=%.0f" % NativeGame.energy)

	if frames >= limit:
		print("SPECIAL DONE energy=%.0f slots=%s" % [
			NativeGame.energy, str(NativeGame.special_slots)])
		quit()
		return true
	return false


func _count_bullets() -> int:
	var n := 0
	for c in _arena.get_children():
		if c is NativeBullet:
			n += 1
	return n
