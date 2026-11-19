extends Node2D
class_name NativeEnemyRing
## NativeEnemyRing — the orbiting swarm family (ports o_enemy_around_1/2,
## o_enemy_around_1_delayed and o_ducher_around).
##
## The original spawners hover near the player and keep a dozen grunts
## arranged on a rotating circle (g_promien radius, g_kat angle). After
## a delay the radius starts shrinking, tightening the ring into a
## bullet-hell orb; ducher_around's center is glued to the player and
## its ring self-destructs after the attack phase.
##
## Orbiters are real NativeEnemy nodes (shootable, rammable) whose
## positions the ring drives each frame via their orbit_* fields.
## Configure via the fields below before add_child().

var orbiters_count := 10        # enemy_around uses 10, ducher_around 12
var start_radius := 170.0
var shrink_delay := 1000.0      # frames before the radius starts falling
var shrink_rate := 1.0          # base px/frame shrink (orig: 1 + r/500)
var glue_to_player := false     # ducher_around pins its center on you
var lifetime := 0.0             # >0 self-destructs after N frames
var orbiter_health := 8.0
var orbiter_kind := NativeEnemy.Kind.MINI

const ORBIT_SPEED := 0.017      # ~1°/frame, matches g_kat += 1
const SCORE_ON_CLEAR := 500

var _orbiters: Array[NativeEnemy] = []
var _radius := start_radius
var _clock := 0.0
var _dead := false


func _ready() -> void:
	add_to_group("enemy_rings")
	for i in orbiters_count:
		var orbiter := NativeEnemy.new()
		orbiter.kind = orbiter_kind
		orbiter.health = orbiter_health
		orbiter.mode = NativeEnemy.Mode.CHASE   # overridden by orbit
		orbiter.orbit_around = self
		orbiter.orbit_radius = _radius
		orbiter.orbit_angle = TAU * i / orbiters_count
		orbiter.orbit_speed = ORBIT_SPEED
		add_child(orbiter)
		_orbiters.append(orbiter)


func _physics_process(_delta: float) -> void:
	if NativeGame.paused or _dead:
		return
	_clock += 1.0

	# enemy_around herds within ~10px of the player; ducher_around
	# pins its center directly on the ship's position.
	var ship := get_tree().get_first_node_in_group("player")
	if ship != null:
		var to_player: Vector2 = ship.global_position - position
		if glue_to_player:
			position = ship.global_position
		elif to_player.length() > 10.0:
			position += to_player.normalized() * minf(2.0, to_player.length() - 10.0)

	# Lifetime self-destruct (ducher_around's g_niszcz > 100 phase).
	if lifetime > 0.0 and _clock > lifetime:
		_dead = true
		for orbiter in _orbiters:
			if is_instance_valid(orbiter):
				orbiter.queue_free()
		queue_free()
		return

	# Radius holds for shrink_delay frames then decays
	# (g_promien -= 1 + promien/500 in the original).
	if _clock > shrink_delay:
		_radius = maxf(60.0, _radius - (shrink_rate + _radius / 500.0))

	# Push the new radius onto live orbiters.
	var alive := 0
	for orbiter in _orbiters:
		if is_instance_valid(orbiter) and not orbiter._dead:
			alive += 1
			orbiter.orbit_radius = _radius
			orbiter._hit_radius = 16.0

	# All orbiters dead = ring cleared.
	if alive == 0:
		_dead = true
		NativeGame.add_score(SCORE_ON_CLEAR)
		var boom := NativeExplosion.new()
		boom.global_position = position
		get_parent().add_child(boom)
		queue_free()
