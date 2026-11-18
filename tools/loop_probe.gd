extends SceneTree

## Verify the imported ogg loop settings and that playback wraps at loop_offset.
##   godot --path . -s tools/loop_probe.gd -- --track=map_3 --seek=20 --frames=900

var p: AudioStreamPlayer
var frames := 0
var limit := 900
var last := -1.0
var track := "map_3"
var seek_to := 20.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--track="):
			track = a.substr(8)
		elif a.begins_with("--seek="):
			seek_to = float(a.substr(7))
		elif a.begins_with("--frames="):
			limit = int(a.substr(9))
	var s: AudioStreamOggVorbis = load("res://data/m/%s.ogg" % track)
	print("STREAM %s loop=%s loop_offset=%.3f length=%.3f" % [track, str(s.loop),
		s.loop_offset, s.get_length()])
	p = AudioStreamPlayer.new()
	p.stream = s
	root.add_child(p)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 2:
		p.play()
		if seek_to > 0.0:
			p.seek(seek_to)
	var pos := p.get_playback_position()
	if frames % 30 == 0 or (pos < last - 0.3):
		print("f=%d pos=%.3f playing=%s" % [frames, pos, str(p.playing)])
	last = pos
	if frames >= limit:
		quit()
		return true
	return false
