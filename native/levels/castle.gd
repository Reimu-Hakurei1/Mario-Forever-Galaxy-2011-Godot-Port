extends Node2D
## NativeCastle — a castle-crawl stage (ports the original's castle rooms).
##
## Same ship, same HUD, same death/respawn flow as the arena — but the
## world scrolls downward past the player (G.castle_speed) instead of
## spawning waves. NativeCastleScroller streams destructible blocks,
## enemies, coins and keys; touching a key ends the stage.
##
## Flow mirrors arena.gd: death → lose life → respawn → buddies revive;
## key found → LEVEL CLEAR → shop → star map.

const WORLD_SIZE := Vector2(1024, 768)
const PLAYER_SPAWN := Vector2(435, 425)
const RESPAWN_DELAY := 2.0
const LEVEL_CLEAR_DELAY := 3.0

@onready var _ship: NativeShip = $Ship
@onready var _hud: NativeHUD = $HUD
@onready var _scroller: NativeCastleScroller = $CastleScroller

var _level_cfg: Dictionary = {}
var _respawn_timer := -1.0
var _death_pending := false
var _level_cleared := false
var _clear_timer := -1.0
var _pause_label: Label = null
var _help_label: Label = null
var _help_topic_shown := -1
var _last_energy := 100.0
var _shake := 0.0


func _ready() -> void:
	Engine.max_fps = 60

	_level_cfg = NativeGame.pending_level
	NativeGame.pending_level = {}
	var bg_id: int = _level_cfg.get("background", 4)
	var music_track: String = _level_cfg.get("music", "hard_castle")

	# Backdrop — castle interiors use the dungeon backgrounds.
	var bg := Sprite2D.new()
	var tex := NativeAssets.background(bg_id)
	if tex != null:
		bg.texture = tex
		bg.centered = false
		bg.scale = Vector2(WORLD_SIZE.x / tex.get_width(),
			WORLD_SIZE.y / tex.get_height())
	bg.z_index = -100
	add_child(bg)

	NativeGame.reset_run()
	# enemy_controller.gd perioder code 1002 — the castle intro topic.
	NativeGame.trigger_help(27, 27)
	NativeGame.ensure_weapons()
	NativeGame.castle_key_found = false

	if NativeGame.muzyka == 1:
		var music := NativeAssets.music(music_track)
		if music != null:
			var player := AudioStreamPlayer.new()
			player.stream = music
			player.volume_db = linear_to_db(maxf(0.01, NativeGame.glosnosc_dzwieku))
			add_child(player)
			player.play()

	_show_level_intro()


func _unhandled_input(event: InputEvent) -> void:
	# Fire button dismisses the tutorial popup.
	if event is InputEventKey and event.pressed and not event.echo \
			and NativeGame.help_topic != 0 \
			and event.keycode in [KEY_SPACE, KEY_CTRL, KEY_Z, KEY_X, KEY_C]:
		NativeGame.help_topic = 0
		_help_topic_shown = -1
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_P:
				_set_paused(not NativeGame.paused)
			KEY_Q:
				if NativeGame.paused:
					NativeGame.paused = false
					NativeGame.save()
					get_tree().change_scene_to_file(
						"res://native/levels/star_map.tscn")


func _set_paused(on: bool) -> void:
	NativeGame.paused = on
	if _pause_label == null:
		_pause_label = Label.new()
		_pause_label.text = "PAUSED — ESC resume · Q quit to map"
		_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pause_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_pause_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pause_label.add_theme_font_size_override("font_size", 56)
		_pause_label.add_theme_color_override("font_color", Color.WHITE)
		var layer := CanvasLayer.new()
		layer.layer = 30
		layer.add_child(_pause_label)
		add_child(layer)
	_pause_label.get_parent().visible = on


func _process(delta: float) -> void:
	# Screenshake on hull hits — same feedback as the arena.
	if NativeGame.energy < _last_energy - 0.01:
		_shake = 0.25
	_last_energy = NativeGame.energy
	if _shake > 0.0:
		_shake -= delta
		position = Vector2(randf_range(-4, 4), randf_range(-4, 4)) * (_shake / 0.25)
	else:
		position = Vector2.ZERO

	# G.help tutorial popup — same overlay as the arena.
	if NativeGame.help_topic != _help_topic_shown:
		_help_topic_shown = NativeGame.help_topic
		_refresh_help_label()

	# Death flow.
	if NativeGame.energy <= 0.0 and not _death_pending and not _level_cleared:
		_death_pending = true
		_on_player_died()

	# Key found = stage clear (o_key sets g_end_level in the original).
	if not _level_cleared and NativeGame.castle_key_found:
		_level_cleared = true
		_on_level_cleared()

	if _respawn_timer >= 0.0:
		_respawn_timer -= delta
		if _respawn_timer < 0.0:
			_respawn()

	if _clear_timer >= 0.0:
		_clear_timer -= delta
		if _clear_timer < 0.0:
			_next_level()


func _on_player_died() -> void:
	for i in 4:
		var boom := NativeExplosion.new()
		boom.global_position = _ship.global_position + Vector2(
			randf_range(-30, 30), randf_range(-30, 30))
		add_child(boom)
	var wreck := NativeDeathWreck.new()
	wreck.global_position = _ship.global_position
	add_child(wreck)
	_ship.visible = false
	NativeGame.lives -= 1
	if NativeGame.lives < 0:
		print("GAME OVER — score=%d coins=%d" % [NativeGame.score, NativeGame.coins])
		NativeGame.lives = 3
		NativeGame.save()
		get_tree().change_scene_to_file("res://native/ui/game_over.tscn")
		return
	_respawn_timer = RESPAWN_DELAY


func _respawn() -> void:
	NativeGame.energy = 100.0
	NativeGame.overheating = 0.0
	_death_pending = false
	# script_odnawianie_kumpli — buddies revive with the player.
	for buddy in get_tree().get_nodes_in_group("buddies"):
		if is_instance_valid(buddy):
			buddy.revive()
	_ship.visible = true
	_ship.global_position = PLAYER_SPAWN
	_ship.vel = Vector2.ZERO
	_ship.invulnerable = true
	await get_tree().create_timer(2.0).timeout
	_ship.invulnerable = false


func _on_level_cleared() -> void:
	NativeGame.add_score(500)
	print("CASTLE CLEAR — score=%d coins=%d" % [NativeGame.score, NativeGame.coins])
	NativeAssets.play_sound(105)
	_show_banner("KEY FOUND!\nLEVEL CLEAR!")
	_clear_timer = LEVEL_CLEAR_DELAY


func _next_level() -> void:
	NativeGame.complete_node(NativeGame.active_node)
	if NativeGame.campaign_complete():
		NativeGame.save()
		get_tree().change_scene_to_file("res://native/ui/ending.tscn")
		return
	if NativeGame.cleared_map_exit():
		NativeGame.map_transition = int(NativeGame.active_node.get_slice(":", 0)) + 1
	NativeGame.save()
	get_tree().change_scene_to_file("res://native/levels/star_map.tscn")


func _show_level_intro() -> void:
	var world := NativeLevelTable.world_of(NativeGame.active_level) + 1
	var level := NativeLevelTable.level_of(NativeGame.active_level) + 1
	var label := Label.new()
	label.text = "WORLD %d — LEVEL %d\n\n! CASTLE — FIND THE KEY !" % [world, level]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_top = -60
	label.offset_bottom = 60
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 8)
	var layer := CanvasLayer.new()
	layer.layer = 25
	layer.add_child(label)
	add_child(layer)
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)


func _show_banner(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 8)
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.add_child(label)
	add_child(layer)


## G.help popup — identical overlay to the arena's.
func _refresh_help_label() -> void:
	if _help_label == null:
		_help_label = Label.new()
		_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_help_label.add_theme_font_size_override("font_size", 20)
		_help_label.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
		_help_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_help_label.add_theme_constant_override("outline_size", 6)
		_help_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_help_label.offset_left = -460
		_help_label.offset_right = 460
		_help_label.offset_top = -190
		_help_label.offset_bottom = -60
		var layer := CanvasLayer.new()
		layer.layer = 26
		layer.add_child(_help_label)
		add_child(layer)
	var txt := NativeHelpTable.text(NativeGame.help_topic)
	_help_label.text = txt + "\n\n[SPACE]" if NativeGame.help_topic != 0 else ""
	_help_label.visible = NativeGame.help_topic != 0
