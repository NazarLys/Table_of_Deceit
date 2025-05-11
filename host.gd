extends Node

@onready var generate_port_button: Button = $GeneratePortButton
@onready var port_label: Label = $PortLabel

var server_port: int = 0
var multiplayer_peer: ENetMultiplayerPeer = null

func _ready():
	# Підключаємо сигнал кнопки
	generate_port_button.pressed.connect(_on_generate_port_pressed)

func _on_generate_port_pressed():
	randomize()
	server_port = randi() % 10000 + 1024

	# Виведення порту на екран
	port_label.text = "🔌 Порт сервера: " + str(server_port)

	# Створення мережевого сервера
	multiplayer_peer = ENetMultiplayerPeer.new()
	var error = multiplayer_peer.create_server(server_port, 32)  # Вказуємо максимальну кількість клієнтів

	if error != OK:
		# Якщо помилка при створенні сервера
		port_label.text += "\n❌ Помилка створення сервера!"
		print("❌ Помилка під час створення сервера:", error)
	else:
		# Налаштовуємо multiplayer_peer після створення сервера
		get_tree().multiplayer.network_peer = multiplayer_peer  # Підключаємо до multiplayer
		get_tree().multiplayer.peer_connected.connect(_on_peer_connected)
		get_tree().multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		print("✅ Сервер створено на порту:", server_port)

# Обробка підключення нових гравців
func _on_peer_connected(id: int):
	print("🎮 Гравець підключився! ID: ", id)

# Обробка відключення гравців
func _on_peer_disconnected(id: int):
	print("👋 Гравець відключився! ID: ", id)
