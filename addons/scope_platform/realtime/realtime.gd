class_name ScopeRealtime
extends RefCounted

signal message_received(message: Dictionary)
signal connection_changed(connected: bool)

var _api: ScopeAPI
var _socket: WebSocketPeer
var connected: bool = false

func _init(api: ScopeAPI) -> void:
	_api = api

func connect_with_session(session: ScopeSession) -> ScopeResponse:
	_socket = WebSocketPeer.new()
	_socket.handshake_headers = PackedStringArray([
		"X-Scope-Application-ID: " + ScopeConfig.application_id(),
		"X-Scope-Public-Key: " + ScopeConfig.public_key(),
		"Authorization: Bearer " + session.get_access_token()
	])
	var url := ScopeConfig.api_url().replace("https://", "wss://").replace("http://", "ws://") + "/realtime"
	var error := _socket.connect_to_url(url)
	if error != OK:
		return ScopeResponse.fail(0, error_string(error))
	return ScopeResponse.ok(0)

func poll() -> void:
	if _socket == null:
		return
	_socket.poll()
	connected = _socket.get_ready_state() == WebSocketPeer.STATE_OPEN
	if not connected:
		return
	while _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet().get_string_from_utf8()
		var message := JSON.parse_string(packet)
		if message is Dictionary:
			message_received.emit(message)

func is_open() -> bool:
	return connected

func online() -> ScopeResponse:
	return await _online_request("/realtime/online")

func online_friends() -> ScopeResponse:
	return await _online_request("/realtime/online/friends")

func subscribe(channel: String) -> ScopeResponse:
	return _send_command("subscribe", channel)

func unsubscribe(channel: String) -> ScopeResponse:
	return _send_command("unsubscribe", channel)

func publish(channel: String, data: Dictionary) -> ScopeResponse:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ScopeResponse.fail(0, "Realtime is not connected")
	_socket.send_text(JSON.stringify({"type": "publish", "channel": channel, "data": data}))
	return ScopeResponse.ok(200)

func send_command(command_type: String, data: Dictionary = {}) -> ScopeResponse:
	if command_type.strip_edges().is_empty():
		return ScopeResponse.fail(400, "Realtime command type is required")
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ScopeResponse.fail(0, "Realtime is not connected")
	_socket.send_text(JSON.stringify({"type": command_type, "data": data}))
	return ScopeResponse.ok(200)

func close() -> void:
	if _socket != null:
		_socket.close()
	connected = false

func _online_request(endpoint: String) -> ScopeResponse:
	var result := await _api.request_get(endpoint)
	if result.success:
		var users: Array[ScopeOnlineUser] = []
		if result.data is Array:
			for value in result.data:
				users.append(ScopeOnlineUser.from_json(value))
		result.data = users
	return result

func _send_command(command_type: String, channel: String) -> ScopeResponse:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ScopeResponse.fail(0, "Realtime is not connected")
	_socket.send_text(JSON.stringify({"type": command_type, "channel": channel}))
	return ScopeResponse.ok(200)
