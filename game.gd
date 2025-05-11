# game.gd — Full Multiplayer Game Script (Godot 4.x compatible)
extends Node

# === AUTOLOADED SINGLETON ===
var global := Global

# === CONSTANTS ===
const CARD_TYPES = ["king", "queen", "ace", "joker"]
const CARD_COUNTS = {"king": 6, "queen": 6, "ace": 6, "joker": 2}

# === NODE REFERENCES ===
@onready var turn_label = $Turn
@onready var round_label = $UI/Rounds
@onready var round_card_sprite = $Deck/RoundCard
@onready var output_label = $UI/Output
@onready var timer_label = $UI/TurnTimer/TimerLabel
@onready var turn_timer = $UI/TurnTimer
@onready var pass_button = $Pass
@onready var liar_button = $Liar
@onready var hand_container = $Hand
@onready var player_sprites = [$Player0, $Player1, $Player2, $Player3]
@onready var magazine_labels = [$Magazine0/Label, $Magazine1/Label, $Magazine2/Label, $Magazine3/Label]

# === GAME STATE ===
var player_seat = -1
var current_turn = -1
var turn_order: Array[int] = []
var alive = [false, false, false, false]
var bullet_chambers = [1, 1, 1, 1]
var round_target_card = ""

var player_hands = {}
var selected_cards: Array[TextureButton] = []
var table_history = []
var client_has_selection = {}
var client_selected_indices = {}
var turn_time_left = 60

func _ready():
	turn_label.text = ""
	pass_button.hide()
	liar_button.hide()
	turn_timer.timeout.connect(_on_TurnTimer_timeout)

	if multiplayer.is_server():
		player_seat = 0
		var peers = [multiplayer.get_unique_id()]
		peers.append_array(Array(multiplayer.get_peers()))
		for i in range(peers.size()):
			global.peer_to_seat[peers[i]] = i
			global.character_selections[peers[i]] = global.character_selections.get(peers[i], i % 4)
			alive[i] = true
			turn_order.append(i)
			rpc_id(peers[i], "assign_seat", i, global.character_selections[peers[i]])
			update_character_sprite(i, global.character_selections[peers[i]])
		start_new_round()
	else:
		player_seat = -1

@rpc("any_peer")
func assign_seat(seat: int, char_id: int):
	player_seat = seat
	alive[seat] = true
	update_character_sprite(seat, char_id)

func update_character_sprite(seat: int, char_id: int):
	player_sprites[seat].texture = load("res://characters/character%d.png" % char_id)

func start_new_round():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	round_target_card = ["king", "queen", "ace"].pick_random()
	rpc("broadcast_round", round_target_card)
	broadcast_round(round_target_card)
	deal_cards()

@rpc("any_peer")
func broadcast_round(card: String):
	round_target_card = card
	round_label.text = "Round: %s" % card.capitalize()
	round_card_sprite.texture = load("res://cards/%s.png" % card)
	table_history.clear()
	for m in magazine_labels:
		m.text = "1/6"
	bullet_chambers = [1, 1, 1, 1]

func deal_cards():
	var full_deck = []
	for type in CARD_TYPES:
		for i in range(CARD_COUNTS[type]):
			full_deck.append(type)
	full_deck.shuffle()
	
func _peer_for_seat(seat: int) -> int:
	for peer_id in global.peer_to_seat:
		if global.peer_to_seat[peer_id] == seat:
			return peer_id
	return 1  # fallback to host (useful during debug)
	
	player_hands.clear()
	for player_seat_id in turn_order:
		player_hands[seat] = []
		

	current_turn = turn_order[0]
	send_turn(current_turn)

@rpc("any_peer")
func receive_hand(seat: int, cards: Array):
	if seat != player_seat:
		return
	hand_container.clear()
	selected_cards.clear()
	for i in range(cards.size()):
		var card = cards[i]
		var tex = load("res://cards/%s.png" % card)
		var btn = TextureButton.new()
		btn.texture_normal = tex
		btn.pressed.connect(func(): _toggle_card(btn))
		hand_container.add_child(btn)
		selected_cards.append(btn)

func _toggle_card(btn):
	btn.modulate = btn.modulate == Color(1, 1, 1) if Color(1, 0.5, 0) else Color(1, 1, 1)

func send_turn(seat):
	current_turn = seat
	rpc("set_turn", seat, bullet_chambers[seat])
	set_turn(seat, bullet_chambers[seat])

@rpc("any_peer")
func set_turn(seat: int, bullet: int):
	current_turn = seat
	magazine_labels[seat].text = "%d/6" % bullet
	turn_label.text = "Your Turn" if seat == player_seat else ""
	var positions = [
	Vector2(-618, -201),
	Vector2(-294, -201),
	Vector2(25, -201),
	Vector2(345, -201)]
	turn_label.position = positions[seat]
	var show_ui = (seat == player_seat)
	pass_button.visible = show_ui
	liar_button.visible = show_ui
	turn_time_left = 60
	timer_label.text = "Time: %d" % turn_time_left
	turn_timer.start()

func _on_TurnTimer_timeout():
	turn_time_left -= 1
	timer_label.text = "Time: %d" % turn_time_left
	if turn_time_left <= 0:
		turn_timer.stop()
		if selected_cards.size() > 0:
			_on_Pass_pressed()
		else:
			_on_Liar_pressed()

func _on_Pass_pressed():
	if !multiplayer.is_server():
		rpc_id(1, "player_pass_request", _get_selected_card_indices())
	else:
		perform_pass(player_seat, _get_selected_card_indices())

func _on_Liar_pressed():
	if !multiplayer.is_server():
		rpc_id(1, "player_liar_request")
	else:
		perform_liar_call(player_seat)

@rpc("authority")
func player_pass_request(indices: Array):
	var pid = multiplayer.get_remote_sender_id()
	var seat = global.peer_to_seat[pid]
	perform_pass(seat, indices)

@rpc("authority")
func player_liar_request():
	var pid = multiplayer.get_remote_sender_id()
	var seat = global.peer_to_seat[pid]
	perform_liar_call(seat)

func perform_pass(seat: int, indices: Array):
	if indices.is_empty():
		return
	var passed = []
	for i in indices:
		if i < player_hands[seat].size():
			passed.append(player_hands[seat][i])
			player_hands[seat].remove_at(i)
	# store entry
	table_history.append({"seat": seat, "cards": passed})
	bullet_chambers[seat] += 1
	advance_turn()

func perform_liar_call(caller: int):
	if table_history.is_empty():
		return
	var last = table_history.back()
	var liar = false
	for c in last.cards:
		if c != round_target_card and c != "joker":
			liar = true
	if global.game_mode == "devil" and "joker" in last.cards:
		for i in range(4):
			if i != last.seat and alive[i]:
				if bullet_chambers[i] >= randi() % 6 + 1:
					eliminate(i)
	else:
		if liar:
			eliminate(last.seat)
		else:
			eliminate(caller)
	start_new_round()

func eliminate(seat):
	alive[seat] = false
	player_sprites[seat].modulate = Color(0.5, 0.5, 0.5)
	magazine_labels[seat].text = ""
	if current_turn == seat:
		advance_turn()

func advance_turn():
	var i = turn_order.find(current_turn)
	for j in range(1, 5):
		var s = turn_order[(i + j) % 4]
		if alive[s]:
			send_turn(s)
			return

func _get_selected_card_indices():
	var indices = []
	for i in range(hand_container.get_child_count()):
		var card = hand_container.get_child(i)
		if card.modulate != Color(1, 1, 1):
			indices.append(i)
	return indices
