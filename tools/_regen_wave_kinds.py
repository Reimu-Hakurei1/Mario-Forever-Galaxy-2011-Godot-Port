#!/usr/bin/env python3
"""Regenerate wave_scripts.json `kinds` from the real instance_create
object ids inside each objects/spawners/*.gd script.

The previous extraction collapsed 83/115 scripts to `goomba`; this pass
counts actual spawned objects per script and maps them onto native
kinds. Boss/effect/pickup objects are skipped here — bosses are covered
by SCRIPT_BOSSES in level_table.gd, pickups by `drop` waves.
"""
import json, re, os, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPAWNERS = os.path.join(ROOT, "objects", "spawners")
WS_PATH = os.path.join(ROOT, "data", "levels", "native", "wave_scripts.json")

# GameMaker object id -> native kind name. Only damageable enemies;
# bullets/effects/pickups/castle-parts/bosses are excluded.
ID2KIND = {
    12: "goomba",          # o_enemy_1
    49: "runner",          # o_enemy_9 suicide runner
    82: "jumbo",           # o_dodatkowy_2 (sprite 50)
    95: "bonus_fall",      # o_enemy_17e
    98: "bonus_fall",      # o_enemy_17g
    99: "bonus_fall",      # o_enemy_17h
    101: "bonus_fall",     # o_enemy_17i
    118: "ufo_a",          # o_ufo_a
    153: "rocket_ufo",     # o_rocketufo_a
    156: "fat_boy",        # o_fatboy_a
    157: "fat_cannon",     # o_fatboy_cannon
    164: "eye",            # o_skyeye
    248: "castle_enemy",   # o_castle_enemier
    249: "castle_enemy",   # o_castle_enemier_2_nonblock
    260: "castle_enemy",   # o_castle_enemier_2
    317: "ufo_a2",         # o_ufo_a2
    327: "ghost",          # o_shyghost
    329: "ghost2",         # o_shyghost2
    330: "ghost3",         # o_shyghost3
    340: "castle_enemy",   # o_castle_enemier_3
    349: "castle_enemy",   # o_castle_enemier_2_nonblock_harder
    353: "flame_map",      # o_flamecans (600hp)
    356: "goomba_team",    # o_goomba_team
    365: "bonus_fall",     # o_bonusho
    382: "kamikaze",       # o_spikey_swarm_map_5 (darts swarm)
    396: "ghost",          # o_ducher_do_okala (ring of shyghosts)
    397: "ducher_fall",    # o_ducher_spadajace
    400: "flame_map",      # o_flamecans_map5 (600hp)
    401: "ufo_gunship",    # o_ufoteam (200hp)
    410: "mini",           # o_enemy_dookola_1
    412: "mini",           # o_enemy_dookola_2
    432: "flame_map",      # o_flamecans2 (600hp)
    434: "mini",           # o_enemy_dookola_1_delayed
    435: "cyber_team",     # o_cyber_team
    438: "flame_shooter",  # o_flamecans_shoota
    440: "hammer_team",    # o_hammer_team
    442: "ufos_orbiter",   # o_ufos_team (450hp orbit-rockets)
    444: "ufos_orbiter",   # o_ufos_team_dolny
    453: "fat_boy_heavy",  # o_fatboy_boss6 used as a wave enemy (9000hp)
    469: "flame_map7",     # o_flamecans_map7 (1100hp)
    482: "ufos_orbiter",   # o_ufos_team2
    495: "ufo_gunship2",   # o_ufoteam2 (1200hp)
    501: "eye2",           # o_skyeye2
    # o_dodatkowy_*_samosterujacing additions — boss-script helpers,
    # rarely wave-spawned; treat as fragile swarm darts.
    57: "mini", 58: "mini", 116: "mini", 402: "mini", 403: "mini",
    446: "mini", 488: "mini", 509: "mini", 510: "mini", 512: "mini",
    513: "mini", 531: "mini",
    # Castle stream enemies reuse the shooter behavior.
    242: "shooter",  # o_castle_obj is terrain, skip anyway
}
ID2KIND.pop(242, None)

BOSS_IDS = {
    40, 169, 251, 261, 262, 263, 335, 336, 345, 347, 361, 369, 373,
    375, 377, 389, 416, 417, 418, 429, 453, 461, 465, 466, 476, 504,
    505, 507, 508, 514, 122, 113, 109, 122,
}
# boss talk/fight/endtalk objects + boss helper fx — not wave enemies.
BOSS_IDS |= {122, 123, 169, 261, 263, 335, 336, 361, 375, 417, 465,
             504, 507, 508, 514, 40, 262, 334, 362, 418, 466, 505}

# instance_create(S, x, y, id) — greedy to the LAST ,digits) on the
# line, which is always the object id (x/y may nest R.random calls).
CREATE_RE = re.compile(r"instance_create\(S,.*,\s*(\d+)\)")

def main():
    ws = json.load(open(WS_PATH, encoding="utf-8"))
    boss_report = []
    changed = 0
    for script, entry in ws.items():
        path = os.path.join(SPAWNERS, script + ".gd")
        if not os.path.exists(path):
            continue
        src = open(path, encoding="utf-8").read()
        counts = collections.Counter(int(m) for m in CREATE_RE.findall(src))
        # Boss objects authored inside the script — SCRIPT_BOSSES must
        # cover these (report only; the table is hand-verified).
        bosses = sorted(i for i in counts if i in BOSS_IDS
                        or i in (251, 345, 347, 369, 373, 377, 389,
                                 416, 429, 453, 461, 476))
        if bosses:
            boss_report.append((script, bosses))
        # Weighted kind mix — dedupe preserving frequency order.
        kinds = []
        for oid, n in counts.most_common():
            k = ID2KIND.get(oid)
            if k and k not in kinds:
                kinds.append(k)
        if not kinds:
            continue
        old = entry.get("kinds", [])
        if old != kinds:
            entry["kinds"] = kinds
            entry["kind"] = kinds[0]
            changed += 1
    json.dump(ws, open(WS_PATH, "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)
    print(f"updated {changed}/{len(ws)} scripts")
    print("\nscripts containing boss objects:")
    for s, b in boss_report:
        print(" ", s, b)

if __name__ == "__main__":
    main()
