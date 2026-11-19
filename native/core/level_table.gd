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

## Campaign = the original's authored stage schedules, extracted from
## script_perioder_maps/script_perioder_map_* in part_7.gd into
## data/levels/native/stages.json. Each playable (map, node) pair is one
## level; index = rank in that sorted list. Nodes without a schedule
## block are map connectors/minigames, not levels.
const LEVELS_PER_WORLD := 10
const WORLDS := 8
const STAGES_PATH := "res://data/levels/native/stages.json"

static var _stages: Dictionary = {}
static var _playable: Array = []   # ["m:n", ...] sorted by map then node


static func _load_stages() -> void:
	if not _stages.is_empty():
		return
	if FileAccess.file_exists(STAGES_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(STAGES_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_stages = parsed.get("stages", {})
	_playable = _stages.keys()
	_playable.sort_custom(func(a, b):
		var pa: PackedStringArray = str(a).split(":")
		var pb: PackedStringArray = str(b).split(":")
		return int(pa[0]) * 1000 + int(pa[1]) < int(pb[0]) * 1000 + int(pb[1]))

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
	"ring", "ducher_ring", "ducher_fall", "bonus_fall",
	"goomba_team", "ufo_team", "ufos_team", "cyber_team", "hammer_team",
	"eye2", "ufo_a2", "ghost2", "ghost3"]


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
	_load_stages()
	if level_index < _playable.size():
		return _authored_config(_playable[level_index], level_index)
	# Fallback for indices past the authored roster (modulo wrap).
	var wrapped := level_index % maxi(1, _playable.size())
	if wrapped != level_index:
		return _authored_config(_playable[wrapped], level_index)
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


## Config for one extracted stage schedule. Waves come straight from
## stages.json (already in spawner dict format); boss/castle flags and
## the stage title were extracted alongside them.
static func _authored_config(key: String, level_index: int) -> Dictionary:
	var st: Dictionary = _stages.get(key, {})
	var parts: PackedStringArray = key.split(":")
	var world := int(parts[0])
	var node := int(parts[1])
	# Minigame nodes — the original's map_minigame routing: 1/3 = card
	# game rooms, 2 = shop, 10 = training stage.
	if bool(st.get("is_minigame", false)):
		return {
			"background": -1, "music": "", "waves": [], "boss": {},
			"mode": "minigame",
			"minigame": int(st.get("minigame", 0)),
			"label": str(st.get("title", "MINIGAME")),
		}
	var theme: Dictionary = WORLD_THEME.get(world, WORLD_THEME[0])
	var pool: Array = theme["music"]
	var bg_pool: Array = theme.get("bg_pool", [theme["bg"]])
	var waves: Array = []
	for w in st.get("waves", []):
		var wave: Dictionary = (w as Dictionary).duplicate()
		wave["health"] = float(wave.get("health", 10.0)) * \
			minf(8.0 + level_index * 0.4, 40.0) / 10.0
		waves.append(wave)
	# Authored schedules can be sparse — top up with a couple of
	# procedural waves so every stage has a proper ending.
	if waves.size() < 3:
		var tail := _generate_waves(level_index, world)
		var t: float = (waves[waves.size() - 1]["delay"] + 5.0) if not waves.is_empty() else 1.0
		for i in range(maxi(0, tail.size() - 2), tail.size()):
			var w: Dictionary = tail[i].duplicate()
			w["delay"] = t
			waves.append(w)
			t += 8.0
	waves.sort_custom(func(a, b): return float(a["delay"]) < float(b["delay"]))
	var is_boss := bool(st.get("is_boss", false))
	return {
		"background": int(bg_pool[node % bg_pool.size()]),
		"music": str(pool[node % pool.size()]),
		"waves": waves,
		"boss": {"tier": world,
			"variant": BOSS_VARIANTS.get(world, "")} if is_boss else {},
		"mode": "castle" if bool(st.get("is_castle", false)) else "arena",
		"label": str(st.get("title", "")) if str(st.get("title", "")) != "" \
			else "M%d-%02d" % [world + 1, node + 1],
	}


## Total levels in the campaign — the authored playable stages.
static func level_count() -> int:
	_load_stages()
	return _playable.size()


## Which map/node a flat index belongs to ("m:n" stage key).
static func stage_key(level_index: int) -> String:
	_load_stages()
	if _playable.is_empty():
		return "0:0"
	return _playable[level_index % _playable.size()]


## Map number (world) and node index for a flat level index.
static func world_of(level_index: int) -> int:
	var p := stage_key(level_index).split(":")
	return int(p[0])


static func level_of(level_index: int) -> int:
	var p := stage_key(level_index).split(":")
	return int(p[1])


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


## Scripted waves — the original's ~115 named o_wave_* spawner objects,
## pre-extracted to data/levels/native/wave_scripts.json (pattern,
## count, per-spawn interval in frames, enemy kinds). Each level draws
## two entries so the whole catalogue is scheduled across the campaign.
##
## Legacy kind names that have no native equivalent are aliased to the
## closest ported behaviour; "boss" entries become sky-eye mini-bosses.
const _KIND_ALIASES := {
	"shy_ghost": "ghost", "warlock": "shooter",
	"castle_enemy": "shooter", "fat_boy": "fat_boy", "boss": "eye",
}
const _MAX_WAVE_COUNT := 40   # originals run 100-200; cap for pacing

static var _wave_scripts: Dictionary = {}


static func _scripted_for(world: int, level: int, difficulty: int,
		start_delay: float) -> Array:
	var scripts := _load_wave_scripts()
	var names := scripts.keys()
	if names.is_empty():
		return []
	names.sort()
	var hp := minf(8.0 + difficulty * 0.4, 40.0)
	var waves: Array = []
	var t := start_delay
	# Stride through the catalogue so consecutive levels get different
	# families and all 115 scripts appear across the 80-level campaign.
	var base: int = level * names.size() / LEVELS_PER_WORLD / WORLDS
	for offset in [0, 1]:
		var entry: Dictionary = scripts[names[(base + offset) % names.size()]]
		var wave := _scripted_wave(str(names[(base + offset) % names.size()]),
			entry, t, hp)
		if not wave.is_empty():
			waves.append(wave)
		t += 9.0
	return waves


static func _load_wave_scripts() -> Dictionary:
	if not _wave_scripts.is_empty():
		return _wave_scripts
	var path := "res://data/levels/native/wave_scripts.json"
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			_wave_scripts = parsed
	return _wave_scripts


## Translate one extracted spawner entry into a spawner wave dict.
## Returns {} for entries with no usable enemies (pure boss cues etc.).
static func _scripted_wave(script_name: String, entry: Dictionary,
		delay: float, hp: float) -> Dictionary:
	var kinds: Array = []
	for k in entry.get("kinds", []):
		var mapped: String = _KIND_ALIASES.get(str(k), str(k))
		if mapped in KINDS and mapped not in kinds:
			kinds.append(mapped)
	if kinds.is_empty():
		return {}
	var pattern: String = str(entry.get("pattern", "stream"))
	var count: int = mini(int(entry.get("count", 10)), _MAX_WAVE_COUNT)
	# Legacy interval is in 60fps frames; floor at ~7 frames so waves
	# don't dump their whole count in one tick.
	var interval_s: float = maxf(float(entry.get("interval", 15)) / 60.0, 0.12)
	var edge := "top"
	match pattern:
		"piranhas": edge = "bottom"
		"zigzag": edge = "left" if script_name.hash() % 2 == 0 else "right"
		"gunship", "ufo_stream": edge = "right"
	var wave := {
		"delay": delay, "count": count, "edge": edge,
		"mode": "formation", "health": hp,
		"pattern": pattern, "interval_s": interval_s,
		"kind": kinds[0], "kinds": kinds,
		"script": script_name,
	}
	# Pattern-specific massaging.
	if pattern == "circle":
		wave["count"] = clampi(count, 4, 16)   # orbiter count, not enemies
		wave["interval_s"] = 0.05
	elif pattern == "grid":
		# Original grids run 200 across ~30 slots; native caps at 40.
		wave["count"] = mini(count, 40)
	elif pattern == "loot":
		wave["count"] = mini(count, 8)
	elif pattern == "bonus":
		# Bonus waves drop bonus_fall/ducher_fall targets plus the
		# original's indestructible bonus_* ram-blockers.
		if "bonus_fall" not in kinds and "ducher_fall" not in kinds:
			kinds.append("bonus_fall")
			wave["kinds"] = kinds
		kinds = wave.get("kinds", kinds)
		if "bonus_block" not in kinds:
			kinds.append("bonus_block")
			wave["kinds"] = kinds
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
		# Team fighters are squad spawns — one ring per wave tick, so
		# they only appear as deliberate set pieces on later waves.
		if w >= 4 and roll == 3:
			kind = ["goomba_team", "ufo_team", "cyber_team", "hammer_team"][w % 4]
		if w >= 5 and roll >= 20:
			kind = ["jumbo", "crab", "ros", "warlord", "ring"][roll % 5]
		elif w >= 4 and roll >= 16:
			kind = ["tank", "eye", "eye2", "elite", "hunter"][roll % 5]
		elif w >= 3 and roll >= 12:
			kind = ["ufo_a", "ufo_a2", "ufo_b", "shooter", "stinger", "drone", "lancer", "rocket_ufo"][roll % 8]
		elif w >= 2 and roll >= 8:
			kind = ["kamikaze", "mini", "shooter", "dart", "weaver", "ace", "ghost", "ghost2", "ghost3", "ducher_fall", "bonus_fall", "runner"][roll % 12]
		elif w >= 2 and roll == 7:
			mode = "chase"
		if kind in ["kamikaze", "ufo_b", "weaver", "ace", "ghost", "ghost2", "ghost3", "runner"]:
			mode = "kamikaze"
		elif kind in ["shooter", "ufo_a", "tank", "eye", "ros", "crab",
				"stinger", "drone", "hunter", "lancer", "rocket_ufo"]:
			mode = "formation"

		var count := 3 + w + (difficulty / 3)
		if kind == "ring" or kind == "ducher_ring" \
				or kind.ends_with("_team"):
			count = 1   # the squad/ring IS the wave
		var hp := minf(8.0 + difficulty * 0.4, 40.0)
		match kind:
			"mini": hp = hp * 0.4
			"kamikaze", "ufo_b": hp = hp * 0.6
			"tank", "jumbo": hp = hp * 2.5
			"eye", "eye2": hp = hp * 6.0
			"ghost2": hp = hp * 2.5
			"ghost3": hp = hp * 3.0
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
