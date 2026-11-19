extends Control
## NativeIntro — opening story sequence.

## Ports the role of the original's intro/cutscene rooms: a short text
## scroll that sets up the galaxy campaign. Lightweight on purpose —
## pages fade in sequence and any key/click advances to hero select.
## The full animated cutscenes are a later milestone.

const HERO_SCENE := "res://native/ui/hero_select.tscn"

const PAGES := [
	"Long ago, the Mushroom Kingdom\nspread its light across the galaxy.",
	"Now darkness gathers at the edge\nof the stars...",
	"Only a brave pilot can cross\nthe void and drive it back.",
	"Choose your ship. The galaxy\nis waiting.",
]

var _page := 0
var _label: Label
var _tween: Tween


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_label.text = PAGES[_page]
	_label.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 1.2)


func _advance() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
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
