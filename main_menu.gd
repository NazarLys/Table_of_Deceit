extends Node

@onready var liars_button: Button = $LiarsDeck
@onready var devils_button: Button = $DevilsDeck
@onready var play_button: Button = $Play

var selected_deck: String = ""
var hovered_button: Button = null

func _ready():
	# Connect pressed signals
	liars_button.pressed.connect(_on_liars_pressed)
	devils_button.pressed.connect(_on_devils_pressed)
	play_button.pressed.connect(_on_play_pressed)

	# Connect hover signals
	liars_button.mouse_entered.connect(func(): _on_hover(liars_button))
	liars_button.mouse_exited.connect(_on_hover_exit)
	devils_button.mouse_entered.connect(func(): _on_hover(devils_button))
	devils_button.mouse_exited.connect(_on_hover_exit)
	play_button.mouse_entered.connect(func(): _on_hover(play_button))
	play_button.mouse_exited.connect(_on_hover_exit)

	_update_buttons()

func _on_liars_pressed():
	selected_deck = "liars"
	_update_buttons()

func _on_devils_pressed():
	selected_deck = "devils"
	_update_buttons()

func _on_play_pressed():
	if selected_deck == "":
		print("⚠️ Please select a deck before starting the game!")
		return
	get_tree().change_scene_to_file("res://Lobby.tscn")

func _on_hover(button: Button):
	hovered_button = button
	_update_buttons()

func _on_hover_exit():
	hovered_button = null
	_update_buttons()

func _update_buttons():
	# Reset to default
	liars_button.modulate = Color(1, 1, 1)
	devils_button.modulate = Color(1, 1, 1)
	play_button.modulate = Color(1, 1, 1)

	liars_button.scale = Vector2(0.38, 0.38)
	devils_button.scale = Vector2(0.38, 0.38)
	play_button.scale = Vector2(0.42, 0.42)

	# Pressed effect
	if selected_deck == "liars":
		liars_button.modulate = Color(0.8, 0.8, 0.8)
		liars_button.scale = Vector2(0.375, 0.375)
	elif selected_deck == "devils":
		devils_button.modulate = Color(0.8, 0.8, 0.8)
		devils_button.scale = Vector2(0.375, 0.375)

	# Hover effect (if not selected)
	if hovered_button != null:
		if hovered_button == play_button:
			play_button.modulate = Color(1.2, 1.2, 1.2)
			play_button.scale = Vector2(0.425, 0.425)
		elif hovered_button == liars_button and selected_deck != "liars":
			liars_button.modulate = Color(1.2, 1.2, 1.2)
			liars_button.scale = Vector2(0.385, 0.385)
		elif hovered_button == devils_button and selected_deck != "devils":
			devils_button.modulate = Color(1.2, 1.2, 1.2)
			devils_button.scale = Vector2(0.385, 0.385)
