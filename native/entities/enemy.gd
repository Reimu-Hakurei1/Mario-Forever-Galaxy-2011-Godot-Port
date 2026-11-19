extends Node2D
class_name NativeEnemy
## NativeEnemy — basic flying enemy (ports GameMaker `o_enemy_1` / goomba).
##
## The original enemy is a state machine: it spawns off-screen, flies to a
## formation slot, then sways in place while tracking the player. Bullets
## drain its `health`; at zero it dies with an explosion and drops score.
##
## This port implements the common case — formation-hover with player
## tracking — and exposes the knobs (health, sway, speed) so each enemy
## type can be tuned without touching the base class.

const SPRITE_ID := 11             # s_enemy_a — 16 frame animation
const ANIM_FPS := 8.0
const HIT_FLASH_TIME := 4         # frames of white flash on hit (oberwanie)
const DEATH_SCORE := 100

## Movement modes.
enum Mode { SPAWN, FORMATION, CHASE, DYING }

var health := 100.0               # g_energia
var mode := Mode.SPAWN
var formation_slot := Vector2.ZERO
var sway_phase := 0.0
var sway_amplitude := 14.0        # px — the "ruch" oscillator from the original
var sway_speed := 0.05            # radians per frame
var chase_speed := 1.2            # px/frame toward the player
var drift_speed := 0.4            # px/frame toward formation slot

var _anim: AnimatedSprite2D
var _flash := 0
var _dead := false


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


func _physics_process(_delta: float) -> void:
	if _dead:
		return

	match mode:
		Mode.SPAWN:
			# Glide toward the assigned formation slot, then start swaying.
			var to_slot := formation_slot - position
			if to_slot.length() < 8.0:
				mode = Mode.FORMATION
			else:
				position += to_slot.normalized() * drift_speed
		Mode.FORMATION:
			_sway_and_track()
		Mode.CHASE:
			_chase_player()
		Mode.DYING:
			pass

	if _flash > 0:
		_flash -= 1
		_anim.modulate = Color(3, 3, 3)   # additive-style white hit flash
	else:
		_anim.modulate = Color.WHITE

	_check_player_collision()
	_cull_offscreen()


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
	# Face the direction of travel.
	_anim.rotation = to_player.angle()


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
	# TODO(native): explosion effect + death sound once effects port over.
	queue_free()


## Original destroys enemies that stray far outside the room; we do the
## same so escaped enemies don't accumulate.
func _cull_offscreen() -> void:
	var room := NativeGame.room_size()
	const M := 260.0
	if position.x < -M or position.x > room.x + M \
			or position.y < -M or position.y > room.y + M:
		NativeGame.enemies_missed += 1
		queue_free()
