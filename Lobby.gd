extends Control

@onready var status_label = $StatusLabel
@onready var EnterCode = $EnterCode
@onready var host_button = $Host
@onready var join_button = $Join
@onready var changeb_button = $ChangeLeft
@onready var changen_button = $ChangeRight
@onready var character_sprite: Sprite2D = $Character

var hovered_button: Button = null
var current_character_index: int = 0
var is_host: bool = false

var character_images: Array[Texture2D] = [
	preload("res://characters/character0.png"),
	preload("res://characters/character1.png"),
	preload("res://characters/character2.png"),
	preload("res://characters/character3.png")
]

var socket := WebSocketPeer.new()
var signaling_url := "wss://tableofdeceitserver.glitch.me" 
var my_peer_id = 0
var rtc_multiplayer : WebRTCMultiplayerPeer
var connections = {}
var _pending_room_code = null

func _ready():
	set_process(true)
	update_character_sprite()
	setup_ui_signals()

func setup_ui_signals():
	host_button.pressed.connect(_on_HostButton_pressed)
	join_button.pressed.connect(_on_JoinButton_pressed)
	changeb_button.pressed.connect(_on_ChangeLeft_pressed)
	changen_button.pressed.connect(_on_ChangeRight_pressed)
	host_button.mouse_entered.connect(func(): _on_hover(host_button))
	host_button.mouse_exited.connect(_on_hover_exit)
	join_button.mouse_entered.connect(func(): _on_hover(join_button))
	join_button.mouse_exited.connect(_on_hover_exit)
	changeb_button.mouse_entered.connect(func(): _on_hover(changeb_button))
	changeb_button.mouse_exited.connect(_on_hover_exit)
	changen_button.mouse_entered.connect(func(): _on_hover(changen_button))
	changen_button.mouse_exited.connect(_on_hover_exit)
	
func update_character_sprite():
	character_sprite.texture = character_images[current_character_index]
	
func _process(delta):
	if socket:
		socket.poll()
		var state = socket.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			if _pending_room_code != null:
				var msg = {"id": 0, "type": 0, "data": _pending_room_code}
				socket.send_text(JSON.stringify(msg))
				_pending_room_code = null
			while socket.get_available_packet_count() > 0:
				var pkt = socket.get_packet().get_string_from_utf8()
				_handle_signaling_message(pkt)
		elif state == WebSocketPeer.STATE_CLOSED:
			if my_peer_id != 0:
				status_label.text = "Disconnected from signaling server."
				my_peer_id = 0

func _on_HostButton_pressed():
	status_label.text = "Connecting as host..."
	connect_to_signaling("")

func _on_JoinButton_pressed():
	var code = EnterCode.text.strip_edges()
	if code.length() == 0:
		status_label.text = "Please enter a room code."
		return
	status_label.text = "Connecting to room %s..." % code
	connect_to_signaling(code)

func connect_to_signaling(room_code: String):
	var err = socket.connect_to_url(signaling_url)
	if err != OK:
		status_label.text = "[Error] Could not initiate WebSocket connection."
		return
	_pending_room_code = room_code

func _handle_signaling_message(msg_text: String):
	var json = JSON.new()
	var parse_result = json.parse(msg_text)
	if parse_result != OK:
		return
	var message = json.get_data()
	if message == null:
		return
	var msg_type = int(message.type)
	var from_id = int(message.id)
	var data = message.data

	match msg_type:
		0:
			status_label.text = "Joined room %s." % data
		1:
			my_peer_id = int(data)
			if my_peer_id == 1:
				status_label.text = "Hosting room. Code: %s" % data
			else:
				status_label.text = "Joined as peer #%d." % my_peer_id
			rtc_multiplayer = WebRTCMultiplayerPeer.new()
			if my_peer_id == 1:
				rtc_multiplayer.create_server()
			else:
				rtc_multiplayer.create_client(my_peer_id)
			get_tree().multiplayer.multiplayer_peer = rtc_multiplayer
		2:
			if !connections.has(from_id):
				var is_initiator = my_peer_id == 1
				_start_webrtc_handshake(from_id, is_initiator)
		3:
			if connections.has(from_id):
				rtc_multiplayer.remove_peer(from_id)
				connections.erase(from_id)
				status_label.text = "Peer %d disconnected." % from_id
		4:
			_on_received_offer(from_id, data)
		5:
			_on_received_answer(from_id, data)
		6:
			_on_received_candidate(from_id, data)

func _start_webrtc_handshake(peer_id: int, is_initiator: bool):
	var pc := WebRTCPeerConnection.new()
	var config := {"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]}
	pc.initialize(config)
	pc.session_description_created.connect(func(type, sdp): _on_local_description_created(peer_id, type, sdp))
	pc.ice_candidate_created.connect(func(mid, index, sdp): _on_local_ice_candidate(peer_id, mid, index, sdp))
	pc.data_channel_received.connect(func(channel): _on_data_channel_received(peer_id, channel))
	connections[peer_id] = pc
	var err = rtc_multiplayer.add_peer(pc, peer_id)
	if err != OK:
		push_error("Failed to add WebRTC peer: %s" % err)
	if is_initiator:
		pc.create_data_channel("game", {})
		pc.create_offer()

func _on_local_description_created(peer_id: int, type: String, sdp: String):
	var pc: WebRTCPeerConnection = connections[peer_id]
	pc.set_local_description(type, sdp)
	var msg_type = 4 if type == "offer" else 5
	var msg = {"id": peer_id, "type": msg_type, "data": sdp}
	socket.send_text(JSON.stringify(msg))

func _on_local_ice_candidate(peer_id: int, mid: String, index: int, sdp: String):
	var candidate_data = "%s|%d|%s" % [mid, index, sdp]
	var msg = {"id": peer_id, "type": 6, "data": candidate_data}
	socket.send_text(JSON.stringify(msg))

func _on_received_offer(from_id: int, sdp_offer: String):
	if !connections.has(from_id):
		_start_webrtc_handshake(from_id, false)
	var pc: WebRTCPeerConnection = connections[from_id]
	pc.set_remote_description("offer", sdp_offer)
	pc.create_answer()

func _on_received_answer(from_id: int, sdp_answer: String):
	if connections.has(from_id):
		var pc: WebRTCPeerConnection = connections[from_id]
		pc.set_remote_description("answer", sdp_answer)

func _on_received_candidate(from_id: int, data: String):
	var parts = data.split("|", false)
	if parts.size() == 3:
		var mid = parts[0]
		var index = parts[1].to_int()
		var sdp = parts[2]
		if connections.has(from_id):
			connections[from_id].add_ice_candidate(mid, index, sdp)

func _on_data_channel_received(peer_id: int, channel: WebRTCDataChannel):
	print("Data channel with peer %d established." % peer_id)
	_begin_game_session()

func _begin_game_session():
	var peer_id = multiplayer.get_unique_id()
	Global.character_selections[peer_id] = current_character_index
	get_tree().change_scene_to_file("res://game.tscn")

func _on_ChangeRight_pressed():
	current_character_index = (current_character_index + 1) % character_images.size()
	update_character_sprite()

func _on_ChangeLeft_pressed():
	current_character_index = (current_character_index - 1 + character_images.size()) % character_images.size()
	update_character_sprite()

func _on_hover(button: Button):
	hovered_button = button
	_update_buttons()

func _on_hover_exit():
	hovered_button = null
	_update_buttons()

func _update_buttons():
	host_button.modulate = Color(1, 1, 1)
	join_button.modulate = Color(1, 1, 1)
	changeb_button.modulate = Color(1, 1, 1)
	changen_button.modulate = Color(1, 1, 1)
	if hovered_button:
		hovered_button.modulate = Color(1.2, 1.2, 1.2)
		if hovered_button in [host_button, join_button]:
			hovered_button.scale = Vector2(0.203, 0.203)
	else:
		host_button.scale = Vector2(0.201, 0.201)
		join_button.scale = Vector2(0.201, 0.201)
