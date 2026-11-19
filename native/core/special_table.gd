extends RefCounted
class_name NativeSpecialTable
## NativeSpecialTable — the 9 special items (G.specialslot[0..3]).
##
## The original grants up to 4 special slots per hero (choose_hero.gd
## presets them per hero). Pressing the special button fires
## specialslot[0]; prev/next keys rotate the ring so a different
## special becomes active. Each id maps to a g_sekwencja_special
## scripted sequence in script_special (part_5_8.gd).
##
## The original sequences are elaborate scripted cinematics; this port
## implements each one's gameplay effect directly:
##   1  seq 23000 — trickle heal (+1/frame ~10s)
##   2  seq 22000 — spawns object 218 (heavy blast)
##   3  seq 1000  — growing piercing slug (sila 5, grows x30)
##   4  seq 1     — particle nova ring (special_spread_obrywanie)
##   5  seq 5000  — red-phase shot variant
##   6  seq 30000 — THREE object-304 missiles (sila 200 each!)
##   7  seq 50000 — big trickle heal (+2/frame ~10s)
##   8  seq 80000 — ring of 11 bomb objects (starter_boom staggered)
##   9  seq 100000— zwolnij_gre (bullet-time); approximated as
##                enemy-bullet clear + bullet-time slow-mo
##
## "heal_rate" ticks hull per second while active_seconds lasts.
## "damage"/"count"/"spread" describe the attack payloads.

const ITEMS := [
	{},  # id 0 = empty slot (never an item)
	{"name": "FIELD DRESSING", "desc": "Slow hull repair over ~10s",
		"heal_rate": 60.0, "heal_time": 10.0, "icon": 1},
	{"name": "NOVA BLAST", "desc": "Heavy damage to every enemy",
		"damage": 30.0, "icon": 2},
	{"name": "PIERCER SLUG", "desc": "Huge slow bolt, pierces everything",
		"damage": 80.0, "pierce": true, "icon": 3},
	{"name": "NOVA RING", "desc": "Damage nova around the ship",
		"damage": 15.0, "icon": 4},
	{"name": "RED SHOT", "desc": "Heavy single slug",
		"damage": 40.0, "icon": 5},
	{"name": "TRIPLE MISSILE", "desc": "Three heavy seeking bolts",
		"damage": 60.0, "count": 3, "icon": 6},
	{"name": "NANO SWARM", "desc": "Massive hull repair over ~10s",
		"heal_rate": 120.0, "heal_time": 10.0, "icon": 7},
	{"name": "BOMB RING", "desc": "Eleven bombs burst outward",
		"damage": 25.0, "count": 11, "icon": 8},
	{"name": "CHRONO", "desc": "Bullet-time: clears enemy fire, slows the game",
		"clear_bullets": true, "slowmo": 3.0, "icon": 9},
]

## Shop price for a duplicate special — the original only stocks
## specials the player has found (dodaj_do_sklepu_support), so prices
## here are our own reasonable curve.
const PRICES := [0, 4000, 8000, 15000, 12000, 10000, 25000, 20000, 30000, 50000]


static func at(id: int) -> Dictionary:
	if id <= 0 or id >= ITEMS.size():
		return {}
	return ITEMS[id]
