extends Control

## Wave schedule strip shown under the level canvas. Draws every spawn rule
## as a span on the 0-200 period axis (the same clock the runtime uses) and
## lets you click a span to select that spawn in the editor.

var editor = null            # level_editor.gd instance
var pad_left := 34.0
var pad_right := 8.0
var axis_y := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(0, 72)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _period_to_x(p: float) -> float:
	var w := size.x - pad_left - pad_right
	return pad_left + clampf(p, 0.0, 200.0) / 200.0 * w


func _x_to_period(x: float) -> float:
	var w := size.x - pad_left - pad_right
	return clampf((x - pad_left) / w, 0.0, 1.0) * 200.0


func _spawn_end(s: Dictionary) -> float:
	return float(s["start"]) + maxi(int(s["count"]) - 1, 0) * float(s["interval"])


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.07, 0.08, 0.11))
	axis_y = h * 0.55
	# axis
	draw_line(Vector2(pad_left, axis_y), Vector2(w - pad_right, axis_y), Color(1, 1, 1, 0.35), 1.0)
	for p in [0.0, 50.0, 100.0, 150.0, 200.0]:
		var x := _period_to_x(p)
		draw_line(Vector2(x, axis_y - 4), Vector2(x, axis_y + 4), Color(1, 1, 1, 0.35))
		draw_string(ThemeDB.fallback_font, Vector2(x - 8, axis_y + 18), str(int(p)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))
	draw_string(ThemeDB.fallback_font, Vector2(4, axis_y + 18), "periods", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))
	if editor == null:
		return
	# spawn spans, newest on top
	for i in editor.spawns.size():
		var s: Dictionary = editor.spawns[i]
		var x0 := _period_to_x(float(s["start"]))
		var x1 := _period_to_x(_spawn_end(s))
		var col := Color.from_hsv(fmod(i * 0.13, 1.0), 0.65, 0.95, 0.85)
		var r := Rect2(x0, axis_y - 16, maxf(x1 - x0, 5.0), 12)
		draw_rect(r, col)
		draw_rect(r, Color(0, 0, 0, 0.5), false, 1.0)
		if int(s["count"]) > 1:
			# tick marks for each individual spawn
			for n in int(s["count"]):
				var tx := _period_to_x(float(s["start"]) + n * float(s["interval"]))
				draw_line(Vector2(tx, r.position.y), Vector2(tx, r.end.y), Color(0, 0, 0, 0.45), 1.0)
		# count label above the span
		var label := "%s x%d" % [str(editor._kind_name(int(s.kind))).left(10), int(s["count"])]
		draw_string(ThemeDB.fallback_font, Vector2(x0 + 2, r.position.y - 3), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col.lightened(0.3))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var p := _x_to_period(event.position.x)
		# topmost match wins (last drawn = last spawn)
		var best := -1
		for i in range(editor.spawns.size() - 1, -1, -1):
			var s: Dictionary = editor.spawns[i]
			if p >= float(s["start"]) and p <= _spawn_end(s):
				best = i
				break
		if best >= 0:
			editor._select_spawn_index(best)
		accept_event()
