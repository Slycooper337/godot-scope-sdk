class_name ScopeMessages
extends RefCounted
var _api: ScopeAPI
func _init(api: ScopeAPI) -> void: _api = api
func send(user_id: int, text: String) -> ScopeResponse:
	var trimmed := text.strip_edges()
	if user_id <= 0: return ScopeResponse.fail(400, "Recipient is required")
	if trimmed.is_empty() or trimmed.length() > 2000: return ScopeResponse.fail(400, "Message must be between 1 and 2000 characters")
	var result := await _api.request_post("/wizards-wager/messages", {"user_id": user_id, "text": trimmed})
	if result.success: result.data = ScopeMessage.from_json(result.data)
	return result
func list(user_id: int, limit: int = 50) -> ScopeResponse:
	if user_id <= 0: return ScopeResponse.fail(400, "User is required")
	var result := await _api.request_get("/wizards-wager/messages?user_id=%d&limit=%d" % [user_id, clampi(limit, 1, 100)])
	if result.success:
		var messages: Array[ScopeMessage] = []
		if result.data is Array:
			for item in result.data: messages.append(ScopeMessage.from_json(item))
		result.data = messages
	return result
