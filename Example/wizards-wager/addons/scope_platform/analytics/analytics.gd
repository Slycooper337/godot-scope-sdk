class_name ScopeAnalytics
extends RefCounted

var _api: ScopeAPI
var offline_batching_enabled: bool = false
var _queue: Array[Dictionary] = []

func _init(api: ScopeAPI) -> void:
	_api = api

func track(name: String, payload: Dictionary = {}) -> void:
	_queue.append({
		"name": name,
		"payload": payload,
		"occurred_at": Time.get_datetime_string_from_system(true, true)
	})

func flush() -> ScopeResponse:
	if _queue.is_empty():
		return ScopeResponse.ok(204)
	var batch: Array[Dictionary] = []
	for index in mini(100, _queue.size()):
		batch.append(_queue[index])
	var result := await _api.request_post("/analytics/events", {"events": batch})
	if result.success:
		_queue = _queue.slice(batch.size())
	return result

func queued_count() -> int:
	return _queue.size()
