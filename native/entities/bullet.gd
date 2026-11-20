extends Node2D
class_name NativeBullet
## NativeBullet — player projectile (ports GameMaker `o_laser_u` plus the
## weapon-1000 series projectiles `o_bullet_rakiety_*` / `o_kumpel_1`).
##
## Standard bolts accelerate after firing (speed ramps 4 -> ~8 px/frame)
## and grow slightly as they travel. The super-weapon fields below port
## the distinct rocket behaviours from script_laser_1000..1008:
##   homing       - deg/frame the bolt steers toward the nearest enemy
##   weave        - RODEO ROCKET drunk oscillation (radians of deflection)
##   gravity      - px/frame^2 downward pull on arcing war balls
##   bounce_floor - SENTINEL/SHOOTING BALL bounce off the room bottom
##   life_frames  - hard lifetime in physics frames (0 = off-screen rule)
##   shrapnel     - on hit, fan of N bolts at damage/shrapnel each
##   auto_shot    - SENTINEL: fire an aimed bolt every N frames
##   orbit_mode   - GUARDIAN satellite: orbits its spawn anchor and
##                  shoots; harmless to enemies itself
var velocity := Vector2.ZERO     # world px/frame
var damage := 34.0
var explosive := false          # EXPLOSIVE AMMO — splash damage on hit
var coin_on_hit := false        # CREATE COINS — GOLD GUN drops a coin
var pierce := false             # PIERCER SLUG — passes through enemies

# --- super-weapon (proj) tuning -------------------------------------
var max_speed := 9.0            # original rockets cap at 20 px/frame
var accel_per_frame := 0.4
var homing := 0.0               # deg/frame
var weave := 0.0                # radians
var weave_speed := 0.1
var gravity := 0.0              # px/frame^2
var bounce_floor := false
var life_frames := 0
var shrapnel := 0
var auto_shot_every := 0
var auto_shot_damage := 0.0
var orbit_mode := false
var orbit_anchor := Vector2.ZERO
var orbit_shot_every := 0
var orbit_shot_damage := 0.0
var sprite_id := 95             # s_bulletprof_1
var sprite2_id := -1            # optional additive second sprite
var scale0 := 0.2               # base sprite scale (rockets differ)
# Regular-weapon projectile quirks ported from the laser_u*/bullet_2xx
# objects: `charge_frames` bolts ride the ship's muzzle while they grow
# (o_bullet_200/201/202/203, laser_u6/15/16/19 follow the parent until
# g_wielkoscx reaches its threshold), `wobble` is the frozen_ball's
# ±0.5°/frame heading weave, `grow_rate` replaces the default visual
# stretch for the laser_u88 family's fast-growing shots.
var charge_frames := 0
var charge_offset := Vector2.ZERO
var charge_dir := Vector2.UP
var owner_ship: Node2D = null
var wobble := 0.0               # deg/frame heading oscillation
var grow_rate := SCALE_GROWTH

const START_SPEED := 4.0         # px/frame — original ramps +0.4/frame
const MAX_SPEED := 9.0
const ACCEL := 0.4
const SCALE_GROWTH := 0.005      # visual stretch per frame (g_wielkoscx)
const MARGIN := 200.0            # original kills bolts 200px outside the room

var _sprite: Sprite2D
var _sprite2: Sprite2D
var _scale := 0.2
var _dead := false
var _weave_base := 0.0
var _hit := {}                  # pierce: enemy_id -> last-hit physics frame
var _age := 0
var _dir_angle := 0.0           # weave base heading
var _orbit_angle := 0.0
var _orbit_radius := 0.0
var _orbit_phase := 0           # 0 delay, 1 expand, 2 fire, 3 contract
var _phase_timer := 0
var _shot_cd := 0


func _ready() -> void:
	_scale = scale0
	_sprite = Sprite2D.new()
	_sprite.texture = NativeAssets.sprite_frame(sprite_id, 0)
	if _sprite.texture != null:
		_sprite.offset = -NativeAssets.sprite_origin(sprite_id)
	_sprite.scale = Vector2(_scale, _scale)
	# Bullets fly toward enemies — mark them so the ship's hurtbox ignores
	# friendly fire and enemies can detect them via group scan.
	add_child(_sprite)
	if sprite2_id >= 0:
		_sprite2 = Sprite2D.new()
		_sprite2.texture = NativeAssets.sprite_frame(sprite2_id, 0)
		if _sprite2.texture != null:
			_sprite2.offset = -NativeAssets.sprite_origin(sprite2_id)
		_sprite2.material = CanvasItemMaterial.new()
		_sprite2.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		add_child(_sprite2)
	_dir_angle = velocity.angle() if velocity.length() > 0.0 else -PI / 2.0
	_weave_base = _dir_angle
	if orbit_mode:
		orbit_anchor = position


func _physics_process(_delta: float) -> void:
	if NativeGame.paused or _dead:
		return
	_age += 1

	if orbit_mode:
		_tick_orbit()
		return

	# Charge phase — the bolt is still "in the gun": it tracks the ship's
	# muzzle offset and grows instead of flying (g_wielkoscy < 0.4 gate).
	if charge_frames > 0:
		charge_frames -= 1
		if is_instance_valid(owner_ship):
			position = owner_ship.global_position + charge_offset
		_scale = minf(_scale + grow_rate * 4.0, 0.6)
		_sprite.scale = Vector2(_scale, _scale)
		_sprite.rotation = charge_dir.angle()
		if charge_frames <= 0:
			velocity = charge_dir * START_SPEED * 1.5
		else:
			return

	# Accelerate like the original (speed += accel/frame up to the cap).
	var speed := velocity.length()
	if speed > 0.0 and speed < max_speed:
		velocity = velocity.normalized() \
			* minf(speed + accel_per_frame, max_speed)

	# RODEO ROCKET — the "drunk" rocket sweeps its heading back and forth
	# (the original ping-pongs `direction` between ~10 and ~170 degrees).
	if weave > 0.0:
		var spd := velocity.length()
		if spd > 0.0:
			velocity = Vector2.from_angle(
				_weave_base + sin(_age * weave_speed) * weave) * spd

	# Homing rockets steer toward the nearest enemy (bullet_rockets_1/3/4/6
	# rotate `direction` by up to N degrees per frame).
	if homing > 0.0:
		var target := _nearest_enemy()
		if target != null:
			var want: float = (target.global_position - global_position).angle()
			var diff := wrapf(want - velocity.angle(), -PI, PI)
			var turn := deg_to_rad(homing)
			velocity = velocity.rotated(clampf(diff, -turn, turn))

	# frozen_ball / frozen_ball_2 — the plasma ball wobbles its heading
	# ±0.5° per frame while it drifts (g_testuj 1/2 direction nudge).
	if wobble > 0.0:
		velocity = velocity.rotated(deg_to_rad(sin(_age * 0.35) * wobble))

	# War balls fall — gravity pulls vspeed down every frame; SENTINEL
	# and SHOOTING BALL bounce off the room bottom (vspeed = -10).
	if gravity > 0.0:
		velocity.y += gravity
		if bounce_floor and position.y > NativeGame.room_size().y:
			velocity.y = -10.0

	position += velocity

	# SENTINEL — autonomously fires an aimed bolt every N frames.
	if auto_shot_every > 0 and _age % auto_shot_every == 0:
		_auto_fire()

	# Hit test — the original used place_meeting() against the enemy parent
	# object; a group scan is the same check in native terms. Bullets are
	# small and few, so the scan is cheap. Castle blocks share the scan —
	# they're destructible but aren't enemies (no score on break).
	for group in ["enemies", "blocks"]:
		for target in NativeGame.group_roster(group):
			if not is_instance_valid(target) \
					or position.distance_to(target.global_position) >= 34.0:
				continue
			var tid: int = target.get_instance_id()
			var frame := Engine.get_physics_frames()
			# Piercing bolts keep flying — a per-target cooldown stops one
			# enemy eating the whole volley in a single frame.
			if pierce:
				if frame - int(_hit.get(tid, -9999)) < 12:
					continue
				_hit[tid] = frame
			target.take_damage(damage)
			if explosive:
				_splash(target)
			if coin_on_hit:
				_drop_coin()
			if shrapnel > 0:
				_shrapnel_burst()
			if shrapnel > 0 or gravity > 0.0:
				_boom()
			if not pierce:
				_dead = true
				queue_free()
				return

	# Slight visual stretch as the bolt travels (laser_u88 family's
	# shots grow much faster — grow_rate overrides the default).
	_scale += grow_rate
	_sprite.scale = Vector2(_scale, _scale)
	_sprite.rotation = velocity.angle()
	if _sprite2 != null:
		_sprite2.scale = Vector2(_scale, _scale)
		_sprite2.rotation = velocity.angle()

	# Original: destroy once comfortably outside the room bounds.
	# Uses the design room size, not the viewport (headless viewports lie).
	var room := NativeGame.room_size()
	if life_frames > 0 and _age >= life_frames:
		_boom()
		queue_free()
	elif position.x < -MARGIN or position.x > room.x + MARGIN \
			or position.y < -MARGIN or position.y > room.y + MARGIN:
		queue_free()


## Rocket impact — the original spawns o_exploder_1 (obj 15) plus a
## particle ring wherever a warhead detonates.
func _boom() -> void:
	var boom := NativeExplosion.new()
	boom.burst_scale = 1.1
	boom.global_position = global_position
	get_parent().add_child(boom)
	for i in 3:
		var spark := NativeExplosion.new()
		spark.variant = "spark"
		spark.global_position = global_position
		get_parent().add_child(spark)


## bullet_rockets_6 — SPREAD ROCKETS: on impact it bursts into ten small
## bolts fanned across the heading (sila/10 damage each).
func _shrapnel_burst() -> void:
	for i in shrapnel:
		var bolt := NativeBullet.new()
		bolt.global_position = global_position
		bolt.velocity = velocity.normalized() \
			.rotated(deg_to_rad(-20.0 + i * 4.0)) * START_SPEED * 1.5
		bolt.damage = damage / float(shrapnel)
		bolt.max_speed = max_speed
		bolt.accel_per_frame = accel_per_frame
		bolt.sprite_id = sprite_id
		get_parent().add_child(bolt)


## bullet_rockets_8 — SENTINEL: every auto_shot_every frames it lobs a
## small bolt (o_laser_u, obj 106) straight at the nearest enemy, or a
## random heading when the field is clear (sila/20 damage).
func _auto_fire() -> void:
	_shot_cd += 1
	var bolt := NativeBullet.new()
	bolt.global_position = global_position
	var target := _nearest_enemy()
	var dir := Vector2.DOWN
	if target != null:
		dir = (target.global_position - global_position).normalized()
	else:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	bolt.velocity = dir * START_SPEED * 1.5
	bolt.damage = auto_shot_damage
	bolt.max_speed = 14.0
	bolt.accel_per_frame = 0.6
	get_parent().add_child(bolt)


## buddy_1 (o_kumpel_1) — GUARDIAN: a satellite that orbits its launch
## point. It idles 100 frames, expands its orbit radius to 10px over 30,
## then fires buddy_bullet_200 bolts (full weapon damage) every 6 frames
## for ~60 frames, contracts, and repeats until its 650-frame life ends
## in an explosion. It never collides with enemies itself.
func _tick_orbit() -> void:
	_phase_timer += 1
	_orbit_angle += deg_to_rad(4.0)      # direction += 4 per frame
	match _orbit_phase:
		0:  # launch delay
			if _phase_timer >= 100:
				_orbit_phase = 1
				_phase_timer = 0
		1:  # expand radius 0 -> 10
			_orbit_radius = minf(_orbit_radius + 1.0, 10.0)
			if _orbit_radius >= 10.0:
				_orbit_phase = 2
				_phase_timer = 0
		2:  # fire window — a bolt every 6 frames for ~60 frames
			if _phase_timer % orbit_shot_every == 0:
				_orbit_shot()
			if _phase_timer >= 60:
				_orbit_phase = 3
				_phase_timer = 0
		3:  # contract back to the anchor
			_orbit_radius = maxf(_orbit_radius - 1.0, 0.0)
			if _orbit_radius <= 0.0:
				_orbit_phase = 0
				_phase_timer = 0

	# The node stays on its launch anchor — the two pod sprites circle it
	# (o_kumpel_1 draws sprites 221/222 at +/- radius around its x/y).
	var off := Vector2(sin(_orbit_angle), -cos(_orbit_angle)) * _orbit_radius
	_sprite.position = off
	_sprite.rotation = _orbit_angle
	if _sprite2 != null:
		_sprite2.position = -off
		_sprite2.rotation = -_orbit_angle

	if _age >= life_frames:
		_boom()
		queue_free()


## buddy_bullet_200 — the guardian's bolt: heavy slug, full weapon damage,
## accelerates hard (+1/frame in the original).
func _orbit_shot() -> void:
	var bolt := NativeBullet.new()
	bolt.global_position = global_position
	var target := _nearest_enemy()
	var dir := Vector2.DOWN
	if target != null:
		# point_direction ± random(3) spread in the original
		dir = (target.global_position - global_position).normalized() \
			.rotated(deg_to_rad(randf_range(-3.0, 3.0)))
	else:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	bolt.velocity = dir * START_SPEED
	bolt.damage = orbit_shot_damage
	bolt.max_speed = 16.0
	bolt.accel_per_frame = 1.0
	bolt.sprite_id = 207
	get_parent().add_child(bolt)


## EXPLOSIVE AMMO — the ISOMATIC CANNON's warhead: on impact it also
## damages every other enemy within splash range for half damage.
func _splash(primary: Node2D) -> void:
	for enemy in NativeGame.group_roster("enemies"):
		if is_instance_valid(enemy) and enemy != primary \
				and position.distance_to(enemy.global_position) < 70.0:
			enemy.take_damage(damage * 0.5)


## CREATE COINS — the GOLD GUN literally mints currency: each hit drops
## a coin pickup where the bolt landed.
func _drop_coin() -> void:
	var coin := NativePickup.new()
	coin.kind = NativePickup.Kind.COIN
	coin.global_position = position
	get_parent().add_child(coin)


## Closest living enemy — shared by homing, SENTINEL and GUARDIAN shots
## (the original's instance_nearest(..., 12) = enemy parent object).
func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for enemy in NativeGame.group_roster("enemies"):
		if not is_instance_valid(enemy):
			continue
		var d: float = global_position.distance_squared_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best
