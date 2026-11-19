extends RefCounted
class_name NativeLevelTable
## NativeLevelTable — level catalogue for the native game.
##
## The original stores level layouts inside GameMaker room creation code
## and wave objects; untangling all of that is a later milestone. For now
## this table generates sensible arena configs procedurally: each
## (world, level) gets a background, a music track, and a wave list whose
## size/difficulty scales with progression. Hand-authored levels can
## replace entries here without touching gameplay code.
##
## Level ids are flat: index = world * LEVELS_PER_WORLD + level.

const LEVELS_PER_WORLD := 10
const WORLDS := 8

# Background/music pools per world — picked from data/assets.json ids.
# `music` is a per-level pool: config_for rotates through it so levels
# in the same world don't all share one track.
const WORLD_THEME := {
	0: {"bg": 0, "bg_pool": [0, 44], "music": ["mixed_battle", "real_battle", "training"]},
	1: {"bg": 2, "music": ["hard_squad", "brutal_force", "castle_fly2"]},
	2: {"bg": 4, "music": ["castle_dungeon", "hard_castle", "dark"]},
	3: {"bg": 5, "music": ["dark", "ghosts", "evil_castle"]},
	4: {"bg": 6, "music": ["brutal_force", "violence", "riot"]},
	5: {"bg": 44, "music": ["hard_life", "violation", "rage"]},
	6: {"bg": 48, "music": ["rage", "death_star", "real_battle"]},
	7: {"bg": 41, "bg_pool": [41, 52], "music": ["last_boss", "boss_bowser", "finishing"]},
}

# Boss levels override the world pool with these tracks.
const BOSS_MUSIC := {
	0: "real_battle", 1: "brutal_force", 2: "hard_castle", 3: "evil_castle",
	4: "violence", 5: "violation", 6: "death_star", 7: "last_boss",
}

# Enemy kinds available to the generator — must match the spawner's
# string→Kind mapping and enemy.gd's KIND_PROFILES.
# Which world fields which alternate boss (objects/bosses/ufo_mega,
# fat_boy_boss, flame_cans_boss appear in specific original stages).
const BOSS_VARIANTS := {1: "ufo_mega", 3: "fat_boy", 5: "flame_cans"}

const KINDS := ["goomba", "shooter", "kamikaze", "tank", "eye",
	"mini", "ufo_a", "ufo_b", "ros", "crab", "jumbo", "elite",
	"dart", "stinger", "weaver", "drone", "hunter", "warlord",
	"lancer", "ace", "ghost", "rocket_ufo",
	"cannon", "flame_cannon", "rotary", "fat_cannon", "flame", "fan",
	"ring", "ducher_ring", "ducher_fall", "bonus_fall"]


## Build the arena config for a flat level index. Returns a Dictionary
## the arena scene consumes: {background, music, waves, boss, label}.
##
## Levels can be hand-authored: drop a JSON file at
## `data/levels/native/<index>.json` (e.g. `00.json` = level 1) and it
## replaces the generated config entirely — see data/levels/native/
## for the format. Waves are the same dicts the spawner consumes.
static func config_for(level_index: int) -> Dictionary:
	var custom := _custom_config(level_index)
	if not custom.is_empty():
		return custom
	var world := level_index / LEVELS_PER_WORLD
	var level := level_index % LEVELS_PER_WORLD
	var theme: Dictionary = WORLD_THEME.get(world, WORLD_THEME[0])
	var difficulty := level_index  # 0-based progression drives wave size

	# Hand-authored blueprint gives each level its signature opening;
	# scripted o_wave_* patterns fill the middle; procedural waves tail
	# it off so the ending still varies per level.
	var waves := _blueprint_for(world, level, difficulty)
	var scripted := _scripted_for(world, level, difficulty,
		waves[waves.size() - 1]["delay"] + 5.0)
	waves.append_array(scripted)
	var tail := _generate_waves(difficulty, world)
	# Take only the last two procedural waves as the finale, re-spaced
	# after the scripted block (their own delays are absolute to the
	# procedural schedule, so they can't be reused directly).
	var finale_start: float = waves[waves.size() - 1]["delay"] + 5.0
	var picked := 0
	for i in range(maxi(0, tail.size() - 2), tail.size()):
		var w: Dictionary = tail[i].duplicate()
		w["delay"] = finale_start + picked * 8.0
		waves.append(w)
		picked += 1

	# Music: boss levels get the world's boss track; normal levels rotate
	# through the world pool by level number.
	var is_boss := level % 5 == 4
	# Castle stages — the original interleaves side-scroll castle rooms
	# between shmup stages; here every pre-boss level (slot 4 of each
	# five) is a castle crawl ending at a key.
	var is_castle := level % 5 == 3
	var pool: Array = theme["music"]
	var music := str(BOSS_MUSIC.get(world, str(pool[0]))) if is_boss \
		else str(pool[level % pool.size()])

	# Background rotates within the world for variety (bg 52 = cave set,
	# unused until now — slots into the final world).
	var bg_pool: Array = theme.get("bg_pool", [theme["bg"]])
	var bg_id: int = int(bg_pool[level % bg_pool.size()])

	return {
		"background": bg_id,
		"music": music,
		"waves": waves,
		# Every 5th level ends with a boss fight once the waves are clear.
		"boss": {"tier": world, "variant": BOSS_VARIANTS.get(world, "")} if level % 5 == 4 else {},
		"mode": "castle" if is_castle else "arena",
		"label": "W%d-%02d" % [world + 1, level + 1],
	}


## Load a hand-authored level override. Missing keys fall back to the
## world's theme defaults so files only need to specify what they change.
static func _custom_config(level_index: int) -> Dictionary:
	var path := "res://data/levels/native/%02d.json" % level_index
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("NativeLevelTable: bad JSON in %s" % path)
		return {}
	var world := level_index / LEVELS_PER_WORLD
	var theme: Dictionary = WORLD_THEME.get(world, WORLD_THEME[0])
	var level := level_index % LEVELS_PER_WORLD
	var is_boss := level % 5 == 4
	var pool: Array = theme["music"]
	var bg_pool: Array = theme.get("bg_pool", [theme["bg"]])
	return {
		"background": int(parsed.get("background", bg_pool[level % bg_pool.size()])),
		"music": str(parsed.get("music",
			BOSS_MUSIC.get(world, pool[level % pool.size()]) if is_boss
			else pool[level % pool.size()])),
		"waves": parsed.get("waves", []),
		"boss": parsed.get("boss", {"tier": world, "variant": BOSS_VARIANTS.get(world, "")} if is_boss else {}),
		"mode": str(parsed.get("mode", "castle" if level % 5 == 3 else "arena")),
		"label": str(parsed.get("label", "W%d-%02d" % [world + 1, level + 1])),
	}


## Total levels in the campaign.
static func level_count() -> int:
	return WORLDS * LEVELS_PER_WORLD


## Which world/level a flat index belongs to.
static func world_of(level_index: int) -> int:
	return level_index / LEVELS_PER_WORLD


static func level_of(level_index: int) -> int:
	return level_index % LEVELS_PER_WORLD


## Hand-authored wave blueprints — distinct level "feels" layered on top
## of the procedural generator. Each returns a wave list; config_for
## picks one per level so the campaign isn't purely random.
##
## Archetypes:
##   opener    — gentle goomba curtains (early levels / world intros)
##   swarm     — fast MINI + KAMIKAZE floods from the sides
##   fortress  — shooter/tank wall that holds formation and fires
##   ambush    — alternating chase/kamikaze waves, no breathing room
##   elitewing — heavy hitters: elites, jumbos, crabs, ros
static func _blueprint_for(world: int, level: int, difficulty: int) -> Array:
	var t := 1.0
	# Base HP grows gently and caps — scaled to the weapon catalog's damage
	# values (script_set_weapons firepower ~2-80/hit). A maxed goomba is
	# ~40hp ≈ 16 starter-gun hits, matching the original's 3-30 energia
	# weak enemies vs 2-4 firepower shots.
	var hp := minf(8.0 + difficulty * 0.4, 40.0)
	match level % 5:
		0:  # opener — readable, teaches the loop
			return _waves_from([
				["goomba", "top", "formation", 4, hp],
				["goomba", "right", "formation", 4, hp],
				["shooter", "top", "formation", 3, hp * 1.4],
				["goomba", "left", "chase", 5, hp],
			], t, 7.0)
		1:  # swarm — numbers and speed
			return _waves_from([
				["mini", "top", "formation", 8, hp * 0.4],
				["mini", "left", "chase", 6, hp * 0.4],
				["kamikaze", "right", "kamikaze", 6, hp * 0.6],
				["mini", "top", "chase", 10, hp * 0.4],
				["ufo_b", "left", "kamikaze", 4, hp * 0.6],
			], t, 6.0)
		2:  # fortress — static defence grid
			return _waves_from([
				["shooter", "top", "formation", 4, hp * 1.4],
				["tank", "top", "formation", 2, hp * 2.5],
				["eye", "top", "formation", 1, hp * 6.0],
				["ufo_a", "right", "formation", 4, hp * 1.4],
				["ros", "top", "formation", 3, hp * 2.0],
			], t, 8.0)
		3:  # ambush — pressure from every edge
			return _waves_from([
				["kamikaze", "right", "kamikaze", 5, hp * 0.6],
				["goomba", "left", "chase", 6, hp],
				["mini", "top", "chase", 8, hp * 0.4],
				["shooter", "left", "formation", 3, hp * 1.4],
				["kamikaze", "top", "kamikaze", 7, hp * 0.6],
			], t, 6.5)
		_:  # elite wing — heavy hitters (level%5==4 pairs with boss)
			return _waves_from([
				["elite", "top", "formation", 4, hp * 1.8],
				["jumbo", "top", "chase", 3, hp * 2.5],
				["crab", "top", "formation", 2, hp * 2.0],
				["ufo_a", "right", "formation", 4, hp * 1.4],
				["eye", "top", "formation", 1, hp * 6.0],
			], t, 8.5)


## Scripted wave catalogue — translations of the original's ~130
## o_wave_* spawner objects (objects/spawners/). Each family below
## corresponds to a real legacy script family:
##
##   asteroids   — o_wave_4_asteroids: rock clumps drifting in from top
##   divers      — o_perioder_*: kamikaze streams dropping from above
##   piranhas    — o_wave_map_6_piranhasus: swarm rising from below
##   ghosts      — o_wave_ghost_*: shy phantoms dripping from top corners
##   zigzag      — o_wave_9_zigzag: alternating side entries
##   grid        — wave_map_4_grouping_*: 30-slot 3-row formations
##   swarm       — o_wave_11_spikey_swarm: tight kamikaze clouds
##   gunship     — o_wave_14_gun_range: shooter streams
##   heavy       — heavyweight escorts (tank/eye/elite mixes)
##   ufo_stream  — UFO streams crossing the arena
##   circle      — o_wave_*_circle*: whole wave released as one ring
##   bonus/loot  — o_wave_6_bonus_wave / wave_funny_bonus_catch: pickups
##
## `interval_s` is the original's per-spawn tick (~15-20 frames ≈ 0.3s).
## Counts are scaled down from the originals' 100-200 where needed to
## keep native HP/damage pacing fair.
static func _scripted_for(world: int, level: int, difficulty: int,
		start_delay: float) -> Array:
	var hp := minf(8.0 + difficulty * 0.4, 40.0)
	var waves: Array = []
	var t := start_delay
	# Two scripted waves per level, chosen deterministically per world
	# so every world shows its signature spawner families.
	var pool: Array = _SCRIPTED_FAMILIES[world]
	var first: int = pool[level % pool.size()]
	var pool2: Array = _SCRIPTED_FAMILIES[(world + 3) % _SCRIPTED_FAMILIES.size()]
	var second: int = pool2[(level + 1) % pool2.size()]
	for spec_index in [first, second]:
		waves.append(_scripted_wave(_SCRIPTED_SPECS[spec_index], t, hp))
		t += 9.0
	return waves


## Per-world scripted wave pools — indices into _SCRIPTED_SPECS.
const _SCRIPTED_FAMILIES := [
	[0, 1, 9, 7],   # world 1: asteroids, divers, bonus, swarm
	[2, 3, 8, 6],   # world 2: piranhas, ghosts, ufo stream, gunship
	[5, 4, 6, 10],  # world 3: grid, zigzag, gunship, circle
	[2, 11, 7, 9],  # world 4: piranhas, loot, swarm, bonus
	[8, 1, 6, 4],   # world 5: ufo stream, divers, gunship, zigzag
	[5, 10, 3, 2],  # world 6: grid, circle, ghosts, piranhas
	[4, 6, 1, 11],  # world 7: zigzag, gunship, divers, loot
	[10, 5, 7, 0],  # world 8: circle, grid, swarm, asteroids
]


## Pattern specs: [pattern, kinds, count, edge].
const _SCRIPTED_SPECS := [
	["asteroids", ["ros", "crab", "jumbo"], 8, "top"],
	["divers", ["kamikaze", "ufo_b", "dart"], 20, "top"],
	["piranhas", ["weaver", "dart", "mini"], 16, "bottom"],
	["ghosts", ["ghost", "ghost", "eye"], 10, "top"],
	["zigzag", ["goomba", "shooter", "kamikaze"], 14, "left"],
	["grid", ["shooter", "goomba", "mini"], 30, "top"],
	["swarm", ["mini", "kamikaze", "dart"], 18, "top"],
	["gunship", ["rocket_ufo", "ufo_a", "shooter"], 8, "right"],
	["heavy", ["tank", "eye", "elite"], 6, "top"],
	["ufo_stream", ["ufo_a", "ufo_b", "ros"], 12, "top"],
	["circle", ["goomba", "mini", "shooter"], 10, "top"],
	["loot", [], 5, "top"],
	["bonus", ["bonus_fall", "ducher_fall"], 6, "top"],
]


static func _scripted_wave(spec: Array, delay: float, hp: float) -> Dictionary:
	var pattern: String = spec[0]
	var kinds: Array = spec[1]
	var count: int = spec[2]
	var edge: String = spec[3]
	var wave := {
		"delay": delay, "count": count, "edge": edge,
		"mode": "formation", "health": hp,
		"pattern": pattern, "interval_s": 0.3,
	}
	if not kinds.is_empty():
		wave["kinds"] = kinds
		wave["kind"] = kinds[0]
	# Circle waves release as one ring — count is orbiter count.
	if pattern == "circle":
		wave["count"] = count
		wave["interval_s"] = 0.05
	# Loot/bonus waves drop pickups, not enemies.
	if pattern == "loot":
		wave["pattern"] = "loot"
	if pattern == "bonus":
		wave["pattern"] = "bonus"
	return wave


## Build wave dicts from compact [kind, edge, mode, count, health] rows.
static func _waves_from(rows: Array, t0: float, step: float) -> Array:
	var waves: Array = []
	var t := t0
	for r in rows:
		waves.append({
			"delay": t, "count": r[3], "edge": r[1], "mode": r[2],
			"kind": r[0], "health": r[4],
		})
		t += step
	return waves


## Procedural wave list — fallback for variety and future hand edits.
## Kept deterministic per level so replays feel consistent.
static func _generate_waves(difficulty: int, world: int) -> Array:
	var waves: Array = []
	var wave_count := 4 + mini(difficulty / 4, 4)        # 4-8 waves
	var t := 1.0
	for w in wave_count:
		# Later waves favour nastier kinds — the pool widens with
		# difficulty so early levels stay readable while late ones mix.
		var kind := "goomba"
		var mode := "formation"
		var roll := (w * 7 + difficulty * 3 + world) % 24
		if w >= 5 and roll >= 20:
			kind = ["jumbo", "crab", "ros", "warlord", "ring"][roll % 5]
		elif w >= 4 and roll >= 16:
			kind = ["tank", "eye", "elite", "hunter"][roll % 4]
		elif w >= 3 and roll >= 12:
			kind = ["ufo_a", "ufo_b", "shooter", "stinger", "drone", "lancer", "rocket_ufo"][roll % 7]
		elif w >= 2 and roll >= 8:
			kind = ["kamikaze", "mini", "shooter", "dart", "weaver", "ace", "ghost", "ducher_fall", "bonus_fall"][roll % 9]
		elif w >= 2 and roll == 7:
			mode = "chase"
		if kind in ["kamikaze", "ufo_b", "weaver", "ace", "ghost"]:
			mode = "kamikaze"
		elif kind in ["shooter", "ufo_a", "tank", "eye", "ros", "crab",
				"stinger", "drone", "hunter", "lancer", "rocket_ufo"]:
			mode = "formation"

		var count := 3 + w + (difficulty / 3)
		if kind == "ring" or kind == "ducher_ring":
			count = 1   # the ring IS the wave
		var hp := minf(8.0 + difficulty * 0.4, 40.0)
		match kind:
			"mini": hp = hp * 0.4
			"kamikaze", "ufo_b": hp = hp * 0.6
			"tank", "jumbo": hp = hp * 2.5
			"eye": hp = hp * 6.0
			"shooter", "ufo_a": hp = hp * 1.4
			"ros": hp = hp * 2.0
			"crab": hp = hp * 2.0
			"elite": hp = hp * 1.8
			"dart": hp = hp * 0.7
			"weaver": hp = hp * 0.8
			"warlord": hp = hp * 1.6
			"hunter": hp = hp * 1.3
			"lancer": hp = hp * 1.4
			"ace": hp = hp * 0.9
			"ghost": hp = hp * 1.2
			"rocket_ufo": hp = hp * 1.5

		waves.append({
			"delay": t,
			"count": count,
			"edge": ["top", "left", "right"][w % 3],
			"mode": mode,
			"kind": kind,
			"health": hp,
		})
		t += 7.0 + (w % 3) * 2.0
	return waves
