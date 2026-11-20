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
var _last_energy := 100.0
var _shake := 0.0                   # screenshake timer after hull hits
var _stars: Sprite2D = null         # parallax starfield layer


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

	# Parallax starfield — a generated dot texture drifting behind the
	# level art so the arena feels like it's moving through space.
	_stars = Sprite2D.new()
	_stars.texture = _make_starfield_texture()
	_stars.centered = false
	_stars.z_index = -99
	add_child(_stars)

	# Run state resets each time a level scene starts.
	NativeGame.reset_run()
	NativeGame.ensure_weapons()

	# Level music — loops for the duration of the scene.
	if NativeGame.muzyka == 1:
		var music := NativeAssets.music(music_track)
		if music != null:
			var player := AudioStreamPlayer.new()
			player.stream = music
			player.volume_db = linear_to_db(maxf(0.01, NativeGame.glosnosc_dzwieku))
			add_child(player)
			player.play()

	# First level gets a controls hint so new players learn the scheme.
	if NativeGame.active_level == 0:
		var hint := Label.new()
		hint.text = "ARROWS — MOVE      SPACE — FIRE      ESC — PAUSE"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 18)
		hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		hint.add_theme_constant_override("outline_size", 5)
		hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		hint.offset_top = -140
		hint.offset_bottom = -110
		var hlayer := CanvasLayer.new()
		hlayer.layer = 24
		hlayer.add_child(hint)
		add_child(hlayer)
		var htw := create_tween()
		htw.tween_interval(6.0)
		htw.tween_property(hint, "modulate:a", 0.0, 1.0)
		htw.tween_callback(hlayer.queue_free)

	_show_level_intro()


func _unhandled_input(event: InputEvent) -> void:
	# ESC / P toggles pause — every entity checks NativeGame.paused.
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_P:
				_set_paused(not NativeGame.paused)
			KEY_Q:
				# Quit to map mid-level — progress this level is lost but
				# coins/score/upgrades already earned stay in the profile.
				if NativeGame.paused:
					NativeGame.paused = false
					NativeGame.save()
					_go_to_map()


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
	# Parallax drift — stars slide left and wrap; frozen while paused.
	if _stars != null and not NativeGame.paused:
		_stars.position.x -= delta * 12.0
		if _stars.position.x <= -1024.0:
			_stars.position.x += 1024.0

	# Screenshake — a sharp jolt whenever hull energy drops.
	if NativeGame.energy < _last_energy - 0.01:
		_shake = 0.25
	_last_energy = NativeGame.energy
	if _shake > 0.0:
		_shake -= delta
		position = Vector2(randf_range(-4, 4), randf_range(-4, 4)) * (_shake / 0.25)
	else:
		position = Vector2.ZERO

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
	# explosion anim plus the tumbling s_die wreck (o_death: the hull
	# spins and falls off the bottom of the screen).
	for i in 4:
		var boom := NativeExplosion.new()
		boom.global_position = _ship.global_position + Vector2(
			randf_range(-30, 30), randf_range(-30, 30))
		add_child(boom)
	_spawn_death_tumble()
	_ship.visible = false
	NativeGame.lives -= 1
	if NativeGame.lives < 0:
		# Out of lives — game over. Spare lives refill for the next run;
		# score/coins/upgrades persist.
		print("GAME OVER — score=%d coins=%d" % [NativeGame.score, NativeGame.coins])
		NativeGame.lives = 3
		NativeGame.save()
		get_tree().change_scene_to_file("res://native/ui/game_over.tscn")
		return
	_respawn_timer = RESPAWN_DELAY


## The o_death wreck — the hull tumbles off the bottom of the screen.
func _spawn_death_tumble() -> void:
	var wreck := NativeDeathWreck.new()
	wreck.global_position = _ship.global_position
	add_child(wreck)


func _respawn() -> void:
	NativeGame.energy = 100.0
	NativeGame.overheating = 0.0
	_death_pending = false
	# script_odnawianie_kumpli — buddies revive with bonus hull when
	# the player comes back.
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
	# Flawless bonus — no enemy escaped the arena this level.
	var flawless := NativeGame.enemies_missed == 0
	if flawless:
		NativeGame.add_score(500)
	print("LEVEL CLEAR — score=%d coins=%d%s" % [
		NativeGame.score, NativeGame.coins, " FLAWLESS+500" if flawless else ""])
	# Victory sting — rising chime (the original's upgrade/fanfare sfx).
	NativeAssets.play_sound(105)   # snd_upgrade_up
	_show_banner("LEVEL CLEAR!" + ("\nFLAWLESS +500" if flawless else ""))
	_clear_timer = LEVEL_CLEAR_DELAY


## Level cleared — mark the map node complete and return to the
## star map (the original's level → map_complev → map room flow).
## Clearing a map's exit node queues the inter-map transition; the
## final castle routes to the campaign ending.
func _next_level() -> void:
	NativeGame.complete_node(NativeGame.active_node)
	if NativeGame.campaign_complete():
		NativeGame.save()
		# room_animation_4 plays before the ending rooms.
		var cs = load("res://native/ui/cutscene.gd").new()
		cs.setup("finale")
		cs.next_scene = "res://native/ui/ending.tscn"
		get_tree().root.add_child(cs)
		return
	if NativeGame.cleared_map_exit():
		NativeGame.map_transition = int(NativeGame.active_node.get_slice(":", 0)) + 1
	NativeGame.save()
	get_tree().change_scene_to_file("res://native/levels/star_map.tscn")


func _go_to_map() -> void:
	get_tree().change_scene_to_file("res://native/levels/star_map.tscn")


## Boss levels — drop the boss in once the field is clear.
func _spawn_boss() -> void:
	_boss_spawned = true
	print("BOSS incoming — tier %d" % _boss_cfg.get("tier", 0))
	# Boss entrance sting — bowser growl family from the original sfx.
	NativeAssets.play_sound(90 + randi() % 3)
	var boss := NativeBoss.new()
	boss.tier = _boss_cfg.get("tier", 0)
	boss.variant = str(_boss_cfg.get("variant", ""))
	add_child(boss)


## Level intro card — world/level name for a few seconds, plus a boss
## warning on boss levels. Purely cosmetic; gameplay starts immediately.
func _show_level_intro() -> void:
	var world := NativeLevelTable.world_of(NativeGame.active_level) + 1
	var level := NativeLevelTable.level_of(NativeGame.active_level) + 1
	var text := "WORLD %d — LEVEL %d" % [world, level]
	if not _boss_cfg.is_empty():
		text += "\n\n! BOSS APPROACHES !"
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_top = -60
	label.offset_bottom = 60
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 8)
	var layer := CanvasLayer.new()
	layer.layer = 25
	layer.add_child(label)
	add_child(layer)
	# Fade out after a beat.
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)


## 2048x768 starfield — the right half duplicates the left so the
## parallax wrap at -1024 is seamless (same stars re-enter).
static func _make_starfield_texture() -> Texture2D:
	var img := Image.create(2048, 768, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 160:
		var x := randi() % 1024
		var y := randi() % 768
		var c := Color(1, 1, 1, 0.2 + randf() * 0.55)
		img.set_pixel(x, y, c)
		img.set_pixel(x + 1024, y, c)   # mirrored tile for seamless wrap
	return ImageTexture.create_from_image(img)


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
