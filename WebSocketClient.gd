extends Node

class_name WebSocketClient

signal connected
signal disconnected
signal message_received(msg: String)
signal connection_error(error: int)

var _client := WebSocketPeer.new()
var _connected := false

func _process(_delta):
	if _connected:
		var status = _client.get_ready_state()
		_client.poll()

		while _client.get_available_packet_count() > 0:
			var packet = _client.get_packet()
			var msg = packet.get_string_from_utf8()
			emit_signal("message_received", msg)

func connect_to_url(url: String):
	var err = _client.connect_to_url(url)
	if err != OK:
		push_error("WebSocket connection failed: %s" % err)
		emit_signal("connection_error", err)
		return

	_connected = true
	set_process(true)
	print("Connecting to:", url)

func disconnect_from_server():
	if _connected:
		_client.close(1000, "Bye")
		_connected = false
		set_process(false)
		emit_signal("disconnected")

func is_connected_to_server() -> bool:
	return _connected and _client.get_ready_state() == WebSocketPeer.STATE_OPEN

func send(msg: String):
	if is_connected_to_server():
		_client.send_text(msg)
	else:
		push_error("Attempted to send message while not connected.")
