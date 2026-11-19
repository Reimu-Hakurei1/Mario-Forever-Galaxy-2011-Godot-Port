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
var _pattern := 0
var _spiral_angle := 0.0           # rotation offset for spiral barrages
var _hp_bar: ProgressBar


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
		Phase.DYING:
			pass

	if _flash > 0:
		_flash -= 1
		_anim.modulate = Color(3, 3, 3)
	else:
		_anim.modulate = Color.WHITE

	_update_hp_bar()
	_check_player_collision()


## Boss drifts side to side while rotating attack patterns.
func _hover_and_attack() -> void:
	# Slow patrol across the upper arena.
	var room := NativeGame.room_size()
	position.x += sin(Time.get_ticks_msec() / 2400.0) * 0.5
	position.x = clampf(position.x, 140.0, room.x - 140.0)

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

	_minion_timer -= 1.0
	if _minion_timer <= 0.0:
		_summon_minions()
		_minion_timer = MINION_INTERVAL


## Rotate through attack patterns: aimed burst → radial ring → fan →
## spiral stream, escalating in ENRAGE.
func _fire_pattern() -> void:
	var ship := get_tree().get_first_node_in_group("player")
	if ship == null:
		return
	match _pattern % 4:
		0:
			# Aimed 3-shot burst at the player.
			_fire_aimed(ship.global_position, 3, 0.15)
		1:
			# Radial ring of bullets in all directions.
			_fire_radial(10)
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


## Summon a small escort — the original bosses call in enemy_9 grunts
## early and heavier wingmen (ufo/crab/elite) in later worlds.
func _summon_minions() -> void:
	var pool: Array = [NativeEnemy.Kind.GOOMBA, NativeEnemy.Kind.MINI]
	if tier >= 4:
		pool = [NativeEnemy.Kind.UFO_A, NativeEnemy.Kind.CRAB,
			NativeEnemy.Kind.ELITE]
	elif tier >= 2:
		pool = [NativeEnemy.Kind.SHOOTER, NativeEnemy.Kind.GHOST]
	for i in 2:
		var minion := NativeEnemy.new()
		minion.kind = pool[(tier + i) % pool.size()]
		minion.health = 10.0
		minion.mode = NativeEnemy.Mode.CHASE
		minion.global_position = position + Vector2(-40 + i * 80, 40)
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
	NativeGame.add_score(5000 + tier * 1000)
	NativeGame.coins += 20 + tier * 5
	_spawn_explosion()
	# Boss death sequence: brief pause then free.
	await get_tree().create_timer(1.2).timeout
	queue_free()


func _spawn_explosion() -> void:
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
