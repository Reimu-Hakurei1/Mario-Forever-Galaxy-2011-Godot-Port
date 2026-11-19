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
const WORLD_THEME := {
	0: {"bg": 0, "music": "mixed_battle"},     # asteroid belt
	1: {"bg": 2, "music": "hard_squad"},       # rocky world
	2: {"bg": 4, "music": "castle_fly2"},      # castle approach
	3: {"bg": 5, "music": "dark"},             # dark space
	4: {"bg": 6, "music": "brutal_force"},     # brutal zone
	5: {"bg": 44, "music": "hard_life"},       # hard life
	6: {"bg": 48, "music": "rage"},            # rage
	7: {"bg": 41, "music": "last_boss"},       # final world
}

# Enemy kinds available to the generator.
const KINDS := ["goomba", "shooter", "kamikaze", "tank", "eye"]


## Build the arena config for a flat level index. Returns a Dictionary
## the arena scene consumes: {background, music, waves}.
static func config_for(level_index: int) -> Dictionary:
	var world := level_index / LEVELS_PER_WORLD
	var level := level_index % LEVELS_PER_WORLD
	var theme: Dictionary = WORLD_THEME.get(world, WORLD_THEME[0])
	var difficulty := level_index  # 0-based progression drives wave size

	return {
		"background": theme["bg"],
		"music": theme["music"],
		"waves": _generate_waves(difficulty, world),
		"label": "W%d-%02d" % [world + 1, level + 1],
	}


## Total levels in the campaign.
static func level_count() -> int:
	return WORLDS * LEVELS_PER_WORLD


## Which world/level a flat index belongs to.
static func world_of(level_index: int) -> int:
	return level_index / LEVELS_PER_WORLD


static func level_of(level_index: int) -> int:
	return level_index % LEVELS_PER_WORLD


## Procedural wave list — later waves introduce harder kinds and bigger
## groups. Kept deterministic per level so replays feel consistent.
static func _generate_waves(difficulty: int, world: int) -> Array:
	var waves: Array = []
	var wave_count := 4 + mini(difficulty / 4, 4)        # 4-8 waves
	var t := 1.0
	for w in wave_count:
		# Later waves favour nastier kinds.
		var roll := (w * 7 + difficulty * 3 + world) % 10
		var kind := "goomba"
		var mode := "formation"
		if w >= 1 and roll >= 6:
			kind = "shooter"
		elif w >= 2 and roll >= 8:
			kind = "kamikaze"
			mode = "kamikaze"
		elif w >= 3 and roll == 9:
			kind = "tank"
		elif w >= 4 and roll == 5:
			kind = "eye"
		elif w >= 2 and roll == 4:
			mode = "chase"

		var count := 3 + w + (difficulty / 3)
		var hp := 100.0 + difficulty * 12.0
		match kind:
			"kamikaze": hp = 60.0 + difficulty * 6.0
			"tank": hp = 400.0 + difficulty * 30.0
			"eye": hp = 160.0 + difficulty * 15.0
			"shooter": hp = 140.0 + difficulty * 12.0

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
