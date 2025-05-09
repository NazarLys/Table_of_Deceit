extends Node

# Game nodes
var turn_indicator: Node
var round_label: Label
var hand_container: Node
var pass_button: Button
var liar_button: Button
var timer_label: Label
var turn_timer: Timer
var round_card: Sprite2D
var table_area: Node

# Card configuration
const MAIN_DECK_TYPES = ["king", "queen", "ace", "joker"]
const MAIN_DECK_COUNTS = {
	"king": 5,
	"queen": 5,
	"ace": 5,
	"joker": 2
}

# Game state
var hand_cards: Array = []
var selected_cards: Array = []
var turn_time_left: int = 60

func _ready():
	turn_indicator = $Turn
	round_label = $UI/Rounds
	hand_container = $Hand
	table_area = $Table
	pass_button = $Pass
	liar_button = $Liar
	timer_label = $UI/TurnTimer/TimerLabel
	turn_timer = $UI/TurnTimer
	round_card = $Deck/RoundCard

	pass_button.pressed.connect(_on_PassButton_pressed)
	liar_button.pressed.connect(_on_LiarButton_pressed)
	turn_timer.timeout.connect(_on_TurnTimer_timeout)
	turn_timer.wait_time = 1.0  # 1 second intervals
	turn_timer.one_shot = false
	turn_timer.start()
	


	start_round()

func start_round():
	# Pick table card
	var table_deck = ["king", "queen", "ace"]
	var chosen_card = table_deck.pick_random()
	round_label.text = "Current Round: \n %s" % chosen_card.capitalize()
	round_card.texture = load("res://cards/%s.png" % chosen_card)

	# Prepare hand
	hand_cards.clear()
	hand_container.get_children().map(func(c): c.queue_free())
	selected_cards.clear()

	# Shuffle and deal cards
	var full_deck = []
	for type in MAIN_DECK_TYPES:
		for i in MAIN_DECK_COUNTS[type]:
			full_deck.append(type)
	full_deck.shuffle()

	var card_spacing: float = 80.0
	for i in range(5):
		var card_type: String = full_deck.pop_back()
		var card_tex: Texture2D = load("res://cards/%s.png" % card_type)
		var card_button := TextureButton.new()
		card_button.name = "%s_card_%d" % [card_type, i]
		card_button.texture_normal = card_tex
		card_button.position = Vector2(i * card_spacing, 0)
		card_button.pressed.connect(_on_Card_pressed.bind(card_button))
		hand_container.add_child(card_button)
		hand_cards.append(card_button)

	pass_button.show()
	liar_button.show()
	turn_time_left = 60
	timer_label.text = str("Time left: %s" % turn_time_left)
	turn_timer.start()

func _on_Card_pressed(button):
	if selected_cards.has(button):
		selected_cards.erase(button)
		button.modulate = Color(1, 1, 1)
	else:
		selected_cards.append(button)
		button.modulate = Color(1, 0.5, 0)  # Orange glow

func _on_PassButton_pressed():
	if selected_cards.is_empty():
		print("No cards selected!")
		return

	for i in range(selected_cards.size()):
		var card = selected_cards[i]
		card.texture_normal = load("res://cards/back.png")
		card.modulate = Color(1, 1, 1)

		# Make card slightly larger
		card.scale = Vector2(1.3, 1.3)  # Adjust the scale as needed
		

		# Move from hand to table
		hand_container.remove_child(card)
		table_area.add_child(card)
		
		var card_width = 20
		var spacing = 200
		var base_x = -310
		var base_y = -350

		# Position card more to the left (-100 for offset) and slightly higher
		card.position = Vector2(base_x + i * (card_width + spacing), base_y)

	selected_cards.clear()
	pass_button.hide()
	liar_button.hide()

func _on_LiarButton_pressed():
	print("LIAR called!")
	pass_button.hide()
	liar_button.hide()

func _on_TurnTimer_timeout():
	if turn_time_left > 0:
		turn_time_left -= 1
		timer_label.text = str("Time left: %s" % turn_time_left)
	else:
		print("Turn timed out")
		turn_timer.stop()
		pass_button.hide()
		liar_button.hide()

