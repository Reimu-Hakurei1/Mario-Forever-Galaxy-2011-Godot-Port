import os, re, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

# ---------- 1. folder moves ----------
os.makedirs("gfx", exist_ok=True)
moves = [
    ("data/a", "gfx/cutscene"),
    ("data/g", "gfx/map"),
    ("data/l", "gfx/logo"),
    ("data/t", "gfx/title"),
    ("data/s", "sfx"),
    ("data/levels", "levels"),
]
# skipper save file leaves the music folder first
if os.path.exists("data/skipper"):
    shutil.move("data/skipper", "data/skipper")
moves.insert(4, ("data/m", "music"))
# images split
if os.path.isdir("images/sprites"):
    os.makedirs("gfx/sprites", exist_ok=True)
    for f in os.listdir("images/sprites"):
        shutil.move(os.path.join("images/sprites", f), os.path.join("gfx/sprites", f))
if os.path.isdir("images/backgrounds"):
    os.makedirs("gfx/backgrounds", exist_ok=True)
    for f in os.listdir("images/backgrounds"):
        shutil.move(os.path.join("images/backgrounds", f), os.path.join("gfx/backgrounds", f))
for d in moves:
    if os.path.exists(d[0]):
        shutil.move(d[0], d[1])
        print("moved", d[0], "->", d[1])
for leftover in ["images/sprites", "images/backgrounds", "images", "data/m", "data/a", "data/g", "data/l", "data/s", "data/t"]:
    if os.path.isdir(leftover) and not os.listdir(leftover):
        os.rmdir(leftover)

# ---------- 2. path reference rewrites ----------
TEXT_EXT = {".gd", ".json", ".tscn", ".tres", ".import", ".cfg", ".ini",
            ".md", ".py", ".txt", ".uid", ".gdshader", ".translation"}
SKIP_DIRS = {".git", ".godot", "__pycache__"}
subs = [
    ("data/skipper", "data/skipper"),
    ("levels/", "levels/"),
    ("gfx/cutscene/", "gfx/cutscene/"),
    ("gfx/map/", "gfx/map/"),
    ("gfx/logo/", "gfx/logo/"),
    ("music/", "music/"),
    ("sfx/", "sfx/"),
    ("gfx/title/", "gfx/title/"),
    ("res://gfx/", "res://gfx/"),
]
changed = []
for dirpath, dirnames, filenames in os.walk("."):
    dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
    for fn in filenames:
        ext = os.path.splitext(fn)[1]
        if ext not in TEXT_EXT and fn != ".import":
            continue
        p = os.path.join(dirpath, fn)
        try:
            s = open(p, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        orig = s
        for a, b in subs:
            s = s.replace(a, b)
        if s != orig:
            open(p, "w", encoding="utf-8", newline="").write(s)
            changed.append(p)
print("rewrote", len(changed), "files")
