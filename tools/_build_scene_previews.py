import re, os

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def label(name, text, x1, y1, x2, y2, size=22, color="Color(1,1,1,1)", parent="Preview"):
    return ('[node name="%s" type="Label" parent="%s"]\n'
            'layout_mode = 1\nanchors_preset = 0\n'
            'offset_left = %.1f\noffset_top = %.1f\noffset_right = %.1f\noffset_bottom = %.1f\n'
            'theme_override_font_sizes/font_size = %d\n'
            'theme_override_colors/font_color = %s\n'
            'theme_override_colors/font_outline_color = Color(0, 0, 0, 1)\n'
            'theme_override_constants/outline_size = 4\n'
            'text = "%s"\nhorizontal_alignment = 1\nvertical_alignment = 1\n'
            % (name, parent, x1, y1, x2, y2, size, color, text.replace("\n", "\\n")))

def button(name, text, x, y, w=280, h=56):
    return ('[node name="%s" type="Button" parent="Preview"]\n'
            'layout_mode = 1\nanchors_preset = 0\n'
            'offset_left = %.1f\noffset_top = %.1f\noffset_right = %.1f\noffset_bottom = %.1f\n'
            'theme_override_font_sizes/font_size = 22\ntext = "%s"\n'
            % (name, x, y, x + w, y + h, text))

def rect(name, color, x1=None, y1=None, x2=None, y2=None, parent="Preview"):
    s = '[node name="%s" type="ColorRect" parent="%s"]\nlayout_mode = 1\n' % (name, parent)
    if x1 is None:
        s += 'anchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\n'
    else:
        s += 'anchors_preset = 0\noffset_left = %.1f\noffset_top = %.1f\noffset_right = %.1f\noffset_bottom = %.1f\n' % (x1, y1, x2, y2)
    s += 'color = %s\n' % color
    return s

GOLD = "Color(1,0.85,0.3,1)"
WHITE = "Color(1,1,1,1)"
DIM = "Color(0.6,0.6,0.7,1)"

SCENES = {}

SCENES["native/ui/title.tscn"] = ("Title", "Control", "",
    rect("BG", "Color(0.02,0.03,0.1,1)")
    + label("Logo", "MARIO FOREVER\nGALAXY", 212, 140, 812, 300, 64, GOLD)
    + button("BtnContinue", "CONTINUE", 372, 400)
    + button("BtnNewGame", "NEW GAME", 372, 480)
    + button("BtnOptions", "OPTIONS", 372, 560)
    + label("Hint", "press ENTER to continue", 312, 660, 712, 690, 16, DIM))

SCENES["native/ui/options.tscn"] = ("Options", "Control", "",
    rect("BG", "Color(0.03,0.04,0.12,1)")
    + label("Title", "OPTIONS", 412, 60, 612, 130, 48, GOLD)
    + rect("Panel", "Color(0.08,0.1,0.22,0.9)", 212, 170, 812, 590)
    + label("R1", "SOUND EFFECTS      [ ON ]", 262, 220, 762, 260, 24)
    + label("R2", "MUSIC               [ ON ]", 262, 280, 762, 320, 24)
    + label("R3", "SFX VOLUME          [ ====>    ]", 262, 340, 762, 380, 24)
    + label("R4", "MUSIC VOLUME        [ ====>    ]", 262, 400, 762, 440, 24)
    + label("R5", "EFFECTS             [ FULL ]", 262, 460, 762, 500, 24)
    + label("R6", "KEY BINDINGS        [ click to rebind ]", 262, 520, 762, 560, 20, "Color(0.7,0.8,1,1)"))

SCENES["native/ui/shop.tscn"] = ("Shop", "Control", "",
    rect("BG", "Color(0.04,0.03,0.08,1)")
    + label("Title", "SHOP", 462, 50, 562, 110, 44, GOLD)
    + label("Coins", "COINS: 12,345", 62, 120, 300, 160, 24, "Color(1,0.9,0.4,1)")
    + rect("Item1", "Color(0.12,0.1,0.2,0.95)", 62, 190, 492, 300)
    + rect("Item2", "Color(0.12,0.1,0.2,0.95)", 62, 320, 492, 430)
    + rect("Item3", "Color(0.12,0.1,0.2,0.95)", 62, 450, 492, 560)
    + rect("Item4", "Color(0.12,0.1,0.2,0.95)", 62, 580, 492, 690)
    + label("I1", "WEAPON UPGRADE", 82, 210, 400, 245, 22)
    + label("I1p", "500 coins", 82, 250, 300, 280, 18, DIM)
    + label("I2", "EXTRA LIFE", 82, 340, 400, 375, 22)
    + label("I2p", "1,000 coins", 82, 380, 320, 410, 18, DIM)
    + label("I3", "SPECIAL ITEM", 82, 470, 400, 505, 22)
    + label("I3p", "2,500 coins", 82, 510, 320, 540, 18, DIM)
    + label("I4", "HULL REPAIR", 82, 600, 400, 635, 22)
    + label("I4p", "250 coins", 82, 640, 320, 670, 18, DIM)
    + button("BtnLeave", "LEAVE", 812, 330, 150, 60))

SCENES["native/ui/hero_select.tscn"] = ("HeroSelect", "Control", "",
    rect("BG", "Color(0.02,0.04,0.1,1)")
    + label("Title", "CHOOSE YOUR HERO", 262, 60, 762, 120, 40, GOLD)
    + rect("H1", "Color(0.1,0.15,0.35,0.9)", 90, 180, 280, 480)
    + rect("H2", "Color(0.1,0.15,0.35,0.9)", 300, 180, 490, 480)
    + rect("H3", "Color(0.1,0.15,0.35,0.9)", 510, 180, 700, 480)
    + rect("H4", "Color(0.1,0.15,0.35,0.9)", 720, 180, 910, 480)
    + label("N1", "HERO 1", 130, 200, 270, 240, 22)
    + label("N2", "HERO 2", 340, 200, 430, 240, 22)
    + label("N3", "HERO 3", 550, 200, 650, 240, 22)
    + label("N4", "HERO 4", 760, 200, 900, 240, 22)
    + label("D1", "balanced all-rounder", 110, 430, 290, 470, 16, "Color(0.7,0.75,0.85,1)")
    + label("D2", "heavy hitter, slow", 320, 430, 500, 470, 16, "Color(0.7,0.75,0.85,1)")
    + label("D3", "fast, fragile", 530, 430, 710, 470, 16, "Color(0.7,0.75,0.85,1)")
    + label("D4", "support ship", 740, 430, 920, 470, 16, "Color(0.7,0.75,0.85,1)"))

SCENES["native/ui/card_game.tscn"] = ("CardGame", "Control", "",
    rect("BG", "Color(0.05,0.02,0.08,1)")
    + label("Title", "CARD GAME", 362, 40, 662, 100, 44, GOLD)
    + rect("C1", "Color(0.35,0.25,0.1,0.95)", 140, 160, 300, 380)
    + rect("C2", "Color(0.35,0.25,0.1,0.95)", 300, 160, 460, 380)
    + rect("C3", "Color(0.35,0.25,0.1,0.95)", 460, 160, 620, 380)
    + rect("C4", "Color(0.35,0.25,0.1,0.95)", 620, 160, 780, 380)
    + label("Q", "FIND THE STAR CARD!", 262, 430, 762, 470, 26, "Color(1,0.9,0.5,1)")
    + label("P", "prize: 10,000 coins", 362, 500, 662, 530, 18, DIM))

SCENES["native/ui/ending.tscn"] = ("Ending", "Control", "",
    rect("BG", "Color(0.01,0.02,0.06,1)")
    + label("Title", "THE END", 362, 300, 662, 400, 64, GOLD)
    + label("Sub", "thanks for playing", 362, 430, 662, 470, 24, "Color(0.7,0.75,0.85,1)"))

SCENES["native/ui/game_over.tscn"] = ("GameOver", "Control", "",
    rect("BG", "Color(0.08,0.01,0.01,1)")
    + label("Title", "GAME OVER", 312, 280, 712, 380, 64, "Color(1,0.3,0.3,1)")
    + label("Score", "SCORE: 0", 412, 420, 612, 460, 28)
    + button("BtnRetry", "TRY AGAIN", 372, 540, 280, 60))

SCENES["native/ui/intro.tscn"] = ("Intro", "Control", "",
    rect("BG", "Color(0.02,0.02,0.05,1)")
    + rect("Box", "Color(0.06,0.07,0.15,0.95)", 150, 200, 874, 500)
    + label("T1", "LONG AGO IN A GALAXY FAR, FAR AWAY...", 200, 240, 824, 290, 26, "Color(1,0.9,0.6,1)")
    + label("T2", "PEACH HAS BEEN CAPTURED BY THE FINAL BOSS.", 200, 320, 824, 370, 24)
    + label("T3", "ONLY A BRAVE STAR PILOT CAN SAVE HER.", 200, 400, 824, 450, 24)
    + button("BtnStart", "BEGIN", 392, 560, 240, 60))

SCENES["native/levels/star_map.tscn"] = ("StarMap", "Control", "",
    rect("BG", "Color(0.01,0.02,0.08,1)")
    + label("Title", "STAR MAP", 412, 20, 612, 70, 36, "Color(0.6,0.8,1,1)")
    + label("N1", "o", 180, 200, 220, 240, 40, GOLD)
    + label("N2", "o", 420, 160, 460, 200, 40, "Color(0.5,0.6,0.8,1)")
    + label("N3", "o", 640, 240, 680, 280, 40, "Color(0.5,0.6,0.8,1)")
    + label("N4", "o", 330, 380, 370, 420, 40, "Color(0.5,0.6,0.8,1)")
    + label("N5", "o", 560, 340, 600, 380, 40, "Color(0.5,0.6,0.8,1)")
    + label("N6", "*", 800, 480, 860, 540, 48, GOLD)
    + label("Cap", "click a node to fly there — lanes connect visited worlds", 212, 700, 812, 730, 16, "Color(0.5,0.55,0.65,1)"))

SHIP_TEX = "res://gfx/sprites/s_player_a.543.0.png"

def node2d_preview(bg_color, caption, ship_pos="Vector2(512, 600)"):
    return ('[node name="BG" type="ColorRect" parent="Preview"]\n'
            'layout_mode = 1\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\n'
            'color = %s\n\n'
            '[node name="ShipPreview" type="Sprite2D" parent="Preview"]\n'
            'position = %s\ntexture = ExtResource("tex_ship")\n\n'
            '[node name="Caption" type="Label" parent="Preview"]\n'
            'layout_mode = 1\nanchors_preset = 0\n'
            'offset_left = 60.0\noffset_top = 8.0\noffset_right = 900.0\noffset_bottom = 40.0\n'
            'theme_override_font_sizes/font_size = 20\n'
            'theme_override_colors/font_color = Color(1, 1, 1, 0.8)\n'
            'theme_override_colors/font_outline_color = Color(0, 0, 0, 1)\n'
            'theme_override_constants/outline_size = 4\n'
            'text = "%s"\nhorizontal_alignment = 0\n' % (bg_color, ship_pos, caption))

SCENES["native/levels/arena.tscn"] = ("Arena", "CanvasLayer", "tex_ship",
    node2d_preview("Color(0.02,0.05,0.12,1)",
        "ARENA — enemies spawn from the wave table at runtime"))

SCENES["native/levels/castle.tscn"] = ("Castle", "CanvasLayer", "tex_ship",
    node2d_preview("Color(0.09,0.05,0.03,1)",
        "CASTLE — side-scrolling stage, blocks stream past",
        "Vector2(220, 600)"))

SCRIPT_FOR = {
    "native/ui/title.tscn": "native/ui/title.gd",
    "native/ui/options.tscn": "native/ui/options.gd",
    "native/ui/shop.tscn": "native/ui/shop.gd",
    "native/ui/hero_select.tscn": "native/ui/hero_select.gd",
    "native/ui/card_game.tscn": "native/ui/card_game.gd",
    "native/ui/ending.tscn": "native/ui/ending.gd",
    "native/ui/game_over.tscn": "native/ui/game_over.gd",
    "native/ui/intro.tscn": "native/ui/intro.gd",
    "native/levels/star_map.tscn": "native/levels/star_map.gd",
    "native/levels/arena.tscn": "native/levels/arena.gd",
    "native/levels/castle.tscn": "native/levels/castle.gd",
}

PREVIEW_DROP = ('\n\tvar _preview := get_node_or_null("Preview")\n'
                '\tif _preview != null:\n'
                '\t\tremove_child(_preview)\n'
                '\t\t_preview.free()\n')

for path, (new_root, ptype, tex_id, preview_body) in SCENES.items():
    s = open(path, encoding="utf-8").read()
    s = re.sub(r'\[node name="Native\w+"', '[node name="%s"' % new_root, s, count=1)
    added = 0
    if tex_id:
        add = '[ext_resource type="Texture2D" path="%s" id="%s"]\n' % (SHIP_TEX, tex_id)
        s = s.replace("]\n\n[node", "]\n" + add + "\n[node", 1)
        m = re.search(r"load_steps=(\d+)", s)
        s = s[:m.start()] + "load_steps=%d" % (int(m.group(1)) + 1) + s[m.end():]
        added = 1
    s = s.rstrip() + '\n\n[node name="Preview" type="%s" parent="."]\n' % ptype
    if ptype == "Control":
        s += "layout_mode = 3\nanchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\n"
    s += "\n" + preview_body + "\n"
    open(path, "w", encoding="utf-8", newline="").write(s)
    print("scene", path)

for tscn, gd in SCRIPT_FOR.items():
    s = open(gd, encoding="utf-8").read()
    if "_preview" in s:
        continue
    s2 = s.replace("func _ready() -> void:\n", "func _ready() -> void:\n" + PREVIEW_DROP, 1)
    if s2 == s:
        print("!! no _ready in", gd)
        continue
    open(gd, "w", encoding="utf-8", newline="").write(s2)
    print("patched", gd)
