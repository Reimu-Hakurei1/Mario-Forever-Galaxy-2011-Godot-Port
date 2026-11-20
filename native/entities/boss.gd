extends Node2D
class_name NativeBoss
## NativeBoss — level boss (ports the GameMaker `o_boss*` / anim_bowser family).
##
## Bosses in the original are just very durable enemies with attack
## patterns. This port gives the boss a health pool, a HUD health bar,
## and rotating attack patterns: aimed bursts, radial spreads, and
## summon-minions phases. Difficulty scales with `tier` (world index).
##
## Add to a level by placing a NativeBoss node (or spawning one from a
## wave entry with kind "boss" once the spawner learns boss waves).

enum Phase { ENTER, FIGHT, ENRAGE, DYING }

## Boss looks escalate with world tier — later worlds field angrier,
## meaner variants of the same hull (the original swaps boss sprites
## per stage the same way).
## Each world fields a distinct boss hull from the original's boss
## catalog — 328/332 are the h_* fighters, 334 is s_boss_ocznix,
## 501/502 are the rocket platforms and big-rock bruiser. Tiers past
## the roster reuse the angriest hull with hotter tints.
const TIER_PROFILES := [
	{"sprite": 328, "scale": 0.8, "tint": Color.WHITE},
	{"sprite": 501, "scale": 0.75, "tint": Color(0.85, 0.95, 1.0)},
	{"sprite": 332, "scale": 0.8, "tint": Color(1.0, 0.85, 0.7)},
	{"sprite": 502, "scale": 0.7, "tint": Color(1.0, 0.8, 0.6)},
	{"sprite": 334, "scale": 0.85, "tint": Color(1.0, 0.9, 0.8)},
	{"sprite": 501, "scale": 0.85, "tint": Color(0.9, 0.8, 1.0)},
	{"sprite": 332, "scale": 0.9, "tint": Color(1.0, 0.65, 0.6)},
	{"sprite": 502, "scale": 0.8, "tint": Color(1.0, 0.6, 0.55)},
]
const ANIM_FPS := 6.0
const ENTER_SPEED := 0.8          # px/frame descent
const FIGHT_Y := 160.0            # hover line at the top of the arena
const HIT_FLASH := 4
# Boss hull — the original's boss_*.gd scripts set g_energia 1000-50000
# per world tier (boss_1=1000 … boss_8=50000, a 50x escalation). Our
# damage scale is compressed, so the curve keeps the same *shape*:
# early bosses fall fast, the last one is a genuine wall.
const BASE_HP := 1200.0
const TIER_HP_MULT := [1.0, 1.6, 2.0, 2.5, 3.2, 4.5, 6.5, 9.0]
const BURST_INTERVAL := 150.0     # frames between attack patterns
const MINION_INTERVAL := 600.0    # frames between minion summons

# Alternate boss encounters from objects/bosses/ — the original fields
# ufo_mega / fat_boy_boss / flame_cans_boss in specific stages instead
# of the clown. Each overrides the hull sprite, HP and bar name.
const VARIANTS := {
	"ufo_mega": {"name": "UFO MEGA", "sprite": 174, "scale": 1.1,
		"tint": Color(0.8, 0.9, 1.0), "hp_mult": 0.7},
	"fat_boy": {"name": "KOOPA_TROOPA'S FAT_BOY", "sprite": 178,
		"scale": 0.9, "tint": Color(1.0, 0.85, 0.6), "hp_mult": 3.0},
	"flame_cans": {"name": "FLAME CANS", "sprite": 306, "scale": 1.0,
		"tint": Color(1.0, 0.6, 0.3), "hp_mult": 1.5},
}

var tier := 0                     # world index — scales HP and aggression
var variant := ""                 # "", "ufo_mega", "fat_boy", "flame_cans"
var boss_name := "BOWSER'S_SPACE_CLOWN"
var health := BASE_HP
var phase := Phase.ENTER
var max_health := BASE_HP

var _anim: AnimatedSprite2D
var _flash := 0
var _dead := false
var _pattern_timer := 90.0
var _minion_timer := 300.0
var _barrage_timer := 300.0
var _wp_index := -1
var _wp_timer := 0.0
var _pattern := 0
var _spiral_angle := 0.0           # rotation offset for spiral barrages
# boss_8_fight.gd "dodatkowy" finale — g_sekwencja_rakiet frame beats
# (100/400/500/1250/1600 at 60fps) translated to seconds.
var _finale_t := -1.0
var _finale_step := 0
var _finale_rockets := 0
var _finale_rocket_t := 0.0
var hero_name := ""                 # set in _ready for end-talk lines
var _hp_bar: ProgressBar
var _dialogue: NativeBossDialogue


func _ready() -> void:
	add_to_group("enemies")
	max_health = BASE_HP * TIER_HP_MULT[mini(tier, TIER_HP_MULT.size() - 1)]
	if VARIANTS.has(variant):
		max_health *= VARIANTS[variant]["hp_mult"]
	health = max_health

	# Spawn above the arena and descend to the fight line.
	var room := NativeGame.room_size()
	position = Vector2(room.x / 2.0, -120.0)

	# Tier picks the visual profile (sprite/scale/tint) and tightens the
	# attack clock — deeper worlds mean faster, angrier bosses.
	var profile: Dictionary = TIER_PROFILES[mini(tier, TIER_PROFILES.size() - 1)]
	var sprite_id: int = profile["sprite"]
	if VARIANTS.has(variant):
		var v: Dictionary = VARIANTS[variant]
		boss_name = v["name"]
		sprite_id = v["sprite"]
		profile = {"sprite": sprite_id, "scale": v["scale"],
			"tint": v["tint"]}
	# fat_boy_boss_2.gd — first FAT_BOY warns about the fat-boy enemies.
	if variant == "fat_boy":
		NativeGame.trigger_help(28, 28)

	_anim = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("fight")
	for tex in NativeAssets.sprite_frames(sprite_id):
		frames.add_frame("fight", tex)
	frames.set_animation_speed("fight", ANIM_FPS)
	_anim.sprite_frames = frames
	_anim.play("fight")
	_anim.offset = -NativeAssets.sprite_origin(sprite_id)
	_anim.scale = Vector2.ONE * profile["scale"]
	_anim.modulate = profile["tint"]
	add_child(_anim)

	_build_hp_bar()
	_start_intro_speech()


## The original boss objects play their g_dialogue typewriter speech
## while the boss descends (o_boss_*_talk), then the fight starts.
func _start_intro_speech() -> void:
	hero_name = NativeGame.HEROES[clampi(NativeGame.hero, 0,
		NativeGame.HEROES.size() - 1)]["name"]
	_dialogue = NativeBossDialogue.new()
	_dialogue.finished.connect(func(): pass)
	add_child(_dialogue)
	_dialogue.play(NativeDialogueTable.for_boss(tier, variant, hero_name))


func _physics_process(_delta: float) -> void:
	if NativeGame.paused or _dead:
		return

	match phase:
		Phase.ENTER:
			# Descend to the fight line, then begin the attack loop.
			if position.y < FIGHT_Y:
				position.y += ENTER_SPEED
			else:
				phase = Phase.FIGHT
				_pattern_timer = 60.0
		Phase.FIGHT, Phase.ENRAGE:
			_hover_and_attack()
			_finale_tick(_delta)
		Phase.DYING:
			pass

	if _flash > 0:
		_flash -= 1
		_anim.modulate = Color(3, 3, 3)
	else:
		_anim.modulate = Color.WHITE

	_update_hp_bar()
	_check_player_collision()


## Boss patrols a waypoint dance — the boss_N_fight scripts cycle
## g_sekwencja states through dox/doy targets (center → left → right →
## low corners) while firing, advancing on arrival or a timeout.
func _hover_and_attack() -> void:
	_patrol()

	_pattern_timer -= 1.0
	if _pattern_timer <= 0.0:
		_fire_pattern()
		_pattern += 1
		# Enrage shortens the cycle as health drops; higher tiers start
		# angrier (attack interval shrinks ~8% per world).
		var interval := BURST_INTERVAL * maxf(0.5, 1.0 - tier * 0.08)
		if health < max_health * 0.35:
			phase = Phase.ENRAGE
			interval *= 0.6
		_pattern_timer = interval

	# Phase barrage — the boss_N_fight scripts run a periodic missile
	# volley (g_rakiety ~500f cycle) whose spread grows with the fight
	# phase (etap <10 / 10-19 / >=20 → 2 / 4 / 6 launch points).
	_barrage_timer -= 1.0
	if _barrage_timer <= 0.0:
		_fire_barrage()
		_barrage_timer = 480.0 - tier * 20.0

	_minion_timer -= 1.0
	if _minion_timer <= 0.0:
		_summon_minions()
		_minion_timer = MINION_INTERVAL


## Waypoint patrol — boss_8_fight's 14-state dance scaled to our arena:
## center-top, left, right, then the low corners, looping. The boss
## accelerates toward the current target (g_ixor ramp in the original)
## and advances to the next waypoint on arrival or after ~10s.
func _patrol() -> void:
	if _wp_index < 0:
		_wp_index = 0
		_wp_timer = 0.0
	var room := NativeGame.room_size()
	var cx := room.x / 2.0
	var waypoints := [
		Vector2(cx, 200), Vector2(200, 300), Vector2(room.x - 200, 300),
		Vector2(cx, 350), Vector2(200, 300), Vector2(room.x - 200, 300),
		Vector2(cx, 350), Vector2(160, 480), Vector2(room.x - 160, 480),
		Vector2(cx, 350),
	]
	var target: Vector2 = waypoints[_wp_index % waypoints.size()]
	target.y = minf(target.y, room.y * 0.62)
	var to := target - position
	var dist := to.length()
	_wp_timer += 1.0
	if dist < 18.0 or _wp_timer > 600.0:
		_wp_index += 1
		_wp_timer = 0.0
		return
	# Accelerating approach — the original ramps g_ixor ±0.3/frame.
	var speed := minf(1.5 + _wp_timer / 240.0, 3.2)
	position += to.normalized() * speed


## Fight phase 0/1/2 from remaining hull — the original's g_etap
## thresholds (~66% and ~33% health) that escalate volley size.
func _fight_phase() -> int:
	var frac := health / max_health
	if frac > 0.66:
		return 0
	if frac > 0.33:
		return 1
	return 2


## Missile barrage — aimed fan whose shot count climbs 5/7/9 across
## the three fight phases, mirroring the boss_1_fight launch-point
## escalation (2 → 4 → 6 emitters).
func _fire_barrage() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if ship == null:
		return
	var count := 5 + _fight_phase() * 2
	_fire_aimed(ship.global_position, count, 0.22)
	NativeAssets.play_sound(79)


## boss_8_fight.gd — the castle boss runs a scripted missile sequence
## once the fight is underway: a 3-missile fan, two 18-way bullet rings,
## then a 30-rocket barrage (g_sekwencja_rakiet 100/400/500/1250).
func _finale_tick(delta: float) -> void:
	if tier != 7:
		return
	if _finale_t < 0.0:
		_finale_t = 0.0
		return
	_finale_t += delta
	match _finale_step:
		0:
			if _finale_t > 100.0 / 60.0:
				_finale_step = 1
				# Missiles at GM directions 90/45/135 (down, down-right,
				# down-left) — obj 509.
				for a in [PI / 2.0, PI / 4.0, 3.0 * PI / 4.0]:
					_spawn_bullet(Vector2.RIGHT.rotated(a))
		1:
			if _finale_t > 400.0 / 60.0:
				_finale_step = 2
				_fire_radial(18)          # obj 513 ring #1
		2:
			if _finale_t > 500.0 / 60.0:
				_finale_step = 3
				_fire_radial(18)          # obj 513 ring #2
		3:
			if _finale_t > 1250.0 / 60.0:
				_finale_step = 4
				_finale_rockets = 30
		4:
			if _finale_rockets > 0:
				_finale_rocket_t += delta
				if _finale_rocket_t > 11.0 / 60.0:
					_finale_rocket_t = 0.0
					_finale_rockets -= 1
					# obj 510 — direction 90 ± 40° random.
					_spawn_bullet(Vector2.RIGHT.rotated(
						PI / 2.0 + randf_range(-0.7, 0.7)))


## Rotate through attack patterns: aimed burst → radial ring → fan →
## spiral stream, escalating in ENRAGE.
func _fire_pattern() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if ship == null:
		return
	match _pattern % 4:
		0:
			# Aimed burst — widens with the fight phase like the
			# original's per-phase volley counts.
			_fire_aimed(ship.global_position, 3 + _fight_phase(), 0.15)
		1:
			# Radial ring — the boss_N_fight scripts launch exactly
			# 12 bullet objects (o_bullet_49) in a full circle.
			_fire_radial(12)
		2:
			# Sweeping fan downward toward the player's half.
			_fire_fan(ship.global_position, 5)
		_:
			# Spiral stream — bullets fan out rotating each volley.
			_fire_spiral()
	if phase == Phase.ENRAGE:
		_fire_aimed(ship.global_position, 2, 0.1)   # bonus shot when enraged


func _fire_aimed(target: Vector2, count: int, spread_angle: float) -> void:
	var base := (target - position).normalized().angle()
	for i in count:
		var dir := Vector2.RIGHT.rotated(base + (i - (count - 1) / 2.0) * spread_angle)
		_spawn_bullet(dir)
	NativeAssets.play_sound(79)


func _fire_radial(count: int) -> void:
	for i in count:
		var dir := Vector2.RIGHT.rotated(TAU * i / count)
		_spawn_bullet(dir)
	NativeAssets.play_sound(79)


func _fire_fan(target: Vector2, count: int) -> void:
	var base := (target - position).normalized().angle()
	for i in count:
		var dir := Vector2.RIGHT.rotated(base + (i - (count - 1) / 2.0) * 0.3)
		_spawn_bullet(dir)
	NativeAssets.play_sound(79)


## Spiral barrage — a rotating fan of bullets sprayed downward. Each
## volley advances the spiral angle so the stream curls around the arena.
func _fire_spiral() -> void:
	_spiral_angle += 0.5
	for i in 5:
		var dir := Vector2.DOWN.rotated(_spiral_angle + (i - 2) * 0.22)
		_spawn_bullet(dir)
	NativeAssets.play_sound(79)


func _spawn_bullet(dir: Vector2) -> void:
	var bullet := NativeEnemyBullet.new()
	bullet.global_position = position
	bullet.velocity = dir * (NativeEnemyBullet.SPEED * 1.3)
	get_parent().add_child(bullet)


## Summon a small escort — extracted from the boss_N_fight scripts:
## every tier calls in enemy_9 RUNNER grunts; boss_5+ adds ring
## orbiters (enemy_around_1) and heavier wingmen (boss_giga_2 ≈ elite);
## boss_7/8 lean on the bonus_3_b swarm (also accelerating runners).
func _summon_minions() -> void:
	# Signature adds per boss_N_fight script:
	#  boss_1/3 release a sub-boss (o_boss_3/o_boss_5) — approximated by
	#    an elite heavy escort; boss_4/5 call goomba_team orbit squads;
	#    boss_5/6 field bossgiga2 (bigger ring + bruiser); boss_8 sends
	#    the dodatkowy_3_b heavy swarm.
	match tier:
		0, 2:
			if randf() < 0.35:
				var heavy := NativeEnemy.new()
				heavy.kind = NativeEnemy.Kind.FAT_BOY
				heavy.health = 60.0
				heavy.global_position = position + Vector2(0, 80)
				get_parent().add_child(heavy)
		3, 4:
			if randf() < 0.4:
				var squad := NativeEnemyRing.new()
				squad.orbiters_count = 6
				squad.start_radius = 140.0
				squad.shrink_delay = 700.0
				squad.orbiter_kind = NativeEnemy.Kind.GOOMBA
				squad.orbiter_health = 8.0
				squad.global_position = position + Vector2(0, 120)
				get_parent().add_child(squad)
				return
		5, 6:
			if randf() < 0.4:
				var big := NativeEnemyRing.new()
				big.orbiters_count = 10
				big.start_radius = 180.0
				big.shrink_delay = 800.0
				big.orbiter_kind = NativeEnemy.Kind.ELITE
				big.orbiter_health = 15.0
				big.global_position = position + Vector2(0, 120)
				get_parent().add_child(big)
				var bruiser := NativeEnemy.new()
				bruiser.kind = NativeEnemy.Kind.FAT_BOY
				bruiser.health = 80.0
				bruiser.global_position = position + Vector2(0, 60)
				get_parent().add_child(bruiser)
				return
		7:
			var swarm := NativeEnemyRing.new()
			swarm.orbiters_count = 12
			swarm.start_radius = 200.0
			swarm.shrink_delay = 900.0
			swarm.orbiter_kind = NativeEnemy.Kind.RUNNER
			swarm.orbiter_health = 12.0
			swarm.global_position = position + Vector2(0, 120)
			get_parent().add_child(swarm)
			return
	# Late-tier bosses sometimes release a ring instead of a pair.
	if tier >= 4 and randf() < 0.3:
		var ring := NativeEnemyRing.new()
		ring.orbiters_count = 8 if tier < 6 else 12
		ring.start_radius = 160.0
		ring.shrink_delay = 900.0
		ring.orbiter_kind = NativeEnemy.Kind.RUNNER \
			if tier >= 6 else NativeEnemy.Kind.GOOMBA
		ring.orbiter_health = 10.0
		ring.global_position = position + Vector2(0, 120)
		get_parent().add_child(ring)
		return
	var pool: Array = [NativeEnemy.Kind.RUNNER, NativeEnemy.Kind.GOOMBA,
		NativeEnemy.Kind.MINI]
	if tier >= 4:
		pool = [NativeEnemy.Kind.RUNNER, NativeEnemy.Kind.ELITE,
			NativeEnemy.Kind.UFO_A]
	elif tier >= 2:
		pool = [NativeEnemy.Kind.RUNNER, NativeEnemy.Kind.SHOOTER,
			NativeEnemy.Kind.GHOST]
	var count := 4 if tier >= 6 else 2   # boss_7/8 swarm harder
	for i in count:
		var minion := NativeEnemy.new()
		minion.kind = pool[(tier + i) % pool.size()]
		minion.health = 10.0
		minion.mode = NativeEnemy.Mode.CHASE
		minion.global_position = position + Vector2(
			-60 + i * (120.0 / maxf(1.0, count - 1.0)), 40)
		minion.formation_slot = minion.global_position
		get_parent().add_child(minion)


func take_damage(amount: float) -> bool:
	if _dead or phase == Phase.DYING:
		return false
	health -= amount
	_flash = HIT_FLASH
	if health <= 0.0:
		die()
		return true
	return false


func die() -> void:
	if _dead:
		return
	_dead = true
	phase = Phase.DYING
	NativeGame.kill_enemy()
	# boss_8_fight.gd awards +100000 score (g_naliczator) on the kill.
	NativeGame.add_score(5000 + tier * 1000 + (100000 if tier == 7 else 0))
	NativeGame.coins += 20 + tier * 5
	_spawn_explosion()
	# Post-fight villain line (o_boss_*_end_talk) plays while the
	# wreckage burns, then the level-end sequence resumes.
	var end_lines := NativeDialogueTable.for_end(tier, variant, hero_name)
	if not end_lines.is_empty():
		var talk := NativeBossDialogue.new()
		add_child(talk)
		talk.play(end_lines)
		await talk.finished
	# Boss death sequence: the wreck tumbles down-screen (the original's
	# anim_bowser_* death spin) while the end-talk plays, then frees.
	var wreck := _anim
	var tw := create_tween().set_parallel()
	tw.tween_property(wreck, "rotation", TAU * 1.5, 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y + 500.0, 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(wreck, "modulate:a", 0.0, 1.6)
	await get_tree().create_timer(1.7).timeout
	queue_free()


func _spawn_explosion() -> void:
	# Boss kills get the original's kaboom effect (sprite 236,
	# s_special_kaboom) plus the standard burst.
	var kaboom := NativeExplosion.new()
	kaboom.sprite_id = 236
	kaboom.burst_scale = 2.2
	kaboom.global_position = position
	get_parent().add_child(kaboom)
	for i in 5:
		var boom := NativeExplosion.new()
		boom.global_position = position + Vector2(randf_range(-80, 80), randf_range(-50, 50))
		get_parent().add_child(boom)


func _check_player_collision() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if ship == null or ship.invulnerable:
		return
	var to_boss: Vector2 = position - ship.global_position
	var dist: float = to_boss.length()
	# Solid body — shove the ship out of the boss hull like castle
	# blocks do, so the player can't fly through the sprite.
	const BODY := 85.0
	if dist < BODY + 18.0 and dist > 0.01:
		ship.global_position += to_boss.normalized() * (BODY + 18.0 - dist)
		NativeGame.damage_player(30.0)
		ship.vel -= to_boss.normalized() * 6.0


func _build_hp_bar() -> void:
	# Boss health bar pinned to the top-center of the screen. A CanvasLayer
	# is required — a bare Control under this Node2D would ride along with
	# the boss's horizontal drift instead of staying HUD-fixed.
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_hp_bar = ProgressBar.new()
	_hp_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hp_bar.offset_left = 312.0
	_hp_bar.offset_right = 712.0
	_hp_bar.offset_top = 12.0
	_hp_bar.offset_bottom = 30.0
	_hp_bar.max_value = max_health
	_hp_bar.value = health
	_hp_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(4)
	_hp_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.2, 0.2)
	fill.set_corner_radius_all(4)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	layer.add_child(_hp_bar)

	# The original names every boss on its health bar
	# (G.pasek_napis = "BOWSER'S_SPACE_CLOWN").
	var name_label := Label.new()
	name_label.text = boss_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_left = 312.0
	name_label.offset_right = 712.0
	name_label.offset_top = -2.0
	name_label.offset_bottom = 16.0
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	name_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(name_label)


func _update_hp_bar() -> void:
	if _hp_bar != null:
		_hp_bar.value = health
