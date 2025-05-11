extends Control

@onready var ip_input = $IpInput
@onready var host_button = $Host
@onready var join_button = $Join
@onready var changeb_button = $ChangeLeft
@onready var changen_button = $ChangeRight
@onready var character_sprite: Sprite2D = $Character  

var hovered_button: Button = null

var character_images: Array[Texture2D] = [
	preload("res://characters/character0.png"),
	preload("res://characters/character1.png"),
	preload("res://characters/character2.png"),
	preload("res://characters/character3.png")
]

# Track the current selection index
var current_character_index: int = 0


func _ready():
	update_character_sprite()
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	changeb_button.pressed.connect(_on_ChangeLeft_pressed)
	changen_button.pressed.connect(_on_ChangeRight_pressed)

	# Connect hover signals for all buttons
	host_button.mouse_entered.connect(func(): _on_hover(host_button))
	host_button.mouse_exited.connect(_on_hover_exit)
	
	join_button.mouse_entered.connect(func(): _on_hover(join_button))
	join_button.mouse_exited.connect(_on_hover_exit)
	
	changeb_button.mouse_entered.connect(func(): _on_hover(changeb_button))
	changeb_button.mouse_exited.connect(_on_hover_exit)
	
	changen_button.mouse_entered.connect(func(): _on_hover(changen_button))
	changen_button.mouse_exited.connect(_on_hover_exit)

func update_character_sprite() -> void:
	# Update the Character Sprite's texture based on current_character_index
	character_sprite.texture = character_images[current_character_index]

func _on_ChangeRight_pressed() -> void:
	# Cycle to the next character (wrap around to 0 after the last index)
	current_character_index = (current_character_index + 1) % character_images.size()
	update_character_sprite()

func _on_ChangeLeft_pressed() -> void:
	# Cycle to the previous character (wrap around to last index if at first index)
	current_character_index = (current_character_index - 1 + character_images.size()) % character_images.size()
	update_character_sprite()

func _on_host_pressed() -> void:
	# Save selected character index in Global dictionary with peer_id as key
	var peer_id = multiplayer.get_unique_id()
	Global.character_selections[peer_id] = current_character_index
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(12345, 4)  # Change port and max_players if needed
	multiplayer.multiplayer_peer = peer
	Global.peer_to_seat[peer_id] = 0  # Host is always seat 0
	get_tree().change_scene_to_file("res://game.tscn")

func _on_join_pressed() -> void:
	var ip = ip_input.text.strip_edges()
	if ip == "":
		printerr("No IP entered!")
		return
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip, 12345)
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	
func _on_connected_to_server():
	var peer_id = multiplayer.get_unique_id()
	Global.character_selections[peer_id] = current_character_index
	get_tree().change_scene_to_file("res://game.tscn")

# Обробка подій миші для підсвітки кнопки
func _on_hover(button: Button):
	hovered_button = button
	_update_buttons()

# Обробка виходу миші з кнопки
func _on_hover_exit():
	hovered_button = null
	_update_buttons()

# Оновлення кнопок, щоб підсвітити при наведенні
func _update_buttons():
	# Reset to default for all buttons
	host_button.modulate = Color(1, 1, 1)
	join_button.modulate = Color(1, 1, 1)
	changeb_button.modulate = Color(1, 1, 1)
	changen_button.modulate = Color(1, 1, 1)

	# Hover effect for buttons
	if hovered_button != null:
		if hovered_button == host_button:
			host_button.modulate = Color(1.2, 1.2, 1.2)  # Підсвічування кнопки Host
			host_button.scale = Vector2(0.203, 0.203)  # Збільшення кнопки Host на 5%
		elif hovered_button == join_button:
			join_button.modulate = Color(1.2, 1.2, 1.2)  # Підсвічування кнопки Join
			join_button.scale = Vector2(0.203, 0.203)  # Збільшення кнопки Join на 5%
		elif hovered_button == changeb_button:
			changeb_button.modulate = Color(1.2, 1.2, 1.2)  # Підсвічування кнопки ChangeB
		elif hovered_button == changen_button:
			changen_button.modulate = Color(1.2, 1.2, 1.2)  # Підсвічування кнопки ChangeN
	else:
		# Відновлюємо масштаб до звичайного стану, якщо мишка не на кнопці
		host_button.scale = Vector2(0.201, 0.201)  # Відновлення масштабу кнопки Host
		join_button.scale = Vector2(0.201, 0.201)  # Відновлення масштабу кнопки Join

