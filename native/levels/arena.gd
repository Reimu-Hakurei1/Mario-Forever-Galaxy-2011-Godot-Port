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
const PLAYER_SPAWN := Vector2(435, 425)
const RESPAWN_DELAY := 2.0
const LEVEL_CLEAR_DELAY := 3.0

@onready var _ship: NativeShip = $Ship
@onready var _spawner: NativeWaveSpawner = $WaveSpawner
@onready var _hud: NativeHUD = $HUD

var _respawn_timer := -1.0          # <0 means "ship alive / not pending"
var _death_pending := false
var _level_cleared := false
var _clear_timer := -1.0


func _ready() -> void:
	# The project already renders at 1024x768 (project.godot display
	# settings) and Galaxy arenas are single-screen — no camera work needed.
	Engine.max_fps = 60

	# Backdrop: original levels tile background sprites; our first slice
	# uses a single full-screen texture stretched to the room.
	var bg := Sprite2D.new()
	var tex := NativeAssets.background(BACKGROUND_ID)
	if tex != null:
		bg.texture = tex
		bg.centered = false
		bg.scale = Vector2(WORLD_SIZE.x / tex.get_width(), WORLD_SIZE.y / tex.get_height())
	bg.z_index = -100
	add_child(bg)

	# Run state resets each time a level scene starts.
	NativeGame.reset_run()


func _process(delta: float) -> void:
	# Death flow — NativeGame.energy hits 0 when the ship is destroyed.
	# _death_pending guards against retriggering during the respawn delay.
	if NativeGame.energy <= 0.0 and not _death_pending and not _level_cleared:
		_death_pending = true
		_on_player_died()

	# Level-clear check: every wave launched AND the field is clean.
	if not _level_cleared and _spawner.is_finished() \
			and get_tree().get_nodes_in_group("enemies").is_empty():
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
	NativeGame.lives -= 1
	if NativeGame.lives < 0:
		# TODO(native): proper game-over screen / return to star map.
		print("GAME OVER — score=%d coins=%d" % [NativeGame.score, NativeGame.coins])
		get_tree().quit()
		return
	_respawn_timer = RESPAWN_DELAY


func _respawn() -> void:
	NativeGame.energy = 100.0
	NativeGame.overheating = 0.0
	_death_pending = false
	_ship.global_position = PLAYER_SPAWN
	_ship.invulnerable = true
	await get_tree().create_timer(2.0).timeout
	_ship.invulnerable = false


func _on_level_cleared() -> void:
	print("LEVEL CLEAR — score=%d coins=%d" % [NativeGame.score, NativeGame.coins])
	_show_banner("LEVEL CLEAR!")
	_clear_timer = LEVEL_CLEAR_DELAY


## Temporary stand-in for the star-map transition: advance the level
## counter and reload the arena with a fresh run. The real flow will route
## through the map screen once it's ported.
func _next_level() -> void:
	NativeGame.level_index += 1
	NativeGame.reset_run()
	get_tree().reload_current_scene()


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
