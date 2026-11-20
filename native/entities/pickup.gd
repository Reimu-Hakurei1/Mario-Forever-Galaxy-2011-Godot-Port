extends Node2D
class_name NativePickup
## NativePickup — collectible drops (ports `o_coindrop`, `o_diamonddrop`,
## `o_drop` and the special_weapon_1..6 / level_weapon_1 pickups).
##
## The original drops coins/gems when enemies die; they drift, then magnet
## toward the player when close and award currency/score on contact.
## This port keeps that loop: drift → magnet → collect.

enum Kind { COIN, GEM, HEALTH, LIFE, COOLING, FLOWER, FIRESTAR, BOMBSTAR, LEVELGUN }

const SPRITES := {
	Kind.COIN: 229,       # s_bonus_coin
	Kind.GEM: 231,        # s_bonus_diamond
	Kind.HEALTH: 481,     # special_weapon_1 — energy mushroom sprite
	Kind.LIFE: 155,       # s_bonuslives — extra ship
	Kind.COOLING: 488,    # special_weapon_2 — cooling mushroom
	Kind.FLOWER: 482,     # special_weapon_3 — flower of fire (booster 1)
	Kind.FIRESTAR: 489,   # special_weapon_4 — star of fireballs (booster 2)
	Kind.BOMBSTAR: 490,   # special_weapon_5 — cool star of explosions
	Kind.LEVELGUN: 424,   # level_weapon_1 — free weapon upgrade
}
const DRIFT_SPEED := 0.5     # px/frame downward drift
const MAGNET_RANGE := 90.0   # px — starts homing inside this radius
const MAGNET_SPEED := 4.0    # px/frame toward player
const COLLECT_RANGE := 26.0
## o_coindrop sizeof tiers — coins paid per pickup (x coins_booster).
## sizeof 1 also has a "daj_jeden_kasy" variant paying 2; we use 10.
const COIN_VALUES := [10, 100, 500, 1000, 2000, 5000, 7500, 10000, 15000, 100000]
## o_diamonddrop pays SCORE (naliczator), not coins — same tier curve.
const VALUES := {
	Kind.COIN: {"score": 10},
	Kind.GEM: {"score": 10},
	# Health mushroom — special_weapon_1.gd adds (200 +
	# mushroom_gives_more) to g_energion in ORIGINAL units; the reserve
	# trickles 1 unit/frame into hull (~0.1 ours per frame).
	Kind.HEALTH: {"heal_reserve": 200.0, "score": 0},
	Kind.LIFE: {"life": 1, "score": 250},
	Kind.COOLING: {"cool": true, "score": 50},
	Kind.FLOWER: {"booster_fire": 20.0, "score": 100},
	Kind.FIRESTAR: {"booster_boom": 20.0, "score": 100},
	Kind.BOMBSTAR: {"bomb_ring": true, "score": 150},
	Kind.LEVELGUN: {"level_gun": true, "score": 500},
}

var kind := Kind.COIN
## Coin/gem size tier 1..10 (o_coindrop/o_diamonddrop `sizeof`).
var tier := 1
## Special-item id (1..9) when this drop carries a special — ports
## o_specjaldrop1. 0 = a normal currency/powerup pickup.
var special_id := 0
var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	add_to_group("pickups")
	_sprite = Sprite2D.new()
	if special_id > 0:
		# Special icons live on sprite 239 (same sheet the original's
		# special-slot HUD draws from).
		var tex := NativeAssets.sprite_frame(239, special_id)
		if tex != null:
			_sprite.texture = tex
			_sprite.offset = -NativeAssets.sprite_origin(239)
			_sprite.modulate = Color(1.0, 0.7, 0.3)
	else:
		var tex := NativeAssets.sprite_frame(SPRITES[kind], 0)
		if tex != null:
			_sprite.texture = tex
			_sprite.offset = -NativeAssets.sprite_origin(SPRITES[kind])
	# Powerup sprites get a colour cue so they read differently from
	# currency drops at a glance.
	match kind:
		Kind.LIFE:
			_sprite.modulate = Color(1.0, 0.4, 0.6)
		Kind.COOLING:
			_sprite.modulate = Color(0.5, 0.9, 1.0)
		Kind.FLOWER:
			_sprite.modulate = Color(1.0, 0.6, 0.3)
		Kind.FIRESTAR:
			_sprite.modulate = Color(1.0, 0.8, 0.3)
		Kind.BOMBSTAR:
			_sprite.modulate = Color(0.9, 0.5, 0.9)
		Kind.LEVELGUN:
			_sprite.modulate = Color(0.6, 1.0, 0.6)
	add_child(_sprite)


func _physics_process(_delta: float) -> void:
	if NativeGame.paused:
		return
	_t += 0.08
	# Bob/spin so pickups read as alive.
	_sprite.rotation = sin(_t) * 0.35
	_sprite.position.y = sin(_t * 1.7) * 3.0

	var ship := NativeGame.player()
	if ship == null:
		return

	var to_ship: Vector2 = ship.global_position - position
	var dist: float = to_ship.length()

	if dist < COLLECT_RANGE:
		_collect(ship)
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


func _collect(ship: Node2D = null) -> void:
	# First-time tutorial popups — the original's G.pierwsze_zdobycie
	# → G.help pattern (coin_drop/diamond_drop/special_weapon_*).
	match kind:
		Kind.COIN:
			NativeGame.trigger_help(1, 8)
		Kind.GEM:
			NativeGame.trigger_help(0, 7)
		Kind.HEALTH:
			NativeGame.trigger_help(3, 11)   # special_weapon_1
		Kind.COOLING:
			NativeGame.trigger_help(6, 10)   # special_weapon_2
		Kind.FLOWER:
			NativeGame.trigger_help(2, 9)    # special_weapon_3
		Kind.FIRESTAR:
			NativeGame.trigger_help(5, 13)   # special_weapon_4
		Kind.BOMBSTAR:
			NativeGame.trigger_help(4, 12)   # special_weapon_5
		Kind.LEVELGUN:
			NativeGame.trigger_help(24, 24)  # level_weapon_1
	# Special drop — fills the first empty G.specialslot ring slot.
	# If the ring is full the item salvages for a coin refund.
	if special_id > 0:
		# special_weapon_6.gd maps each special to topics 14..22.
		NativeGame.trigger_help(13 + special_id, 13 + special_id)
		if NativeGame.add_special(special_id) >= 0:
			NativeAssets.play_sound(62)
		else:
			NativeGame.coins += NativeSpecialTable.PRICES[special_id] / 4
			NativeAssets.play_sound(62)
		return
	var v: Dictionary = VALUES[kind]
	var t := clampi(tier, 1, COIN_VALUES.size()) - 1
	if kind == Kind.COIN:
		# coin_drop.gd sizeof payout x coins_booster (CLASSIC +2%).
		NativeGame.coins += int(round(COIN_VALUES[t] * NativeGame.coins_booster))
	if kind == Kind.GEM:
		# diamond_drop.gd pays score points on the same tier curve.
		NativeGame.add_score(COIN_VALUES[t])
	if v.has("heal_reserve"):
		NativeGame.energy_reserve += v["heal_reserve"] \
			+ NativeGame.mushroom_gives_more
	if v.has("life"):
		NativeGame.lives += v["life"]
	if v.has("cool"):
		# Cooling mushroom removes 200 overheat + better_cooling_mushroom
		# hero bonus (special_weapon_2.gd) — not a full purge.
		NativeGame.overheating = maxf(0.0, NativeGame.overheating
			- (200.0 + NativeGame.better_cooling_mushroom))
	if v.has("booster_fire"):
		NativeGame.booster_fire_time = v["booster_fire"]
	if v.has("booster_boom"):
		NativeGame.booster_boom_time = v["booster_boom"]
	if v.has("bomb_ring"):
		_fire_bomb_ring(ship)
	if v.has("level_gun"):
		# level_weapon_1.gd — grants weapon id 4 (TRIPLER) at level 8
		# into G.weapon[2] (the second gun slot).
		var slot := 1 if NativeGame.gun_slots[0] else 0
		NativeGame.weapons[slot] = 4
		NativeGame.weapon_level[slot] = 8
	NativeGame.add_score(v.get("score", 0))
	NativeAssets.play_sound(62)  # pickup chime (original sampel id)


## COOL STAR OF EXPLOSIONS — special_weapon_5.gd spawns 11
## cool_explosion_bullets (obj 302) in a ring, starter_boom staggered
## 36 degrees apart. Here they burst outward from the pickup.
func _fire_bomb_ring(ship: Node2D) -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in 11:
		var bolt := NativeBullet.new()
		bolt.global_position = global_position
		bolt.velocity = Vector2.RIGHT.rotated(i * TAU / 11.0) * 2.8
		bolt.damage = 20.0
		bolt.sprite_id = 490
		bolt.scale0 = 0.4
		bolt.life_frames = 240
		bolt.weave = 2.0
		bolt.weave_speed = 0.15
		parent.add_child(bolt)
