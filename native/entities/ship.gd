extends Node2D
class_name NativeShip
## NativeShip — the player's ship (ports GameMaker `o_player_a`).
##
## The original is a custom inertia-flier, NOT a platformer:
##   - Arrow keys accelerate the ship; velocity decays when keys are released
##   - The hull visibly banks (tilts) while turning
##   - Five gun muzzles are hard-coded around the hull; Space fires all
##     charged weapons, each with its own reload timer and heat cost
##
## Constants below are transcribed from script_sterowanie / script_strzelanie
## in game/scripts/part_5_8.gd so the feel matches the original.

const SPRITE_ID := 543          # s_player_a — 16 frames, origin (48,74)
const FRAME_BANK_LEFT := 0      # g_image_index 0 — banked left
const FRAME_LEVEL := 1          # g_image_index 1 — upright
const FRAME_BANK_RIGHT := 2     # g_image_index 2 — banked right

# Playfield bounds inside the 1024x768 room (from script_sterowanie).
const BOUND_LEFT := 70.0
const BOUND_RIGHT := 800.0
const BOUND_TOP := 100.0
const BOUND_BOTTOM := 750.0

# Movement tuning (per-step values at 60 fps, from the original script).
const ACCEL_X := 0.4            # + upgradeWING/10 per frame
const ACCEL_X_REVERSE := 0.6
const ACCEL_Y := 0.1            # + upgradeWING/20 per frame
const ACCEL_Y_REVERSE := 0.2
const MAX_SPEED_X := 5.0        # + upgradeBOOST, divided by samus_slower
const MAX_SPEED_Y := 5.0        # + upgradeBOOST/2, divided by samus_slower
const DRAG := 1.04              # velocity /= DRAG when coasting
const TILT_MIN := 70.0          # image_angle clamps
const TILT_MAX := 110.0
const TILT_RETURN := 0.5        # degrees/frame back to 90

# The five hard-coded gun muzzles (G.ladowanie_* arrays, player_a ev_0_0):
# each entry is [muzzle_angle, muzzle_range, fire_direction]. The muzzle
# angle is added to the hull tilt to get the world-space shot angle.
const MUZZLES := [
	[260.0, 70.0, -1],   # top-left gun
	[180.0, 80.0, -1],   # nose gun (straight ahead)
	[100.0, 70.0, -1],   # top-right gun
	[45.0, 60.0, 1],     # bottom-left gun
	[315.0, 60.0, 1],    # bottom-right gun
]

# Per-slot charge thresholds come from the weapon catalog
# (NativeWeaponTable.slot_stats()["delay"]) — higher "fr" = slower gun.
const OVERHEAT_COOLING := 0.6   # heat dissipated per frame when not firing

signal died

var vel := Vector2.ZERO         # g_ixor / g_iyor combined
var tilt := 90.0                # g_image_angle — hull bank angle
var bank_frame := FRAME_LEVEL   # g_image_index — which bank sprite to show
var invulnerable := false       # g_shield / spawn protection
var fire_held := false
## Test/tool hook: when true the trigger is treated as held regardless of
## keyboard state (used by headless probes that can't press keys).
var fire_override := false

var _charge := PackedFloat32Array()   # g_ladowanie[1..5]
var _muzzle_sprite: AnimatedSprite2D
var _hurtbox: Area2D
var _sfx: AudioStreamPlayer
var _weapon_levels := PackedInt32Array()  # g_levelup per slot
var _shield_sprite: Sprite2D          # bubble shown while shielded
var _shielded := false                # invulnerable came from SHIELD pickup
var _orbit_balls: Array[Sprite2D] = []  # upgradeBALLS weapon orbs
var _ball_hits := {}                  # ball index -> {enemy_id: last_hit_frame}


func _ready() -> void:
	add_to_group("player")
	_charge.resize(MUZZLES.size())
	for i in MUZZLES.size():
		_charge[i] = 0.0
	_weapon_levels.resize(MUZZLES.size())

	# Hull sprite — AnimatedSprite2D with the three bank frames. The
	# original rotates the whole sprite by -tilt degrees.
	_muzzle_sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("bank")
	for f in [FRAME_BANK_LEFT, FRAME_LEVEL, FRAME_BANK_RIGHT]:
		var tex := NativeAssets.sprite_frame(SPRITE_ID, f)
		if tex != null:
			frames.add_frame("bank", tex)
	_muzzle_sprite.sprite_frames = frames
	_muzzle_sprite.play("bank")
	_muzzle_sprite.offset = -NativeAssets.sprite_origin(SPRITE_ID)
	# Hero tint — recolours the hull so ship choice is visible.
	_muzzle_sprite.modulate = NativeGame.hero_tint
	add_child(_muzzle_sprite)

	# Hurtbox — a generous circle covering the hull. The original relies on
	# sprite masks; a circle keeps collisions fair and cheap.
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 1 << 0    # layer 1 = player
	_hurtbox.collision_mask = 0          # player doesn't detect, only gets detected
	_hurtbox.monitorable = true
	_hurtbox.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	shape.shape = circle
	_hurtbox.add_child(shape)
	add_child(_hurtbox)

	# One-shot sfx player for muzzle reports.
	_sfx = AudioStreamPlayer.new()
	add_child(_sfx)

	# Shield bubble — a generated ring texture around the hull. Shown
	# only while a SHIELD pickup is active (NativeGame.shield_time).
	_shield_sprite = Sprite2D.new()
	_shield_sprite.texture = _make_shield_texture()
	_shield_sprite.modulate = Color(0.5, 0.8, 1.0, 0.8)
	_shield_sprite.visible = false
	add_child(_shield_sprite)

	# Spawn in the middle of the playfield.
	position = Vector2(435, 425)

	# Companion buddies — the original creates both in the player create
	# event (o_kumpel_a x2). They follow on side offsets and soak fire.
	# Deferred: the ship is still inside the arena's own add_child when
	# _ready runs, and Godot rejects nested adds at that moment.
	for s in [-1, 1]:
		var buddy := NativeBuddy.new()
		buddy.side = s
		buddy.global_position = position + Vector2(95.0 * s, 55.0)
		get_parent().add_child.call_deferred(buddy)


func _physics_process(delta: float) -> void:
	if NativeGame.paused:
		return
	_tick_shield(delta)
	_poll_input()
	_apply_movement(delta)
	_apply_firing(delta)
	_update_visuals(delta)
	_tick_orbit(delta)
	_tick_reserve()
	_tick_balls()
	_tick_special(delta)


## Shield pickup timer — while active the hull is invulnerable and the
## bubble ring shows. Spawn-protection invulnerability is separate: the
## shield flag only releases what the shield itself set.
func _tick_shield(delta: float) -> void:
	if NativeGame.shield_time > 0.0:
		NativeGame.shield_time = maxf(0.0, NativeGame.shield_time - delta)
		invulnerable = true
		_shielded = true
		_shield_sprite.visible = true
		_shield_sprite.rotation += delta * 2.5
		_shield_sprite.modulate.a = 0.55 + sin(Time.get_ticks_msec() / 120.0) * 0.25
	elif _shielded:
		_shielded = false
		invulnerable = false
		_shield_sprite.visible = false


## 64px ring texture generated once — cyan bubble outline.
static func _make_shield_texture() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(32, 32)
	for y in 64:
		for x in 64:
			var d := Vector2(x, y).distance_to(c)
			if d > 26.0 and d < 30.0:
				img.set_pixel(x, y, Color(0.5, 0.85, 1.0, 0.9))
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------------------
# Input — arrow keys move, Space fires (matches ster1..ster5 bindings).
# ---------------------------------------------------------------------------

func _poll_input() -> void:
	# Space or Left Ctrl fires; fire_override is the headless test hook.
	fire_held = fire_override or Input.is_key_pressed(KEY_SPACE) \
		or Input.is_key_pressed(KEY_CTRL)


# ---------------------------------------------------------------------------
# Movement — inertia model transcribed from script_sterowanie.
# ---------------------------------------------------------------------------

func _apply_movement(delta: float) -> void:
	var slower := maxf(0.01, NativeGame.samus_slower)
	var wing := float(NativeGame.upgrade_wing)
	var boost := float(NativeGame.upgrade_boost)

	# Arrows are primary; WASD works as an alternate scheme.
	var left := Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var right := Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	var up := Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	var down := Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)

	# --- Horizontal: accelerate toward max speed, drag when coasting ---
	if left and vel.x > 0.0:
		vel.x -= (ACCEL_X_REVERSE + wing / 10.0) / slower * delta * 60.0
	elif left:
		vel.x -= (ACCEL_X + wing / 10.0) / slower * delta * 60.0
	if right and vel.x < 0.0:
		vel.x += (ACCEL_X_REVERSE + wing / 10.0) / slower * delta * 60.0
	elif right:
		vel.x += (ACCEL_X + wing / 10.0) / slower * delta * 60.0
	var max_x := (MAX_SPEED_X + boost) / slower
	vel.x = clampf(vel.x, -max_x, max_x)
	if not left and not right:
		vel.x /= (DRAG + wing / 20.0)
		if absf(vel.x) <= 0.1:
			vel.x = 0.0

	# --- Vertical: same model, slightly weaker authority ---
	if up and vel.y > 0.0:
		vel.y -= (ACCEL_Y_REVERSE + wing / 20.0) / slower * delta * 60.0
	elif up:
		vel.y -= (ACCEL_Y + wing / 20.0) / slower * delta * 60.0
	if down and vel.y < 0.0:
		vel.y += (ACCEL_Y_REVERSE + wing / 20.0) / slower * delta * 60.0
	elif down:
		vel.y += (ACCEL_Y + wing / 20.0) / slower * delta * 60.0
	var max_y := (MAX_SPEED_Y + boost / 2.0) / slower
	vel.y = clampf(vel.y, -max_y, max_y)
	if not up and not down:
		vel.y /= (DRAG + wing / 20.0)
		if absf(vel.y) <= 0.01:
			vel.y = 0.0

	# Integrate and clamp to the playfield.
	position += vel * delta * 60.0
	position.x = clampf(position.x, BOUND_LEFT, BOUND_RIGHT)
	position.y = clampf(position.y, BOUND_TOP, BOUND_BOTTOM)
	if position.x == BOUND_LEFT or position.x == BOUND_RIGHT:
		vel.x = 0.0
	if position.y == BOUND_TOP or position.y == BOUND_BOTTOM:
		vel.y = 0.0


# ---------------------------------------------------------------------------
# Firing — five muzzles, per-slot charge timers, overheat (script_strzelanie).
# ---------------------------------------------------------------------------

func _apply_firing(delta: float) -> void:
	# Overdrive star countdown — while active, weapons cycle faster.
	if NativeGame.overdrive_time > 0.0:
		NativeGame.overdrive_time = maxf(0.0, NativeGame.overdrive_time - delta)

	# Guns only work with hull integrity and while not overheated.
	var can_fire: bool = NativeGame.energy > 0.0 and not NativeGame.paused \
		and NativeGame.overheating < NativeGame.overheat_max()
	var rate_mult := 1.5 if NativeGame.overdrive_time > 0.0 else 1.0

	for i in MUZZLES.size():
		var wid := NativeGame.weapons[i] if i < NativeGame.weapons.size() else -1
		if wid < 0:
			_charge[i] = 0.0
			continue    # empty slot — G.weapon[slot] == -1 in the original
		var st := NativeWeaponTable.slot_stats(
			NativeGame.weapon_level[i], wid)
		# Charge builds every frame (g_ladowanie), fires when it reaches
		# the weapon's firerate threshold minus upgrade shaving.
		_charge[i] += (1.0 + NativeGame.samus_firerate) * rate_mult * delta * 60.0
		if can_fire and fire_held and _charge[i] >= st["delay"]:
			_charge[i] = 0.0
			_fire_slot(i, st)

	# Heat bleeds off whenever the trigger isn't cycling weapons.
	# samus_cooling is the original's extra vent rate (hero 3 quirk).
	if not (can_fire and fire_held):
		NativeGame.overheating = maxf(0.0, NativeGame.overheating \
			- (OVERHEAT_COOLING + NativeGame.samus_cooling) * delta * 60.0)


## Spawn the weapon in slot `index`. Bolt count/arc come from the weapon's
## catalog type (the original's script_laser_<id> functions each hard-code
## a pattern; we group them by shoptype):
##   SINGLE   — `multi` bolts in a tight fan (multi>1 = burst spread)
##   MULTI / MULTISHOT / MULTI-SIDE — symmetric fan of `multi` bolts
##   SPREAD   — wide shotgun arc of `multi` bolts
##   SIDE     — forward bolt plus `multi-1` bolts perpendicular to the hull
##   MISC     — single bolt (GOLD GUN's CREATE COINS flag handled per-bolt)
## Flags in `add` (AUTO-TARGETING, ONLY FORWARD SHOTS, EXPLOSIVE AMMO,
## CREATE COINS) tweak aim or bolt behaviour.
func _fire_slot(index: int, st: Dictionary) -> void:
	var m: Array = MUZZLES[index]
	var muzzle_angle := float(m[0]) + tilt - 90.0
	var rad := deg_to_rad(muzzle_angle)
	# Original formula: x uses sin, y uses cos — compass-style degrees.
	var offset := Vector2(sin(rad), cos(rad)) * float(m[1])
	var spawn_pos := position + offset
	var aim := offset.normalized()
	var add: String = st.get("add", "N/A")

	# ONLY FORWARD SHOTS — phase weapons ignore hull aim and shoot up.
	if "ONLY FORWARD" in add:
		aim = Vector2(0, -1)
	# AUTO-TARGETING — bend the aim at the nearest enemy.
	elif "AUTO-TARGETING" in add:
		var target := _nearest_enemy()
		if target != null:
			aim = (target.global_position - spawn_pos).normalized()

	var wtype: String = st.get("type", "")

	# Weapon ids >= 1000 are the rocket/super series — the original's
	# script_laser_1000..1008 each spawn a distinct projectile object
	# (homing missiles, drunk/weaving rockets, arcing war balls, the
	# SENTINEL auto-turret and the GUARDIAN orbiting shooter) instead of
	# the standard fan patterns.
	if int(st.get("id", -1)) >= 1000:
		_fire_super_weapon(st, spawn_pos, aim)
		NativeGame.overheating += st["overheat"]
		_play_shot_sound()
		return

	var count: int = maxi(1, int(st.get("multi", 1)))
	var dirs: Array[Vector2] = []
	match wtype:
		"SPREAD SHOT WEAPON":
			for i in count:
				dirs.append(aim.rotated((i - (count - 1) / 2.0) * 0.42))
		"SIDE SHOT WEAPON":
			var perp := Vector2(-aim.y, aim.x)
			dirs.append(aim)
			for i in count - 1:
				var side := 1.0 if i % 2 == 0 else -1.0
				dirs.append((aim * 0.4 + perp * side * 0.9).normalized())
		"MULTI SHOT WEAPON", "MULTISHOT SHOT WEAPON", \
		"MULTISHOT WEAPON", "MULTI-SIDE SHOT WEAPON":
			for i in count:
				dirs.append(aim.rotated((i - (count - 1) / 2.0) * 0.3))
		_:
			# SINGLE SHOT (+ MISC): tight fan when multi > 1.
			for i in count:
				dirs.append(aim.rotated((i - (count - 1) / 2.0) * 0.14))

	for dir in dirs:
		var bullet := NativeBullet.new()
		bullet.global_position = spawn_pos
		bullet.velocity = dir * NativeBullet.START_SPEED
		bullet.damage = st["damage"]
		bullet.explosive = "EXPLOSIVE AMMO" in add
		bullet.coin_on_hit = "CREATE COINS" in add
		get_parent().add_child(bullet)

	NativeGame.overheating += st["overheat"]
	_play_shot_sound()


## Muzzle report — sound id 29 from the original sampel table.
func _play_shot_sound() -> void:
	var stream := NativeAssets.sound(29)
	if stream != null and NativeGame.dzwiek == 1:
		_sfx.stream = stream
		_sfx.volume_db = linear_to_db(maxf(0.01, NativeGame.glosnosc_dzwieku))
		_sfx.play()


## Spawn the projectile for a weapon-1000-series slot. `st["proj"]` is
## the behaviour tag from NativeWeaponTable.SUPER_WEAPONS; each maps to
## the object the matching script_laser_100x created:
##   HOMING / HOMING_SLOW — steer toward the nearest enemy
##   RODEO            — drunk heading oscillation
##   SWARM            — twin homing missiles with random spawn jitter
##   GRAVITY(+BOUNCE) — arcing war ball that detonates on impact
##   HOMING_SHRAPNEL  — homing rocket bursting into a 10-bolt fan
##   SENTINEL         — falling auto-turret that lobs aimed shots
##   GUARDIAN         — orbiting satellite shooter (harmless body)
##   NONE             — BIG DA ROCKA: the original has no
##                      script_laser_1009, so it fires nothing.
func _fire_super_weapon(st: Dictionary, spawn_pos: Vector2, aim: Vector2) -> void:
	var proj: String = st.get("proj", "NONE")
	if proj == "NONE":
		return
	var dmg: float = st["damage"]

	# SWARM fires two missiles per trigger with ±20px spawn jitter
	# (script_laser_1003 creates obj 203 twice).
	var shots := 2 if proj == "SWARM" else 1
	for _s in shots:
		var bolt := NativeBullet.new()
		bolt.global_position = spawn_pos + Vector2(
			randf_range(-20.0, 20.0), randf_range(-20.0, 20.0)) \
			if proj == "SWARM" else spawn_pos
		bolt.damage = dmg
		bolt.sprite_id = _proj_sprite(proj)
		bolt.sprite2_id = _proj_sprite2(proj)
		bolt.scale0 = _proj_scale(proj)
		match proj:
			"HOMING", "HOMING_SLOW", "HOMING_SHRAPNEL", "SWARM":
				# Direction 90 in the original = up; homing bolts steer to
				# the target anyway, so aim is only the launch heading.
				bolt.velocity = aim * 2.0
				bolt.max_speed = 20.0
				bolt.accel_per_frame = \
					0.32 if proj == "SWARM" else \
					(0.12 if proj == "HOMING_SLOW" else 0.09)
				bolt.homing = 0.5 if proj == "HOMING_SLOW" else 3.0
				if proj == "HOMING_SHRAPNEL":
					bolt.shrapnel = 10
			"RODEO":
				bolt.velocity = aim * 2.0
				bolt.max_speed = 9.0
				bolt.accel_per_frame = 0.09
				bolt.weave = 1.4
				bolt.weave_speed = 0.1
			"GRAVITY", "GRAVITY_BOUNCE":
				# War balls lob forward with a random ±15° spread and fall.
				var dir := aim.rotated(deg_to_rad(randf_range(-15.0, 15.0)))
				bolt.velocity = dir * 8.0
				bolt.max_speed = 8.0
				bolt.accel_per_frame = 0.0
				bolt.gravity = 0.2
				bolt.bounce_floor = proj == "GRAVITY_BOUNCE"
			"SENTINEL":
				var dir := aim.rotated(deg_to_rad(randf_range(-15.0, 15.0)))
				bolt.velocity = dir * 8.0
				bolt.max_speed = 8.0
				bolt.accel_per_frame = 0.0
				bolt.gravity = 0.2
				bolt.bounce_floor = true
				bolt.life_frames = 600
				bolt.auto_shot_every = 40
				bolt.auto_shot_damage = dmg / 20.0
			"GUARDIAN":
				bolt.orbit_mode = true
				bolt.life_frames = 650
				bolt.orbit_shot_every = 6
				bolt.orbit_shot_damage = dmg
		get_parent().add_child(bolt)


## Sprite indices the original rocket objects draw (draw_sprite_ext calls
## in bullet_rockets_*.gd / buddy_1.gd). sprite2 is the additive-glow
## second layer where the original used blend mode 1.
func _proj_sprite(proj: String) -> int:
	match proj:
		"HOMING_SLOW": return 41      # s_bullet8 — big ballistic rocket
		"HOMING_SHRAPNEL": return 218 # s_bullet_minigun6
		"GRAVITY", "GRAVITY_BOUNCE", "SENTINEL": return 217  # s_bullet_minigun5
		"GUARDIAN": return 221        # sprite221 — orbiting pod
		_: return 24                  # s_bullet_5 — small rocket


func _proj_sprite2(proj: String) -> int:
	match proj:
		"GRAVITY_BOUNCE": return 219  # s_bullet_minigun7 glow
		"SENTINEL": return 220        # s_bullet_minigun8 glow
		"GUARDIAN": return 222        # sprite222 — far pod
		_: return -1


func _proj_scale(proj: String) -> float:
	match proj:
		"GUARDIAN": return 0.5
		"GRAVITY", "GRAVITY_BOUNCE", "SENTINEL", "HOMING_SHRAPNEL": return 0.6
		_: return 0.5


# ---------------------------------------------------------------------------
# Special items — ports script_special / script_zmiana_specjala.
# X fires the active special (specialslot[0]); Z/C rotate the ring so a
# different item becomes active. Effects implement each item's
# g_sekwencja_special outcome — see NativeSpecialTable for the mapping.
# ---------------------------------------------------------------------------

var _special_prev := {KEY_X: false, KEY_Z: false, KEY_C: false}


func _tick_special(delta: float) -> void:
	# Trickle heal from FIELD DRESSING / NANO SWARM.
	if NativeGame.special_heal_left > 0.0:
		NativeGame.special_heal_left = maxf(0.0, NativeGame.special_heal_left - delta)
		if NativeGame.special_heal_left > 0.0 and NativeGame.energy > 0.0:
			NativeGame.heal_player(NativeGame.special_heal_rate * delta)

	# Edge-triggered special buttons (keyboard_check in the original).
	var use := Input.is_key_pressed(KEY_X)
	if use and not _special_prev[KEY_X]:
		_use_special(NativeGame.special_active())
	_special_prev[KEY_X] = use
	var prev := Input.is_key_pressed(KEY_Z)
	if prev and not _special_prev[KEY_Z]:
		NativeGame.rotate_special(-1)
	_special_prev[KEY_Z] = prev
	var next := Input.is_key_pressed(KEY_C)
	if next and not _special_prev[KEY_C]:
		NativeGame.rotate_special(1)
	_special_prev[KEY_C] = next


## Fire the item in the active special slot. Each id maps to the
## gameplay effect of its g_sekwencja_special sequence.
func _use_special(id: int) -> void:
	if id <= 0 or NativeGame.energy <= 0.0:
		return
	var item := NativeSpecialTable.at(id)
	if item.is_empty():
		return
	NativeAssets.play_sound(62)

	# Heal-over-time specials (seq 23000 / 50000).
	if item.has("heal_rate"):
		NativeGame.special_heal_rate = item["heal_rate"]
		NativeGame.special_heal_left = item["heal_time"]
		return

	match id:
		2:  # NOVA BLAST — seq 22000 heavy blast: hurts everything on screen
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy):
					enemy.take_damage(item["damage"])
			# The original flashes the special_weapon sprite on cast.
			_flash_special_fx(480)
		3:  # PIERCER SLUG — seq 1000: huge bolt straight up, pierces
			_special_bolt(Vector2(0, -1) * 2.5, item["damage"], true,
				{"sprite": 411, "tint": Color(0.5, 0.9, 1.0), "scale": 0.45})
		4:  # NOVA RING — seq 1: damage nova around the ship
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) \
						and global_position.distance_to(enemy.global_position) < 320.0:
					enemy.take_damage(item["damage"])
			_flash_special_fx(480)
		5:  # RED SHOT — seq 5000: single heavy slug
			_special_bolt(Vector2(0, -1) * 3.0, item["damage"], false,
				{"sprite": 480, "tint": Color(1.0, 0.35, 0.3), "scale": 0.5})
		6:  # TRIPLE MISSILE — seq 30000: three photon_laser31 bolts
			# (obj 304, sprite 411) fanned around the nose
			for i in 3:
				_special_bolt(Vector2(0, -1).rotated((i - 1) * 0.28) * 3.2,
					item["damage"], false,
					{"sprite": 411, "tint": Color(0.6, 0.9, 1.0), "scale": 0.45})
		8:  # BOMB RING — seq 80000: eleven cool_explosion_bullets (obj
			# 302, sprite 490) spiral outward from the ship
			for i in 11:
				var dir := Vector2.RIGHT.rotated(i * TAU / 11.0)
				var bolt := _special_bolt_ret(dir * 2.8, item["damage"], false,
					{"sprite": 490, "tint": Color(1.0, 0.6, 0.4), "scale": 0.4})
				if bolt != null:
					bolt.weave = 2.0
					bolt.weave_speed = 0.15
		9:  # CHRONO — seq 100000 zwolnij_gre: clears enemy fire + shield
			for bullet in get_tree().get_nodes_in_group("enemy_bullets"):
				if is_instance_valid(bullet):
					bullet.queue_free()
			NativeGame.shield_time = item["shield"]
			_flash_special_fx(480)


## Brief muzzle flash using the original's special_weapon sprite
## (o_special_weapon_1-6 all draw sprite 480/481 on cast).
func _flash_special_fx(sprite_id: int) -> void:
	var flash := Sprite2D.new()
	flash.texture = NativeAssets.sprite_frame(sprite_id, 0)
	if flash.texture == null:
		flash.queue_free()
		return
	flash.offset = -NativeAssets.sprite_origin(sprite_id)
	flash.scale = Vector2(0.6, 0.6)
	flash.global_position = global_position
	get_parent().add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)


## Spawn one special bolt — same parent/group conventions as _fire_slot.
## `fx` optionally overrides the projectile sprite/tint/scale with the
## original's special_weapon_* artwork.
func _special_bolt(dir: Vector2, dmg: float, pierce: bool,
		fx: Dictionary = {}) -> void:
	_special_bolt_ret(dir, dmg, pierce, fx)


## Same as _special_bolt but returns the spawned bullet for tweak-ups.
func _special_bolt_ret(dir: Vector2, dmg: float, pierce: bool,
		fx: Dictionary = {}) -> NativeBullet:
	var bullet := NativeBullet.new()
	bullet.global_position = global_position
	bullet.velocity = dir
	bullet.damage = dmg
	bullet.pierce = pierce
	if fx.has("sprite"):
		bullet.sprite_id = int(fx["sprite"])
	if fx.has("scale"):
		bullet.scale0 = float(fx["scale"])
	if fx.has("tint"):
		bullet.modulate = fx["tint"]
	get_parent().add_child(bullet)
	return bullet


## Closest living enemy to the ship — the auto-targeting weapons'
## "nearest target" pick (script_laser_* aimed at g_x/g_y similarly).
func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var d := global_position.distance_squared_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


## ORBIT upgrade — steady hull regeneration while alive (the original's
## script_regeneracja_od_specjala adds energia each tick).
func _tick_orbit(delta: float) -> void:
	if NativeGame.upgrade_orbit <= 0 or NativeGame.energy <= 0.0 \
			or NativeGame.energy >= NativeGame.max_energy():
		return
	NativeGame.heal_player(NativeGame.upgrade_orbit * 0.5 * delta)


## g_energion reserve — health mushrooms don't heal instantly; the
## reserve trickles 1 unit/frame into hull while the ship is alive
## (script_odnawianie_kumpli). Our hull is ~10x smaller, so each
## reserve point restores 0.1 hull per physics frame.
func _tick_reserve() -> void:
	if NativeGame.energy_reserve <= 0.0 or NativeGame.energy <= 0.0:
		return
	NativeGame.energy_reserve = maxf(0.0, NativeGame.energy_reserve - 1.0)
	NativeGame.heal_player(0.1)


## BALLS upgrade — orbiting weapon orbs. Each orb circles the hull and
## damages enemies it touches, with a short per-target cooldown so a
## parked orb can't melt a single enemy instantly.
const BALL_RADIUS := 58.0
const BALL_DAMAGE := 6.0
const BALL_HIT_COOLDOWN := 25      # physics frames between hits per orb/foe

func _tick_balls() -> void:
	_sync_balls()
	if _orbit_balls.is_empty():
		return
	var n := _orbit_balls.size()
	var angle0 := Time.get_ticks_msec() / 1000.0 * 2.2
	var frame := Engine.get_physics_frames()
	for i in n:
		var ball := _orbit_balls[i]
		var ang := angle0 + i * TAU / n
		ball.global_position = global_position + Vector2.RIGHT.rotated(ang) * BALL_RADIUS
		# Contact damage — same group scan the bullets use.
		var hits: Dictionary = _ball_hits.get(i, {})
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			var eid := enemy.get_instance_id()
			if frame - int(hits.get(eid, -9999)) < BALL_HIT_COOLDOWN:
				continue
			if ball.global_position.distance_to(enemy.global_position) < 26.0:
				hits[eid] = frame
				enemy.take_damage(BALL_DAMAGE)
		_ball_hits[i] = hits


## Keep the orb count in sync with upgrade_balls — bought in the shop.
func _sync_balls() -> void:
	var want := NativeGame.upgrade_balls
	while _orbit_balls.size() < want:
		var ball := Sprite2D.new()
		var tex := NativeAssets.sprite_frame(406, 0)   # s_bullet_mini
		if tex != null:
			ball.texture = tex
		ball.modulate = Color(1.0, 0.85, 0.3)
		ball.scale = Vector2(0.6, 0.6)
		get_parent().add_child(ball)
		_orbit_balls.append(ball)
	while _orbit_balls.size() > want:
		_orbit_balls.pop_back().queue_free()


# ---------------------------------------------------------------------------
# Visuals — bank frame follows horizontal input, hull rotates with tilt.
# ---------------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	# Hull tilt: arrows/WASD bank the ship, release returns to level flight.
	var key_left := Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var key_right := Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	if key_left:
		tilt += 1.0
		bank_frame = FRAME_BANK_LEFT
	elif key_right:
		tilt -= 1.0
		bank_frame = FRAME_BANK_RIGHT
	else:
		bank_frame = FRAME_LEVEL
		if tilt > 90.0:
			tilt -= TILT_RETURN + NativeGame.upgrade_wing / 5.0
		elif tilt < 90.0:
			tilt += TILT_RETURN + NativeGame.upgrade_wing / 5.0
		if absf(tilt - 90.0) <= 0.9:
			tilt = 90.0
	tilt = clampf(tilt, TILT_MIN, TILT_MAX)

	# The original draws with rotation = -image_angle (see level scene
	# metadata: image_angle 90 -> rotation -PI/2).
	rotation = deg_to_rad(-tilt)
	_muzzle_sprite.frame = bank_frame

	# Hit flash — red pulse for a split second after taking damage.
	# The ship ticks the timer down itself (static state has no process).
	var hull_color := NativeGame.hero_tint
	if NativeGame.hurt_flash > 0.0:
		NativeGame.hurt_flash = maxf(0.0, NativeGame.hurt_flash - delta)
		hull_color = Color(3.0, 0.7, 0.7)
	_muzzle_sprite.modulate = hull_color

	# Spawn protection / shield blink — alpha strobes while invulnerable.
	if invulnerable and int(Time.get_ticks_msec() / 90) % 2 == 0:
		_muzzle_sprite.modulate.a = 0.4
