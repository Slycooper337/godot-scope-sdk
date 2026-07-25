class_name ScopeDatabase
extends RefCounted

var _api: ScopeAPI


func _init(api: ScopeAPI) -> void:
	_api = api


func read(key: String, record_scope: String = "user") -> ScopeResponse:
	return await _read(key, record_scope)


func write(key: String, data: Dictionary, record_scope: String = "user") -> ScopeResponse:
	return await _write(key, data, record_scope)


func remove(key: String, record_scope: String = "user") -> ScopeResponse:
	return await _remove(key, record_scope)


func read_shared(key: String) -> ScopeResponse:
	return await _read(key, "shared")


func write_shared(key: String, data: Dictionary) -> ScopeResponse:
	return await _write(key, data, "shared")


func remove_shared(key: String) -> ScopeResponse:
	return await _remove(key, "shared")


func _read(key: String, record_scope: String) -> ScopeResponse:
	var result := await _api.request_get(_endpoint(key, record_scope))
	if result.success:
		result.data = ScopeDatabaseRecord.from_json(result.data, key)
	return result


func _write(key: String, data: Dictionary, record_scope: String) -> ScopeResponse:
	var result := await _api.request_put(
		"/database/%s" % key.uri_encode(),
		{
			"scope": record_scope,
			"data": data
		}
	)
	if result.success:
		result.data = ScopeDatabaseRecord.from_json(result.data, key)
	return result


func _remove(key: String, record_scope: String) -> ScopeResponse:
	return await _api.request_delete(_endpoint(key, record_scope))


func _endpoint(key: String, record_scope: String) -> String:
	return "/database/%s?scope=%s" % [key.uri_encode(), record_scope]
