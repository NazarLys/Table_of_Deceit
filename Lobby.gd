extends Control

@onready var ip_input = $IpInput
@onready var host_button = $Host
@onready var join_button = $Join

func _ready():
	host_button.pressed.connect(_on_host_button_pressed)
	join_button.pressed.connect(_on_join_button_pressed)

func _on_host_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(12345, 4)
	multiplayer.multiplayer_peer = peer
	print("Server started on port 12345")
	get_tree().change_scene_to_file("res://Game.tscn")  # Replace with your game scene path

func _on_join_button_pressed():
	var peer = ENetMultiplayerPeer.new()
	var ip = ip_input.text.strip_edges()
	peer.create_client(ip, 12345)
	multiplayer.multiplayer_peer = peer
	print("Trying to join %s..." % ip)
	get_tree().change_scene_to_file("res://.tscn")
