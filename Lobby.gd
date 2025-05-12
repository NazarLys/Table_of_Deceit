extends Control

@onready var enter_code = $EnterCode
@onready var host_button = $Host
@onready var join_button = $Join
@onready var status_label = $StatusLabel
@onready var start_button = $StartGame  

# Collect any player placeholder overlays for dimming
var player_overlays := []
func _ready():
	# Assume Lobby.tscn has ColorRect nodes named "Player 0", "Player 1", etc.
	for i in range(Global.max_players):
		var node_name = "Player %d" % i
		if has_node(node_name):
			player_overlays.append(get_node(node_name))
	# Connect UI signals
	host_button.pressed.connect(_on_Host_pressed)
	join_button.pressed.connect(_on_Join_pressed)
	start_button.pressed.connect(_on_StartGame_pressed)
	# Connect multiplayer signals for join/leave
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	update_lobby_ui()

func _on_Host_pressed():
	var code = enter_code.text.strip_edges()
	if code == "":
		status_label.text = "Enter a room code to host."
		return
	# Initialize WebRTC peer as host/server
	var rtc = WebRTCMultiplayerPeer.new()
	# The signaling server is assumed to use 'code' as room ID
	rtc.create_server()  # Use appropriate room code if supported
	multiplayer.multiplayer_peer = rtc
	status_label.text = "Hosting room '%s'..." % code
	host_button.disabled = true
	join_button.disabled = true

func _on_Join_pressed():
	var code = enter_code.text.strip_edges()
	if code == "":
		status_label.text = "Enter a room code to join."
		return
	# Initialize WebRTC peer as client
	var rtc = WebRTCMultiplayerPeer.new()
	# Connect to the existing room; convert code to int if needed
	rtc.create_client(code.to_int())
	multiplayer.multiplayer_peer = rtc
	status_label.text = "Joining room '%s'..." % code
	host_button.disabled = true
	join_button.disabled = true

func _on_peer_connected(id: int):
	status_label.text = "Player %d connected." % id
	update_lobby_ui()

func _on_peer_disconnected(id: int):
	status_label.text = "Player %d disconnected." % id
	update_lobby_ui()

func update_lobby_ui():
	# Dim (show overlay) for empty seats, undim for occupied seats
	var total = 1 + multiplayer.get_peers().size()
	for i in range(player_overlays.size()):
		if i < total:
			player_overlays[i].visible = false
		else:
			player_overlays[i].visible = true
@rpc("authority")
func start_game():
	# All peers receive this to change scene to the game
	status_label.text = "Starting game..."
	get_tree().change_scene("res://Game.tscn")

func _on_StartGame_pressed():
	if multiplayer.is_server():
		# Only host triggers game start
		rpc("start_game")
		start_game()
