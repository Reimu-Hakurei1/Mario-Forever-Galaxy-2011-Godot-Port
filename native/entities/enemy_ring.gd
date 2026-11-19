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
# Team-fighter options (o_goomba_team/o_ufo_team/o_cyber_team/
# o_hammer_team/o_ufos_team): mixed-member squads that cross the
# screen and shoot instead of herding on the player.
var orbiter_kinds: Array = []   # non-empty cycles members by index
var drift := Vector2.ZERO       # px/frame crossing velocity
var shoot_interval := 0.0       # seconds between mother volleys
var volley_count := 1

const ORBIT_SPEED := 0.017      # ~1°/frame, matches g_kat += 1
const SCORE_ON_CLEAR := 500

var _orbiters: Array[NativeEnemy] = []
var _radius := start_radius
var _clock := 0.0
var _shoot_clock := 0.0
var _dead := false


## Aimed volley from the ring's center — the team fighters' bullet
## patterns in the original are straight shots at the player.
func _fire_volley() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if ship == null:
		return
	var base_angle: float = (ship.global_position - global_position).angle()
	for i in volley_count:
		var bullet := NativeEnemyBullet.new()
		var spread := (i - (volley_count - 1) / 2.0) * 0.35
		bullet.velocity = Vector2.from_angle(base_angle + spread) * 240.0
		bullet.global_position = global_position
		get_parent().add_child(bullet)


func _ready() -> void:
	add_to_group("enemy_rings")
	for i in orbiters_count:
		var orbiter := NativeEnemy.new()
		if orbiter_kinds.is_empty():
			orbiter.kind = orbiter_kind
		else:
			orbiter.kind = orbiter_kinds[i % orbiter_kinds.size()]
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

	# Team fighters cross the screen on their drift vector; regular
	# rings herd near the player instead.
	if drift != Vector2.ZERO:
		position += drift * _delta * 60.0
	else:
		var ship0 := get_tree().get_first_node_in_group("player")
		if ship0 != null:
			var to_player: Vector2 = ship0.global_position - position
			if glue_to_player:
				position = ship0.global_position
			elif to_player.length() > 10.0:
				position += to_player.normalized() * minf(2.0, to_player.length() - 10.0)

	# Team fighters that drift off-screen are gone — free the squad.
	if drift != Vector2.ZERO:
		var room := NativeGame.room_size()
		if position.x < -220.0 or position.x > room.x + 220.0 \
				or position.y < -220.0 or position.y > room.y + 220.0:
			for orbiter in _orbiters:
				if is_instance_valid(orbiter):
					orbiter.queue_free()
			queue_free()
			return

	# Mother volleys — team fighters fire while crossing.
	if shoot_interval > 0.0:
		_shoot_clock += _delta
		if _shoot_clock >= shoot_interval:
			_shoot_clock = 0.0
			_fire_volley()

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
