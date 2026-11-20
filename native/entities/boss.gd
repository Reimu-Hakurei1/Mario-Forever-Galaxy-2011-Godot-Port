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

## ---- boss_N_fight.gd choreography ----
## Faithful port of objects/bosses/boss_1..8_fight.gd. Waypoint dances
## use -1 for the center column ((room_width-120)/2). `sweep` selects
## the bossbul fired during the rozstrzel 100-202 sweep; `hell` marks
## boss_8's sekwencja_rakiet bullet-hell instead of the sq2 barrage.
const WP_MAIN := [
	[-1, 350], [200, 300], [700, 300], [-1, 350], [200, 300], [700, 300],
	[-1, 350], [200, 300], [700, 300], [-1, 350], [100, 500], [-1, 350],
	[700, 500]]
const WP_BOSS2 := [
	[-1, 300], [100, 200], [500, 200], [-1, 300], [100, 200], [500, 200],
	[-1, 300], [100, 200], [500, 200], [-1, 300], [100, 500], [-1, 300],
	[500, 500]]
const FIGHT_CFG := [
	# boss_1_fight — climax dance, 4-shot volleys, no sweep.
	{"wps": WP_MAIN, "volley": 4, "volley_gap": 10, "ring": 20,
		"ring_gap": 30, "tail": 5, "tail_gap": 40, "sweep": "",
		"giga0": -300.0, "hell": false},
	# boss_2_fight — castle dance, 6-shot volleys, wing lasers >8000hp,
	# periodic bonus drops, etap-scaled missile swarm.
	{"wps": WP_BOSS2, "volley": 6, "volley_gap": 10, "ring": 20,
		"ring_gap": 30, "tail": 5, "tail_gap": 40, "sweep": "",
		"giga0": 0.0, "hell": false, "laser": true, "bonus": true},
	# boss_3_fight — adds the rozstrzel sweep (bossbul_1 slow_home).
	{"wps": WP_MAIN, "volley": 2, "volley_gap": 10, "ring": 30,
		"ring_gap": 30, "tail": 10, "tail_gap": 40, "sweep": "slow_home",
		"giga0": -300.0, "hell": false},
	# boss_4_fight — + goomba_team releases (obj 356).
	{"wps": WP_MAIN, "volley": 2, "volley_gap": 10, "ring": 30,
		"ring_gap": 30, "tail": 10, "tail_gap": 40, "sweep": "slow_home",
		"giga0": -300.0, "hell": false, "goomba": true},
	# boss_5_fight — + goomba window, bossgiga2 orbit pair (419).
	{"wps": WP_MAIN, "volley": 2, "volley_gap": 10, "ring": 30,
		"ring_gap": 30, "tail": 10, "tail_gap": 40, "sweep": "slow_home",
		"giga0": -300.0, "hell": false, "goomba": true, "biggery": true},
	# boss_6_fight — + dookola surrounder (410), paired rockets (116).
	{"wps": WP_MAIN, "volley": 2, "volley_gap": 10, "ring": 30,
		"ring_gap": 30, "tail": 10, "tail_gap": 40, "sweep": "slow_home",
		"giga0": -300.0, "hell": false, "goomba": true, "biggery": true,
		"dookola": true, "rockets": true},
	# boss_7_fight — hyper cadence (20 shots / 3f), bossbul_33 sweep,
	# faster ring/tail, rockets, teams, orbit pair.
	{"wps": WP_MAIN, "volley": 20, "volley_gap": 3, "ring": 30,
		"ring_gap": 5, "tail": 10, "tail_gap": 5, "sweep": "fast_home",
		"giga0": -300.0, "hell": false, "goomba": true, "biggery": true,
		"dookola": true, "rockets": true},
	# boss_8_fight — the bullet-hell finale (sekwencja_rakiet).
	{"wps": WP_MAIN, "volley": 20, "volley_gap": 3, "ring": 30,
		"ring_gap": 5, "tail": 10, "tail_gap": 5, "sweep": "fast_home",
		"giga0": -300.0, "hell": true},
]
## Original g_energia ceilings — the missile swarm (obj 49) only fires
## while energia > 4000, so only the last three bosses qualify; the
## fraction preserves each boss's cutoff as a health ratio.
const ORIG_MAX_HP := [1000.0, 15000.0, 1000.0, 1500.0, 3500.0,
	15000.0, 35000.0, 50000.0]
## 12 launch offsets from the boss_N_fight missile block (obj 49).
const MISSILE_OFFSETS := [
	Vector2(-69, -115), Vector2(50, -115), Vector2(-101, -115),
	Vector2(18, -115), Vector2(-37, -147), Vector2(82, -147),
	Vector2(-101, -115), Vector2(18, -115), Vector2(50, -115),
	Vector2(-37, -147), Vector2(82, -147), Vector2(50, -147)]

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
# boss_N_fight.gd state — g_sekwencja dance/sweep, g_sekwencja2 barrage
# machine, g_giga orb cycle, team/biggery/rocket timers, boss_8 finale.
var _seq := 0
var _dox := 452.0
var _doy := 350.0
var _ixor := 0.0
var _rozstrzel := 0.0
var _rozstrzelywywuj := 0.0
var _sq2 := 0
var _sq2_t := 0.0
var _sq2_n := 0.0
var _rakiety := 0.0
var _giga_t := 0.0
var _giga_orb: NativeEnemy = null
var _gigatak := false
var _rzuc_raz := false
var _kiedy_team := 0.0
var _kiedy_biggery := 0.0
var _promien_biggery := 0.0
var _kat_biggery := 0.0
var _biggery: Array = []
var _wypusc_goombe := 0.0
var _wypuszczanie_goomby := 0.0
var _rakieta := 0.0
var _ulatwiacz := 0.0
var _laser_t := 0.0
var _seq_rakiet := 0.0
var _gigatron := 0
var _gigatime := 0.0
var _ilosc_rakiet := 0
var _strzelaj_rakiet := 0.0
var _gigarandom := 0.0
var _rakietnice := 0.0
var hero_name := ""                 # set in _ready for end-talk lines
var _hp_bar: ProgressBar
var _dialogue: NativeBossDialogue


func _ready() -> void:
	add_to_group("enemies")
	max_health = BASE_HP * TIER_HP_MULT[mini(tier, TIER_HP_MULT.size() - 1)]
	if VARIANTS.has(variant):
		max_health *= VARIANTS[variant]["hp_mult"]
	health = max_health
	# g_giga starts at -300 in most scripts (first orb ~600f in); boss_2
	# starts at 0.
	_giga_t = float(FIGHT_CFG[mini(tier, FIGHT_CFG.size() - 1)]
		.get("giga0", -300.0))

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
		Phase.FIGHT, Phase.ENRAGE:
			_fight_tick()
		Phase.DYING:
			pass

	if _flash > 0:
		_flash -= 1
		_anim.modulate = Color(3, 3, 3)
	else:
		_anim.modulate = Color.WHITE

	_update_hp_bar()
	_check_player_collision()


## Per-frame fight logic — ports the ev_8_0 bodies of boss_N_fight.gd.
## Every boss shares the same skeleton: waypoint dance (g_sekwencja),
## the sq2 barrage state machine, the giga orb cycle, then per-script
## extras (sweep, teams, orbit pair, rockets, boss_8 hell).
func _fight_tick() -> void:
	var cfg: Dictionary = FIGHT_CFG[mini(tier, FIGHT_CFG.size() - 1)]
	if cfg.get("hell", false):
		_boss8_tick(cfg)
	else:
		_seq_tick(cfg)
	_barrage_tick(cfg)
	_giga_tick()
	_team_tick(cfg)
	_extras_tick(cfg)
	if health < max_health * 0.35 and phase == Phase.FIGHT:
		phase = Phase.ENRAGE


## g_sekwencja dance + rozstrzel sweep + g_ixor movement — shared by
## boss_1..7 (boss_8 has its own gated variant in _boss8_tick).
func _seq_tick(cfg: Dictionary) -> void:
	var has_sweep: bool = cfg["sweep"] != ""
	if has_sweep and _giga_t < 300.0:
		_rozstrzel += 1.0
		if _rozstrzel > 1000.0 and _giga_t < 300.0 and _seq < 100:
			_seq = 100
		match _seq:
			100:
				_dox = 100.0; _doy = 200.0; _seq = 101
			200:
				_seq = 201; _dox = 900.0; _doy = 200.0
			202:
				_seq = 0; _rozstrzel = 0.0
			201:
				_rozstrzelywywuj += 1.0
				if _rozstrzelywywuj >= 20.0:
					_rozstrzelywywuj = 0.0
					var kind: String = cfg["sweep"]
					var pos := Vector2(position.x + randf_range(-8, 8),
						position.y + (16.0 if kind == "slow_home" else 80.0))
					_fire_boss_bullet(kind, pos)
			_:
				if _seq >= 102 and _seq < 200:
					_seq += 1
	if _seq == 13 and (not has_sweep or _rozstrzel < 1000.0):
		_seq = 0
	if _seq < 100:
		var w: Array = cfg["wps"][_seq % cfg["wps"].size()]
		_dox = ((NativeGame.room_size().x - 120.0) / 2.0) \
			if w[0] < 0 else float(w[0])
		_doy = float(w[1])
	_move_toward_target(has_sweep)


## boss_8_fight.gd — the finale doesn't use the normal dance: waypoint
## targets only apply after g_rakietnice>500 warmup and freeze once
## g_rozstrzel passes g_kiedy_rozstrzel; the sekwencja_rakiet beats are
## the real attack.
func _boss8_tick(cfg: Dictionary) -> void:
	_rakietnice += 3.0
	if _rozstrzel < 1000.0 and _giga_t < 300.0:
		_rozstrzel += 1.0
	if _rakietnice > 500.0 and _rozstrzel < 1000.0:
		if _seq == 13:
			_seq = 0
		else:
			var w: Array = cfg["wps"][_seq % cfg["wps"].size()]
			_dox = ((NativeGame.room_size().x - 120.0) / 2.0) \
				if w[0] < 0 else float(w[0])
			_doy = float(w[1])
	_move_toward_target(true)
	# g_sekwencja_rakiet — the bullet-hell timeline.
	if _gigatron <= 0:
		_seq_rakiet += 1.0
	match int(_seq_rakiet):
		100:
			for d in [90.0, 45.0, 135.0]:
				_spawn_dart(509, d)
		400, 500, 600, 700, 800, 900, 1000:
			for i in 18:
				_spawn_dart(513, 20.0 * i)
		1250:
			_ilosc_rakiet = 30
		1600:
			_gigatron = 20
			_seq_rakiet = 1601.0
		2200:
			_seq_rakiet = 0.0
	# obj 510 rocket stream — every >10f while ilosc_rakiet lasts.
	_strzelaj_rakiet += 1.0
	if _ilosc_rakiet > 0 and _strzelaj_rakiet > 10.0:
		_strzelaj_rakiet = 0.0
		_ilosc_rakiet -= 1
		_spawn_dart(510, 90.0 + randf_range(-40.0, 40.0))
	# obj 512 rotating volleys — every >50f while gigatron lasts.
	_gigatime += 1.0
	if _gigatime > 50.0 and _gigatron > 0:
		_gigatime = 0.0
		_gigatron -= 1
		_gigarandom = randf_range(0.0, 1110.0)
		for i in 10:
			_spawn_dart(512, 36.0 * i + _gigarandom)


## g_ixor/g_dox/g_doy movement shared by all fight scripts — accelerate
## ±0.3/frame toward dox (cap 10, or 3 mid-sweep), damp within 16px,
## ease y by 2px/frame, advance g_sekwencja on arrival.
func _move_toward_target(has_sweep: bool) -> void:
	if _gigatak:
		return
	var sweeping := has_sweep and _rozstrzel >= 1000.0
	if position.x < _dox:
		if not sweeping or _ixor < 3.0:
			_ixor += 0.3
	elif position.x > _dox:
		if not sweeping or _ixor > -3.0:
			_ixor -= 0.3
	_ixor = clampf(_ixor, -10.0, 10.0)
	if absf(position.x - _dox) < 16.0:
		_ixor /= 1.2
	position.x += _ixor
	position.y += signf(_doy - position.y) * minf(2.0, absf(_doy - position.y))
	if absf(position.x - _dox) < 4.0 and absf(position.y - _doy) < 4.0 \
			and absf(_ixor) < 1.0:
		_seq += 1


## g_sekwencja2 barrage machine — identical skeleton in every fight
## script; only volley/ring/tail counts and gaps differ per tier.
func _barrage_tick(cfg: Dictionary) -> void:
	match _sq2:
		0:
			_sq2 = 1
		1:
			_sq2_t += 1.0
			if _sq2_t >= 100.0:
				_sq2_t = 0.0
				_sq2_n = float(cfg["volley"])
				_sq2 = 2
		2, 4, 6, 8, 10:
			_sq2_t += 1.0
			if _sq2_t > float(cfg["volley_gap"]) and _sq2_n > 0.0 \
					and _seq < 9 and _rozstrzel < 1000.0:
				_sq2_n -= 1.0
				_sq2_t = 0.0
				_fire_boss_bullet("aimed", Vector2(
					position.x + randf_range(-8.0, 8.0),
					position.y + 80.0 + randf_range(-8.0, 8.0)))
			if _sq2_n <= 0.0:
				_sq2 += 1
		3, 5, 7, 9, 11:
			_sq2_t += 1.0
			if _sq2_t >= 50.0:
				_sq2_t = 0.0
				_sq2_n = float(cfg["volley"])
				_sq2 += 1
		12:
			_sq2_t += 1.0
			if _sq2_t > float(cfg["ring_gap"]) and _sq2_n > 0.0:
				_sq2_n -= 1.0
				_sq2_t = 0.0
				_fire_boss_bullet("down_accel", position)
			if _sq2_n <= 0.0:
				_sq2 = 13
		13:
			_sq2_t += 1.0
			if _sq2_t >= 50.0:
				_sq2_t = 0.0
				_sq2_n = float(cfg["tail"])
				_sq2 = 14
		14:
			_sq2_t += 1.0
			if _sq2_t > float(cfg["tail_gap"]) and _sq2_n > 0.0:
				_sq2_n -= 1.0
				_sq2_t = 0.0
				_fire_boss_bullet("slow_home",
					Vector2(position.x, position.y + 16.0))
			if _sq2_n <= 0.0:
				_sq2 = 1
				_sq2_t = 0.0


## g_giga cycle — inside the arena box the counter climbs; at 300 the
## boss rears back (g_gigatak) and launches o_bossgiga (obj 170) above
## itself; past 400 the orb goes live, the boss dives to y=500, and a
## second orb follows ~50f later (g_rzuc_jeszcze_raz).
func _giga_tick() -> void:
	# g_giga climbs only inside the arena box while no sweep is active;
	# ==300 launches the orb (g_gigatak freezes movement), >400 resets.
	if _giga_t < 400.0 and _giga_t > -400.0 \
			and position.x > 100.0 and position.x < 800.0 \
			and position.y > 250.0 and _rozstrzel < 1000.0:
		_giga_t += 1.0
		if _giga_t == 300.0:
			_gigatak = true
			_giga_orb = _spawn_giga_orb()
	if _giga_t > 400.0:
		if _rzuc_raz:
			_giga_t = -300.0
			_rzuc_raz = false
		else:
			_giga_t = 250.0
			_rzuc_raz = true
		_gigatak = false
		_doy = 500.0


func _spawn_giga_orb() -> NativeEnemy:
	var orb := NativeEnemy.new()
	orb.kind = NativeEnemy.Kind.GHOST
	orb.sprite_id_override = 201
	orb.health = 12.0
	orb.global_position = position + Vector2(0, -200)
	get_parent().add_child(orb)
	return orb


## Per-tier extras — team releases, the bossgiga2 orbit pair, paired
## rockets, boss_2's wing lasers and bonus drops, and the obj-49
## missile swarm (only bosses whose original max HP exceeds 4000).
func _team_tick(cfg: Dictionary) -> void:
	# g_wypusc_goombe — goomba_team (356) squads early in each cycle.
	if cfg.get("goomba", false):
		_wypusc_goombe += 1.0
		_wypuszczanie_goomby += 1.0
		var window := 100.0 if tier == 4 else 150.0
		if _wypuszczanie_goomby < window and _wypusc_goombe > 30.0:
			_wypusc_goombe = 0.0
			_spawn_team_squad()
		if _wypuszczanie_goomby > 800.0:
			_wypuszczanie_goomby = 0.0
	# g_kiedy_team — o_enemy_dookola_1 (410) surrounder near the player.
	if cfg.get("dookola", false):
		_kiedy_team += 1.0
		if _kiedy_team > 400.0:
			_kiedy_team = -400.0
			var ship := get_tree().get_first_node_in_group("player")
			var ring := NativeEnemyRing.new()
			ring.orbiters_count = 6
			ring.orbiter_kinds = [NativeEnemy.Kind.GOOMBA,
				NativeEnemy.Kind.RUNNER, NativeEnemy.Kind.MINI,
				NativeEnemy.Kind.UFO_A]
			ring.orbiter_health = 8.0
			ring.start_radius = 130.0
			ring.shrink_delay = 700.0
			ring.global_position = (ship.global_position if ship != null
				else position) + Vector2(0, 60)
			get_parent().add_child(ring)
	# g_kiedy_biggery — the paired bossgiga2 (419) orbiters.
	if cfg.get("biggery", false):
		_kiedy_biggery += 1.0
		if _kiedy_biggery > 800.0:
			_kiedy_biggery = 0.0
			for i in 2:
				var orb := NativeEnemy.new()
				orb.kind = NativeEnemy.Kind.MINI
				orb.sprite_id_override = 201
				orb.health = 10.0
				orb.contact_damage = 20.0
				orb.global_position = position
				get_parent().add_child(orb)
				_biggery.append(orb)
			_promien_biggery = 0.0
			_kat_biggery = 0.0
		if not _biggery.is_empty():
			_promien_biggery += 2.0
			_kat_biggery += _promien_biggery / 400.0 \
				+ 1.0 / (_promien_biggery / 300.0)
			var anchor := _biggery_anchor()
			for i in _biggery.size():
				var orb: NativeEnemy = _biggery[i]
				if not is_instance_valid(orb):
					continue
				if _promien_biggery > 1200.0:
					orb.queue_free()
					continue
				orb.global_position = anchor.global_position \
					+ Vector2(sin(deg_to_rad(_kat_biggery + 180.0 * i)),
						cos(deg_to_rad(_kat_biggery + 180.0 * i))) \
					* _promien_biggery
			_biggery = _biggery.filter(func(o): return is_instance_valid(o))
			if _biggery.is_empty():
				_promien_biggery = 0.0
				_kat_biggery = 0.0
	# g_rakieta — boss_6/7 paired rockets (116) every 220f.
	if cfg.get("rockets", false):
		_rakieta += 1.0
		if _rakieta > 220.0:
			_rakieta = 0.0
			for ox in [-20.0, 20.0]:
				var r := NativeEnemy.new()
				r.kind = NativeEnemy.Kind.RUNNER
				r.dart_dir = Vector2.DOWN * 3.0
				r.dart_speed = 3.0
				r.health = 8.0
				r.global_position = position + Vector2(ox, -111)
				get_parent().add_child(r)


var _big_anchor: Node2D = null
func _biggery_anchor() -> Node2D:
	if _big_anchor == null or not is_instance_valid(_big_anchor):
		_big_anchor = Node2D.new()
		_big_anchor.position = Vector2(0, -50)
		add_child(_big_anchor)
	return _big_anchor


func _spawn_team_squad() -> void:
	var squad := NativeEnemyRing.new()
	squad.orbiters_count = 5
	squad.orbiter_kinds = [NativeEnemy.Kind.GOOMBA,
		NativeEnemy.Kind.GOOMBA, NativeEnemy.Kind.MINI]
	squad.orbiter_health = 8.0
	squad.start_radius = 110.0
	squad.shrink_delay = 600.0
	squad.global_position = position + Vector2(0, 80)
	get_parent().add_child(squad)


func _extras_tick(cfg: Dictionary) -> void:
	# boss_2 wing lasers — g_laser counts while energia>8000; past
	# 1000 it vents twin bolts (obj 112) from the wingtips.
	if cfg.get("laser", false):
		if health / max_health > 0.53:
			_laser_t += 1.0
			if _laser_t > 1000.0:
				_laser_t = 0.0
				for ox in [-122.0, 122.0]:
					var b := NativeEnemyBullet.new()
					b.sprite_id = 108
					b.global_position = position + Vector2(ox, 0)
					b.velocity = Vector2.DOWN * 6.0
					get_parent().add_child(b)
	# boss_2 bonus drops — g_ulatwiacz>400 releases a pickup up top.
	if cfg.get("bonus", false):
		_ulatwiacz += 1.0
		if _ulatwiacz > 400.0:
			_ulatwiacz = 0.0
			var p := NativePickup.new()
			p.kind = NativePickup.Kind.GEM
			p.tier = 3
			p.global_position = Vector2(randf_range(16, 666), -64)
			get_parent().add_child(p)
	# Missile swarm — obj 49 launches while energia>4000 (only the
	# last three original bosses qualify) and seq<=9.
	var orig_max: float = ORIG_MAX_HP[mini(tier, 7)]
	if orig_max > 4000.0 and health / max_health > 4000.0 / orig_max \
			and _seq <= 9:
		_rakiety += 1.0
		if _rakiety > 500.0:
			_rakiety = 0.0
			var pairs: int = [2, 4, 6][_fight_phase()]
			for i in mini(pairs * 2, MISSILE_OFFSETS.size()):
				var m := NativeEnemy.new()
				m.kind = NativeEnemy.Kind.RUNNER
				m.health = 8.0
				m.global_position = position + MISSILE_OFFSETS[i]
				get_parent().add_child(m)


## boss_8 "dodatkowy" additions — objects 509/510/512/513 are enemy
## fighters (parent o_enemy_1) launched on fixed GM directions; sprite
## 502 for 509/512, sprite 41 (enemy_9) for 510/513.
func _spawn_dart(obj_id: int, gm_dir_deg: float) -> void:
	var d := NativeEnemy.new()
	d.kind = NativeEnemy.Kind.RUNNER
	d.sprite_id_override = 502 if obj_id in [509, 512] else 41
	d.dart_dir = Vector2.RIGHT.rotated(deg_to_rad(gm_dir_deg)) * 3.5
	d.dart_speed = 3.5
	d.health = 15.0
	d.global_position = position
	get_parent().add_child(d)


func _fire_boss_bullet(kind: String, pos: Vector2) -> void:
	var b := NativeEnemyBullet.new()
	b.move_kind = kind
	b.global_position = pos
	b.damage = 15.0
	get_parent().add_child(b)
	NativeAssets.play_sound(79)


func _fight_phase() -> int:
	var frac := health / max_health
	if frac > 0.66:
		return 0
	if frac > 0.33:
		return 1
	return 2

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
	kaboom.variant = "kaboom"
	kaboom.global_position = position
	get_parent().add_child(kaboom)
	for i in 6:
		var boom := NativeExplosion.new()
		boom.variant = "falling" if i % 2 == 0 else "debris"
		boom.global_position = position + Vector2(randf_range(-80, 80), randf_range(-50, 50))
		get_parent().add_child(boom)
	for i in 4:
		var spark := NativeExplosion.new()
		spark.variant = "spark"
		spark.global_position = position
		get_parent().add_child(spark)


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
