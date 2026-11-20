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
		"giga0": -300.0, "hell": false, "biggery": true,
		"dookola": true, "rockets": true},
	# boss_7_fight — hyper cadence (20 shots / 3f), bossbul_33 sweep,
	# faster ring/tail, rockets, teams, orbit pair.
	{"wps": WP_MAIN, "volley": 20, "volley_gap": 3, "ring": 30,
		"ring_gap": 5, "tail": 10, "tail_gap": 5, "sweep": "fast_home",
		"giga0": -300.0, "hell": false, "biggery": true,
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
## boss_N_fight missile swarm (obj 49 = enemy_9) — volley size/positions
## scale with g_etap, the stage's slot in the map perioder schedule
## (<10 early, 10-19 mid, >=20 late game).
const MISSILE_VOLLEYS := [
	[Vector2(-69, -115), Vector2(50, -115)],
	[Vector2(-101, -115), Vector2(18, -115), Vector2(-37, -147),
		Vector2(82, -147)],
	[Vector2(-101, -115), Vector2(18, -115), Vector2(50, -115),
		Vector2(-37, -147), Vector2(82, -147), Vector2(50, -147)]]
## boss_2 g_smierc milestone thresholds as fractions of its 15000 HP —
## each crossing sheds a wing burst and awards +1000 score.
const SMIERC_FRACS := [0.5333, 0.2667, 0.0667]
const SMIERC_OFFSETS := [Vector2(122, 0), Vector2(-122, 0),
	Vector2(50, -50), Vector2(-50, -50), Vector2(50, 40), Vector2(-50, 40)]

# Alternate boss encounters from objects/bosses/ — keyed by the exact
# GameMaker object each stage script instance_creates. `hp` is the
# original's absolute g_energia (the *_2..*_7 scripts are separate
# difficulty objects, not reskins): flame_cans 600/1200/1200/2000,
# fat_boy 8000/8000/3000/1500/7000/9000/12000, ufo_mega 800.
# fat_boy variants also carry cannon `adders`, a periodic obj-116 dart
# fan (`rockets` = frame period; `side` = wing pair at x±100), and
# six-coin death drops (`coins`). flame_cans variants carry volley
# size `volley` and charge-cycle head start `charge`.
const VARIANTS := {
	"ufo_mega": {"name": "UFO MEGA", "sprite": 174, "scale": 1.1,
		"tint": Color(0.8, 0.9, 1.0), "hp": 800.0},
	"flame_cans": {"name": "FLAME CANS", "sprite": 182, "scale": 1.0,
		"tint": Color(1.0, 0.6, 0.3), "hp": 600.0,
		"volley": 10.0, "charge": 800.0},
	"flame_cans_2": {"name": "FLAME CANS", "sprite": 182, "scale": 1.0,
		"tint": Color(1.0, 0.6, 0.3), "hp": 1200.0,
		"volley": 4.0, "charge": 800.0},
	"flame_cans_3": {"name": "FLAME CANS", "sprite": 182, "scale": 1.0,
		"tint": Color(1.0, 0.6, 0.3), "hp": 1200.0,
		"volley": 10.0, "charge": 200.0},
	"flame_cans_4": {"name": "FLAME CANS", "sprite": 182, "scale": 1.0,
		"tint": Color(1.0, 0.6, 0.3), "hp": 2000.0,
		"volley": 20.0, "charge": 800.0},
	"fat_boy": {"name": "KOOPA_TROOPA'S FAT_BOY", "sprite": 178,
		"scale": 0.9, "tint": Color(1.0, 0.85, 0.6), "hp": 8000.0,
		"adders": [1.0, 1.3, 1.7]},
	"fat_boy_2": {"name": "KOOPA_TROOPA'S FAT_BOY", "sprite": 178,
		"scale": 0.9, "tint": Color(1.0, 0.85, 0.6), "hp": 8000.0,
		"adders": [1.0, 1.3, 1.7], "rockets": 420.0},
	"fat_boy_3": {"name": "KOOPA_TROOPA'S FAT_BOY", "sprite": 178,
		"scale": 0.9, "tint": Color(1.0, 0.85, 0.6), "hp": 3000.0,
		"adders": [1.0, 1.3, 1.7], "rockets": 620.0},
	"fat_boy_4": {"name": "KOOPA_TROOPA'S FAT_BOY", "sprite": 178,
		"scale": 0.9, "tint": Color(1.0, 0.85, 0.6), "hp": 1500.0,
		"adders": [1.0, 1.3, 1.7], "coins": true},
	"fat_boy_5": {"name": "KOOPA_TROOPA'S FAT_BOY", "sprite": 178,
		"scale": 0.9, "tint": Color(1.0, 0.85, 0.6), "hp": 7000.0,
		"adders": [1.0, 2.5, 1.0], "rockets": 520.0, "coins": true},
	"fat_boy_6": {"name": "UPGRADED_KOOPA_TROOPA'S_FAT_BOY",
		"sprite": 178, "scale": 0.9, "tint": Color(1.0, 0.85, 0.6),
		"hp": 9000.0, "adders": [1.0, 1.1, 1.2], "rockets": 520.0,
		"side": true, "coins": true},
	"fat_boy_7": {"name": "UPGRADED_KOOPA_TROOPA'S_FAT_BOY",
		"sprite": 178, "scale": 0.9, "tint": Color(1.0, 0.85, 0.6),
		"hp": 12000.0, "adders": [1.0, 1.1, 1.2], "rockets": 520.0,
		"side": true, "coins": true},
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
var _drift_x := 0.0
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
var _orbit_radius := 0.0
var _orbit_angle := 0.0
var _biggery: Array = []
var _wypusc_goombe := 0.0
var _wypuszczanie_goomby := 0.0
var _rakieta := 0.0
var _ulatwiacz := 0.0
var _laser_t := 0.0
var _seq_rakiet := 0.0
var _gigatron := 0
var _gigatime := 0.0
var _rockets_left := 0
var _strzelaj_rakiet := 0.0
var _gigarandom := 0.0
var _rakietnice := 0.0
var _smierc_done := [false, false, false]   # boss_2 HP milestone bursts
var _laser_charge: Array = []               # sprite-109 charge effects
var hero_name := ""                 # set in _ready for end-talk lines
var _hp_bar: ProgressBar
var _body_radius := 85.0          # hull block radius — set from sprite size
var _dialogue: NativeBossDialogue
# Clown render stack — boss_N_fight draw events compose sprite 328
# (hull) over fixed overlays: 332 glow, 329 body, 330 rotor (5 additive
# ghost phases), 334 pulsing eyes, all jittered by g_obrywacz on hits.
# boss_8 adds two sprite-501 spoiler panels (g_spoiler deploy).
var _visual: Node2D
var _rotor: Sprite2D
var _rotor_ghosts: Array = []
var _eyes: Array = []
var _spoilers: Array = []
var _wirnik := 0.0
var _oczu := 0.0
var _obrywacz := 0.0
var _jitter := Vector2.ZERO
var _spoiler := 0.0


func _ready() -> void:
	add_to_group("enemies")
	max_health = BASE_HP * TIER_HP_MULT[mini(tier, TIER_HP_MULT.size() - 1)]
	if VARIANTS.has(variant):
		# Variant objects carry their own absolute g_energia — they
		# don't scale with the clown tier table.
		max_health = float(VARIANTS[variant]["hp"])
		if VARIANTS[variant].has("adders"):
			_fb_adders = VARIANTS[variant]["adders"]
		if VARIANTS[variant].has("rockets"):
			_fb_rocket_period = float(VARIANTS[variant]["rockets"])
			_fb_side = bool(VARIANTS[variant].get("side", false))
		if VARIANTS[variant].has("volley"):
			_fc_volley_max = float(VARIANTS[variant]["volley"])
		_ladowanie = float(VARIANTS[variant].get("charge", 0.0))
	health = max_health
	# g_giga starts at -300 in most scripts (first orb ~600f in); boss_2
	# starts at 0.
	_giga_t = float(FIGHT_CFG[mini(tier, FIGHT_CFG.size() - 1)]
		.get("giga0", -300.0))

	# Spawn above the arena and descend to the fight line.
	var room := NativeGame.room_size()
	position = Vector2(room.x / 2.0, -120.0)

	# All eight boss_N_fight objects draw the same clown hull (sprite
	# 328) — the original's only visual escalation is the damage jitter
	# and HP-state frames, not a sprite swap. Alternate encounters
	# (ufo_mega/fat_boy/flame_cans) keep their own hulls.
	var profile: Dictionary = TIER_PROFILES[mini(tier, TIER_PROFILES.size() - 1)]
	var sprite_id: int = 328
	if VARIANTS.has(variant):
		var v: Dictionary = VARIANTS[variant]
		boss_name = v["name"]
		sprite_id = v["sprite"]
		profile = {"sprite": sprite_id, "scale": v["scale"],
			"tint": v["tint"]}
	# fat_boy_boss_2.gd — first FAT_BOY warns about the fat-boy enemies.
	if variant.begins_with("fat_boy"):
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
	if variant == "":
		# Clown fights hold g_animacja = 0 — a static hull frame, not a
		# playing animation (only boss_2's HP states change it, and its
		# hull isn't sprite 328 anyway).
		_anim.pause()
		_build_clown_layers()
	else:
		add_child(_anim)

	# boss_2 laser charge effects (o_bosefe, sprite 109) — parked at the
	# wingtips, revealed during the g_laser 800-1000 charge window.
	if FIGHT_CFG[mini(tier, FIGHT_CFG.size() - 1)].get("laser", false):
		for ox in [-122.0, 122.0]:
			var c := _sprite_layer(self, 109, Vector2(ox, 32), true)
			c.visible = false
			_laser_charge.append(c)
	if variant.begins_with("fat_boy"):
		_build_fatboy_cannons()

	# Hull block radius from the real sprite bounds (0.45 · longest
	# side · scale, same rule as NativeEnemy) — keeps the ship from
	# overlapping the boss sprite at any rotation.
	var hull_tex := NativeAssets.sprite_frame(sprite_id, 0)
	if hull_tex != null:
		var hs := hull_tex.get_size()
		_body_radius = maxf(85.0,
			maxf(hs.x, hs.y) * 0.45 * float(profile["scale"]))

	_build_hp_bar()
	_start_intro_speech()


## The boss_N_fight draw events render a fixed layer stack around the
## hull sprite: additive glow (332) behind, body plate (329), the
## flapping rotor (330, |sin(wirnik)| x-scale + 5 ghost phases), hull,
## then pulsing additive eyes (334). boss_8 adds spoiler panels (501).
func _build_clown_layers() -> void:
	_visual = Node2D.new()
	add_child(_visual)
	_sprite_layer(_visual, 332, Vector2.ZERO, true)
	_sprite_layer(_visual, 329, Vector2(0, 8), false)
	_rotor = _sprite_layer(_visual, 330, Vector2(0, 58), true)
	for phase in [10.0, 20.0, 30.0, 50.0]:
		var g := _sprite_layer(_visual, 330, Vector2(0, 58), true)
		g.modulate.a = 0.3
		g.set_meta("phase", phase)
		_rotor_ghosts.append(g)
	_visual.add_child(_anim)
	for i in 4:
		var eye := _sprite_layer(_visual, 334,
			Vector2(-33 if i % 2 == 0 else 23, -58), true)
		eye.scale = Vector2.ONE * (2.0 if i >= 2 else 1.0)
		_eyes.append(eye)
	if tier == 7:
		for i in 2:
			var sp := _sprite_layer(_visual, 501, Vector2.ZERO, false)
			sp.scale.x = -1.0 if i == 1 else 1.0
			_spoilers.append(sp)


func _sprite_layer(parent: Node, sprite_id: int, offset: Vector2,
		additive: bool) -> Sprite2D:
	var s := Sprite2D.new()
	var tex := NativeAssets.sprite_frame(sprite_id, 0)
	if tex != null:
		s.texture = tex
	s.offset = -NativeAssets.sprite_origin(sprite_id)
	s.position = offset
	if additive:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = mat
	parent.add_child(s)
	return s


## Per-frame animation for the layer stack — ports the draw-event
## counters: g_wirnik += 15 drives the rotor flip, g_efekt_oczu the
## eye pulse, g_obrywacz decays the hit jitter, g_spoiler deploys the
## boss_8 airbrakes.
func _anim_tick() -> void:
	if _visual == null:
		return
	_wirnik += 15.0
	if _rotor != null:
		_rotor.scale.x = absf(sin(deg_to_rad(_wirnik)))
		for g in _rotor_ghosts:
			g.scale.x = absf(sin(deg_to_rad(_wirnik + g.get_meta("phase"))))
	_oczu += 1.0
	var eye_rot := deg_to_rad(cos(deg_to_rad(_oczu)) * 534.0)
	for e in _eyes:
		e.rotation = eye_rot
	if _obrywacz > 0.5:
		_jitter = Vector2(randf_range(-_obrywacz, _obrywacz),
			randf_range(-_obrywacz, _obrywacz))
		_obrywacz /= 1.05
	else:
		_jitter = Vector2.ZERO
		_obrywacz = 0.0
	_visual.position = _jitter
	if tier == 7 and _spoiler < 60.0:
		_spoiler += 0.5
		for i in _spoilers.size():
			var sp: Sprite2D = _spoilers[i]
			sp.position = Vector2((1.0 if i == 0 else -1.0) * _spoiler,
				-_spoiler)
			sp.rotation = deg_to_rad(_drift_x)


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
			_anim_tick()
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
	# Variant bosses run their own object AI, not the clown choreography.
	# The *_2..*_7 objects share the family script — match by prefix.
	if variant == "ufo_mega":
		_ufo_tick()
		return
	if variant.begins_with("fat_boy"):
		_fatboy_tick()
		return
	if variant.begins_with("flame_cans"):
		_flame_cans_tick()
		return
	if cfg.get("hell", false):
		_boss8_tick(cfg)
	else:
		_seq_tick(cfg)
		# boss_8_fight's g_sekwencja2 is vestigial — it latches to 1 and
		# is never read again, so the barrage machine doesn't run there.
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
					# boss_3-6 sweep fires obj 119 dead-center at
					# (x, y+16); boss_7's obj 506 scatters ±16 around
					# (x, y+80) — matching the original spawn points.
					var pos := Vector2(position.x, position.y + 16.0) \
						if kind == "slow_home" else Vector2(
							position.x + randf_range(-16.0, 16.0),
							position.y + 80.0 + randf_range(-16.0, 16.0))
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
			_rockets_left = 30
		1600:
			_gigatron = 20
			_seq_rakiet = 1601.0
		2200:
			_seq_rakiet = 0.0
	# obj 510 rocket stream — every >10f while ilosc_rakiet lasts.
	_strzelaj_rakiet += 1.0
	if _rockets_left > 0 and _strzelaj_rakiet > 10.0:
		_strzelaj_rakiet = 0.0
		_rockets_left -= 1
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
		if not sweeping or _drift_x < 3.0:
			_drift_x += 0.3
	elif position.x > _dox:
		if not sweeping or _drift_x > -3.0:
			_drift_x -= 0.3
	_drift_x = clampf(_drift_x, -10.0, 10.0)
	if absf(position.x - _dox) < 16.0:
		_drift_x /= 1.2
	position.x += _drift_x
	position.y += signf(_doy - position.y) * minf(2.0, absf(_doy - position.y))
	if absf(position.x - _dox) < 4.0 and absf(position.y - _doy) < 4.0 \
			and absf(_drift_x) < 1.0:
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
				# obj 121 (bossbul_3) at (x±16, y+80±16), rodzaj=20.
				_fire_boss_bullet("aimed", Vector2(
					position.x + randf_range(-16.0, 16.0),
					position.y + 80.0 + randf_range(-16.0, 16.0)))
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
			# obj 120 (bossbul_2) at (x,y), direction -90 — gated only
			# on the sweep timer, no g_sekwencja check.
			if _sq2_t > float(cfg["ring_gap"]) and _sq2_n > 0.0 \
					and _rozstrzel < 1000.0:
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
			# obj 119 (bossbul_1) at (x, y+16), rodzaj=0.
			if _sq2_t > float(cfg["tail_gap"]) and _sq2_n > 0.0 \
					and _rozstrzel < 1000.0:
				_sq2_n -= 1.0
				_sq2_t = 0.0
				_fire_boss_bullet("slow_home",
					Vector2(position.x, position.y + 16.0))
			if _sq2_n <= 0.0:
				_sq2 = 1
				_sq2_t = 0.0


## o_ufo_mega — a strafing gunship, not a dancer: it hard-tracks the
## player's x (position.x = target + decaying offset), and whenever it
## settles within 25px it spends ~200f charging (g_strzal 50 +
## delayshot 150) then drops an o_bullet_5 orb (sprite 54, dmg 10)
## from y-24. It repeats until killed; below half HP it swaps to the
## cracked sprite 175.
var _ufo_seq := 0
var _ufo_tx := 0.0
var _ufo_off := 0.0
var _ufo_strzal := 0.0
var _ufo_delayshot := 0.0
var _ufo_cracked := false
var _ufo_init := false

func _ufo_tick() -> void:
	var ship := NativeGame.player()
	if ship == null:
		return
	# Create event: g_gdzie_jest_gracz = player.x +-60, dodawaczuj =
	# x - target — the ship may not exist yet at _ready, so init lazily.
	if not _ufo_init:
		_ufo_init = true
		_ufo_tx = ship.global_position.x + randf_range(-60.0, 60.0)
		_ufo_off = position.x - _ufo_tx
	if _ufo_seq == 0:
		position.x = _ufo_tx + _ufo_off
		_ufo_off /= 1.05
		if absf(position.x - ship.global_position.x) <= 25.0:
			_ufo_seq = 2
			_ufo_strzal = 50.0
			_ufo_delayshot = 0.0
	else:
		_ufo_strzal -= 1.0
		_ufo_delayshot += 1.0
		if _ufo_strzal <= 0.0 and _ufo_delayshot >= 150.0:
			var b := NativeEnemyBullet.new()
			b.sprite_id = 54
			b.global_position = position + Vector2(0, -24)
			# o_bullet_5 drops ~24px then dies after ~10f.
			b.velocity = Vector2.DOWN * 1.6
			b.damage = 10.0
			b.life_frames = 15
			get_parent().add_child(b)
			# Next run: re-aim at the player's current x +/-30.
			_ufo_tx = ship.global_position.x + randf_range(-30.0, 30.0)
			_ufo_off = position.x - _ufo_tx
			_ufo_seq = 0
			_ufo_delayshot = 0.0
	# g_podniszczony — the original cracks the hull at energia < 50
	# (absolute, not a fraction): sprite swaps 174 -> 175.
	if not _ufo_cracked and health < 50.0:
		_ufo_cracked = true
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("fight")
		for tex in NativeAssets.sprite_frames(175):
			frames.add_frame("fight", tex)
		frames.set_animation_speed("fight", ANIM_FPS)
		_anim.sprite_frames = frames
		_anim.play("fight")
		_anim.offset = -NativeAssets.sprite_origin(175)


## o_fatboy_boss — dances the top band (dox 100-850, doy 100-200) while
## its barrel tracks the player at 0.5deg/frame. Three cannon pods
## (obj 370, sprite 179) sit at the barrel tip 90px out at aim+90deg;
## each reloads on its own adder (1.0/1.3/1.7) — zaladuj>150 fires an
## o_bullet_fatboy2 (sprite 180, speed 4 +0.02/f, 200 dmg) and the pod
## squashes (xscale 0.2 -> 1). Contact is lethal: it drags the ship in
## and burns 500 hull.
var _fb_seq := 0
var _fb_v := Vector2.ZERO
var _fb_dir := 0.0
var _fb_cannons: Array = []        # {sprite, timer, adder, squash}
var _fb_zaladuj := [-270.0, -340.0, -350.0]
var _fb_adders := [1.0, 1.3, 1.7]
# fat_boy_boss_2+ periodic obj-116 dart barrages: `rockets` is the frame
# period, `side` variants fire a wing pair at x+-100 first, and every
# barrage is followed 40f later by a second 90/45/135 fan (g_podwujne).
var _fb_rocket_period := 0.0
var _fb_side := false
var _fb_rakieta := 0.0
var _fb_podwujne := 0.0

func _fatboy_tick() -> void:
	var ship := NativeGame.player()
	# g_sekwencja: 1-99 count, 100 picks a target, 201 moves.
	if _fb_seq >= 1 and _fb_seq < 100:
		_fb_seq += 1
	elif _fb_seq == 100:
		_dox = randf_range(100.0, 850.0)
		_doy = randf_range(100.0, 200.0)
		_fb_seq = 201
	elif _fb_seq == 201:
		for axis in 2:
			var pos := position.x if axis == 0 else position.y
			var tgt := _dox if axis == 0 else _doy
			var v := _fb_v.x if axis == 0 else _fb_v.y
			if pos < tgt - 40.0:
				v += 0.05
			elif pos > tgt + 40.0:
				v -= 0.05
			else:
				v /= 1.055
			if absf(v) < 0.005:
				v = 0.0
			if axis == 0:
				_fb_v.x = v
			else:
				_fb_v.y = v
		if _fb_v == Vector2.ZERO \
				and absf(position.x - _dox) <= 40.0 \
				and absf(position.y - _doy) <= 40.0:
			_fb_seq = 1
		rotation = deg_to_rad(-_fb_v.x * 5.0)
		position += _fb_v
	else:
		_fb_seq = 1
	# Barrel tracks the player at 0.5deg/frame.
	if ship != null:
		var want: float = (ship.global_position - position).angle()
		_fb_dir = rotate_toward(_fb_dir, want, deg_to_rad(0.5))
	# Cannon pods at the barrel tip — radius 90 at aim+90deg.
	var tip := position + Vector2.RIGHT.rotated(_fb_dir + PI / 2.0) * 90.0
	for i in _fb_cannons.size():
		var c: Dictionary = _fb_cannons[i]
		var sp: Sprite2D = c["sprite"]
		sp.position = tip - position
		sp.rotation = _fb_dir
		if float(c["squash"]) > 0.0:
			c["squash"] = maxf(0.0, float(c["squash"]) - 0.01)
			sp.scale.x = 0.2 + (1.0 - float(c["squash"])) * 0.8
		else:
			sp.scale.x = 1.0
		c["timer"] = float(c["timer"]) + float(c["adder"])
		if float(c["timer"]) > 150.0:
			c["timer"] = 0.0
			c["squash"] = 1.0
			var b := NativeEnemyBullet.new()
			b.move_kind = "fatboy"
			b.sprite_id = 180
			b.global_position = tip
			b.damage = 200.0
			get_parent().add_child(b)
	# fat_boy_boss_2+ rocket barrages (obj 116 = o_dodatkowy_3_b,
	# sprite 41): every `rockets` frames a first volley, then g_podwujne
	# repeats a 90/45/135 fan 40f later. Side variants lead with a
	# wing pair at x+-100 instead of the center fan.
	if _fb_rocket_period > 0.0:
		_fb_rakieta += 1.0
		if _fb_rakieta > _fb_rocket_period:
			if _fb_side:
				_spawn_dart(116, 90.0, Vector2(-100, 0))
				_spawn_dart(116, 90.0, Vector2(100, 0))
			else:
				for dg in [90.0, 45.0, 135.0]:
					_spawn_dart(116, dg)
			_fb_rakieta = 0.0
			_fb_podwujne = 1.0
		if _fb_podwujne > 0.0:
			_fb_podwujne += 1.0
			if _fb_podwujne > 40.0:
				for dg in [90.0, 45.0, 135.0]:
					_spawn_dart(116, dg)
				_fb_podwujne = 0.0


func _build_fatboy_cannons() -> void:
	for i in 3:
		var s := _sprite_layer(self, 179, Vector2.ZERO, false)
		s.visible = true
		_fb_cannons.append({"sprite": s, "timer": _fb_zaladuj[i],
			"adder": _fb_adders[i], "squash": 0.0})


## o_flamecans_boss (251) — waypoint drifter with a charge-up volley:
## picks random targets in [200,650]x[100,500], banks into turns
## (image_angle = -ixor*5), then runs an 800f cannon cycle — smolder
## 0-300, charge 300-600 (screen shake), vent 600-800, and at 800
## spits 10 aimed flame bolts (obj 250, speed 5, +-10deg, dmg 20)
## every 10f before a ~77f cooldown resets the cycle.
var _fc_seq := 0
var _fc_v := Vector2.ZERO
var _ladowanie := 0.0
var _fc_sekwencer := 2
var _fc_strzelacz := 0.0
var _fc_volley := 10.0
var _fc_volley_max := 10.0   # variant volley size (4/10/20)
var _fc_podniszczony := false

func _flame_cans_tick() -> void:
	# g_sekwencja 1-199 counts up, 200 picks a new target, 201 moves.
	if _fc_seq >= 1 and _fc_seq < 200:
		_fc_seq += 1
	elif _fc_seq == 200:
		_dox = randf_range(200.0, 650.0)
		_doy = randf_range(100.0, 500.0)
		_fc_seq = 201
	elif _fc_seq == 201:
		# Inertial drift: accelerate 0.11/frame outside a +-40px box,
		# damp /1.11 inside it; sub-0.005 velocities snap to zero.
		for axis in 2:
			var pos := position.x if axis == 0 else position.y
			var tgt := _dox if axis == 0 else _doy
			var v := _fc_v.x if axis == 0 else _fc_v.y
			if pos < tgt - 40.0:
				v += 0.11
			elif pos > tgt + 40.0:
				v -= 0.11
			else:
				v /= 1.11
			if absf(v) < 0.005:
				v = 0.0
			if axis == 0:
				_fc_v.x = v
			else:
				_fc_v.y = v
		if _fc_v == Vector2.ZERO \
				and absf(position.x - _dox) <= 40.0 \
				and absf(position.y - _doy) <= 40.0:
			_fc_seq = 1
		# Bank into the turn like the original's image_angle.
		rotation = deg_to_rad(-_fc_v.x * 5.0)
		position += _fc_v
	else:
		_fc_seq = 1
	# g_ladowanie charge cycle — smolder/charge/vent then the volley.
	_ladowanie += 1.0
	if _ladowanie >= 800.0 and _fc_sekwencer < 2:
		_fc_strzelacz = 0.0
		_fc_sekwencer += 1
		_fc_volley = _fc_volley_max
		if _fc_sekwencer < 2:
			_ladowanie = 0.0
	if _fc_sekwencer == 2 and _fc_seq > 0:
		_fc_strzelacz += 1.0
		if _fc_strzelacz > 10.0:
			_fc_strzelacz = 0.0
			_fc_volley -= 1.0
			var b := NativeEnemyBullet.new()
			b.move_kind = "aimed"
			b.sprite_id = 25
			b.global_position = position
			b.damage = 20.0
			get_parent().add_child(b)
		if _fc_volley <= 0.0:
			_fc_sekwencer = 3
			_fc_volley = _fc_volley_max
	elif _fc_sekwencer >= 3 and _fc_sekwencer < 80:
		_fc_sekwencer += 1.0
		if _fc_sekwencer == 80:
			_fc_sekwencer = 0
			_fc_volley = 0.0
			_ladowanie = 0.0
	# podniszczony — below half health it takes heavy damage once.
	if not _fc_podniszczony and health < max_health * 0.5:
		_fc_podniszczony = true
		var boom := NativeExplosion.new()
		boom.variant = "burst"
		boom.global_position = position
		get_parent().add_child(boom)


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
		# boss_4 releases inside the first 150f of each 800f
		# cycle, boss_5 inside 100f.
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
			var ship := NativeGame.player()
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
				# boss_giga_2: ~400hp gravity orb — contact hauls the
				# ship in and drains 200 hull; kills pay flat 5000.
				orb.giga2_pull = true
				orb.health = 400.0
				orb.global_position = position
				get_parent().add_child(orb)
				_biggery.append(orb)
			_orbit_radius = 0.0
			_orbit_angle = 0.0
		if not _biggery.is_empty():
			_orbit_radius += 2.0
			_orbit_angle += _orbit_radius / 400.0 \
				+ 1.0 / (_orbit_radius / 300.0)
			var anchor := _biggery_anchor()
			for i in _biggery.size():
				var orb: NativeEnemy = _biggery[i]
				if not is_instance_valid(orb):
					continue
				if _orbit_radius > 1200.0:
					orb.queue_free()
					continue
				orb.global_position = anchor.global_position \
					+ Vector2(sin(deg_to_rad(_orbit_angle + 180.0 * i)),
						cos(deg_to_rad(_orbit_angle + 180.0 * i))) \
					* _orbit_radius
			_biggery = _biggery.filter(func(o): return is_instance_valid(o))
			if _biggery.is_empty():
				_orbit_radius = 0.0
				_orbit_angle = 0.0
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
	# boss_2 wing lasers — g_laser only counts while energia>8000
	# (frac > 8000/15000); frames 800-1000 show the sprite-109 charge
	# effects at the wingtips, past 1000 it vents twin sprite-108 bolts.
	if cfg.get("laser", false):
		var laser_on := health / max_health > 8000.0 / 15000.0
		if laser_on:
			_laser_t += 1.0
		for c in _laser_charge:
			c.visible = laser_on and _laser_t > 800.0 \
				and _laser_t < 1000.0
		if laser_on and _laser_t > 1000.0:
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
	# boss_2 g_smierc milestones — crossing 8000/4000/1000 HP sheds an
	# explosion + 30 flash particles (obj 15/35) at the wing hardpoints
	# and awards +1000 score each.
	if tier == 1:
		var frac := health / max_health
		for i in SMIERC_FRACS.size():
			if not _smierc_done[i] and frac <= SMIERC_FRACS[i]:
				_smierc_done[i] = true
				NativeGame.add_score(1000)
				for j in 2:
					var off: Vector2 = SMIERC_OFFSETS[i * 2 + j]
					var at := position + off
					var burst := NativeExplosion.new()
					burst.variant = "burst"
					burst.global_position = at
					get_parent().add_child(burst)
					for k in 15:
						var spark := NativeExplosion.new()
						spark.variant = "spark"
						spark.global_position = at + Vector2(
							randf_range(-20, 20),
							randf_range(-20, 20))
						get_parent().add_child(spark)
	# Missile swarm — obj 49 launches while energia>4000 (only bosses
	# whose HP cap exceeds 4000 qualify) and seq<=9; volley size and
	# spread follow g_etap (the stage's perioder slot on the map).
	var orig_max: float = ORIG_MAX_HP[mini(tier, 7)]
	if orig_max > 4000.0 and health / max_health > 4000.0 / orig_max \
			and _seq <= 9:
		_rakiety += 1.0
		if _rakiety > 500.0:
			_rakiety = 0.0
			var volley: Array = MISSILE_VOLLEYS[_etap()]
			for off in volley:
				var m := NativeEnemy.new()
				m.kind = NativeEnemy.Kind.RUNNER
				m.health = 10.0
				m.global_position = position + off
				get_parent().add_child(m)


## g_etap — the stage's index within its map region ("m:n" node key).
func _etap() -> int:
	if NativeGame.active_node == "":
		return 0
	var parts := NativeGame.active_node.split(":")
	return int(parts[1]) if parts.size() > 1 else 0


## boss_8 "dodatkowy" additions — objects 509/510/512/513 are enemy
## fighters (parent o_enemy_1) launched on fixed GM directions; sprite
## 502 for 509/512, sprite 41 (enemy_9) for 510/513.
func _spawn_dart(obj_id: int, gm_dir_deg: float,
		offset := Vector2.ZERO) -> void:
	var d := NativeEnemy.new()
	d.kind = NativeEnemy.Kind.RUNNER
	d.sprite_id_override = 502 if obj_id in [509, 512] else 41
	d.dart_dir = Vector2.RIGHT.rotated(deg_to_rad(gm_dir_deg)) * 3.5
	d.dart_speed = 3.5
	d.health = 15.0
	d.global_position = position + offset
	get_parent().add_child(d)


func _fire_boss_bullet(kind: String, pos: Vector2) -> void:
	var b := NativeEnemyBullet.new()
	b.move_kind = kind
	# Original hull sprites: bossbul_1/3/33 draw sprite 25, bossbul_2
	# draws sprite 115.
	b.sprite_id = 115 if kind == "down_accel" else 25
	b.global_position = pos
	b.damage = 15.0
	get_parent().add_child(b)
	# boss_bullet_3/33 spawn 1-2 o_bosefe_2 glow effects (obj 122,
	# sprite 109) at launch on high-effects settings.
	if kind in ["aimed", "fast_home"]:
		for i in 2:
			var glow := NativeExplosion.new()
			glow.variant = "muzzle"
			glow.global_position = pos
			get_parent().add_child(glow)
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
	_obrywacz = 3.0   # boss_N_fight: every hit kicks the damage jitter
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
	# Kill score — every boss_N_fight awards g_naliczator += 100000,
	# except boss_2 which pays 1000 * g_boss_strenght and then raises
	# the multiplier by 3 (rematch scaling, reset per run).
	if tier == 1:
		NativeGame.add_score(1000 * NativeGame.boss_strenght)
		NativeGame.boss_strenght += 3
	else:
		NativeGame.add_score(100000)
	NativeGame.coins += 20 + tier * 5
	# fat_boy_boss_2+ drop six o_coindrop pickups (obj 214) on death —
	# two at y-200, two at y-400, two at hull level, all ~300/600px
	# to the boss's right.
	if VARIANTS.has(variant) and VARIANTS[variant].get("coins", false):
		for spec in [[300.0, -200.0], [600.0, -200.0],
				[300.0, -400.0], [600.0, -400.0],
				[300.0, 0.0], [600.0, 0.0]]:
			var drop := NativePickup.new()
			drop.kind = NativePickup.Kind.COIN
			drop.global_position = position + Vector2(
				spec[0] + randf_range(-30.0, 30.0),
				spec[1] + randf_range(-30.0, 30.0))
			get_parent().add_child(drop)
	# ufo_mega death drops five o_coindrop pickups at (x, y-40).
	if variant == "ufo_mega":
		for i in 5:
			var drop := NativePickup.new()
			drop.kind = NativePickup.Kind.COIN
			drop.global_position = position + Vector2(0, -40)
			get_parent().add_child(drop)
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
	var ship := NativeGame.player()
	if ship == null or ship.invulnerable:
		return
	var to_boss: Vector2 = position - ship.global_position
	var dist: float = to_boss.length()
	# Solid body sized from the hull sprite — the fixed 85px radius let
	# the ship overlap the clown's rotor tips and the fat-boy/flame-can
	# variant hulls. Same 0.45·longest-side rule as NativeEnemy.
	var body := _body_radius + 18.0
	if dist < body and dist > 0.01:
		# to_boss points ship→boss — subtract to shove the ship away.
		ship.global_position -= to_boss.normalized() * (body - dist)
		# fat_boy_boss contact is a kill move — it hauls the ship in and
		# burns 500 hull (g_energia -= 500).
		if variant.begins_with("fat_boy"):
			ship.vel += to_boss.normalized() * -10.0
			NativeGame.damage_player(500.0)
			return
		# boss_N_fight place_meeting: grazing the hull costs only 5
		# energy and knocks the ship down (g_iyor += 3).
		NativeGame.damage_player(5.0)
		ship.vel.y += 3.0


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
	_hp_bar.offset_right = -312.0
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
	name_label.offset_right = -312.0
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
