class_name ScopeResponse
extends RefCounted

var success: bool = false
var status: int = 0
var data: Variant = null
var error: String = ""
var status_code: int:
	get:
		return status
var message: String:
	get:
		return error


static func ok(status: int, data: Variant = null) -> ScopeResponse:
	var response := ScopeResponse.new()

	response.success = true
	response.status = status
	response.data = data

	return response


static func fail(status: int, error: String) -> ScopeResponse:
	var response := ScopeResponse.new()

	response.success = false
	response.status = status
	response.error = error

	return response


static func error_message(payload: Variant, fallback: String = "Request failed") -> String:
	if payload is Dictionary:
		var dictionary: Dictionary = payload
		for key in ["error", "message", "detail"]:
			if dictionary.has(key) and not String(dictionary[key]).is_empty():
				return String(dictionary[key])
	if payload != null and not String(payload).is_empty():
		return String(payload)
	return fallback


func is_success() -> bool:
	return success


func has_data() -> bool:
	return data != null
