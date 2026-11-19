extends Node2D
## NativeArena — a playable native level scene.
##
## One screen = one arena (the original Galaxy rooms are 1024x768 with
## views disabled, so there is no scrolling camera). This script builds
## the backdrop, spawns the ship, wave spawner and HUD, and handles the
## death/game-over flow.
##
## To make a new level: duplicate arena.tscn, change BACKGROUND_ID and the
## `waves` array on the NativeWaveSpawner child. That's the native
## equivalent of editing Waves/Enemies in the old level scenes.

const WORLD_SIZE := Vector2(1024, 768)
const BACKGROUND_ID := 0            # background0 — asteroid field backdrop
const PLAYER_SPAWN := Vector2(435, 425)
const RESPAWN_DELAY := 2.0

@onready var _ship: NativeShip = $Ship
@onready var _spawner: NativeWaveSpawner = $WaveSpawner
@onready var _hud: NativeHUD = $HUD

var _respawn_timer := -1.0          # <0 means "ship alive / not pending"
var _death_pending := false


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
	# Level-complete check: all waves spawned and cleared → level clear.
	# (For now we just log; the map/progression layer comes later.)
	if _spawner.is_finished() and get_tree().get_nodes_in_group("enemies").is_empty():
		pass

	# Death flow — NativeGame.energy hits 0 when the ship is destroyed.
	# _death_pending guards against retriggering during the respawn delay.
	if NativeGame.energy <= 0.0 and not _death_pending:
		_death_pending = true
		_on_player_died()

	# Respawn flow after death.
	if _respawn_timer >= 0.0:
		_respawn_timer -= delta
		if _respawn_timer < 0.0:
			_respawn()


func _on_player_died() -> void:
	NativeGame.lives -= 1
	if NativeGame.lives < 0:
		# TODO(native): game-over screen / return to map.
		print("GAME OVER — score=%d" % NativeGame.score)
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
