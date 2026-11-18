extends SceneTree

## Probe: reach the map, hold the pan pad (obj 235), emulate the warped cursor
## pinned near screen center, and log view/zoom/mouse each frame.
##   godot --path . -s tools/_devin_mapdrag.gd -- --frames=4000

const ENTER := 13
var frames := 0
var room_frames := 0
var last_room := -1
var hold_key := 0
var hold_left := 0
var cool := 0
var done := false
var dragging := false
var drag_frames := 0
var panel_pos := Vector2.ZERO

func _initialize() -> void:
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)

func _tap(key: int) -> void:
	if hold_left > 0 or cool > 0:
		return
	R.keyboard_key_press(null, key)
	hold_key = key
	hold_left = 2
	cool = 16

func _process(_delta: float) -> bool:
	if done:
		return true
	frames += 1
	room_frames += 1
	if hold_left > 0:
		hold_left -= 1
		if hold_left == 0:
			R.keyboard_key_release(null, hold_key)
	if cool > 0:
		cool -= 1
	if not R.game_running:
		return false
	if R.room != last_room:
		last_room = R.room
		room_frames = 0
		var meta: Dictionary = R.room_data.get("rooms", {}).get(str(R.room), {})
		print("ROOM %d %s" % [R.room, meta.get("name", "?")])
		if dragging:
			print("left map mid-drag")
			dragging = false
			drag_frames = 0
	match R.room:
		59:
			if room_frames > 4:
				R.pending_room = 51
		51, 48, 49, 52, 53, 54, 55:
			_tap(ENTER)
		14, 4, 19, 22, 26, 30, 35, 43:
			_map_drag()
		2:
			# reached a level: bug not in map path; quit
			print("reached level room, done")
			done = true
	if frames >= 6000:
		print("DONE frame=%d room=%d" % [frames, R.room])
		done = true
	if done:
		quit()
		return true
	return false

func _find_panel() -> Variant:
	for inst in R.instances:
		if int(inst.g_object_index) == 235:
			return inst
	return null

func _map_drag() -> void:
	var G = load("res://game/globals.gd")
	if not dragging:
		# wait for map to settle, then grab the pad
		if room_frames < 240:
			return
		var p = _find_panel()
		if p == null:
			print("no obj235 panel")
			return
		panel_pos = Vector2(p.x, p.y)
		print("PANEL pos=(%.0f,%.0f) view=(%.1f,%.1f) angle=%.2f" % [
			p.x, p.y, float(R.aget(R.view_xview, 0)), float(R.aget(R.view_yview, 0)),
			float(R.aget(R.view_angle, 0))])
		R.mouse_override = panel_pos
		R.mouse_down[1] = true
		R.mouse_pressed[1] = true
		dragging = true
		drag_frames = 0
		return
	# emulating a real hand: warp the OS cursor to centre+offset each frame.
	# The game's own warp-to-centre runs later in the draw, so the drag block
	# reads exactly what a physical cursor would report (full canvas transform).
	drag_frames += 1
	var wpos := DisplayServer.window_get_position()
	var wsize := DisplayServer.window_get_size()
	if drag_frames <= 15:
		# stay on the pad so the press registers the meeting
		R.mouse_override = panel_pos
	else:
		R.mouse_override = null
		DisplayServer.warp_mouse(Vector2i(wsize.x / 2 + 60, wsize.y / 2))
	if drag_frames % 5 == 0 or drag_frames < 10:
		var blk: Variant = R.get_obj_var(225, "g_zoom_oglada_block")
		var S = _iface()
		print("D%03d blk=%s zplus=(%.1f,%.1f) view=(%.1f,%.1f) mouse=(%.0f,%.0f) antione=%s" % [
			drag_frames, str(blk),
			S.g_zoom_plusx if S else -1, S.g_zoom_plusy if S else -1,
			float(R.aget(R.view_xview, 0)), float(R.aget(R.view_yview, 0)),
			(R.mouse_override[0] if R.mouse_override != null else -1.0),
			(R.mouse_override[1] if R.mouse_override != null else -1.0),
			str(S.g_zoom_antione) if S else "?"])
	if drag_frames >= 240:
		R.mouse_down.erase(1)
		R.mouse_override = null
		print("released; watching decay")
		for i in 60:
			await process_frame
		var S2 = _iface()
		print("after release zplus=(%.2f,%.2f) view=(%.1f,%.1f)" % [
			S2.g_zoom_plusx, S2.g_zoom_plusy,
			float(R.aget(R.view_xview, 0)), float(R.aget(R.view_yview, 0))])
		done = true

func _iface() -> Variant:
	for inst in R.instances:
		if int(inst.g_object_index) == 225:
			return inst
	return null
