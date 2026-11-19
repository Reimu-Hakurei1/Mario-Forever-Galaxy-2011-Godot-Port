extends Node2D
class_name NativeEnemy
## NativeEnemy — flying enemy (ports GameMaker `o_enemy_1` family).
##
## The original enemy is a state machine: spawn off-screen → take a
## formation slot → sway while tracking the player → die to bullets or
## ram the ship. This port implements that loop plus the common variants
## seen across the original's ~40 enemy objects:
##
##   - "goomba"    — formation hover, the baseline enemy
##   - "shooter"   — holds position, periodically fires aimed shots
##   - "kamikaze"  — ignores formation, charges the player relentlessly
##
## Kills award score and roll the original's drop table (coin / gem /
## health), then play the explosion animation.

const SPRITE_ID := 11             # s_enemy_a — 16 frame animation
const ANIM_FPS := 8.0
const HIT_FLASH_TIME := 4         # frames of white flash on hit (oberwanie)
const DEATH_SCORE := 100

## Movement/behaviour modes.
enum Mode { SPAWN, FORMATION, CHASE, KAMIKAZE, DYING }
## Enemy variants — each maps to a family of objects in the original.
enum Kind { GOOMBA, SHOOTER, KAMIKAZE }

# Drop table rolled on death (from the original o_drop logic): most kills
# drop nothing, coins are common, gems rare, health very rare.
const DROP_TABLE := [
	[0.55, null],
	[0.25, NativePickup.Kind.COIN],
	[0.12, null],
	[0.06, NativePickup.Kind.GEM],
	[0.02, NativePickup.Kind.HEALTH],
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
var shoot_interval := 180.0       # frames between shots (shooter only)
var shoot_range := 600.0          # px — only fires when player is in range

var _anim: AnimatedSprite2D
var _flash := 0
var _dead := false
var _shoot_timer := 0.0


func _ready() -> void:
	add_to_group("enemies")

	_anim = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fly")
	for tex in NativeAssets.sprite_frames(SPRITE_ID):
		frames.add_frame("fly", tex)
	frames.set_animation_speed("fly", ANIM_FPS)
	_anim.sprite_frames = frames
	_anim.play("fly")
	_anim.offset = -NativeAssets.sprite_origin(SPRITE_ID)
	add_child(_anim)

	sway_phase = randf() * TAU
	_shoot_timer = shoot_interval * randf_range(0.5, 1.0)


func _physics_process(_delta: float) -> void:
	if _dead:
		return

	match kind:
		Kind.SHOOTER:
			_behave_shooter()
		Kind.KAMIKAZE:
			_behave_kamikaze()
		_:
			_behave_goomba()

	if _flash > 0:
		_flash -= 1
		_anim.modulate = Color(3, 3, 3)   # additive-style white hit flash
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


## Holds its formation slot and fires aimed shots when the player is near.
func _behave_shooter() -> void:
	# Drift to slot first, then orbit it while shooting.
	if mode == Mode.SPAWN:
		var to_slot := formation_slot - position
		if to_slot.length() < 8.0:
			mode = Mode.FORMATION
		else:
			position += to_slot.normalized() * drift_speed
		return
	_sway_and_track()

	_shoot_timer -= 1.0
	var ship := get_tree().get_first_node_in_group("player")
	if _shoot_timer <= 0.0 and ship != null:
		var dist := position.distance_to(ship.global_position)
		if dist < shoot_range:
			_fire_at_player(ship.global_position)
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


## Spawn an aimed enemy bullet at the player's position.
func _fire_at_player(target: Vector2) -> void:
	var bullet := NativeEnemyBullet.new()
	bullet.global_position = position
	var dir := (target - position).normalized()
	bullet.velocity = dir * NativeEnemyBullet.SPEED
	get_parent().add_child(bullet)
	NativeAssets.sound(79)  # enemy shot (original sampel id)


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
	NativeGame.add_score(DEATH_SCORE)
	_roll_drop()
	_spawn_explosion()
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


func _spawn_explosion() -> void:
	var boom := NativeExplosion.new()
	boom.global_position = position
	get_parent().add_child(boom)


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
