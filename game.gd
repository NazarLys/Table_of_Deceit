extends Node

# Autoloaded global singleton
var global := Global

# === CONSTANTS (Card definitions) ===
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

# === GAME STATE VARIABLES ===
var player_seat: int = -1
var current_turn: int = -1
var turn_order: Array[int] = []
var alive = [false, false, false, false]
var bullet_chambers = [1, 1, 1, 1]
var round_target_card: String = ""

var player_hands: Dictionary = {}
var selected_cards: Array[TextureButton] = []
var table_history: Array = []
var client_has_selection: Dictionary = {}
var client_selected_indices: Dictionary = {}
var turn_time_left: int = 60

func _ready():
	# Initialize UI and connect timer signal
	turn_label.text = ""
	pass_button.hide()
	liar_button.hide()
	turn_timer.timeout.connect(_on_TurnTimer_timeout)

	if multiplayer.is_server():
		# Host sets up players and seats
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
		# Broadcast host's character selection to all players
		rpc("set_player_character", multiplayer.get_unique_id(), global.character_selections[multiplayer.get_unique_id()])
		start_new_round()
	else:
		# Client: no seat assigned yet
		player_seat = -1
		# Send this client's character choice to host for synchronization
		rpc_id(1, "set_player_character", multiplayer.get_unique_id(), global.character_selections[multiplayer.get_unique_id()])

@rpc("any_peer")
func set_player_character(peer_id: int, character_index: int):
	# Sync a player's character selection across the network
	global.character_selections[peer_id] = character_index
	if multiplayer.is_server():
		# Host, upon receiving a client's selection, broadcasts it to everyone
		var seat = global.peer_to_seat.get(peer_id, -1)
		if seat != -1:
			rpc("assign_seat", seat, character_index)
	# Update the character sprite for the corresponding seat
	update_character_sprite(global.peer_to_seat.get(peer_id, 0), character_index)

@rpc("any_peer")
func assign_seat(seat: int, char_id: int):
	# Assign a networked player to a seat index and set their character
	if player_seat == -1:
		player_seat = seat  # Set our own seat if not already set
	alive[seat] = true
	if seat == player_seat:
		# If this assignment is for our own player, ensure the character matches our selection
		var pid = multiplayer.get_unique_id()
		if global.character_selections.has(pid) and global.character_selections[pid] != char_id:
			char_id = global.character_selections[pid]
	update_character_sprite(seat, char_id)

func update_character_sprite(seat: int, char_id: int):
	# Update the character image for a given seat
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
	var full_deck: Array[String] = []
	for type in CARD_TYPES:
		for i in range(CARD_COUNTS[type]):
			full_deck.append(type)
	full_deck.shuffle()
	# (Card dealing logic continues, populating each player's hand server-side and sending via RPC)

func _peer_for_seat(seat: int) -> int:
	# Utility: find peer_id given a seat index
	for peer_id in global.peer_to_seat:
		if global.peer_to_seat[peer_id] == seat:
			return peer_id
	return 1  # Fallback to host ID if not found

	player_hands.clear()
	for seat_index in turn_order:
		player_hands[seat_index] = []

	current_turn = turn_order[0]
	send_turn(current_turn)

@rpc("any_peer")
func receive_hand(seat: int, cards: Array):
	if seat != player_seat:
		return  # Only process our own hand data
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
	# Toggle card selection visual
	btn.modulate = btn.modulate == Color(1, 1, 1) ? Color(1, 0.5, 0) : Color(1, 1, 1)

func send_turn(seat: int):
	current_turn = seat
	rpc("set_turn", seat, bullet_chambers[seat])
	set_turn(seat, bullet_chambers[seat])

@rpc("any_peer")
func set_turn(seat: int, bullet: int):
	current_turn = seat
	magazine_labels[seat].text = "%d/6" % bullet
	turn_label.text = (seat == player_seat) ? "Your Turn" : ""
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
		# Auto-press a button if player runs out of time
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
	var passed: Array = []
	for i in indices:
		if i < player_hands[seat].size():
			passed.append(player_hands[seat][i])
			player_hands[seat].remove_at(i)
	# Record the passed cards on the table
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
	if global.game_mode == "devil" and "joker" in last_play.cards:
		# Devil's deck mode: if joker played, random elimination chance for all other alive players
		for i in range(4):
			if i != last_play.seat and alive[i]:
				if bullet_chambers[i] >= randi() % 6 + 1:
					eliminate(i)
	else:
		if liar_detected:
			eliminate(last_play.seat)    # Liar caught – eliminate the last player who played
		else:
			eliminate(caller)           # Liar call was false – eliminate the caller
	start_new_round()

func eliminate(seat: int):
	alive[seat] = false
	player_sprites[seat].modulate = Color(0.5, 0.5, 0.5)  # Grey out eliminated player
	magazine_labels[seat].text = ""
	if current_turn == seat:
		advance_turn()

func advance_turn():
	# Move to the next alive player in turn_order
	var i = turn_order.find(current_turn)
	for j in range(1, 5):
		var next_seat = turn_order[(i + j) % 4]
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
