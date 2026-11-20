extends Control
## NativeIntro — opening story sequence.
##
## Ports the role of the original's intro/cutscene rooms: a short story
## scroll that sets up the galaxy campaign. Pages fade in over a drifting
## starfield with the hero ship cruising past; text types out like a
## terminal. Any key/click skips the typewriter, advances pages, and on
## the last page moves on to hero select. The full animated cutscenes
## (the legacy runtime's room_animation_* rooms) remain a later milestone.

const HERO_SCENE := "res://native/ui/hero_select.tscn"
const SHIP_SPRITE := 543        # s_player_a — same hull as the arena
const TYPEWRITER_CPS := 28.0   # characters per second

const PAGES := [
	"Long ago, the Mushroom Kingdom\nspread its light across the galaxy.",
	"Now darkness gathers at the edge\nof the stars...",
	"Only a brave pilot can cross\nthe void and drive it back.",
	"Choose your ship. The galaxy\nis waiting.",
]

var _page := 0
var _label: Label
var _tween: Tween
var _full_text := ""
var _shown := 0.0
var _ship: Sprite2D
var _ship_vx := 0.6


func _ready() -> void:

	var _preview := get_node_or_null("Preview")
	if _preview != null:
		remove_child(_preview)
		_preview.free()
	# --- starfield backdrop (same generated-dot trick as title/arena) ---
	var img := Image.create(1024, 768, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.01, 0.01, 0.05, 1.0))
	for i in 200:
		img.set_pixel(randi() % 1024, randi() % 768,
			Color(1, 1, 1, 0.2 + randf() * 0.6))
	var stars := TextureRect.new()
	stars.texture = ImageTexture.create_from_image(img)
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.stretch_mode = TextureRect.STRETCH_TILE
	stars.modulate = Color(1, 1, 1, 0.8)
	add_child(stars)
	var tw := create_tween().set_loops()
	tw.tween_property(stars, "position:x", -1024.0, 90.0) \
		.from(0.0).set_trans(Tween.TRANS_LINEAR)

	# --- hero ship drifting across the lower sky ---
	_ship = Sprite2D.new()
	var tex := NativeAssets.sprite_frame(SHIP_SPRITE, 0)
	if tex != null:
		_ship.texture = tex
		_ship.offset = -NativeAssets.sprite_origin(SHIP_SPRITE)
	_ship.scale = Vector2(0.35, 0.35)
	_ship.position = Vector2(-120, 560)
	add_child(_ship)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.offset_top = -120
	_label.offset_bottom = 120
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)

	var hint := Label.new()
	hint.text = "PRESS ANY KEY"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -50
	hint.offset_bottom = -20
	add_child(hint)

	_show_page()


func _show_page() -> void:
	_full_text = PAGES[_page]
	_shown = 0.0
	_label.text = ""
	_label.modulate.a = 1.0


func _process(delta: float) -> void:
	# Typewriter reveal — once the page is fully shown it stays.
	if _shown < _full_text.length():
		_shown = minf(_full_text.length(), _shown + TYPEWRITER_CPS * delta)
		_label.text = _full_text.substr(0, int(_shown))
	# Ship cruises left-to-right and wraps — cheap cinematic motion.
	if _ship != null:
		_ship.position.x += _ship_vx
		if _ship.position.x > 1144:
			_ship.position.x = -120


func _advance() -> void:
	# Mid-typewriter presses complete the line instead of skipping pages.
	if _shown < _full_text.length():
		_shown = _full_text.length()
		_label.text = _full_text
		return
	_page += 1
	if _page >= PAGES.size():
		get_tree().change_scene_to_file(HERO_SCENE)
	else:
		_show_page()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_advance()
	elif event is InputEventMouseButton and event.pressed:
		_advance()
