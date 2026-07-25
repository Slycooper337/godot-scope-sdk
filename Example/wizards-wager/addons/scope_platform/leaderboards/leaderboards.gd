class_name ScopeLeaderboards
extends RefCounted

var _api: ScopeAPI


func _init(api: ScopeAPI) -> void:
	_api = api


func top(metric: String, limit: int = 100) -> ScopeResponse:
	return await _api.request_get(
		"/leaderboards/%s?limit=%d" % [metric.uri_encode(), limit]
	)


func rank(metric: String) -> ScopeResponse:
	return await _api.request_get(
		"/leaderboards/%s/rank" % metric.uri_encode()
	)
