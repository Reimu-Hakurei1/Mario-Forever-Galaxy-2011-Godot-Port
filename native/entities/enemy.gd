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
}

## Per-kind tuning. `sprite` is the GameMaker sprite index; `score` is the
## kill award; shooter-ish kinds get `shoot_interval`/`spread`; `chase`
## overrides chase_speed and `dive` overrides kamikaze_speed.
const KIND_PROFILES := {
	Kind.GOOMBA: {"sprite": 11, "score": 100},
	Kind.SHOOTER: {"sprite": 174, "score": 150, "shoot_interval": 170.0, "spread": 1},
	Kind.KAMIKAZE: {"sprite": 11, "score": 120, "tint": Color(1.0, 0.55, 0.5)},
	Kind.TANK: {"sprite": 178, "score": 300, "shoot_interval": 240.0, "spread": 3, "scale": 0.55},
	Kind.EYE: {"sprite": 185, "score": 200, "shoot_interval": 110.0, "spread": 1, "burst": 3},
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
}

# Drop table rolled on death (from the original o_drop logic): most kills
# drop nothing, coins are common, gems rare, health very rare.
const DROP_TABLE := [
	[0.50, null],
	[0.22, NativePickup.Kind.COIN],      # 0.72
	[0.10, null],                        # 0.82
	[0.05, NativePickup.Kind.GEM],       # 0.87
	[0.04, NativePickup.Kind.POWER],     # 0.91 — overdrive star
	[0.03, NativePickup.Kind.COOLING],   # 0.94 — heat purge
	[0.03, null],                        # 0.95
	[0.02, NativePickup.Kind.HEALTH],    # 0.97
	[0.02, NativePickup.Kind.SHIELD],    # 0.99 — bubble, rare
	[0.01, NativePickup.Kind.LIFE],      # 1.00 — extra ship, very rare
]

var kind := Kind.GOOMBA
var health := 100.0               # g_energia
var mode := Mode.SPAWN
var formation_slot := Vector2.ZERO
var sway_phase := 0.0
var sway_amplitude := 14.0        # px — the "ruch" oscillator from the original
var sway_speed := 0.05            # radians per frame
var chase_speed := 1.2            # px/frame toward the player
var drift_speed := 0.4            # px/frame toward formation slot
var kamikaze_speed := 2.2         # px/frame — kamikaze dive speed
var shoot_interval := 180.0       # frames between shots
var shoot_range := 620.0          # px — only fires when player is in range
var spread := 1                   # bullets per volley
var burst := 1                    # shots per volley trigger (eye)

var _anim: AnimatedSprite2D
var _flash := 0
var _dead := false
var _shoot_timer := 0.0
var _burst_left := 0
var _score := DEATH_SCORE_DEFAULT

const DEATH_SCORE_DEFAULT := 100


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
	if _scale_factor != 1.0:
		_anim.scale = Vector2(_scale_factor, _scale_factor)
	if _tint != Color.WHITE:
		_anim.modulate = _tint
	add_child(_anim)

	sway_phase = randf() * TAU
	_shoot_timer = shoot_interval * randf_range(0.5, 1.0)


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
	_score = p.get("score", DEATH_SCORE_DEFAULT)
	shoot_interval = p.get("shoot_interval", shoot_interval)
	spread = p.get("spread", 1)
	burst = p.get("burst", 1)
	_scale_factor = p.get("scale", 1.0)
	_tint = p.get("tint", Color.WHITE)
	if p.has("chase"):
		chase_speed = p["chase"]
	if p.has("dive"):
		kamikaze_speed = p["dive"]
	# Behaviour family routing: shooters hold station and fire, kamikaze
	# variants dive, everything else uses the goomba pattern. The new
	# kinds join the family that matches their profile.
	if kind == Kind.KAMIKAZE or kind == Kind.UFO_B:
		mode = Mode.KAMIKAZE
		kamikaze_speed = p.get("dive", 2.4)


func _physics_process(_delta: float) -> void:
	if NativeGame.paused or _dead:
		return

	# Shooter-ish kinds share the hold-position-and-fire behaviour.
	if kind in [Kind.SHOOTER, Kind.EYE, Kind.TANK, Kind.UFO_A, Kind.ROS, Kind.CRAB]:
		_behave_shooter()
	elif kind == Kind.KAMIKAZE or kind == Kind.UFO_B:
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
	if kind == Kind.EYE:
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


## Relentless dive — beelines for the player the whole time.
func _behave_kamikaze() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if ship == null:
		return
	var to_player: Vector2 = ship.global_position - position
	if to_player.length() > 4.0:
		position += to_player.normalized() * kamikaze_speed
	_anim.rotation = to_player.angle()


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
	if _dead:
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
	# Streak multiplier applies to the kill score — chained kills pay more.
	var points := int(_score * NativeGame.score_mult())
	NativeGame.add_score(points)
	_roll_drop()
	_spawn_explosion(points)
	queue_free()


## Roll the drop table — coins common, gems rare, health very rare.
func _roll_drop() -> void:
	var roll := randf()
	var acc := 0.0
	for entry in DROP_TABLE:
		acc += entry[0]
		if roll <= acc and entry[1] != null:
			var pickup := NativePickup.new()
			pickup.kind = entry[1]
			pickup.global_position = position
			get_parent().add_child(pickup)
			return


func _spawn_explosion(points: int = -1) -> void:
	var boom := NativeExplosion.new()
	boom.global_position = position
	get_parent().add_child(boom)

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
	if ship == null or ship.invulnerable:
		return
	var to_enemy: Vector2 = position - ship.global_position
	var dist: float = to_enemy.length()
	if dist < 40.0 and dist > 0.01:
		NativeGame.damage_player(15.0)
		# Bounce the player away from the enemy — negate the ship→enemy
		# vector so contact on the left drives the ship right, etc.
		ship.vel -= to_enemy.normalized() * 4.0
		# Rammed enemies die but award no score — only kills do.
		_dead = true
		NativeGame.kill_enemy()
		queue_free()
