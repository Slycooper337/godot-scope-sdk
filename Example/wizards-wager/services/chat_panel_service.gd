class_name ChatPanelService
extends RefCounted

func send(text: String, sequence: int) -> ScopeResponse:
	if not Scope.realtime.is_open():
		return ScopeResponse.fail(0, "Chat is unavailable while disconnected.")
	return Scope.realtime.send_command("send_chat_message", {
		"channel_type": "general",
		"text": text,
		"client_message_id": "%d-%d-%d" % [Scope.session.current_user.id, Time.get_ticks_usec(), sequence]
	})

func request_history() -> ScopeResponse:
	return Scope.realtime.send_command("get_chat_history", {"channel_type": "general", "limit": 100})
