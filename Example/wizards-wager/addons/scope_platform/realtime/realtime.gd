class_name ScopeRealtime
extends RefCounted

signal message_received(message: Dictionary)
signal authentication_failed(message: String)

var _api: ScopeAPI
var _socket: WebSocketPeer
var connected: bool = false
var _auth_failure_emitted := false

func _init(api: ScopeAPI) -> void:
	_api = api

func connect_with_session(session: ScopeSession) -> ScopeResponse:
	if _socket != null:
		_socket.close()
	_socket = WebSocketPeer.new()
	_auth_failure_emitted = false
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
	if _socket == null: return
	_socket.poll()
	connected = _socket.get_ready_state() == WebSocketPeer.STATE_OPEN
	if not connected:
		var close_code := _socket.get_close_code()
		if (close_code == 1008 or close_code == 4001 or close_code == 4401) and not _auth_failure_emitted:
			_auth_failure_emitted = true
			authentication_failed.emit("Realtime session expired.")
		return
	while _socket.get_available_packet_count() > 0:
		var raw_message := _socket.get_packet().get_string_from_utf8()
		var message: Variant = JSON.parse_string(raw_message)
		if message is Dictionary: message_received.emit(message)

func is_open() -> bool:
	return connected

func online() -> ScopeResponse:
	return await _online_request("/realtime/online")

func online_friends() -> ScopeResponse:
	return await _online_request("/realtime/online/friends")

func subscribe(channel: String) -> ScopeResponse:
	return _send("subscribe", channel)

func unsubscribe(channel: String) -> ScopeResponse:
	return _send("unsubscribe", channel)

func publish(channel: String, data: Dictionary) -> ScopeResponse:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ScopeResponse.fail(0, "Realtime is not connected")
	_socket.send_text(JSON.stringify({"type": "publish", "channel": channel, "data": data}))
	return ScopeResponse.ok(200)

func send_command(command_type: String, data: Dictionary = {}) -> ScopeResponse:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ScopeResponse.fail(0, "Realtime is not connected")
	_socket.send_text(JSON.stringify({"type": command_type, "data": data}))
	return ScopeResponse.ok(200)

func close() -> void:
	if _socket != null: _socket.close()
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

func _send(command_type: String, channel: String) -> ScopeResponse:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ScopeResponse.fail(0, "Realtime is not connected")
	_socket.send_text(JSON.stringify({"type": command_type, "channel": channel}))
	return ScopeResponse.ok(200)
