extends Node2D
class_name NativePickup
## NativePickup — collectible drops (ports `o_coindrop`, `o_diamonddrop`).
##
## The original drops coins/gems when enemies die; they drift, then magnet
## toward the player when close and award currency/score on contact.
## This port keeps that loop: drift → magnet → collect.

enum Kind { COIN, GEM, HEALTH, POWER, LIFE, COOLING }

const SPRITES := {
	Kind.COIN: 229,       # s_bonus_coin
	Kind.GEM: 231,        # s_bonus_diamond
	Kind.HEALTH: 136,     # s_spikey (health capsule stand-in)
	Kind.POWER: 489,      # s_bonus_redstar — weapon overdrive star
	Kind.LIFE: 155,       # s_bonuslives — extra ship
	Kind.COOLING: 488,    # s_bonus_cooling — overheat purge
}
const DRIFT_SPEED := 0.5     # px/frame downward drift
const MAGNET_RANGE := 90.0   # px — starts homing inside this radius
const MAGNET_SPEED := 4.0    # px/frame toward player
const COLLECT_RANGE := 26.0
const OVERDRIVE_TIME := 12.0 # seconds of boosted fire
const VALUES := {
	Kind.COIN: {"coins": 1, "score": 10},
	Kind.GEM: {"coins": 5, "score": 50},
	Kind.HEALTH: {"heal": 25.0, "score": 0},
	Kind.POWER: {"overdrive": OVERDRIVE_TIME, "score": 100},
	Kind.LIFE: {"life": 1, "score": 250},
	Kind.COOLING: {"cool": true, "score": 50},
}

var kind := Kind.COIN
var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	add_to_group("pickups")
	_sprite = Sprite2D.new()
	var tex := NativeAssets.sprite_frame(SPRITES[kind], 0)
	if tex != null:
		_sprite.texture = tex
		_sprite.offset = -NativeAssets.sprite_origin(SPRITES[kind])
	# The health sprite (s_spikey) is a huge powerup graphic — shrink it so
	# it reads as a small collectible like the coin and gem.
	if kind == Kind.HEALTH:
		_sprite.scale = Vector2(0.3, 0.3)
	# Gems shimmer in the original via HSV cycling — a gentle hue pulse
	# reads the same at a fraction of the cost.
	if kind == Kind.GEM:
		_sprite.modulate = Color(0.6, 0.9, 1.0)
	# Powerup sprites get a colour cue so they read differently from
	# currency drops at a glance.
	match kind:
		Kind.POWER:
			_sprite.modulate = Color(1.0, 0.5, 0.5)
		Kind.LIFE:
			_sprite.modulate = Color(1.0, 0.4, 0.6)
		Kind.COOLING:
			_sprite.modulate = Color(0.5, 0.9, 1.0)
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	if NativeGame.paused:
		return
	_t += 0.08
	# Bob/spin so pickups read as alive.
	_sprite.rotation = sin(_t) * 0.35
	_sprite.position.y = sin(_t * 1.7) * 3.0

	var ship := get_tree().get_first_node_in_group("player")
	if ship == null:
		return

	var to_ship: Vector2 = ship.global_position - position
	var dist: float = to_ship.length()

	if dist < COLLECT_RANGE:
		_collect()
		queue_free()
	elif dist < MAGNET_RANGE:
		# Magnetize — the original's homing behaviour.
		position += to_ship.normalized() * MAGNET_SPEED
	else:
		# Gentle fall until the player comes into range.
		position.y += DRIFT_SPEED

	# Fallen off the bottom = missed collectible (counts toward results).
	if position.y > NativeGame.room_size().y + 60.0:
		queue_free()


func _collect() -> void:
	var v: Dictionary = VALUES[kind]
	if v.has("coins"):
		NativeGame.coins += v["coins"]
	if v.has("heal"):
		NativeGame.heal_player(v["heal"])
	if v.has("overdrive"):
		NativeGame.overdrive_time = v["overdrive"]
	if v.has("life"):
		NativeGame.lives += v["life"]
	if v.has("cool"):
		NativeGame.overheating = 0.0
	NativeGame.add_score(v.get("score", 0))
	NativeAssets.play_sound(62)  # pickup chime (original sampel id)
