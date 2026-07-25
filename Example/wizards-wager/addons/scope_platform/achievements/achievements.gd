class_name ScopeAchievements
extends RefCounted
var _api: ScopeAPI
func _init(api: ScopeAPI) -> void: _api = api
func list() -> ScopeResponse:
	var result := await _api.request_get("/achievements")
	if result.success:
		var items: Array[ScopeAchievement] = []
		if result.data is Array:
			for value in result.data:
				items.append(ScopeAchievement.from_json(value))
		result.data = items
	return result
func get_achievement(key: String) -> ScopeResponse:
	var result := await _api.request_get("/achievements/%s" % key.uri_encode())
	if result.success: result.data = ScopeAchievement.from_json(result.data)
	return result
