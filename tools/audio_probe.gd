extends SceneTree
var R = load("res://engine/r.gd")

## Boot-intro audio probe: observe music/SFX state through the natural startup.
##   godot --headless --path . -s tools/audio_probe.gd -- --frames=600 --savedir=<dir>

var frames: int = 0
var limit: int = 600
var savedir: String = ""
var started: bool = false
var room_id: int = -1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			limit = int(a.substr(9))
		elif a.begins_with("--savedir="):
			savedir = a.substr(10).replace("\\", "/")
		elif a.begins_with("--room="):
			room_id = int(a.substr(7))
	var game: Node = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frames += 1
	if not R.game_running:
		return false
	if not started:
		started = true
		R.debug_audio = true
		if savedir != "":
			DirAccess.make_dir_recursive_absolute(savedir)
			R.working_directory = savedir
	if savedir != "" and R.working_directory != savedir:
		R.working_directory = savedir
	if room_id >= 0 and R.room != room_id:
		R.pending_room = room_id
	if frames % 60 == 0:
		var mp: AudioStreamPlayer = R.music_player
		var stream_name: String = "none"
		var playing: bool = false
		var pos: float = 0.0
		if mp != null:
			playing = mp.playing
			pos = mp.get_playback_position()
			if mp.stream != null:
				stream_name = str(mp.stream.resource_path)
		var active: int = 0
		for p in R.sfx_players:
			if p.playing:
				active += 1
		var wp: AudioStreamPlayer = R.wap_player
		var wname: String = "none"
		var wpos: float = 0.0
		if wp != null:
			wpos = wp.get_playback_position()
			if wp.stream != null:
				wname = str(wp.stream.resource_path)
		print("AUDIO frame=%d room=%d music=%s playing=%s pos=%.2f wap=%s wpos=%.2f wplaying=%s sfx_active=%d" % [
			frames, R.room, stream_name, playing, pos, wname, wpos,
			wp.playing if wp else false, active])
	if frames >= limit:
		quit()
		return true
	return false