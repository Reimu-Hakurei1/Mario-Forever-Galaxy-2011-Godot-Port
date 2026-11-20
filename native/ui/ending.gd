extends Control
## NativeEnding — shown after the final boss (level 80) falls.
##
## Ports the original's ending room (objects/ui/ending*.gd): the
## princess-rescue dialogue plays as a typewriter scene, then the
## story epilogue fades in, then campaign stats and free play.

const MAP_SCENE := "res://native/levels/star_map.tscn"

## The princess-rescue scene — objects/ui/ending.gd dialogue, with
## "NAME|" speaker tags for the four heroes and the princess.
const SCENE_LINES := [
	"TOAD|HURRAY! YOU HAVE#MANAGED TO#SAVE THE#PRINCESS!",
	"MARIO|PRINCESS...#ARE YOU ALRIGHT?!",
	"PRINCESS|YES, #THANK YOU#FOR SAVING#ME AGAIN.#I AM REALLY#GRATEFUL.",
	"LUIGY|NO PROBLEM...#THAT BASTARD,#TRIED TO#DESTROY#MY KINGDOM.#I REALLY HAVE#NO IDEA HOW#TO THANK YOU.",
	"LUIGY|GIVE ME A KISS#PRINCESS AND#WE ARE FINE#SAVING YOU#IS A PLEASURE#TO ME.",
	"TOAD|IN#MARIO FOREVER 1#WE MADE A LOT#OF KIDS#SO WE OUGHTA#RISE THEM UP.#AND BESIDES#WHAT DO YOU THINK#ABOUT MAKING#AROUND 100#CHILDREN MORE?",
	"PRINCESS|SOUNDS GOOD#FOR ME.#OK THEN TIME TO#GO BACK TO#KINGDOM.",
	"MARIO|TIME TO PARTY!",
	"LUIGY|YES!#LET'S MEET#IN THE KINGDOM.",
	"TOAD|SEE YOU THEN#AND GOOD LUCK#ON YOUR#WAY BACK!",
]

## The epilogue — objects/ui/ending_3.gd closing crawl.
const EPILOGUE := """AND THAT IS HOW OUR STORY ENDS.
MARIO AND HIS FRIENDS ARE FLYING BACK TO THE CASTLE
TO CELEBRATE THEIR GREAT VICTORY!
ONCE AGAIN IT WAS PROOVED THAT EVIL CAN NOT SUCCEED.
THANKS TO YOU!

WELL... PRINCESS AND HER SAVIORS PARTED SO MUCH
THAT EVERYONE IN THE TOADSTOOL KINGDOM COULD HEAR THEM,
AND EVERYONE HAD GREAT TIME!

BUT THERE IS JUST ONE QUESTION LEFT...
WHERE IS THE BOWSER...?"""

## The stinger — objects/ui/ending_bowser.gd: after "WHERE IS THE
## BOWSER...?" the original cuts to Bowser's awakening laugh.
const BOWSER_LINES := [
	"BOWSER|HAHAHAHA!!!#WELL WELL WELL#I HAVE#FINALLY#AWAKENED.",
	"BOWSER|TIME TO RUN#INTO SOME#PARTY.#PREPARE TO#TAKE OFF#MY ARMY!",
	"BOWSER|HAHAHA!#I HOPE THEY#WILL BE#GLAD TO#SEE ME!",
]

var _phase := 0   # 0 = dialogue, 1 = epilogue, 2 = bowser, 3 = stats
var _talk: NativeBossDialogue
var _epilogue: Label
var _stats: Label
var _btn: Button
var _ship: TextureRect
var _toad: TextureRect
var _ship_frame := 0
var _toad_frame := 0
var _anim_t := 0.0


func _ready() -> void:
	NativeAssets.play_music("finishing")
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.06, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_add_starfield()
	_build_characters()
	_build_epilogue()
	_build_stats()
	_play_scene()


## The original ending room shows the hero ship and Toad on stage
## (objects/ui/ending_player.gd sprite 543, ending_toad.gd sprite 511)
## while the princess dialogue plays.
func _build_characters() -> void:
	_ship = _make_sprite(543)
	_ship.position = Vector2(300, 480)
	_ship.custom_minimum_size = Vector2(96, 96)
	add_child(_ship)
	_toad = _make_sprite(511)
	_toad.position = Vector2(640, 430)
	_toad.custom_minimum_size = Vector2(96, 96)
	add_child(_toad)


func _make_sprite(sid: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex := NativeAssets.sprite_frame(sid, 0)
	if tex != null:
		tr.texture = tex
	return tr


func _process(delta: float) -> void:
	if _phase != 0:
		return
	_anim_t += delta
	# Ship engine animation — cycle the s_player_a frames.
	if _anim_t > 0.12:
		_anim_t = 0.0
		_ship_frame = (_ship_frame + 1) % 8
		var tex := NativeAssets.sprite_frame(543, _ship_frame)
		if tex != null:
			_ship.texture = tex
		_toad_frame = (_toad_frame + 1) % 3
		var ttex := NativeAssets.sprite_frame(511, _toad_frame)
		if ttex != null:
			_toad.texture = ttex
	# Gentle hover like the original's floating sprites.
	_ship.position.y = 480.0 + sin(Time.get_ticks_msec() / 900.0) * 8.0
	_toad.position.y = 430.0 + sin(Time.get_ticks_msec() / 700.0 + 1.5) * 6.0


## Phase 1 — the rescue dialogue, auto-advancing typewriter.
func _play_scene() -> void:
	_talk = NativeBossDialogue.new()
	add_child(_talk)
	_talk.finished.connect(_on_scene_done)
	_talk.play(SCENE_LINES)


func _on_scene_done() -> void:
	if is_instance_valid(_talk):
		_talk.queue_free()
	_phase = 1
	# The characters leave stage for the epilogue crawl.
	if is_instance_valid(_ship):
		_ship.queue_free()
	if is_instance_valid(_toad):
		_toad.queue_free()
	_epilogue.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_epilogue, "modulate:a", 1.0, 2.0)
	# Hold the epilogue, then the Bowser stinger, then the stats panel.
	get_tree().create_timer(6.0).timeout.connect(_play_bowser)


func _play_bowser() -> void:
	_phase = 2
	_epilogue.visible = false
	_talk = NativeBossDialogue.new()
	add_child(_talk)
	_talk.finished.connect(_show_stats)
	_talk.play(BOWSER_LINES)


func _show_stats() -> void:
	_phase = 3
	_stats.visible = true
	_btn.visible = true
	var tw := create_tween()
	tw.tween_property(_stats, "modulate:a", 1.0, 1.0)
	tw.parallel().tween_property(_btn, "modulate:a", 1.0, 1.0)


func _build_epilogue() -> void:
	_epilogue = Label.new()
	_epilogue.text = EPILOGUE
	_epilogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_epilogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_epilogue.add_theme_font_size_override("font_size", 22)
	_epilogue.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_epilogue.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_epilogue.add_theme_constant_override("outline_size", 6)
	_epilogue.set_anchors_preset(Control.PRESET_CENTER)
	_epilogue.offset_left = -420
	_epilogue.offset_right = 420
	_epilogue.offset_top = -160
	_epilogue.offset_bottom = 160
	_epilogue.modulate.a = 0.0
	add_child(_epilogue)


func _build_stats() -> void:
	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_theme_font_size_override("font_size", 24)
	_stats.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_stats.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_stats.add_theme_constant_override("outline_size", 6)
	_stats.set_anchors_preset(Control.PRESET_CENTER)
	_stats.offset_left = -300
	_stats.offset_right = 300
	_stats.offset_top = 190
	_stats.offset_bottom = 260
	_stats.text = """THE GALAXY IS SAVED!

FINAL SCORE %d
BEST %d
COINS %d

CREDITS: GAME CREATED BY WWW.SOFTENDO.COM IN 2008(C)
ONLY BEST FREEWARE GAMES! MARIO CHARACTERS ARE
COPYRIGHT OF NINTENDO(C).""" % [
		NativeGame.score, NativeGame.best_score, NativeGame.coins]
	_stats.modulate.a = 0.0
	_stats.visible = false
	add_child(_stats)

	_btn = Button.new()
	_btn.text = "KEEP EXPLORING"
	_btn.custom_minimum_size = Vector2(280, 60)
	_btn.add_theme_font_size_override("font_size", 22)
	_btn.position = Vector2(372, 560)
	_btn.modulate.a = 0.0
	_btn.visible = false
	_btn.pressed.connect(_on_map)
	add_child(_btn)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ENTER and _phase == 3:
		_on_map()


func _on_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)


## Drifting starfield, same generated-dot technique as title/intro.
func _add_starfield() -> void:
	var img := Image.create(1024, 768, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 180:
		img.set_pixel(randi() % 1024, randi() % 768,
			Color(1, 1, 1, 0.25 + randf() * 0.6))
	var tex := ImageTexture.create_from_image(img)
	var stars := TextureRect.new()
	stars.texture = tex
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.stretch_mode = TextureRect.STRETCH_TILE
	stars.modulate = Color(1, 1, 1, 0.7)
	add_child(stars)
	var tw := create_tween().set_loops()
	tw.tween_property(stars, "position:x", -1024.0, 70.0) \
		.from(0.0).set_trans(Tween.TRANS_LINEAR)
