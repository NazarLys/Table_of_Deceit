extends Control

@onready var ip_input = $IpInput
@onready var host_button = $Host
@onready var join_button = $Join
@onready var changeb_button = $ChangeB
@onready var changen_button = $ChangeN

var hovered_button: Button = null

func _ready():
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)

	# Connect hover signals for all buttons
	host_button.mouse_entered.connect(func(): _on_hover(host_button))
	host_button.mouse_exited.connect(_on_hover_exit)
	
	join_button.mouse_entered.connect(func(): _on_hover(join_button))
	join_button.mouse_exited.connect(_on_hover_exit)

	changeb_button.mouse_entered.connect(func(): _on_hover(changeb_button))
	changeb_button.mouse_exited.connect(_on_hover_exit)
	
	changen_button.mouse_entered.connect(func(): _on_hover(changen_button))
	changen_button.mouse_exited.connect(_on_hover_exit)

# Обробка натискання на кнопку Host
func _on_host_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(12345, 4)
	multiplayer.multiplayer_peer = peer
	print("Server started on port 12345")
	get_tree().change_scene_to_file("res://host.tscn") 

# Обробка натискання на кнопку Join
func _on_join_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	var ip = ip_input.text.strip_edges()
	peer.create_client(ip, 12345)
	multiplayer.multiplayer_peer = peer
	print("Trying to join %s..." % ip)
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

