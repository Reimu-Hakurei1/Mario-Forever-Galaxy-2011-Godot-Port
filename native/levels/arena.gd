extends Node2D
## NativeArena — a playable native level scene.
##
## One screen = one arena (the original Galaxy rooms are 1024x768 with
## views disabled, so there is no scrolling camera). This script builds
## the backdrop, spawns the ship, wave spawner and HUD, and handles the
## death/game-over and level-clear flows.
##
## To make a new level: duplicate arena.tscn, change BACKGROUND_ID and the
## `waves` array on the NativeWaveSpawner child. That's the native
## equivalent of editing Waves/Enemies in the old level scenes.

const WORLD_SIZE := Vector2(1024, 768)
const BACKGROUND_ID := 0            # background0 — asteroid field backdrop
const MUSIC_TRACK := "mixed_battle" # data/m/mixed_battle.ogg — level theme
const PLAYER_SPAWN := Vector2(435, 425)
const RESPAWN_DELAY := 2.0
const LEVEL_CLEAR_DELAY := 3.0

@onready var _ship: NativeShip = $Ship
@onready var _spawner: NativeWaveSpawner = $WaveSpawner
@onready var _hud: NativeHUD = $HUD

# Level config handed over by the star map (background/music/waves).
# Falls back to the scene defaults when empty (direct F6 testing).
var _level_cfg: Dictionary = {}

# Boss state — boss levels spawn NativeBoss once the regular waves are
# cleared; the level only completes when the boss (and its minions) die.
var _boss_cfg: Dictionary = {}
var _boss_spawned := false

var _respawn_timer := -1.0          # <0 means "ship alive / not pending"
var _death_pending := false
var _level_cleared := false
var _clear_timer := -1.0
var _pause_label: Label = null


func _ready() -> void:
	# The project already renders at 1024x768 (project.godot display
	# settings) and Galaxy arenas are single-screen — no camera work needed.
	Engine.max_fps = 60

	# Apply the level config the star map staged (if any).
	_level_cfg = NativeGame.pending_level
	NativeGame.pending_level = {}
	var bg_id: int = _level_cfg.get("background", BACKGROUND_ID)
	var music_track: String = _level_cfg.get("music", MUSIC_TRACK)
	if not _level_cfg.get("waves", []).is_empty():
		_spawner.set_waves(_level_cfg["waves"])
	_boss_cfg = _level_cfg.get("boss", {})

	# Backdrop: original levels tile background sprites; our slice uses a
	# single full-screen texture stretched to the room.
	var bg := Sprite2D.new()
	var tex := NativeAssets.background(bg_id)
	if tex != null:
		bg.texture = tex
		bg.centered = false
		bg.scale = Vector2(WORLD_SIZE.x / tex.get_width(), WORLD_SIZE.y / tex.get_height())
	bg.z_index = -100
	add_child(bg)

	# Run state resets each time a level scene starts.
	NativeGame.reset_run()

	# Level music — loops for the duration of the scene.
	if NativeGame.muzyka == 1:
		var music := NativeAssets.music(music_track)
		if music != null:
			var player := AudioStreamPlayer.new()
			player.stream = music
			player.volume_db = linear_to_db(maxf(0.01, NativeGame.glosnosc_dzwieku))
			add_child(player)
			player.play()


func _unhandled_input(event: InputEvent) -> void:
	# ESC / P toggles pause — every entity checks NativeGame.paused.
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ESCAPE or event.keycode == KEY_P):
		_set_paused(not NativeGame.paused)


func _set_paused(on: bool) -> void:
	NativeGame.paused = on
	if _pause_label == null:
		_pause_label = Label.new()
		_pause_label.text = "PAUSED"
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
	# Death flow — NativeGame.energy hits 0 when the ship is destroyed.
	# _death_pending guards against retriggering during the respawn delay.
	if NativeGame.energy <= 0.0 and not _death_pending and not _level_cleared:
		_death_pending = true
		_on_player_died()

	# Level-clear check: every wave launched AND the field is clean.
	# On boss levels, a clean field first summons the boss — the level
	# only clears once the boss itself is dead (it joins the "enemies"
	# group, so this check naturally waits for it and its minions).
	if not _level_cleared and _spawner.is_finished() \
			and get_tree().get_nodes_in_group("enemies").is_empty():
		if not _boss_cfg.is_empty() and not _boss_spawned:
			_spawn_boss()
		elif _boss_cfg.is_empty() or _boss_spawned:
			_level_cleared = true
			_on_level_cleared()

	# Respawn flow after death.
	if _respawn_timer >= 0.0:
		_respawn_timer -= delta
		if _respawn_timer < 0.0:
			_respawn()

	# Advance to the next arena once the clear banner has had its moment.
	if _clear_timer >= 0.0:
		_clear_timer -= delta
		if _clear_timer < 0.0:
			_next_level()


func _on_player_died() -> void:
	# Hull explosion at the death point — the original plays the big
	# explosion anim plus a ship breakup.
	for i in 4:
		var boom := NativeExplosion.new()
		boom.global_position = _ship.global_position + Vector2(
			randf_range(-30, 30), randf_range(-30, 30))
		add_child(boom)
	_ship.visible = false
	NativeGame.lives -= 1
	if NativeGame.lives < 0:
		# Out of lives — game over. Spare lives refill for the next run;
		# score/coins/upgrades persist.
		print("GAME OVER — score=%d coins=%d" % [NativeGame.score, NativeGame.coins])
		NativeGame.lives = 3
		NativeGame.save()
		_go_to_map()
		return
	_respawn_timer = RESPAWN_DELAY


func _respawn() -> void:
	NativeGame.energy = 100.0
	NativeGame.overheating = 0.0
	_death_pending = false
	_ship.visible = true
	_ship.global_position = PLAYER_SPAWN
	_ship.vel = Vector2.ZERO
	_ship.invulnerable = true
	await get_tree().create_timer(2.0).timeout
	_ship.invulnerable = false


func _on_level_cleared() -> void:
	print("LEVEL CLEAR — score=%d coins=%d" % [NativeGame.score, NativeGame.coins])
	_show_banner("LEVEL CLEAR!")
	_clear_timer = LEVEL_CLEAR_DELAY


## Level cleared — unlock the next node and return to the star map,
## matching the original's flow (level → map → next level).
func _next_level() -> void:
	# Unlock the node after the one just cleared, then visit the shop —
	# the original flow is level → results → shop → map.
	NativeGame.level_index = maxi(NativeGame.level_index, NativeGame.active_level + 1)
	NativeGame.save()
	get_tree().change_scene_to_file("res://native/ui/shop.tscn")


func _go_to_map() -> void:
	get_tree().change_scene_to_file("res://native/levels/star_map.tscn")


## Boss levels — drop the boss in once the field is clear.
func _spawn_boss() -> void:
	_boss_spawned = true
	print("BOSS incoming — tier %d" % _boss_cfg.get("tier", 0))
	var boss := NativeBoss.new()
	boss.tier = _boss_cfg.get("tier", 0)
	add_child(boss)


func _show_banner(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 64)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 8)
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.add_child(label)
	add_child(layer)
