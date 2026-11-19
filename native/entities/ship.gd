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

# Per-slot reload thresholds (frames of charge needed). The original reads
# these from shop upgrade tables; these are the stock-weapon values.
const FIRE_DELAY := [18, 14, 18, 22, 22]
const SHOT_DAMAGE := 34.0
const OVERHEAT_PER_SHOT := 8.0
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


func _physics_process(delta: float) -> void:
	if NativeGame.paused:
		return
	_tick_shield(delta)
	_poll_input()
	_apply_movement(delta)
	_apply_firing(delta)
	_update_visuals(delta)


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
	fire_held = fire_override or Input.is_key_pressed(KEY_SPACE)


# ---------------------------------------------------------------------------
# Movement — inertia model transcribed from script_sterowanie.
# ---------------------------------------------------------------------------

func _apply_movement(delta: float) -> void:
	var slower := maxf(0.01, NativeGame.samus_slower)
	var wing := float(NativeGame.upgrade_wing)
	var boost := float(NativeGame.upgrade_boost)

	var left := Input.is_key_pressed(KEY_LEFT)
	var right := Input.is_key_pressed(KEY_RIGHT)
	var up := Input.is_key_pressed(KEY_UP)
	var down := Input.is_key_pressed(KEY_DOWN)

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
		# Charge builds every frame regardless of trigger state.
		_charge[i] += (1.0 + NativeGame.samus_firerate) * rate_mult * delta * 60.0
		if can_fire and fire_held and _charge[i] >= FIRE_DELAY[i]:
			_charge[i] = 0.0
			_fire_muzzle(i)

	# Heat bleeds off whenever the trigger isn't cycling weapons.
	if not (can_fire and fire_held):
		NativeGame.overheating = maxf(0.0, NativeGame.overheating - OVERHEAT_COOLING * delta * 60.0)


## Spawn bolts at muzzle `index`. The offset direction (ship → muzzle)
## becomes each bolt's flight direction, matching how script_laser_* stored
## unx/uny on the spawned bolt. Weapon upgrades fan extra bolts around the
## center shot — the native stand-in for the original's weapon levels.
func _fire_muzzle(index: int) -> void:
	var m: Array = MUZZLES[index]
	var muzzle_angle := float(m[0]) + tilt - 90.0
	var rad := deg_to_rad(muzzle_angle)
	# Original formula: x uses sin, y uses cos — compass-style degrees.
	var offset := Vector2(sin(rad), cos(rad)) * float(m[1])
	var spawn_pos := position + offset
	var base_dir := offset.normalized()
	var base_angle := base_dir.angle()

	# weapon_power 0 = single bolt, 1 = 3-way fan, 2 = 5-way fan.
	# Overdrive adds 2 bolts and widens the fan for its duration.
	var overdrive := NativeGame.overdrive_time > 0.0
	var bolts := 1 + NativeGame.weapon_power * 2 + (2 if overdrive else 0)
	var fan_step := 0.26 if overdrive else 0.18
	for i in bolts:
		var fan := (i - (bolts - 1) / 2.0) * fan_step
		var dir := Vector2.RIGHT.rotated(base_angle + fan)
		var bullet := NativeBullet.new()
		bullet.global_position = spawn_pos
		bullet.velocity = dir * NativeBullet.START_SPEED
		bullet.damage = SHOT_DAMAGE * NativeGame.damage_mult
		get_parent().add_child(bullet)

	NativeGame.overheating += OVERHEAT_PER_SHOT
	# Muzzle report — sound id 29 from the original sampel table.
	var stream := NativeAssets.sound(29)
	if stream != null and NativeGame.dzwiek == 1:
		_sfx.stream = stream
		_sfx.volume_db = linear_to_db(maxf(0.01, NativeGame.glosnosc_dzwieku))
		_sfx.play()


# ---------------------------------------------------------------------------
# Visuals — bank frame follows horizontal input, hull rotates with tilt.
# ---------------------------------------------------------------------------

func _update_visuals(delta: float) -> void:
	# Hull tilt: arrow keys bank the ship, release returns to level flight.
	if Input.is_key_pressed(KEY_LEFT):
		tilt += 1.0
		bank_frame = FRAME_BANK_LEFT
	elif Input.is_key_pressed(KEY_RIGHT):
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

	# Spawn protection blink.
	_muzzle_sprite.modulate.a = 0.4 if invulnerable and int(Time.get_ticks_msec() / 90) % 2 == 0 else 1.0
