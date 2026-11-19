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
static var coins: int = 0            ## G.coins — currency from coins/gems
static var lives: int = 3            ## G.zycia — spare lives
static var level_index: int = 0      ## G.poziom — world/level progression
static var upgrade_wing: int = 0     ## G.upgradeWING — handling authority
static var upgrade_boost: int = 0    ## G.upgradeBOOST — max speed
static var upgrade_freezer: int = 0  ## G.upgradeFREEZER — overheat capacity
static var samus_firerate: float = 0.0  ## G.samus_firerate — fire-rate bonus
static var samus_slower: float = 1.0    ## G.samus_slower — speed divisor
static var efekty: int = 2           ## G.efekty — particle quality setting
static var dzwiek: int = 1           ## G.dzwiek — sound enabled
static var muzyka: int = 1           ## G.muzyka — music enabled
static var glosnosc_dzwieku: float = 1.0  ## G.glosnosc_dzwieku — sfx volume

# --- Per-run state (reset when a level starts) ---
static var energy: float = 100.0     ## G.energia — hull; 0 = death
static var overheating: float = 0.0  ## G.overheating — gun heat
static var paused: bool = false      ## G.pauza
static var enemies_killed: int = 0
static var enemies_missed: int = 0

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
	enemies_killed = 0
	enemies_missed = 0


static func overheat_max() -> float:
	return OVERHEAT_BASE + upgrade_freezer * OVERHEAT_PER_UPGRADE


static func add_score(points: int) -> void:
	score += points


static func kill_enemy() -> void:
	enemies_killed += 1


static func damage_player(amount: float) -> void:
	if paused:
		return
	energy = maxf(0.0, energy - amount)
