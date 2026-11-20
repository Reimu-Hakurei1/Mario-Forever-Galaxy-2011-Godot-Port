extends Node2D
class_name NativeBuddy
## NativeBuddy — companion creature (ports GameMaker `o_kumpel_a`).
##
## The original keeps TWO buddy instances alive for the whole run
## (player_a create event): one on each side of the ship. Each has a
## purchased tier (G.jakikumpel[0..1], 0-2) that picks the sprite
## (459/460/461) and the hull pool (500/5000/15000 orig units). Enemy
## bullets collide with them (bullet mask 26), they smoke near death,
## explode at zero hull, and are revived with bonus hull when the
## player respawns (G.odnow_kumpli).
##
## This port keeps that loop: follow the ship on a side offset, show
## the tier sprite with a damage-state frame, soak enemy fire, revive
## on player respawn.

const FOLLOW_OFFSET := Vector2(95.0, 55.0)   # px beside/behind the hull
const FOLLOW_LERP := 0.12                    # spring toward the slot
const BASE_SPRITE := 459                     # sprites 459/460/461 = tiers
## Hull pools — original 500/5000/15000, our bar is ~10x smaller.
const MAX_ENERGY := [50.0, 500.0, 1500.0]
## Damage-state frame thresholds as fractions of max hull
## (g_hi_explo/g_low_explo in buddy_a.gd).
const HI_FRAC := 0.5
const LO_FRAC := 0.2

var side := -1                 # -1 left buddy, +1 right buddy
var tier := 0                  # 0-2 — G.jakikumpel[side index]
var energy := 50.0
var alive := true

var _sprite: Sprite2D
var _ship: Node2D
var _smoked_hi := false
var _smoked_lo := false


func _ready() -> void:
	add_to_group("buddies")
	_sprite = Sprite2D.new()
	add_child(_sprite)
	_ship = NativeGame.player()
	_sync_tier()


func _physics_process(_delta: float) -> void:
	if NativeGame.paused:
		return
	# Re-read the purchased tier every frame — shop upgrades apply live.
	_sync_tier()
	if _ship == null or not is_instance_valid(_ship):
		_ship = NativeGame.player()
		if _ship == null:
			return

	if not alive:
		# Wreck stays hidden until the next player respawn revives it.
		_sprite.visible = false
		return

	# Spring toward the slot beside the ship.
	var target: Vector2 = _ship.global_position \
		+ Vector2(FOLLOW_OFFSET.x * side, FOLLOW_OFFSET.y)
	global_position = global_position.lerp(target, FOLLOW_LERP)

	# Damage-state frame: pristine / smoking / critical (sprite frames
	# 0/1/2 in the original's draw tiers). Tier 0 is the free base
	# buddy — it is always present, shop tiers just upgrade it.
	var frac := energy / maxf(1.0, _max_energy())
	var frame := 0 if frac > HI_FRAC else (1 if frac > LO_FRAC else 2)
	var tex := NativeAssets.sprite_frame(BASE_SPRITE + tier, frame)
	if tex != null:
		_sprite.texture = tex
		_sprite.offset = -NativeAssets.sprite_origin(BASE_SPRITE + tier)


func _max_energy() -> float:
	return MAX_ENERGY[clampi(tier, 0, 2)]


## Pick up shop purchases and reset hull when the tier changes.
func _sync_tier() -> void:
	var want := NativeGame.buddy_left if side < 0 else NativeGame.buddy_right
	if want != tier:
		tier = want
		# A shop upgrade repairs the creature — fresh hull, back in the fight.
		energy = _max_energy()
		alive = true
		_smoked_hi = false
		_smoked_lo = false
	if alive and energy <= 0.0:
		alive = false


## Enemy fire damages the buddy (o_bullet_* mask 26 collision).
func take_damage(amount: float) -> void:
	if not alive:
		return
	energy -= amount
	var frac := energy / maxf(1.0, _max_energy())
	# Crossing a smoke threshold emits the original's particle burst —
	# approximated with the shared explosion effect.
	if frac <= LO_FRAC and not _smoked_lo:
		_smoked_lo = true
		_boom()
	elif frac <= HI_FRAC and not _smoked_hi:
		_smoked_hi = true
		_boom()
	if energy <= 0.0:
		alive = false
		_boom()


func _boom() -> void:
	var boom := NativeExplosion.new()
	boom.global_position = global_position
	get_parent().add_child(boom)


## Revive after the player respawns — script_odnawianie_kumpli restores
## the buddies with bonus hull (energia + 2000 orig ≈ +200 ours, capped).
func revive() -> void:
	alive = true
	energy = minf(_max_energy(), energy + 200.0)
	_smoked_hi = false
	_smoked_lo = false
