class_name ScopeDatabase
extends RefCounted

var _api: ScopeAPI


func _init(api: ScopeAPI) -> void:
	_api = api


func get(key: String) -> ScopeResponse:
	return await _get(key, "user")


func set(key: String, data: Dictionary) -> ScopeResponse:
	return await _set(key, data, "user")


func delete(key: String) -> ScopeResponse:
	return await _delete(key, "user")


func get_shared(key: String) -> ScopeResponse:
	return await _get(key, "shared")


func set_shared(key: String, data: Dictionary) -> ScopeResponse:
	return await _set(key, data, "shared")


func delete_shared(key: String) -> ScopeResponse:
	return await _delete(key, "shared")


func _get(key: String, record_scope: String) -> ScopeResponse:
	var result := await _api.request_get(_endpoint(key, record_scope))
	if result.success:
		result.data = ScopeDatabaseRecord.from_json(result.data, key)
	return result


func _set(key: String, data: Dictionary, record_scope: String) -> ScopeResponse:
	var result := await _api.request_put(_endpoint(key, record_scope), {"data": data})
	if result.success:
		result.data = ScopeDatabaseRecord.from_json(result.data, key)
	return result


func _delete(key: String, record_scope: String) -> ScopeResponse:
	return await _api.request_delete(_endpoint(key, record_scope))


func _endpoint(key: String, record_scope: String) -> String:
	return "/database/%s?scope=%s" % [key.uri_encode(), record_scope]
