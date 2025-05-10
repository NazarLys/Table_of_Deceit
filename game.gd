extends Node

@onready var multiplayer_id = multiplayer.get_unique_id()

# Game nodes
var turn_indicator: Node
var round_label: Label
var hand_container: Node
var pass_button: Button
var liar_button: Button
var timer_label: Label
var turn_timer: Timer
var round_card: Sprite2D
var table_area: Sprite2D  
@onready var output_label: Label = $UI/Output  # Reference to output label

# Card configuration
const MAIN_DECK_TYPES = ["king", "queen", "ace", "joker"]
const MAIN_DECK_COUNTS = {
	"king": 6,
	"queen": 6,
	"ace": 6,
	"joker": 2
}

# Game state
var hand_cards: Array = []
var selected_cards: Array = []
var turn_time_left: int = 60

# Coordinates for center of the table with assumed size 1280x720
var table_center_x: float = -641  # Table center X
var table_center_y: float = -360  # Table center Y

# Store log lines for output label
var log_lines: Array = []

func _ready():
	turn_indicator = $Turn
	round_label = $UI/Rounds
	hand_container = $Hand
	pass_button = $Pass
	liar_button = $Liar
	timer_label = $UI/TurnTimer/TimerLabel
	turn_timer = $UI/TurnTimer
	round_card = $Deck/RoundCard
	table_area = $UI/Background  

	pass_button.pressed.connect(_on_PassButton_pressed)
	liar_button.pressed.connect(_on_LiarButton_pressed)
	turn_timer.timeout.connect(_on_TurnTimer_timeout)
	turn_timer.wait_time = 1.0
	turn_timer.one_shot = false
	turn_timer.start()

	start_round()

func log_message(msg: String):
	log_lines.append(msg)
	if log_lines.size() > 3:
		log_lines.remove_at(0)
	output_label.text = "\n".join(log_lines)
	output_label.modulate.a = 1.0  # Reset alpha every time

	# Tween to fade only the last message
	var tween := create_tween()
	tween.tween_property(output_label, "modulate:a", 0.0, 1.0).set_delay(1.0)
	tween.finished.connect(func():
		if log_lines.has(msg) and log_lines[-1] == msg:
			log_lines.remove_at(log_lines.size() - 1)
			output_label.text = "\n".join(log_lines)
			output_label.modulate.a = 1.0
	)

func start_round():
	var table_deck = ["king", "queen", "ace"]
	var chosen_card = table_deck.pick_random()
	round_label.text = "Current Round: \n %s" % chosen_card.capitalize()
	round_card.texture = load("res://cards/%s.png" % chosen_card)

	hand_cards.clear()
	hand_container.get_children().map(func(c): c.queue_free())
	selected_cards.clear()

	var full_deck = []
	for type in MAIN_DECK_TYPES:
		for i in MAIN_DECK_COUNTS[type]:
			full_deck.append(type)
	full_deck.shuffle()

	for i in range(5):
		var card_type: String = full_deck.pop_back()
		var card_tex: Texture2D = load("res://cards/%s.png" % card_type)
		var card_button := TextureButton.new()
		card_button.name = "%s_card_%d" % [card_type, i]
		card_button.texture_normal = card_tex
		card_button.pressed.connect(_on_Card_pressed.bind(card_button))

		var wrapper = Control.new()
		wrapper.custom_minimum_size = Vector2(50, 75)
		card_button.scale = Vector2(0.3, 0.3)
		card_button.position = Vector2.ZERO
		card_button.anchor_left = 0
		card_button.anchor_top = 0
		card_button.anchor_right = 0
		card_button.anchor_bottom = 0
		card_button.size_flags_horizontal = Control.SIZE_FILL
		card_button.size_flags_vertical = Control.SIZE_FILL
		var card_spacing: float = 140
		hand_container.add_theme_constant_override("separation", card_spacing)
		wrapper.add_child(card_button)
		hand_container.add_child(wrapper)
		hand_cards.append(card_button)

	pass_button.show()
	liar_button.show()
	turn_time_left = 60
	timer_label.text = str("Time left: %s" % turn_time_left)
	turn_timer.start()

func _on_Card_pressed(button):
	var c = Color.from_hsv(30.0 / 360.0, 0.5, 1.0)
	if selected_cards.has(button):
		selected_cards.erase(button)
		button.modulate = Color(1, 1, 1)
	else:
		selected_cards.append(button)
		button.modulate = c

func _on_PassButton_pressed():
	if selected_cards.is_empty():
		log_message("No cards selected!")
		return

	var card_scale = 0.25
	var card_width = 50 * card_scale
	var spacing = 150
	var total_width = selected_cards.size() * card_width + (selected_cards.size() - 1) * spacing

	# Use coordinates for properly centered card placement
	var base_x = table_center_x + 640  # 640 is half the table width (1280 / 2)
	var base_y = table_center_y + 330  # Slightly higher than bottom (adjusted)
	var center_offset = (1280 - total_width) / 2

	# Position cards in center
	for i in range(selected_cards.size()):
		var card = selected_cards[i]
		card.texture_normal = load("res://cards/back.png")
		card.modulate = Color(1, 1, 1)
		card.scale = Vector2(card_scale, card_scale)

		var wrapper = card.get_parent()
		if wrapper and wrapper.get_parent() == hand_container:
			wrapper.remove_child(card)
			hand_container.remove_child(wrapper)

		add_child(card)
		var x_position = base_x + center_offset + i * (card_width + spacing)
		card.global_position = Vector2(x_position, base_y)

	selected_cards.clear()
	pass_button.hide()
	liar_button.hide()

func _on_LiarButton_pressed():
	log_message("LIAR called!")
	pass_button.hide()
	liar_button.hide()

func _on_TurnTimer_timeout():
	if turn_time_left > 0:
		turn_time_left -= 1
		timer_label.text = str("Time left: %s" % turn_time_left)
	else:
		log_message("Turn timed out")
		turn_timer.stop()
		pass_button.hide()
		liar_button.hide()
