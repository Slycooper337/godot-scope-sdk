class_name ScopeFriends
extends RefCounted
var _api: ScopeAPI
func _init(api: ScopeAPI) -> void: _api = api
func list() -> ScopeResponse: return await _list("/friends")
func send_request(username: String) -> ScopeResponse: return await _api.request_post("/friends/requests", {"username": username})
func requests(direction: String = "incoming") -> ScopeResponse:
	return await _list("/friends/requests" + ("?direction=outgoing" if direction == "outgoing" else ""))
func accept_request(request_id: int) -> ScopeResponse: return await _api.request_post("/friends/requests/%d/accept" % request_id)
func decline_request(request_id: int) -> ScopeResponse: return await _api.request_post("/friends/requests/%d/decline" % request_id)
func remove(friend_user_id: int) -> ScopeResponse: return await _api.request_delete("/friends/%d" % friend_user_id)
func _list(endpoint: String) -> ScopeResponse:
	var result := await _api.request_get(endpoint)
	if result.status >= 200 and result.status < 300:
		result.success = true
		var items: Array[ScopeFriend] = []
		if result.data is Array:
			for value in result.data:
				items.append(ScopeFriend.from_json(value))
		result.data = items
	return result
