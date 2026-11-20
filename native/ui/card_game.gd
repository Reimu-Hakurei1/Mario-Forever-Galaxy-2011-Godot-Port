extends Control
## NativeCardGame — the original's card_game_1/2 shell-game minigame.
##
## Ports objects/ui/card_game*.gd + card.gd: four face-down cards in a
## row (sprite 335), pairs swap places in accelerating rounds
## (g_losowania = 17, interval shrinks via przyspieszacz_losowania),
## then the player clicks a card to flip it. Picking the target card
## face pays the prize (g_dodaj_kase = 10000/100000 coins). ESC/Q quits back
## to the star map.

const CARD_SPRITE := 335
const CARD_SPACING := 200.0
const ROUNDS := 17
var prize_coins := 10000   # card_game_1=10k, card_game_2=100k (o_card_2 g_dodaj_kase)

var _cards: Array[TextureRect] = []
var _faces: Array[int] = []        # card face index per slot (0/1)
var _target_face := 0              # the face the player must find
var _swapping := false
var _done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# map_minigame 3 routes to card_game_2 — o_card_2 pays 100,000.
	if int(NativeGame.pending_level.get("minigame", 1)) == 3:
		prize_coins = 100000
	# Dark felt backdrop + vignette like the original's blanker.
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "CARD GAME"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position.y = 90
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Four cards — faces dealt like the original (slot0 face A, rest B).
	_target_face = randi() % 2
	var deal := [0, 1, 1, 1]
	deal.shuffle()
	# Guarantee at least one of each face.
	if deal[0] == deal[1] and deal[0] == deal[2] and deal[0] == deal[3]:
		deal[0] = 1 - deal[0]
	for i in 4:
		var card := TextureRect.new()
		card.texture = _card_tex(0)      # face-down frame (card.gd g_image_index=0)
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.custom_minimum_size = Vector2(140, 190)
		card.size = Vector2(140, 190)
		card.pivot_offset = card.size / 2.0
		card.position = Vector2(512, 400) + Vector2(
			(i - 1.5) * CARD_SPACING, 0) - card.size / 2.0
		card.gui_input.connect(_on_card_input.bind(i))
		add_child(card)
		_cards.append(card)
		_faces.append(deal[i])
	_swaps()


func _card_tex(frame: int) -> Texture2D:
	var frames := NativeAssets.sprite_frames(CARD_SPRITE)
	if frames.is_empty():
		return null
	return frames[mini(frame, frames.size() - 1)]


## The swap rounds — pairs of cards trade places, speeding up each round
## like g_przyspieszacz_losowania (interval 80 - accel, accel += 10).
func _swaps() -> void:
	if _done:
		return
	var interval := 80.0
	var accel := 0.0
	for round_i in ROUNDS:
		await get_tree().create_timer(
			maxf(0.25, interval / 60.0)).timeout
		if _done:
			return
		var a := randi() % 4
		var b := randi() % 4
		while b == a:
			b = randi() % 4
		var pa: Vector2 = _cards[a].position
		var pb: Vector2 = _cards[b].position
		var tw := create_tween().set_parallel()
		tw.tween_property(_cards[a], "position", pb, 0.28)
		tw.tween_property(_cards[b], "position", pa, 0.28)
		# Slots track the physical cards — swap face records too.
		var tf := _faces[a]
		_faces[a] = _faces[b]
		_faces[b] = tf
		await tw.finished
		interval -= 10.0
		accel += 10.0
	_prompt()


func _prompt() -> void:
	var hint := get_node_or_null("Hint") as Label
	if hint == null:
		hint = Label.new()
		hint.name = "Hint"
		hint.text = "CLICK A CARD — FIND THE %s!" % ["STAR", "MOON"][_target_face]
		hint.add_theme_font_size_override("font_size", 26)
		hint.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
		hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		hint.position.y = -140
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(hint)


func _on_card_input(event: InputEvent, index: int) -> void:
	if _done or _swapping:
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	_done = true
	_swapping = true
	# Flip the picked card — jaka_karta+1, with face 0 showing frame 3.
	var face := _faces[index]
	_cards[index].texture = _card_tex(3 if face == 0 else 2)
	# Flip the others face-up too so the result is readable.
	for i in 4:
		if i != index:
			_cards[i].texture = _card_tex(3 if _faces[i] == 0 else 2)
	var won := face == _target_face
	var msg := Label.new()
	msg.text = "+%d COINS!" % prize_coins if won else "NOT THIS ONE..."
	msg.add_theme_font_size_override("font_size", 34)
	msg.add_theme_color_override("font_color",
		Color(0.4, 1, 0.5) if won else Color(1, 0.5, 0.4))
	msg.set_anchors_preset(Control.PRESET_CENTER)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(msg)
	if won:
		NativeGame.coins += prize_coins
		NativeGame.add_score(5000)
	await get_tree().create_timer(1.6).timeout
	get_tree().change_scene_to_file("res://native/levels/star_map.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://native/levels/star_map.tscn")
