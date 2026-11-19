extends Node2D
class_name NativeEnemyRing
## NativeEnemyRing — the orbiting swarm (ports o_enemy_around_1/2 and
## o_enemy_around_1_delayed).
##
## The original spawner hovers near the player and keeps ten grunts
## arranged on a rotating circle (g_promien radius, g_kat angle).
## After ~1000 frames the radius starts shrinking, tightening the ring
## into a bullet-hell orb. When every orbiter dies the ring is spent.
##
## Orbiters are real NativeEnemy nodes (shootable, rammable) whose
## positions the ring drives each frame via their orbit_* fields.

const ORBITERS := 10
const ORBIT_SPEED := 0.017        # ~1°/frame, matches g_kat += 1
const START_RADIUS := 170.0
const SHRINK_DELAY := 1000.0      # frames before g_promien starts falling
const SCORE_ON_CLEAR := 500

var _orbiters: Array[NativeEnemy] = []
var _angle := 0.0
var _radius := START_RADIUS
var _clock := 0.0
var _dead := false


func _ready() -> void:
	add_to_group("enemy_rings")
	for i in ORBITERS:
		var orbiter := NativeEnemy.new()
		orbiter.kind = NativeEnemy.Kind.MINI
		orbiter.health = 8.0
		orbiter.mode = NativeEnemy.Mode.CHASE   # overridden by orbit
		orbiter.orbit_around = self
		orbiter.orbit_radius = _radius
		orbiter.orbit_angle = TAU * i / ORBITERS
		orbiter.orbit_speed = ORBIT_SPEED
		add_child(orbiter)
		_orbiters.append(orbiter)


func _physics_process(_delta: float) -> void:
	if NativeGame.paused or _dead:
		return
	_clock += 1.0

	# The original ring drifts to stay within ~10px of the player —
	# it herds the swarm around you.
	var ship := get_tree().get_first_node_in_group("player")
	if ship != null:
		var to_player: Vector2 = ship.global_position - position
		if to_player.length() > 10.0:
			position += to_player.normalized() * minf(2.0, to_player.length() - 10.0)

	# Radius holds for ~1000 frames then shrinks (g_promien decay).
	if _clock > SHRINK_DELAY:
		_radius = maxf(60.0, _radius - (1.0 + _radius / 500.0))

	# Push the new radius/angle onto live orbiters.
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
