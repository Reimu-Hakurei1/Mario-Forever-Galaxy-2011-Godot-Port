extends Node2D
class_name NativeEnemy
## NativeEnemy — flying enemy (ports the GameMaker `o_enemy_*` family).
##
## The original has ~40 enemy objects sharing one state machine: spawn
## off-screen → take a formation slot → sway while tracking the player →
## die to bullets or ram the ship. This port keeps that loop and adds a
## `kind` profile per enemy family so each gets its own sprite, stats and
## behaviour — the native equivalent of the original's per-object events.
##
## Kinds ported so far:
##   goomba   — formation hover, the baseline grunts (o_enemy_1)
##   shooter  — UFO that holds station and fires aimed shots (o_ufo_a)
##   kamikaze — beelines for the player, no formation (o_perioder divers)
##   tank     — slow heavy with lots of hull (o_fat_boy_a)
##   eye      — turret that spins and fires bursts (o_sky_eye)
##
## Kills award score and roll the original's drop table (coin / gem /
## health), then play the explosion animation.

## Movement/behaviour modes.
enum Mode { SPAWN, FORMATION, CHASE, KAMIKAZE, DYING }
## Enemy families — each maps to objects in the original registry.
## Sprite ids come from data/assets.json (s_enemy_*/s_ufo_* sheets).
enum Kind {
	GOOMBA, SHOOTER, KAMIKAZE, TANK, EYE,
	MINI, UFO_A, UFO_B, ROS, CRAB, JUMBO, ELITE,
	DART, STINGER, WEAVER, DRONE, HUNTER, WARLORD, LANCER, ACE,
	GHOST, ROCKET_UFO,
	CANNON, FLAME_CANNON, ROTARY, FAT_CANNON,
	FLAME, FAN, FALLER, BONUS, FLAME_SHOOTER, FAT_BOY, BONUS_BLOCK,
	EYE2, UFO_A2, GHOST2, GHOST3, RUNNER,
}

## Per-kind tuning. `sprite` is the GameMaker sprite index; `score` is the
## kill award; shooter-ish kinds get `shoot_interval`/`spread`; `chase`
## overrides chase_speed and `dive` overrides kamikaze_speed.
const KIND_PROFILES := {
	Kind.GOOMBA: {"sprite": 11, "score": 100},
	Kind.SHOOTER: {"sprite": 174, "score": 150, "shoot_interval": 170.0, "spread": 1},
	Kind.KAMIKAZE: {"sprite": 11, "score": 120, "tint": Color(1.0, 0.55, 0.5)},
	Kind.TANK: {"sprite": 178, "score": 300, "shoot_interval": 240.0, "spread": 3, "scale": 0.55},
	Kind.EYE: {"sprite": 185, "score": 1500, "shoot_interval": 110.0, "spread": 1, "burst": 3},
	# Small swarm dart — fast, fragile, cheap kill.
	Kind.MINI: {"sprite": 70, "score": 50, "chase": 2.6, "scale": 0.7},
	# UFO variants — the original's iconic fighters.
	Kind.UFO_A: {"sprite": 174, "score": 180, "shoot_interval": 200.0, "spread": 2},
	Kind.UFO_B: {"sprite": 110, "score": 160, "dive": 2.8, "tint": Color(0.7, 1.0, 0.8)},
	# Long worm-like enemy — slow, armored, lobs shots.
	Kind.ROS: {"sprite": 296, "score": 250, "shoot_interval": 260.0, "spread": 1, "scale": 0.8},
	# Heavy crab — wide spread barrage.
	Kind.CRAB: {"sprite": 73, "score": 350, "shoot_interval": 220.0, "spread": 5, "scale": 0.6},
	# Jumbo brute — big sprite, slow heavy chaser.
	Kind.JUMBO: {"sprite": 50, "score": 400, "chase": 0.9, "scale": 0.5},
	# Elite goomba — the armored 'aup' variant, tanky mid-tier.
	Kind.ELITE: {"sprite": 479, "score": 220, "chase": 1.5},
	# Second-wave variants — sprites pulled straight from the original's
	# enemy catalog (s_enemy_b/l/m/u, s_enemy_h_*, s_enemy_aup2).
	Kind.DART: {"sprite": 29, "score": 130, "chase": 2.2, "scale": 0.7},
	Kind.STINGER: {"sprite": 34, "score": 170, "shoot_interval": 190.0, "spread": 1},
	Kind.WEAVER: {"sprite": 69, "score": 140, "dive": 3.0, "tint": Color(0.8, 0.9, 1.0)},
	Kind.DRONE: {"sprite": 112, "score": 190, "shoot_interval": 150.0, "spread": 2},
	Kind.HUNTER: {"sprite": 328, "score": 260, "shoot_interval": 130.0, "spread": 1, "burst": 2},
	Kind.WARLORD: {"sprite": 478, "score": 380, "chase": 1.3, "scale": 0.6},
	Kind.LANCER: {"sprite": 68, "score": 220, "shoot_interval": 170.0, "spread": 3},
	Kind.ACE: {"sprite": 332, "score": 240, "dive": 3.4, "scale": 0.7,
		"tint": Color(1.0, 0.6, 0.6)},
	# Shy ghost (o_shyghost) — a fast charger that beelines for the hull.
	Kind.GHOST: {"sprite": 493, "score": 300, "dive": 3.2, "scale": 0.8,
		"tint": Color(0.7, 0.85, 1.0)},
	# Rocket UFO (o_rocketufo_a) — hovering gunship that lobs shots.
	Kind.ROCKET_UFO: {"sprite": 176, "score": 220, "shoot_interval": 160.0,
		"spread": 2, "scale": 0.7},
	# Castle defenses (script_castle_cannon / _flame_cannon /
	# _rotary_cannon) — stationary-ish turrets that scroll with the
	# stage, track the ship with a rotating barrel, and lob shots.
	# `health` is the profile default the wave may still override;
	# `barrel` is the rotating overlay sprite; `contact_damage` is the
	# ram penalty (original: -400/-300/-500 hull).
	Kind.CANNON: {"sprite": 300, "score": 250, "health": 60.0,
		"contact_damage": 30.0, "barrel": 301},
	Kind.FLAME_CANNON: {"sprite": 306, "score": 250, "health": 50.0,
		"contact_damage": 25.0, "barrel": 307},
	Kind.ROTARY: {"sprite": 300, "score": 300, "health": 80.0,
		"contact_damage": 35.0, "barrel": 301},
	# o_fatboy_cannon — the fat boy's own gun: slower 300f cadence,
	# longer 90px muzzle, heavier cannonball.
	Kind.FAT_CANNON: {"sprite": 178, "score": 350, "health": 90.0,
		"contact_damage": 40.0, "barrel": 301, "fire_interval": 300.0},
	# o_flame_cans — the flame-throwing can: drifts to a random point,
	# tilts, charges (~300f), then streams a flame jet. Weak on ram
	# (original: -5 hull) but the stream is the real threat.
	Kind.FLAME: {"sprite": 29, "score": 200, "health": 60.0,
		"contact_damage": 8.0, "tint": Color(1.0, 0.6, 0.3)},
	# o_fan — castle windmill hazard (s_wiatrak_center + blade sprites):
	# scrolls down spinning, small contact damage, can't be killed —
	# it's a `hazard`, not a shootable enemy.
	Kind.FAN: {"sprite": 312, "score": 0, "health": 99999.0,
		"contact_damage": 8.0, "hazard": true},
	# bonus_1/2/3/4 (o_bonus_*) — indestructible bonus-stage blockers:
	# they can't be killed (g_oberwanie = -1) and ram the ship for a
	# heavy hit, exactly like the fan hazard but worth nothing.
	Kind.BONUS_BLOCK: {"sprite": 136, "score": 0, "health": 99999.0,
		"contact_damage": 25.0, "hazard": true,
		"tint": Color(1.0, 0.85, 0.4)},
	# fat_boy_a — the koopa's mid-boss bruiser: very tanky, lumbers in
	# and hurls cannon volleys (its three fat_boy_cannon children are
	# approximated by a wide spread).
	Kind.FAT_BOY: {"sprite": 178, "score": 800, "health": 300.0,
		"shoot_interval": 200.0, "spread": 5, "chase": 0.8,
		"contact_damage": 40.0, "scale": 0.6},
	# flame_cans_shooter — the hovering can that parks on an anchor and
	# bursts 10-shot volleys (g_ilosc_pociskow = 10, sekwencer 2).
	Kind.FLAME_SHOOTER: {"sprite": 182, "score": 300, "health": 100.0,
		"shoot_interval": 220.0, "spread": 10, "contact_damage": 8.0,
		"tint": Color(1.0, 0.6, 0.3)},
	# o_enemy_9 — the suicide runner: accelerates from a crawl up to
	# ~5 px/frame while steering at the ship, and self-destructs after
	# 300 frames if it hasn't connected.
	Kind.RUNNER: {"sprite": 41, "score": 250, "dive": 0.5, "ramp": 0.05,
		"life": 300, "contact_damage": 30.0, "tint": Color(1.0, 0.7, 0.5)},
	# o_ducher_falling — a spirit that drops straight down past the
	# ship with a slight sway (the original's g_lolo spawn at y=-300).
	Kind.FALLER: {"sprite": 493, "score": 100, "health": 8.0,
		"contact_damage": 12.0, "tint": Color(0.8, 0.9, 1.0)},
	# o_enemy_17g/h/i — bonus targets: they fall fast, and touching
	# one awards big score and destroys it WITHOUT hurting the ship.
	Kind.BONUS: {"sprite": 493, "score": 400, "health": 1.0,
		"contact_damage": 0.0, "tint": Color(1.0, 0.9, 0.4)},
	# Remaining authored variants — o_sky_eye_2 (blue phase of the
	# sky eye, same laser cycle), o_ufo_a2 (the cracked ufo_a sprite
	# 175 — the original swaps to it under 50% hull), o_shy_ghost_2/3
	# (elite 10k-energy ghosts from the later maps).
	Kind.EYE2: {"sprite": 185, "score": 1500, "shoot_interval": 110.0,
		"spread": 1, "burst": 3, "tint": Color(0.55, 0.7, 1.0)},
	Kind.UFO_A2: {"sprite": 175, "score": 140, "shoot_interval": 180.0,
		"spread": 2, "scale": 0.65},
	Kind.GHOST2: {"sprite": 493, "score": 500, "dive": 3.0, "scale": 0.9,
		"tint": Color(0.6, 1.0, 0.75)},
	Kind.GHOST3: {"sprite": 493, "score": 600, "dive": 3.4, "scale": 0.9,
		"tint": Color(1.0, 0.75, 0.6)},
}

# Drop table — ports objects/items/drop.gd (o_drop): every kill rolls a
# drop object; ~2% of those become a special-item star (o_specjaldrop1),
# the rest pay coins or gems in `sizeof` tiers. The special_weapon_*
# pickups (energy/cooling mushrooms, flower of fire, star of fireballs,
# cool star of explosions) come out of the same roll, gated by world.
const DROP_CHANCE := 0.55      # g_szansa baseline — most kills drop
const SPECIAL_STAR_CHANCE := 0.02   # g_bonus_czy_specjal > 98
const SPECIAL_PICKUP_CHANCE := 0.06 # special_weapon_* branch
# World index (0-7) gates the stronger pickups, like the original's
# map_number ranges in drop.gd.
var _world := 0

var kind := Kind.GOOMBA
var scroll_down := 0.0           # px/frame — castle stages drift enemies
var phalanx := false             # castle_enemy grid — scrolls, no AI
var orbit_around: Node2D = null  # ring-mother — slot on a circle around it
var orbit_radius := 0.0
var orbit_angle := 0.0
var orbit_speed := 0.017         # ~1°/frame like the original g_kat
var health := 10.0                # g_energia — scaled to weapon firepower
var mode := Mode.SPAWN
var formation_slot := Vector2.ZERO
var sway_phase := 0.0
var sway_amplitude := 14.0        # px — the "ruch" oscillator from the original
var sway_speed := 0.05            # radians per frame
var chase_speed := 1.2            # px/frame toward the player
var drift_speed := 0.4            # px/frame toward formation slot
var kamikaze_speed := 2.2         # px/frame — kamikaze dive speed
var speed_ramp := 0.0             # enemy_9 accelerates each frame
var speed_cap := 5.0
var life_limit := 0               # frames before self-destruct (0 = never)
var _age_frames := 0
var shoot_interval := 180.0       # frames between shots
var shoot_range := 620.0          # px — only fires when player is in range
var spread := 1                   # bullets per volley
var burst := 1                    # shots per volley trigger (eye)
var contact_damage := 15.0        # hull lost on ram (cannons hit harder)
var fire_interval := 200.0        # cannon cadence — fat boy's gun is 300

var _anim: AnimatedSprite2D
var _flash := 0
var _dead := false
var _shoot_timer := 0.0
var _burst_left := 0
var _score := DEATH_SCORE_DEFAULT
var _hit_radius := 20.0            # contact radius — derived from sprite size

# Sky-eye laser state machine (o_sky_eye celownik phases):
# AIM reticle tracks the player → FIRE locks the beam → COOLDOWN → repeat.
var _eye_state := 0                # 0 aim, 1 fire, 2 cooldown
var _eye_timer := 0.0
var _eye_target := Vector2.ZERO    # locked beam endpoint
var _eye_lock := Vector2.ZERO      # point the reticle currently tracks
var _aim_line: Line2D              # thin reticle line (aim phase)
var _beam_line: Line2D             # thick damage beam (fire phase)

# Castle cannon state — barrel angle, fire cadence, and the pending
# flame-burst / rotary-spin queues from the original g_taktyka vars.
var _barrel: Sprite2D = null
var _barrel_angle := 0.0
var _rotor: Node2D = null          # FAN's spinning blade assembly
var _hazard := false               # can't be killed or scored (o_fan)
var _cannon_timer := 0.0
var _flame_left := 0
var _flame_timer := 0.0
var _spin_left := 0

# Boss-8 "dodatkowy" additions (objects 509/510/512/513, parent
# o_enemy_1): fighters launched on a fixed GameMaker direction instead
# of AI — sprite_id_override picks their hull (41 vs 502).
var sprite_id_override := -1
## boss_giga_2 (obj 419) — the spinning gravity orb: rotates 5°/frame,
## and on player contact it dies but drags the ship 20px/frame toward
## itself while draining 200 energy. Bullet kills pay a flat 5000.
var giga2_pull := false
var dart_dir := Vector2.ZERO      # px/frame velocity while >0
var dart_speed := 0.0

# Flame-can attack cycle (o_flame_cans g_ladowanie phases):
# 0 drift to point → 1 charge → 2 flame jet → 3 cooldown.
var _flame_state := 0
var _flame_target := Vector2.ZERO
var _flame_dir := Vector2.DOWN
var _flame_jet_left := 0

const DEATH_SCORE_DEFAULT := 100
# Sky-eye timings in frames — ported from g_sekwencja/g_ladowanie in
# objects/enemies/sky_eye.gd: the reticle tracks for ~140f, the beam
# stays lit ~100f, then a short cooldown before the next cycle.
const EYE_AIM_TIME := 140.0
const EYE_FIRE_TIME := 100.0
const EYE_COOLDOWN := 50.0
const EYE_BEAM_HALF_WIDTH := 22.0  # px corridor that hurts the ship


func _ready() -> void:
	add_to_group("enemies")
	_apply_profile()

	_anim = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fly")
	for tex in NativeAssets.sprite_frames(_sprite_id):
		frames.add_frame("fly", tex)
	frames.set_animation_speed("fly", ANIM_FPS)
	_anim.sprite_frames = frames
	_anim.play("fly")
	_anim.offset = -NativeAssets.sprite_origin(_sprite_id)
	# Contact radius follows the real sprite bounds — the sky-eye sprite
	# is 201x154, so a fixed radius let the ship fly through it.
	var texs := NativeAssets.sprite_frames(_sprite_id)
	if not texs.is_empty():
		var ts := texs[0].get_size()
		_hit_radius = maxf(18.0, minf(ts.x, ts.y) * 0.45 * _scale_factor)
	if _scale_factor != 1.0:
		_anim.scale = Vector2(_scale_factor, _scale_factor)
	if _tint != Color.WHITE:
		_anim.modulate = _tint
	add_child(_anim)

	# Castle cannons draw a second sprite for the rotating barrel
	# (original draws sprite 301/307 at the entity's direction on top
	# of the static base sprite).
	var p: Dictionary = KIND_PROFILES.get(kind, {})
	if p.has("barrel"):
		_barrel = Sprite2D.new()
		var btex := NativeAssets.sprite_frame(p["barrel"], 0)
		if btex != null:
			_barrel.texture = btex
			_barrel.offset = -NativeAssets.sprite_origin(p["barrel"])
			_barrel.z_index = 1
			add_child(_barrel)
	# o_fan draws six blade sprites (123) orbiting the hub (312) — a
	# rotor node spins them all together.
	if kind == Kind.FAN:
		_rotor = Node2D.new()
		for i in 6:
			var blade := Sprite2D.new()
			var btex := NativeAssets.sprite_frame(123, 0)
			if btex != null:
				blade.texture = btex
				blade.offset = -NativeAssets.sprite_origin(123)
			blade.position = Vector2.RIGHT.rotated(i * TAU / 6.0) * 30.0
			_rotor.add_child(blade)
		add_child(_rotor)

	sway_phase = randf() * TAU
	_shoot_timer = shoot_interval * randf_range(0.5, 1.0)
	if kind == Kind.EYE or kind == Kind.EYE2:
		_eye_timer = EYE_AIM_TIME


var _sprite_id := 11
var _scale_factor := 1.0
var _tint := Color.WHITE
const ANIM_FPS := 8.0
const HIT_FLASH_TIME := 4         # frames of white flash on hit (oberwanie)


## Pull sprite/score/combat stats out of the kind profile. Health stays
## whatever the wave assigned — profiles only set defaults the wave may
## still override before add_child().
func _apply_profile() -> void:
	var p: Dictionary = KIND_PROFILES.get(kind, KIND_PROFILES[Kind.GOOMBA])
	_sprite_id = p.get("sprite", 11)
	if sprite_id_override >= 0:
		_sprite_id = sprite_id_override
	_score = p.get("score", DEATH_SCORE_DEFAULT)
	shoot_interval = p.get("shoot_interval", shoot_interval)
	spread = p.get("spread", 1)
	burst = p.get("burst", 1)
	_scale_factor = p.get("scale", 1.0)
	_tint = p.get("tint", Color.WHITE)
	contact_damage = p.get("contact_damage", contact_damage)
	fire_interval = p.get("fire_interval", fire_interval)
	_hazard = p.get("hazard", false)
	# Profile health is only a default — a wave that assigned health
	# explicitly (anything above the untouched 10.0) keeps its value.
	if p.has("health") and health <= 10.0:
		health = p["health"]
	if p.has("chase"):
		chase_speed = p["chase"]
	if p.has("dive"):
		kamikaze_speed = p["dive"]
	speed_ramp = p.get("ramp", 0.0)
	life_limit = p.get("life", 0)
	# Behaviour family routing: shooters hold station and fire, kamikaze
	# variants dive, everything else uses the goomba pattern. The new
	# kinds join the family that matches their profile.
	if kind == Kind.KAMIKAZE or kind == Kind.UFO_B or kind == Kind.WEAVER \
			or kind == Kind.ACE or kind == Kind.GHOST or kind == Kind.RUNNER:
		mode = Mode.KAMIKAZE
		kamikaze_speed = p.get("dive", 2.4)


func _physics_process(_delta: float) -> void:
	if NativeGame.paused or _dead:
		return
	_age_frames += 1
	# boss_giga_2 spins 5 degrees per frame (g_image_angle += 5).
	if giga2_pull:
		rotation += deg_to_rad(5.0)
	# enemy_9 burns out after 300 frames if it never reached the ship.
	if life_limit > 0 and _age_frames > life_limit:
		die()
		return

	# Castle stages: the whole world scrolls down past the ship.
	if scroll_down > 0.0:
		position.y += scroll_down

	# Phalanx grid members (o_castle_enemy slots) hold their formation —
	# the scroll carries them, they don't hunt or sway.
	if phalanx:
		if _flash > 0:
			_flash -= 1
			_anim.modulate = Color(3, 3, 3)
		else:
			_anim.modulate = _tint if _tint != Color.WHITE else Color.WHITE
		_check_player_collision()
		_cull_offscreen()
		return

	# Ring-mother orbiters are positioned absolutely by their parent —
	# they don't run their own movement AI.
	if orbit_around != null and is_instance_valid(orbit_around):
		orbit_angle += orbit_speed
		global_position = orbit_around.global_position + Vector2(
			sin(orbit_angle), cos(orbit_angle)) * orbit_radius
		if _flash > 0:
			_flash -= 1
			_anim.modulate = Color(3, 3, 3)
		else:
			_anim.modulate = Color.WHITE
		_check_player_collision()
		return

	# The sky-eye runs its own telegraphed laser cycle instead of volleys.
	if dart_speed > 0.0:
		_behave_dart()
	elif kind == Kind.EYE or kind == Kind.EYE2:
		_behave_skyeye()
	elif kind in [Kind.CANNON, Kind.FLAME_CANNON, Kind.ROTARY,
			Kind.FAT_CANNON]:
		_behave_cannon()
	elif kind == Kind.FLAME:
		_behave_flame()
	elif kind == Kind.FAN:
		_behave_fan()
	elif kind == Kind.FALLER:
		_behave_faller()
	elif kind == Kind.BONUS:
		_behave_bonus()
	elif kind in [Kind.SHOOTER, Kind.TANK, Kind.UFO_A, Kind.ROS,
			Kind.CRAB, Kind.STINGER, Kind.DRONE, Kind.HUNTER, Kind.LANCER,
			Kind.ROCKET_UFO, Kind.FLAME_SHOOTER]:
		_behave_shooter()
	elif kind == Kind.FAT_BOY:
		_chase_player_slow()
		_tick_shooter()
	elif kind == Kind.KAMIKAZE or kind == Kind.UFO_B or kind == Kind.WEAVER \
			or kind == Kind.ACE or kind == Kind.GHOST or kind == Kind.RUNNER:
		_behave_kamikaze()
	else:
		_behave_goomba()

	if _flash > 0:
		_flash -= 1
		_anim.modulate = Color(3, 3, 3)   # additive-style white hit flash
	elif _tint != Color.WHITE:
		_anim.modulate = _tint
	else:
		_anim.modulate = Color.WHITE

	_check_player_collision()
	_cull_offscreen()


## Baseline: glide to slot, sway, drift toward the player slowly.
func _behave_goomba() -> void:
	match mode:
		Mode.SPAWN:
			var to_slot := formation_slot - position
			if to_slot.length() < 8.0:
				mode = Mode.FORMATION
			else:
				position += to_slot.normalized() * drift_speed
		Mode.FORMATION:
			_sway_and_track()
		Mode.CHASE:
			_chase_player()
		_:
			pass


## Holds its formation slot and fires volleys when the player is near.
## Tanks chase slowly instead of holding station.
func _behave_shooter() -> void:
	if kind == Kind.TANK:
		_chase_player_slow()
		_tick_shooter()
		return

	# Spawn-in glide first, then orbit the slot while shooting.
	if mode == Mode.SPAWN:
		var to_slot := formation_slot - position
		if to_slot.length() < 8.0:
			mode = Mode.FORMATION
		else:
			position += to_slot.normalized() * drift_speed
		return
	_sway_and_track()
	# Eye turrets slowly rotate to face the player — reads as tracking.
	if kind == Kind.EYE or kind == Kind.EYE2:
		var ship := get_tree().get_first_node_in_group("player")
		if ship != null:
			_anim.rotation = (ship.global_position - position).angle()
	_tick_shooter()


func _tick_shooter() -> void:
	_shoot_timer -= 1.0
	# Burst enemies fire `burst` shots `spread` apart on each trigger.
	if _burst_left > 0:
		_burst_left -= 1
		var ship := get_tree().get_first_node_in_group("player")
		if ship != null:
			_fire_volley(ship.global_position)
		return
	var ship := get_tree().get_first_node_in_group("player")
	if _shoot_timer <= 0.0 and ship != null:
		var dist := position.distance_to(ship.global_position)
		if dist < shoot_range:
			_fire_volley(ship.global_position)
			_burst_left = burst - 1
			_shoot_timer = shoot_interval
		else:
			_shoot_timer = 30.0   # re-check soon rather than full interval


## o_sky_eye — the big eye. Holds its slot, then cycles a telegraphed
## laser: AIM shows a thin reticle tracking the ship, FIRE locks the
## endpoint and burns a wide beam, COOLDOWN, repeat. Ported from
## objects/enemies/sky_eye.gd (g_sekwencja / g_ladowanie / g_celownik).
func _behave_skyeye() -> void:
	if mode == Mode.SPAWN:
		var to_slot := formation_slot - position
		if to_slot.length() < 8.0:
			mode = Mode.FORMATION
		else:
			position += to_slot.normalized() * drift_speed
		return
	_sway_and_track()
	_ensure_eye_lines()

	var ship := get_tree().get_first_node_in_group("player")
	_eye_timer -= 1.0
	match _eye_state:
		0:  # AIM — reticle chases the ship
			if ship != null:
				_eye_lock = ship.global_position
				_anim.rotation = (ship.global_position - position).angle()
			_aim_line.visible = true
			_aim_line.points = [Vector2.ZERO, to_local(_eye_lock)]
			if _eye_timer <= 0.0:
				_eye_state = 1
				_eye_timer = EYE_FIRE_TIME
				_eye_target = _eye_lock       # beam locks where it aimed
				_beam_line.visible = true
				_aim_line.visible = false
		1:  # FIRE — beam is live; the corridor hurts the ship
			_beam_line.points = [Vector2.ZERO, to_local(_eye_target)]
			if ship != null and not ship.invulnerable \
					and _point_segment_distance(ship.global_position,
						position, _eye_target) < EYE_BEAM_HALF_WIDTH:
				NativeGame.damage_player(15.0)
			if _eye_timer <= 0.0:
				_eye_state = 2
				_eye_timer = EYE_COOLDOWN
				_beam_line.visible = false
		2:  # COOLDOWN
			if _eye_timer <= 0.0:
				_eye_state = 0
				_eye_timer = EYE_AIM_TIME


## Lazily build the reticle + beam Line2Ds (children, freed with the eye).
func _ensure_eye_lines() -> void:
	if _aim_line == null:
		_aim_line = Line2D.new()
		_aim_line.width = 2.0
		_aim_line.default_color = Color(1.0, 0.25, 0.25, 0.8)
		_aim_line.z_index = 5
		add_child(_aim_line)
	if _beam_line == null:
		_beam_line = Line2D.new()
		_beam_line.width = EYE_BEAM_HALF_WIDTH * 2.0
		_beam_line.default_color = Color(1.0, 0.35, 0.1, 0.9)
		_beam_line.z_index = 6
		_beam_line.visible = false
		add_child(_beam_line)


## Distance from `p` to the segment a→b (for the beam hit corridor).
static func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Castle defenses — ported from script_castle_cannon /
## script_castle_flame_cannon / script_castle_rotary_cannon. All three
## scroll with the stage (scroll_down), track the ship with a rotating
## barrel, and fire on the original's ~200-frame cadence:
##   CANNON       — one cannonball every 200f, barrel slews ±0.5°/frame
##   FLAME_CANNON — a 10-shot flame burst (one per 4f, ±5° spread)
##   ROTARY       — 4 shots at 90° apart, then the barrel spins 4.5°/frame
func _behave_cannon() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	# Barrel slews toward the ship — the original turns at 0.5°/frame.
	if ship != null:
		var to_ship: Vector2 = ship.global_position - position
		var want: float = to_ship.angle()
		var diff := wrapf(want - _barrel_angle, -PI, PI)
		_barrel_angle += clampf(diff, -deg_to_rad(0.5), deg_to_rad(0.5))
	if _barrel != null:
		_barrel.rotation = _barrel_angle

	# Rotary spin continues between volleys (g_bodzio countdown).
	if _spin_left > 0:
		_barrel_angle += deg_to_rad(4.5)
		_spin_left -= 1
		if _barrel != null:
			_barrel.rotation = _barrel_angle

	_cannon_timer += 1.0
	# Flame cannon's burst queue runs one shot every 4 frames.
	if _flame_left > 0:
		_flame_timer += 1.0
		if _flame_timer >= 4.0:
			_flame_timer = 0.0
			_flame_left -= 1
			_fire_castle_shot(166, 6.5, _barrel_angle + randf_range(
				-deg_to_rad(5), deg_to_rad(5)), 8.0)
		return
	if _cannon_timer < fire_interval:
		return
	_cannon_timer = 0.0
	match kind:
		Kind.CANNON:
			_fire_castle_shot(158, 4.5, _barrel_angle, 12.0)
		Kind.FAT_CANNON:
			# Longer muzzle reach (90px) and a heavier shell.
			var shot := NativeEnemyBullet.new()
			shot.sprite_id = 158
			shot.damage = 18.0
			shot.global_position = position + \
				Vector2.RIGHT.rotated(_barrel_angle) * 90.0
			shot.velocity = Vector2.RIGHT.rotated(_barrel_angle) * 5.0
			get_parent().add_child(shot)
			NativeAssets.play_sound(79)
		Kind.FLAME_CANNON:
			_flame_left = 10
			_flame_timer = 0.0
		Kind.ROTARY:
			for i in 4:
				_fire_castle_shot(158, 4.5,
					_barrel_angle + i * PI * 0.5, 12.0)
			_spin_left = 10


## Spawn one hostile shot from the barrel muzzle. `sprite_id` 158 is the
## original's animated cannonball, 166 the superfireball for flames.
func _fire_castle_shot(sprite_id: int, speed: float, angle: float,
		dmg: float) -> void:
	var bullet := NativeEnemyBullet.new()
	bullet.sprite_id = sprite_id
	bullet.damage = dmg
	bullet.global_position = position + Vector2.RIGHT.rotated(angle) * 50.0
	bullet.velocity = Vector2.RIGHT.rotated(angle) * speed
	get_parent().add_child(bullet)
	NativeAssets.play_sound(79)


## o_flame_cans — drifts to a random point (g_dox/g_doy), charges up
## (~300f), then streams a flame jet for ~4s before cooling down. The
## original's jet is a particle stream; here it's a stream of fast
## fireballs — same dodge-the-stream gameplay.
func _behave_flame() -> void:
	_flame_timer += 1.0
	match _flame_state:
		0:  # DRIFT — seek a random anchor like g_dox/g_doy
			if _flame_target == Vector2.ZERO:
				_flame_target = position + Vector2(
					randf_range(-200, 200), randf_range(-120, 120))
			var to := _flame_target - position
			if to.length() < 10.0:
				_flame_state = 1
				_flame_timer = 0.0
			else:
				position += to.normalized() * 1.5
				_anim.rotation = to.angle() * 0.08   # slight tilt into drift
		1:  # CHARGE — track the ship, then lock the jet direction
			var ship := get_tree().get_first_node_in_group("player")
			if ship != null:
				var to_ship: Vector2 = ship.global_position - position
				_anim.rotation = to_ship.angle() * 0.12
			if _flame_timer >= 300.0:
				_flame_state = 2
				_flame_timer = 0.0
				_flame_jet_left = 240
				if ship != null:
					var to_ship: Vector2 = ship.global_position - position
					_flame_dir = to_ship.normalized()
				_anim.rotation = _flame_dir.angle()
		2:  # JET — stream fireballs along the locked direction
			if int(_flame_timer) % 3 == 0:
				var shot := NativeEnemyBullet.new()
				shot.sprite_id = 166     # s_superfireball
				shot.damage = 8.0
				shot.global_position = position + _flame_dir * 30.0
				shot.velocity = _flame_dir * 5.5
				get_parent().add_child(shot)
			_flame_jet_left -= 1
			if _flame_jet_left <= 0:
				_flame_state = 3
				_flame_timer = 0.0
		3:  # COOLDOWN
			if _flame_timer >= 200.0:
				_flame_state = 0
				_flame_timer = 0.0
				_flame_target = Vector2.ZERO


## o_fan — the windmill just spins; scroll_down carries it down-screen.
func _behave_fan() -> void:
	if _rotor != null:
		_rotor.rotation += deg_to_rad(3.0)


## o_ducher_falling — drops from above the arena with a gentle sway.
func _behave_faller() -> void:
	sway_phase += sway_speed * 2.0
	position.y += 1.6
	position.x += sin(sway_phase) * 0.4
	_anim.rotation = PI * 0.5


## o_enemy_17* — bonus target: plummets fast with a wobble; touching
## it is pure profit (original awards 2000 x g_nabijacz points).
func _behave_bonus() -> void:
	sway_phase += 0.15
	position.y += 3.5
	position.x += sin(sway_phase) * 0.8
	_anim.rotation = sway_phase


## Relentless dive — beelines for the player the whole time.
func _behave_kamikaze() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if ship == null:
		return
	var to_player: Vector2 = ship.global_position - position
	if to_player.length() > 4.0:
		# enemy_9's signature: it starts slow and accelerates every frame
		# up to ~5 px/frame (R.set_speed += 0.5 while speed < 5).
		if speed_ramp > 0.0:
			kamikaze_speed = minf(kamikaze_speed + speed_ramp, speed_cap)
		position += to_player.normalized() * kamikaze_speed
	_anim.rotation = to_player.angle()


## boss_8_fight.gd "dodatkowy" additions — fly a fixed GM direction
## (set via dart_dir) instead of tracking the player; still killable
## and still rams on contact like every other enemy.
func _behave_dart() -> void:
	position += dart_dir
	_anim.rotation = dart_dir.angle()


## Idle sway around the formation slot + gentle tracking of the player,
## mirroring the original `ruch` sine motion and slot-keeping.
func _sway_and_track() -> void:
	sway_phase += sway_speed
	var sway := Vector2(sin(sway_phase), cos(sway_phase * 0.7)) * sway_amplitude
	var target := formation_slot + sway
	var to_target := target - position
	if to_target.length() > 1.0:
		position += to_target.limit_length(drift_speed * 2.0)


func _chase_player() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if ship == null:
		return
	var to_player: Vector2 = ship.global_position - position
	if to_player.length() > 4.0:
		position += to_player.normalized() * chase_speed
	_anim.rotation = to_player.angle()


## Tanks move like chasers but at a third of the speed.
func _chase_player_slow() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if ship == null:
		return
	var to_player: Vector2 = ship.global_position - position
	if to_player.length() > 4.0:
		position += to_player.normalized() * (chase_speed / 3.0)
	_anim.rotation = to_player.angle()


## Fire `spread` bullets fanned around the aim direction.
func _fire_volley(target: Vector2) -> void:
	var base_dir := (target - position).normalized()
	var base_angle := base_dir.angle()
	for i in spread:
		var offset := (i - (spread - 1) / 2.0) * 0.22   # ~12.6° fan per bullet
		var dir := Vector2.RIGHT.rotated(base_angle + offset)
		var bullet := NativeEnemyBullet.new()
		bullet.global_position = position
		bullet.velocity = dir * NativeEnemyBullet.SPEED
		get_parent().add_child(bullet)
	NativeAssets.play_sound(79)  # enemy shot (original sampel id)


## Called by bullets on hit. Returns true if the hit killed the enemy.
func take_damage(amount: float) -> bool:
	if _dead or _hazard:
		return false
	health -= amount
	_flash = HIT_FLASH_TIME
	if health <= 0.0:
		die()
		return true
	return false


func die() -> void:
	if _dead:
		return
	_dead = true
	NativeGame.kill_enemy()
	# Streak multiplier applies to the kill score — chained kills pay
	# more. boss_giga_2 pays a flat 5000 (g_naliczator += 5000).
	var points := 5000 if giga2_pull \
		else int(_score * NativeGame.score_mult())
	NativeGame.add_score(points)
	_roll_drop()
	_spawn_explosion(points)
	queue_free()


## Roll the drop — o_drop pays coins (sila_monet) or gems
## (sila_diamentow) in sizeof tiers, with rare special pickups.
func _roll_drop() -> void:
	if _hazard:
		return
	_world = clampi(NativeGame.active_level / 10, 0, 7) \
		if NativeGame.active_level >= 0 else 0
	# Castle defenses always spill coins in the original (g_drop with
	# szansa 1000, sila_monet/diamentow 3) — guarantee a couple.
	if kind in [Kind.CANNON, Kind.FLAME_CANNON, Kind.ROTARY, Kind.FAT_CANNON]:
		for i in randi_range(2, 3):
			var coin := NativePickup.new()
			coin.kind = NativePickup.Kind.COIN
			coin.tier = randi_range(2, 4)
			coin.global_position = position + Vector2(
				randf_range(-24, 24), randf_range(-24, 24))
			get_parent().add_child(coin)
		if randf() < 0.3:
			var gem := NativePickup.new()
			gem.kind = NativePickup.Kind.GEM
			gem.tier = randi_range(1, 3)
			gem.global_position = position
			get_parent().add_child(gem)
		return
	if randf() > DROP_CHANCE:
		return
	# ~2% of drops are special-item stars (o_specjaldrop1).
	# better_chance_of_bonus (VETERAN) widens the special pickup gate,
	# like zmniejsz_szansze50proc > (50 - better_chance_of_bonus).
	var bonus := 1.0 + NativeGame.better_chance_of_bonus / 50.0
	if randf() < SPECIAL_STAR_CHANCE * bonus:
		var drop := NativePickup.new()
		drop.special_id = randi_range(1, 9)
		drop.global_position = position
		get_parent().add_child(drop)
		return
	# special_weapon_* pickups — energy/cooling mushrooms always,
	# the fire boosters gated by campaign world like drop.gd's
	# map_number ranges.
	if randf() < SPECIAL_PICKUP_CHANCE * bonus:
		var pk := NativePickup.new()
		var pool: Array = [NativePickup.Kind.HEALTH, NativePickup.Kind.COOLING]
		if _world >= 1:
			pool.append(NativePickup.Kind.FLOWER)
		if _world >= 2:
			pool.append(NativePickup.Kind.FIRESTAR)
		if _world >= 3:
			pool.append(NativePickup.Kind.BOMBSTAR)
		pk.kind = pool[randi() % pool.size()]
		pk.global_position = position
		get_parent().add_child(pk)
		return
	# Currency — coin vs gem by the original's moneta_vs_diament roll
	# (~2:1 coins), sizeof tier uniform 1-10 (jackpot at 10).
	var pickup := NativePickup.new()
	pickup.tier = randi_range(1, 10)
	if randf() < 0.67:
		pickup.kind = NativePickup.Kind.COIN
	else:
		pickup.kind = NativePickup.Kind.GEM
	pickup.global_position = position
	get_parent().add_child(pickup)


func _spawn_explosion(points: int = -1) -> void:
	var boom := NativeExplosion.new()
	# Heavy enemies get a bigger burst — scale follows the hit radius.
	boom.burst_scale = clampf(_hit_radius / 30.0, 0.8, 2.4)
	# o_fallexploder_* — falling spirits burst into raining debris.
	if kind == Kind.FALLER:
		boom.variant = "falling"
	boom.global_position = position
	get_parent().add_child(boom)
	if kind == Kind.FALLER:
		for i in 3:
			var debris := NativeExplosion.new()
			debris.variant = "debris"
			debris.global_position = position
			get_parent().add_child(debris)

	# Floating score popup — the "+100" the original draws on kills.
	# Shows the streak-multiplied amount actually awarded.
	var popup := Label.new()
	popup.text = "+%d" % (points if points >= 0 else _score)
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	popup.add_theme_constant_override("outline_size", 4)
	popup.position = position + Vector2(-20, -30)
	popup.z_index = 50
	get_parent().add_child(popup)
	var tw := popup.create_tween()
	tw.set_parallel(true)
	tw.tween_property(popup, "position:y", popup.position.y - 40.0, 0.8)
	tw.tween_property(popup, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(popup.queue_free)


## Original destroys enemies that stray far outside the room; we do the
## same so escaped enemies don't accumulate.
func _cull_offscreen() -> void:
	var room := NativeGame.room_size()
	const M := 260.0
	if position.x < -M or position.x > room.x + M \
			or position.y < -M or position.y > room.y + M:
		NativeGame.enemies_missed += 1
		queue_free()


## Ramming the ship damages both parties AND knocks the player back —
## the player is pushed away from the enemy along the contact direction:
## enemy on the left shoves the ship right, enemy above drops it down, etc.
func _check_player_collision() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if ship == null:
		return
	var to_enemy: Vector2 = position - ship.global_position
	var dist: float = to_enemy.length()
	# Radius comes from the sprite bounds — big enemies (eye, tanks)
	# can't be flown through anymore.
	var body := _hit_radius + 18.0
	if dist >= body or dist <= 0.01:
		return
	# Never overlap — shove the ship out of the enemy's body even while
	# invulnerable, so nothing can be flown through.
	ship.global_position += to_enemy.normalized() * (body - dist)
	# Bonus targets (o_enemy_17*) — touching awards score and pops
	# them; the ship takes no damage and isn't knocked back.
	if kind == Kind.BONUS:
		var pts := int(400 * NativeGame.score_mult())
		NativeGame.add_score(pts)
		_spawn_explosion(pts)
		_dead = true
		NativeGame.kill_enemy()
		queue_free()
		return
	if ship.invulnerable:
		return
	if giga2_pull:
		# boss_giga_2 contact: the orb dies, hauling the ship toward its
		# position (g_ixor/g_iyor += lengthdir 20) and burning 200 hull.
		ship.vel += to_enemy.normalized() * 20.0
		NativeGame.damage_player(200.0)
		_spawn_explosion(0)
		queue_free()
		return
	NativeGame.damage_player(contact_damage)
	# Bounce the player away from the enemy — negate the ship→enemy
	# vector so contact on the left drives the ship right, etc.
	ship.vel -= to_enemy.normalized() * 4.0
	# Hazards (o_fan) only hurt — they don't die or score.
	if _hazard:
		return
	# Rammed enemies die but award no score — only kills do.
	_dead = true
	NativeGame.kill_enemy()
	queue_free()
