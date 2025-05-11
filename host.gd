extends Control

@onready var start_button = $Start_Button
@onready var port_input = $PortLabel
@onready var output_label = $Label

func _ready():
	start_button.pressed.connect(_start_game)

func _start_game():
	if port_input.text == "":
		output_label.text = "Enter port before hosting!"
		return
	var port = int(port_input.text)
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port, Global.max_players)
	multiplayer.multiplayer_peer = peer
	Global.peer_to_seat[multiplayer.get_unique_id()] = 0
	get_tree().change_scene_to_file("res://game.tscn")
