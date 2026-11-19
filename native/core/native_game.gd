extends RefCounted
class_name NativeGame
## NativeGame — global run state for the native game.
##
## The Godot equivalent of the GameMaker `global.*` variables that lived in
## game/globals.gd — but typed, documented, and namespaced. All members are
## static so any scene or entity can reach them without autoload wiring.
##
## Values that only matter inside one level (wave counters, timers) belong
## on the level node, not here.

# --- Persistent profile (survives level changes; save-file candidate) ---
static var score: int = 0            ## G.punkty — level score
static var best_score: int = 0       ## highest cumulative score ever reached
static var coins: int = 0            ## G.coins — currency from coins/gems
static var lives: int = 3            ## G.zycia — spare lives
static var level_index: int = 0      ## G.poziom — highest unlocked level
static var active_level: int = 0     ## level currently being played
static var upgrade_wing: int = 0     ## G.upgradeWING — handling authority
static var upgrade_boost: int = 0    ## G.upgradeBOOST — max speed
static var upgrade_freezer: int = 0  ## G.upgradeFREEZER — overheat capacity
static var samus_firerate: float = 0.0  ## G.samus_firerate — fire-rate bonus
static var samus_slower: float = 1.0    ## G.samus_slower — speed divisor
static var weapon_power: int = 0        ## weapon upgrade tier — extra bolts per muzzle
static var weapon_type: int = 0         ## 0 PULSE / 1 SPREAD / 2 LANCE — cycle with X
static var overdrive_time: float = 0.0  ## seconds of POWER-star boost remaining
static var shield_time: float = 0.0     ## seconds of SHIELD-bubble invulnerability
static var hurt_flash: float = 0.0      ## seconds of red hit-flash remaining
static var hero: int = 0               ## selected ship index (HEROES table)
static var damage_mult: float = 1.0    ## hero bullet damage multiplier
static var hero_tint: Color = Color.WHITE  ## hull tint for the chosen hero

## Playable ships — the original offered several hulls with different
## handling. Only one hull sprite exists in the assets, so heroes differ
## by stats and tint: firerate/slowdown feed the existing samus_* fields,
## damage scales bullet damage, tint recolours the hull.
const HEROES := [
	{"name": "CLASSIC", "desc": "Balanced all-rounder",
		"firerate": 0.0, "slower": 1.0, "damage": 1.0, "tint": Color.WHITE},
	{"name": "SAMUS", "desc": "Rapid fire, sluggish handling",
		"firerate": 0.5, "slower": 1.2, "damage": 1.0, "tint": Color(1.0, 0.6, 0.6)},
	{"name": "COMET", "desc": "Fast and fragile",
		"firerate": 0.1, "slower": 0.8, "damage": 0.8, "tint": Color(0.6, 0.9, 1.0)},
	{"name": "TITAN", "desc": "Heavy hitter, slow turn",
		"firerate": 0.0, "slower": 1.15, "damage": 1.5, "tint": Color(1.0, 0.85, 0.4)},
]

# Level handoff — the star map writes the chosen level's config here and
# the arena reads it on _ready. Keeps scenes decoupled (no direct refs).
static var pending_level: Dictionary = {}
static var efekty: int = 2           ## G.efekty — particle quality setting
static var dzwiek: int = 1           ## G.dzwiek — sound enabled
static var muzyka: int = 1           ## G.muzyka — music enabled
static var glosnosc_dzwieku: float = 1.0  ## G.glosnosc_dzwieku — sfx volume
static var fullscreen: bool = false     ## borderless fullscreen toggle

# --- Per-run state (reset when a level starts) ---
static var energy: float = 100.0     ## G.energia — hull; 0 = death
static var overheating: float = 0.0  ## G.overheating — gun heat
static var paused: bool = false      ## G.pauza
static var enemies_killed: int = 0
static var enemies_missed: int = 0
static var kill_streak: int = 0          ## consecutive kills within the window
static var streak_expiry: int = 0        ## msec timestamp when the streak dies

# Overheat ceiling from the original: 500 base + 500 per freezer upgrade.
const OVERHEAT_BASE := 500.0
const OVERHEAT_PER_UPGRADE := 500.0

# Galaxy arenas are fixed 1024x768 rooms (views disabled in the original
# data). Game logic uses THIS size — never the viewport size, which can
# differ in windowed/borderless/headless modes.
const ROOM_SIZE := Vector2(1024, 768)


static func room_size() -> Vector2:
	return ROOM_SIZE


static func reset_run() -> void:
	energy = 100.0
	overheating = 0.0
	overdrive_time = 0.0
	shield_time = 0.0
	kill_streak = 0
	enemies_killed = 0
	enemies_missed = 0


static func overheat_max() -> float:
	return OVERHEAT_BASE + upgrade_freezer * OVERHEAT_PER_UPGRADE


static func add_score(points: int) -> void:
	score += points
	if score > best_score:
		best_score = score


static func kill_enemy() -> void:
	enemies_killed += 1
	# Kill streak — kills within 3s of each other chain into a score
	# multiplier (score_mult). The timestamp approach needs no ticking.
	var now := Time.get_ticks_msec()
	if now > streak_expiry:
		kill_streak = 0
	kill_streak += 1
	streak_expiry = now + 3000


## Score multiplier from the current streak — +5% per chained kill,
## capped at x2 (21+ streak).
static func score_mult() -> float:
	if kill_streak < 2 or Time.get_ticks_msec() > streak_expiry:
		return 1.0
	return 1.0 + minf(kill_streak - 1, 20) * 0.05


static func damage_player(amount: float) -> void:
	if paused:
		return
	var before := energy
	energy = maxf(0.0, energy - amount)
	if energy < before:
		hurt_flash = 0.18


static func heal_player(amount: float) -> void:
	energy = minf(energy + amount, 100.0)


## Apply the selected hero's stat line — call after picking a ship.
static func apply_hero() -> void:
	var h: Dictionary = HEROES[clampi(hero, 0, HEROES.size() - 1)]
	samus_firerate = h["firerate"]
	samus_slower = h["slower"]
	damage_mult = h["damage"]
	hero_tint = h["tint"]
	save()


# ---------------------------------------------------------------------------
# Save / load — persists the profile fields (not per-run state) to
# user://native_save.cfg. The original used GameMaker .ini saves in the
# same spirit: unlocked level, currency, upgrades, settings.
# ---------------------------------------------------------------------------

const SAVE_PATH := "user://native_save.cfg"


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "score", score)
	cfg.set_value("profile", "best_score", best_score)
	cfg.set_value("profile", "coins", coins)
	cfg.set_value("profile", "lives", lives)
	cfg.set_value("profile", "level_index", level_index)
	cfg.set_value("profile", "upgrade_wing", upgrade_wing)
	cfg.set_value("profile", "upgrade_boost", upgrade_boost)
	cfg.set_value("profile", "upgrade_freezer", upgrade_freezer)
	cfg.set_value("profile", "weapon_power", weapon_power)
	cfg.set_value("profile", "weapon_type", weapon_type)
	cfg.set_value("profile", "samus_firerate", samus_firerate)
	cfg.set_value("profile", "samus_slower", samus_slower)
	cfg.set_value("profile", "hero", hero)
	cfg.set_value("profile", "damage_mult", damage_mult)
	cfg.set_value("profile", "hero_tint", hero_tint)
	cfg.set_value("settings", "efekty", efekty)
	cfg.set_value("settings", "dzwiek", dzwiek)
	cfg.set_value("settings", "muzyka", muzyka)
	cfg.set_value("settings", "glosnosc_dzwieku", glosnosc_dzwieku)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.save(SAVE_PATH)


## Wipe the profile back to defaults — the title screen's NEW GAME.
static func reset_profile() -> void:
	score = 0
	best_score = 0
	coins = 0
	lives = 3
	level_index = 0
	active_level = 0
	upgrade_wing = 0
	upgrade_boost = 0
	upgrade_freezer = 0
	weapon_power = 0
	weapon_type = 0
	samus_firerate = 0.0
	samus_slower = 1.0
	hero = 0
	damage_mult = 1.0
	hero_tint = Color.WHITE
	save()


## Load the profile if a save exists; missing keys keep defaults.
static func load_save() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	score = int(cfg.get_value("profile", "score", score))
	best_score = int(cfg.get_value("profile", "best_score", best_score))
	coins = int(cfg.get_value("profile", "coins", coins))
	lives = int(cfg.get_value("profile", "lives", lives))
	level_index = int(cfg.get_value("profile", "level_index", level_index))
	upgrade_wing = int(cfg.get_value("profile", "upgrade_wing", upgrade_wing))
	upgrade_boost = int(cfg.get_value("profile", "upgrade_boost", upgrade_boost))
	upgrade_freezer = int(cfg.get_value("profile", "upgrade_freezer", upgrade_freezer))
	weapon_power = int(cfg.get_value("profile", "weapon_power", weapon_power))
	weapon_type = int(cfg.get_value("profile", "weapon_type", weapon_type))
	samus_firerate = float(cfg.get_value("profile", "samus_firerate", samus_firerate))
	samus_slower = float(cfg.get_value("profile", "samus_slower", samus_slower))
	hero = int(cfg.get_value("profile", "hero", hero))
	damage_mult = float(cfg.get_value("profile", "damage_mult", damage_mult))
	hero_tint = cfg.get_value("profile", "hero_tint", hero_tint)
	efekty = int(cfg.get_value("settings", "efekty", efekty))
	dzwiek = int(cfg.get_value("settings", "dzwiek", dzwiek))
	muzyka = int(cfg.get_value("settings", "muzyka", muzyka))
	glosnosc_dzwieku = float(cfg.get_value("settings", "glosnosc_dzwieku", glosnosc_dzwieku))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", fullscreen))
	return true
