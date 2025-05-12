extends Node

# Autoloaded global singleton
var global := Global

# Constants for card deck
const CARD_TYPES = ["king", "queen", "ace", "joker"]
const CARD_COUNTS = {"king": 6, "queen": 6, "ace": 6, "joker": 2}

# Node references (assumes these nodes exist in Game.tscn)
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

# Game state
var player_seat: int = -1
var current_turn: int = -1
var turn_order: Array[int] = []
var alive = [false, false, false, false]
var bullet_chambers = [1, 1, 1, 1]
var round_target_card: String = ""

var player_hands: Dictionary = {}
var selected_cards: Array = []
var table_history: Array = []
var turn_time_left: int = 60

func _ready():
	# Initialize UI
	turn_label.text = ""
	pass_button.hide()
	liar_button.hide()
	turn_timer.timeout.connect(_on_TurnTimer_timeout)
	turn_timer.wait_time = 1  # countdown step per second

	if multiplayer.is_server():
		# Assign seats in join order: host is seat 0
		player_seat = 0
		# Build a real Array[int] of all peer IDs, host first
		var peers: Array[int] = []
		peers.append( multiplayer.get_unique_id() )
		for pid in multiplayer.get_peers():
			peers.append( pid )
		for i in range(peers.size()):
			global.peer_to_seat[peers[i]] = i
			alive[i] = true
			turn_order.append(i)
			# Send seat assignment to each client
			rpc_id(peers[i], "assign_seat", i, global.character_selections.get(peers[i], 0))
			update_character_sprite(i, global.character_selections.get(peers[i], 0))
		# Start first round after assignments
		start_new_round()
	else:
		# Clients simply wait for the host to assign them a seat
			player_seat = -1


@rpc("any_peer")
func assign_seat(seat: int, char_id: int):
	# All peers (including server) record their seat and character
	if player_seat == -1:
		player_seat = seat
	alive[seat] = true
	update_character_sprite(seat, char_id)

func update_character_sprite(seat: int, char_id: int):
	player_sprites[seat].texture = load("res://characters/character%d.png" % char_id)

func start_new_round():
	# Choose random target card for this round
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	round_target_card = ["king", "queen", "ace"].pick_random()
	rpc("broadcast_round", round_target_card)
	# Deal cards to all players
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
	# Build and shuffle full deck
	var full_deck: Array[String] = []
	for t in CARD_TYPES:
		for _i in CARD_COUNTS[t]:
			full_deck.append(t)
	full_deck.shuffle()
	# Clear old hands
	player_hands.clear()
	for seat in turn_order:
		player_hands[seat] = []
	# Deal 5 cards to each player
	for seat in turn_order:
		for j in range(5):
			# take the top card
			var card = full_deck[0]
			full_deck.remove_at(0)
			player_hands[seat].append(card)
		# send that hand off to the right peer
		var peer_id = _peer_for_seat(seat)
		rpc_id(peer_id, "receive_hand", seat, player_hands[seat])
	# kick off turn 0
	current_turn = turn_order[0]
	send_turn(current_turn)

func _peer_for_seat(seat: int) -> int:
	for pid in global.peer_to_seat.keys():
		if global.peer_to_seat[pid] == seat:
			return pid
	return multiplayer.get_unique_id()

@rpc("any_peer")
func receive_hand(seat: int, cards: Array):
	if seat != player_seat:
		return
	hand_container.clear()
	selected_cards.clear()
	for card in cards:
		var tex = load("res://cards/%s.png" % card)
		var btn = TextureButton.new()
		btn.texture_normal = tex
		btn.pressed.connect(func(): _toggle_card(btn))
		hand_container.add_child(btn)
		selected_cards.append(btn)

func _toggle_card(btn: TextureButton):
	btn.modulate = Color(1, 0.5, 0) if btn.modulate == Color(1, 1, 1) else Color(1, 1, 1)

func send_turn(seat: int):
	current_turn = seat
	rpc("set_turn", seat, bullet_chambers[seat])
	set_turn(seat, bullet_chambers[seat])

@rpc("any_peer")
func set_turn(seat: int, bullet: int):
	current_turn = seat
	magazine_labels[seat].text = "%d/6" % bullet
	turn_label.text = "Your Turn" if seat == player_seat else ""
	var positions = [Vector2(-618, -201), Vector2(-294, -201), Vector2(25, -201), Vector2(345, -201)]
	turn_label.position = positions[seat]
	var is_my_turn = (seat == player_seat)
	pass_button.visible = is_my_turn
	liar_button.visible = is_my_turn
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
	var seat = global.peer_to_seat.get(pid, -1)
	if seat != -1:
		perform_pass(seat, indices)

@rpc("authority")
func player_liar_request():
	var pid = multiplayer.get_remote_sender_id()
	var seat = global.peer_to_seat.get(pid, -1)
	if seat != -1:
		perform_liar_call(seat)

func perform_pass(seat: int, indices: Array):
	if indices.is_empty():
		return

	# Collect cards to pass
	var passed: Array = []
	indices.sort()
	for idx in indices:
		if idx < player_hands[seat].size():
			passed.append(player_hands[seat][idx])

	# Remove them in reverse order so earlier indices don’t shift
	for j in range(indices.size() - 1, -1, -1):
		player_hands[seat].remove_at(indices[j])

	table_history.append({"seat": seat, "cards": passed})
	bullet_chambers[seat] += 1
	advance_turn()
	
func perform_liar_call(caller: int):
	if table_history.is_empty():
		return
	var last_play = table_history.back()
	var liar_detected = false
	for card in last_play.cards:
		if card != round_target_card and card != "joker":
			liar_detected = true
	# Reveal last played cards with color feedback
	output_label.bbcode_enabled = true
	output_label.text = ""  # clear previous text
	for card in last_play.cards:
		var is_truth = (card == round_target_card or card == "joker")
		var color_code = "#00FF00" if is_truth else "#FF0000"
		output_label.text += "[color=%s]%s[/color] " % [color_code, card.capitalize()]
	output_label.text += "\n"
	# Devil deck special case: Joker causes random elimination of others
	if global.game_mode == "devil" and "joker" in last_play.cards:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		for i in range(alive.size()):
			if i != last_play.seat and alive[i]:
				if bullet_chambers[i] >= rng.randi_range(1, 6):
					eliminate(i)
	else:
		if liar_detected:
			eliminate(last_play.seat)    # Liar was caught
		else:
			eliminate(caller)           # False call, eliminate caller
	start_new_round()

func eliminate(seat: int):
	alive[seat] = false
	player_sprites[seat].modulate = Color(0.5, 0.5, 0.5)  # Grey out eliminated player
	magazine_labels[seat].text = ""
	if current_turn == seat:
		advance_turn()

func advance_turn():
	var idx = turn_order.find(current_turn)
	var count = turn_order.size()
	# Try each subsequent seat in turn_order, wrapping around
	for offset in range(1, count):
		var next_seat = turn_order[(idx + offset) % count]
		if alive[next_seat]:
			send_turn(next_seat)
			return

func _get_selected_card_indices() -> Array[int]:
	var indices: Array[int] = []
	for i in range(hand_container.get_child_count()):
		var card_btn = hand_container.get_child(i)
		if card_btn.modulate != Color(1, 1, 1):
			indices.append(i)
	return indices
