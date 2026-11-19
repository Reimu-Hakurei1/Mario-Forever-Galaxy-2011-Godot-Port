extends CanvasLayer
class_name NativeBossDialogue
## NativeBossDialogue — the boss intro speech (ports the g_dialogue /
## gadanina typewriter sequence in o_boss_*_talk objects).
##
## The original types each line out automatically (# = manual line
## break), holds it, then advances — no keypress. This overlay does
## the same: a bottom-of-screen caption box, typewriter reveal,
## auto-advance, and a finished signal the boss listens for.

signal finished

const CHARS_PER_SEC := 28.0
const HOLD_EXTRA := 0.9        # seconds a finished line lingers

var _label: Label
var _box: PanelContainer
var _lines: Array = []
var _line_idx := 0
var _shown := 0.0
var _hold := 0.0
var _done := false


func _init() -> void:
	layer = 24


## Start the speech. `lines` come from NativeDialogueTable.
func play(lines: Array) -> void:
	_lines = lines
	if _lines.is_empty():
		finished.emit()
		return
	_build_ui()


func _build_ui() -> void:
	_box = PanelContainer.new()
	_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_box.offset_left = 120.0
	_box.offset_right = -120.0
	_box.offset_top = -150.0
	_box.offset_bottom = -60.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.72)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_box.add_theme_stylebox_override("panel", style)
	add_child(_box)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(1, 0.92, 0.75))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	_box.add_child(_label)


func _process(delta: float) -> void:
	if _done or _lines.is_empty() or NativeGame.paused:
		return
	var text: String = _lines[_line_idx].replace("#", "\n")
	var total := text.length()

	if _shown < total:
		_shown = minf(total, _shown + CHARS_PER_SEC * delta)
		_label.text = text.substr(0, int(_shown))
		return

	# Line fully shown — hold, then advance or finish.
	_hold += delta
	if _hold >= HOLD_EXTRA + total * 0.02:
		_hold = 0.0
		_shown = 0.0
		_line_idx += 1
		if _line_idx >= _lines.size():
			_done = true
			finished.emit()
			var tw := create_tween()
			tw.tween_property(_box, "modulate:a", 0.0, 0.6)
			tw.tween_callback(queue_free)
