class_name ScopeNotifications
extends RefCounted
var _api: ScopeAPI
func _init(api: ScopeAPI) -> void: _api = api
func list(unread_only: bool = false, limit: int = 50) -> ScopeResponse:
	var endpoint := "/notifications?limit=%d" % clampi(limit, 1, 100)
	if unread_only: endpoint += "&unread_only=true"
	var result := await _api.request_get(endpoint)
	if result.status >= 200 and result.status < 300:
		result.success = true
		var items: Array[ScopeNotification] = []
		if result.data is Array:
			for value in result.data:
				items.append(ScopeNotification.from_json(value))
		result.data = items
	return result
func mark_read(notification_id: int) -> ScopeResponse: return await _api.request_post("/notifications/%d/read" % notification_id)
func mark_all_read() -> ScopeResponse: return await _api.request_post("/notifications/read-all")
