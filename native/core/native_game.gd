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
static var level_index: int = 0      ## G.poziom — stages completed count
static var active_level: int = 0     ## level currently being played
## Star-map node progression — the original's G.aktualny_lev /
## G.map_complev / G.map_number model. Nodes are "m:n" keys into the
## extracted map graph; the ship flies lane-to-lane and only nodes
## adjacent to the current (completed) node can be launched.
static var active_node: String = ""      ## "m:n" of the stage being played
static var map_current: String = ""      ## "m:n" the ship is parked on
static var map_done: Array = []          ## completed "m:n" node keys
static var map_transition: int = -1      ## map to advance to (-1 = none)
static var upgrade_wing: int = 0     ## G.upgradeWING — handling authority
static var upgrade_boost: int = 0    ## G.upgradeBOOST — max speed
static var upgrade_freezer: int = 0  ## G.upgradeFREEZER — overheat capacity
static var upgrade_armour: int = 0   ## G.upgradeARMOUR — +max hull per level
static var upgrade_orbit: int = 0    ## G.upgradeORBIT — hull regeneration
static var upgrade_balls: int = 0    ## G.upgradeBALLS — orbiting weapon balls
static var samus_firerate: float = 0.0  ## G.samus_firerate — fire-rate bonus
static var samus_slower: float = 1.0    ## G.samus_slower — speed divisor
static var samus_overpriced: float = 0.0  ## G.samus_overpriced — weapon price markup
static var samus_cooling: float = 0.0   ## G.samus_cooling — extra overheat venting
## Hero-specific item quirks from choose_hero.gd:
static var mushroom_gives_more: float = 0.0   ## G.mushroom_gives_more — health pickup bonus (orig units)
static var better_cooling_mushroom: float = 0.0  ## G.better_cooling_mushroom — cooling pickup power
static var coins_booster: float = 1.0          ## G.coins_booster — coin value multiplier
static var better_chance_of_bonus: float = 0.0 ## G.better_chance_of_bonus — rare-drop luck
## G.jakikumpel[0..1] — the two companion buddies flanking the ship.
## 0 = none, 1-2 = upgraded tiers (sprites 459/460/461). The original
## sells upgrades for cena_kumpla = [100000, 500000] coins.
static var buddy_left: int = 0
static var buddy_right: int = 0
const BUDDY_PRICES := [100000, 500000]
## G.weapon[1..5] / G.levelup[1..5] — one weapon per muzzle slot, each
## independently upgradeable (shop upgrade cost scales off the slot's
## levelup, not the weapon's). -1 = slot empty.
static var weapons: Array[int] = [-1, -1, -1, -1, -1]
static var weapon_level: Array[int] = [0, 0, 0, 0, 0]
## G.weaponslot1..4 — the four paid gun-slot unlocks. Gun slot index 0
## (G.weapon[1]) is always available; slots 1..4 cost 10,000 coins each
## on the shop's armory page until unlocked (choose_hero.gd sets all
## four for hero 2 only).
static var gun_slots: Array[bool] = [false, false, false, false]
## g_bron_etapowa[0/1] — seconds of FLOWER OF FIRE / STAR OF FIREBALLS
## booster fire remaining (special_weapon_3/4 set it to 1200 frames).
static var booster_fire_time: float = 0.0
static var booster_boom_time: float = 0.0
static var special_heal_rate: float = 0.0  ## hull/sec from a heal special
static var special_heal_left: float = 0.0  ## seconds of heal-special left
## g_energion — the health-mushroom's regen reserve. The original
## trickles it into hull at 1 unit/frame (script_odnawianie_kumpli)
## instead of healing instantly.
static var energy_reserve: float = 0.0
static var hurt_flash: float = 0.0      ## seconds of red hit-flash remaining
static var hero: int = 0               ## selected ship index (HEROES table)
static var hero_tint: Color = Color.WHITE  ## hull tint for the chosen hero
## G.specialslot[0..3] — the four special-item slots (ids 1..9 index
## NativeSpecialTable.ITEMS, 0 = empty). Slot 0 is the ACTIVE special:
## the prev/next keys rotate the ring so a different item becomes active.
## Persistent across levels, like the original's profile save.
static var special_slots: Array[int] = [0, 0, 0, 0]

## Playable ships — ports the four `g_hero` loadouts from choose_hero.gd.
## Each hero gets a starter weapon on the centre gun (slot index 1 =
## G.weapon[2]), different starting upgrades, and stat quirks. Weapon
## ids index NativeWeaponTable (0..42 standard, 1000..1009 the rocket
## series). The original hero-2 also gets two special-weapon slots
## (G.weapon[4..5] = 1000 = SMALL ROCKETS) plus all four paid gun-slot
## unlocks (G.weaponslot1..4 = 1).
const HEROES := [
	{"name": "CLASSIC", "desc": "LIGHT MUSHROOM GUN — the every-plumber starter",
		"firerate": 0.0, "slower": 1.0, "tint": Color.WHITE,
		"loadout": {1: [1, 5]}, "upgrades": {},
		"specials": [1, 2, 3, 4],
		"mushroom_more": 150.0, "coins_booster": 1.02},
	{"name": "VETERAN", "desc": "Mushroom gun + WING/BOOST/ARMOUR/BALLS pre-installed",
		"firerate": 0.0, "slower": 1.0, "tint": Color(1.0, 0.6, 0.6),
		"loadout": {1: [1, 5]},
		"upgrades": {"upgrade_boost": 1, "upgrade_wing": 1,
			"upgrade_armour": 1, "upgrade_balls": 1},
		"specials": [8, 7, 5, 4], "bonus_chance": 5.0},
	{"name": "SPECIALIST", "desc": "Extra spare ship, no special items",
		"firerate": 0.0, "slower": 1.1, "tint": Color(0.6, 0.9, 1.0),
		"loadout": {1: [1, 5], 3: [1000, 0], 4: [1000, 0]}, "upgrades": {},
		"lives": 2, "gun_slots": true,
		"specials": [0, 0, 0, 0]},
	{"name": "HEAVY", "desc": "LINEAR SHOTGUN + double freezer, sluggish",
		"firerate": 0.1, "slower": 1.8, "tint": Color(1.0, 0.85, 0.4),
		"loadout": {1: [6, 5]}, "upgrades": {"upgrade_freezer": 2},
		"overpriced": 0.05, "cooling": 1.0,
		"specials": [2, 2, 2, 0], "cooling_mushroom": 300.0},
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
static var castle_key_found: bool = false  ## castle stage: key touched
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


## Fallback for entry points that skip hero select (direct scene launches,
## headless tests): if every slot is empty, arm the current hero's
## starter loadout. Does NOT touch upgrades — only fills empty slots.
static func ensure_weapons() -> void:
	for i in 5:
		if weapons[i] >= 0:
			return
	var h: Dictionary = HEROES[clampi(hero, 0, HEROES.size() - 1)]
	for slot in h.get("loadout", {}):
		var w: Array = h["loadout"][slot]
		weapons[slot] = w[0]
		weapon_level[slot] = w[1]


static func reset_run() -> void:
	energy = max_energy()
	overheating = 0.0
	booster_fire_time = 0.0
	booster_boom_time = 0.0
	special_heal_rate = 0.0
	special_heal_left = 0.0
	energy_reserve = 0.0
	castle_key_found = false
	kill_streak = 0
	enemies_killed = 0
	enemies_missed = 0


static func overheat_max() -> float:
	return OVERHEAT_BASE + upgrade_freezer * OVERHEAT_PER_UPGRADE


## Max hull — the original scales energia as 1000 + ARMOUR*200, i.e.
## +20% per armour level on a 100-point bar.
static func max_energy() -> float:
	return 100.0 + upgrade_armour * 20.0


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
	energy = minf(energy + amount, max_energy())


## Apply the selected hero's loadout — ports the choose_hero.gd block:
## starter weapon on the centre gun, hero-specific starting upgrades,
## samus_* quirks, and (for hero 2) an extra spare ship. Picking a hero
## starts a fresh run, so weapons/upgrades reset to the hero defaults.
static func apply_hero() -> void:
	var h: Dictionary = HEROES[clampi(hero, 0, HEROES.size() - 1)]
	samus_firerate = h.get("firerate", 0.0)
	samus_slower = h.get("slower", 1.0)
	samus_overpriced = h.get("overpriced", 0.0)
	samus_cooling = h.get("cooling", 0.0)
	mushroom_gives_more = h.get("mushroom_more", 0.0)
	better_cooling_mushroom = h.get("cooling_mushroom", 0.0)
	coins_booster = h.get("coins_booster", 1.0)
	better_chance_of_bonus = h.get("bonus_chance", 0.0)
	hero_tint = h["tint"]
	for i in 5:
		weapons[i] = -1
		weapon_level[i] = 0
	for slot in h.get("loadout", {}):
		var w: Array = h["loadout"][slot]
		weapons[slot] = w[0]
		weapon_level[slot] = w[1]
	var up: Dictionary = h.get("upgrades", {})
	upgrade_wing = int(up.get("upgrade_wing", 0))
	upgrade_boost = int(up.get("upgrade_boost", 0))
	upgrade_freezer = int(up.get("upgrade_freezer", 0))
	upgrade_armour = int(up.get("upgrade_armour", 0))
	upgrade_orbit = int(up.get("upgrade_orbit", 0))
	upgrade_balls = int(up.get("upgrade_balls", 0))
	for i in 4:
		special_slots[i] = int(h.get("specials", [0, 0, 0, 0])[i])
	# G.weaponslot1..4 — hero 2 starts with every gun slot unlocked.
	for i in 4:
		gun_slots[i] = bool(h.get("gun_slots", false))
	lives = int(h.get("lives", 3))
	save()


# ---------------------------------------------------------------------------
# Weapon shop math — ports the buy/upgrade/sell formulas from
# objects/items/shop.gd. Prices scale by (1 + samus_overpriced); upgrades
# are per SLOT (weapon_level) and capped at NativeWeaponTable.MAX_LEVEL.
# ---------------------------------------------------------------------------

## Coin price to buy a catalog weapon into an empty slot.
static func weapon_buy_price(weapon_id: int) -> int:
	var w := NativeWeaponTable.at(weapon_id)
	return int(w.get("cost", 0) * (1.0 + samus_overpriced))


## Coin price for the next upgrade level of a slot's current weapon.
static func weapon_upgrade_price(slot: int) -> int:
	var wid := weapons[slot]
	if wid < 0:
		return 0
	var w := NativeWeaponTable.at(wid)
	return int(w.get("upcost", 0) * (weapon_level[slot] + 1))


## Refund for selling a slot's weapon — the original returns the base
## price plus the triangular sum of all upgrade costs paid
## (shop.gd: ((level*(level+1)*0.5)*upgradecost) + shopcost).
static func weapon_sell_price(slot: int) -> int:
	var wid := weapons[slot]
	if wid < 0:
		return 0
	var w := NativeWeaponTable.at(wid)
	var lv := weapon_level[slot]
	var upgrades := int(w.get("upcost", 0) * (lv * (lv + 1) / 2.0))
	return weapon_buy_price(wid) + upgrades


## Is gun slot `slot` (0..4) usable? Slot 0 is always free; slots 1..4
## are the G.weaponslot1..4 paid unlocks.
static func gun_slot_unlocked(slot: int) -> bool:
	return slot == 0 or (slot >= 1 and slot <= 4 and gun_slots[slot - 1])


## Coin price of a gun-slot unlock — the original charges a flat
## 10,000 coins per weaponslot on the shop's armory page.
const GUN_SLOT_PRICE := 10000


## Buy the unlock for gun slot `slot` (1..4). Returns true on success.
static func buy_gun_slot(slot: int) -> bool:
	if slot < 1 or slot > 4 or gun_slots[slot - 1] or coins < GUN_SLOT_PRICE:
		return false
	coins -= GUN_SLOT_PRICE
	gun_slots[slot - 1] = true
	save()
	return true


## Buy catalog weapon `weapon_id` into `slot` (replaces any weapon there,
## refunding the old one first — same net effect as sell-then-buy).
## Returns true on success.
static func equip_weapon(slot: int, weapon_id: int) -> bool:
	if slot < 0 or slot >= 5 or not gun_slot_unlocked(slot) \
			or NativeWeaponTable.at(weapon_id).is_empty():
		return false
	var price := weapon_buy_price(weapon_id)
	if weapons[slot] >= 0:
		price -= weapon_sell_price(slot)
	if coins < price:
		return false
	coins -= price
	weapons[slot] = weapon_id
	save()
	return true


## Upgrade a slot's weapon one level. Max level from the original shop.
static func upgrade_weapon(slot: int) -> bool:
	if slot < 0 or slot >= 5 or weapons[slot] < 0:
		return false
	if weapon_level[slot] >= NativeWeaponTable.MAX_LEVEL:
		return false
	var price := weapon_upgrade_price(slot)
	if coins < price:
		return false
	coins -= price
	weapon_level[slot] += 1
	save()
	return true


## Sell a slot's weapon for its refund and empty the slot.
static func sell_weapon(slot: int) -> int:
	var refund := weapon_sell_price(slot)
	if weapons[slot] < 0:
		return 0
	coins += refund
	weapons[slot] = -1
	weapon_level[slot] = 0
	save()
	return refund


# ---------------------------------------------------------------------------
# Special items — G.specialslot ring. Slot 0 is active; prev/next rotate
# the array (script_zmiana_specjala). Items are earned from drops or
# bought on the shop's SUPPORT page (here: the SPECIALS tab).
# ---------------------------------------------------------------------------

## The item id in the active slot (0 = nothing equipped).
static func special_active() -> int:
	return special_slots[0] if special_slots.size() > 0 else 0


## Rotate the special ring — dir -1 = previous, +1 = next
## (script_zmiana_specjala swaps specialslot entries).
static func rotate_special(dir: int) -> void:
	if special_slots.size() < 2:
		return
	if dir > 0:
		var first := special_slots[0]
		for i in special_slots.size() - 1:
			special_slots[i] = special_slots[i + 1]
		special_slots[special_slots.size() - 1] = first
	else:
		var last := special_slots[special_slots.size() - 1]
		for i in range(special_slots.size() - 1, 0, -1):
			special_slots[i] = special_slots[i - 1]
		special_slots[0] = last


## First empty special slot index, or -1 when all four are full.
static func special_free_slot() -> int:
	for i in special_slots.size():
		if special_slots[i] == 0:
			return i
	return -1


## Store a special item in the first empty slot (special_drop behaviour).
## Returns the slot used, or -1 if the ring is full.
static func add_special(id: int) -> int:
	var slot := special_free_slot()
	if slot < 0:
		return -1
	special_slots[slot] = id
	save()
	return slot


## SUPPORT-page purchase: buy item `id` into the first empty slot.
static func buy_special(id: int) -> bool:
	if id <= 0 or id >= NativeSpecialTable.ITEMS.size():
		return false
	if special_free_slot() < 0:
		return false
	var price: int = NativeSpecialTable.PRICES[id]
	if coins < price:
		return false
	coins -= price
	add_special(id)
	return true


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
	cfg.set_value("profile", "map_current", map_current)
	cfg.set_value("profile", "map_done", map_done)
	cfg.set_value("profile", "map_transition", map_transition)
	cfg.set_value("profile", "upgrade_wing", upgrade_wing)
	cfg.set_value("profile", "upgrade_boost", upgrade_boost)
	cfg.set_value("profile", "upgrade_freezer", upgrade_freezer)
	cfg.set_value("profile", "upgrade_armour", upgrade_armour)
	cfg.set_value("profile", "upgrade_orbit", upgrade_orbit)
	cfg.set_value("profile", "upgrade_balls", upgrade_balls)
	cfg.set_value("profile", "samus_firerate", samus_firerate)
	cfg.set_value("profile", "samus_slower", samus_slower)
	cfg.set_value("profile", "samus_overpriced", samus_overpriced)
	cfg.set_value("profile", "samus_cooling", samus_cooling)
	cfg.set_value("profile", "mushroom_gives_more", mushroom_gives_more)
	cfg.set_value("profile", "better_cooling_mushroom", better_cooling_mushroom)
	cfg.set_value("profile", "coins_booster", coins_booster)
	cfg.set_value("profile", "better_chance_of_bonus", better_chance_of_bonus)
	cfg.set_value("profile", "buddy_left", buddy_left)
	cfg.set_value("profile", "buddy_right", buddy_right)
	cfg.set_value("profile", "weapons", weapons)
	cfg.set_value("profile", "weapon_level", weapon_level)
	cfg.set_value("profile", "gun_slots", gun_slots)
	cfg.set_value("profile", "special_slots", special_slots)
	cfg.set_value("profile", "hero", hero)
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
	active_node = ""
	map_current = "0:0"
	map_done = []
	map_transition = -1
	upgrade_wing = 0
	upgrade_boost = 0
	upgrade_freezer = 0
	upgrade_armour = 0
	upgrade_orbit = 0
	upgrade_balls = 0
	samus_firerate = 0.0
	samus_slower = 1.0
	samus_overpriced = 0.0
	samus_cooling = 0.0
	mushroom_gives_more = 0.0
	better_cooling_mushroom = 0.0
	coins_booster = 1.0
	better_chance_of_bonus = 0.0
	buddy_left = 0
	buddy_right = 0
	for i in 5:
		weapons[i] = -1
		weapon_level[i] = 0
	for i in 4:
		special_slots[i] = 0
	hero = 0
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
	map_current = str(cfg.get_value("profile", "map_current", map_current))
	map_done = cfg.get_value("profile", "map_done", map_done)
	map_transition = int(cfg.get_value("profile", "map_transition", map_transition))
	# Legacy saves only stored a linear level_index — reconstruct an
	# approximate done-set from the first N stage keys so the graph
	# progression has somewhere to resume from.
	if map_done.is_empty() and level_index > 0:
		for i in mini(level_index, NativeLevelTable.level_count()):
			map_done.append(NativeLevelTable.stage_key(i))
		if map_current == "":
			map_current = str(map_done[map_done.size() - 1])
	upgrade_wing = int(cfg.get_value("profile", "upgrade_wing", upgrade_wing))
	upgrade_boost = int(cfg.get_value("profile", "upgrade_boost", upgrade_boost))
	upgrade_freezer = int(cfg.get_value("profile", "upgrade_freezer", upgrade_freezer))
	upgrade_armour = int(cfg.get_value("profile", "upgrade_armour", upgrade_armour))
	upgrade_orbit = int(cfg.get_value("profile", "upgrade_orbit", upgrade_orbit))
	upgrade_balls = int(cfg.get_value("profile", "upgrade_balls", upgrade_balls))
	samus_firerate = float(cfg.get_value("profile", "samus_firerate", samus_firerate))
	samus_slower = float(cfg.get_value("profile", "samus_slower", samus_slower))
	samus_overpriced = float(cfg.get_value("profile", "samus_overpriced", samus_overpriced))
	samus_cooling = float(cfg.get_value("profile", "samus_cooling", samus_cooling))
	mushroom_gives_more = float(cfg.get_value("profile", "mushroom_gives_more", mushroom_gives_more))
	better_cooling_mushroom = float(cfg.get_value("profile", "better_cooling_mushroom", better_cooling_mushroom))
	coins_booster = float(cfg.get_value("profile", "coins_booster", coins_booster))
	better_chance_of_bonus = float(cfg.get_value("profile", "better_chance_of_bonus", better_chance_of_bonus))
	buddy_left = int(cfg.get_value("profile", "buddy_left", buddy_left))
	buddy_right = int(cfg.get_value("profile", "buddy_right", buddy_right))
	var saved_weapons: Array = cfg.get_value("profile", "weapons", [])
	for i in mini(5, saved_weapons.size()):
		weapons[i] = int(saved_weapons[i])
	var saved_levels: Array = cfg.get_value("profile", "weapon_level", [])
	for i in mini(5, saved_levels.size()):
		weapon_level[i] = int(saved_levels[i])
	var saved_guns: Array = cfg.get_value("profile", "gun_slots", [])
	for i in mini(4, saved_guns.size()):
		gun_slots[i] = bool(saved_guns[i])
	var saved_specials: Array = cfg.get_value("profile", "special_slots", [])
	for i in mini(4, saved_specials.size()):
		special_slots[i] = int(saved_specials[i])
	hero = int(cfg.get_value("profile", "hero", hero))
	hero_tint = cfg.get_value("profile", "hero_tint", hero_tint)
	efekty = int(cfg.get_value("settings", "efekty", efekty))
	dzwiek = int(cfg.get_value("settings", "dzwiek", dzwiek))
	muzyka = int(cfg.get_value("settings", "muzyka", muzyka))
	glosnosc_dzwieku = float(cfg.get_value("settings", "glosnosc_dzwieku", glosnosc_dzwieku))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", fullscreen))
	return true


## Mark a map node complete — the original's G.map_complev write after
## a stage falls. level_index tracks the count for legacy displays.
static func complete_node(key: String) -> void:
	if key != "" and not map_done.has(key):
		map_done.append(key)
	level_index = map_done.size()


## The node just cleared was its map's exit (boss castle / last castle)
## — the original sets G.map_completed and runs the inter-map sequence.
static func cleared_map_exit() -> bool:
	if active_node == "":
		return false
	var parts := active_node.split(":")
	if parts.size() != 2:
		return false
	var m := int(parts[0])
	return NativeLevelTable.map_exit(m) == active_node \
		and map_done.has(active_node)


## Campaign finished — the map-7 exit (LAST_CASTLE) is down.
static func campaign_complete() -> bool:
	return cleared_map_exit() and active_node.split(":")[0] == "7"
