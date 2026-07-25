class_name ScopeAPI
extends RefCounted

var _http: HTTPRequest
var _session: ScopeSession
var _request_active: bool = false
signal _request_released


func _init(http: HTTPRequest, session: ScopeSession) -> void:
	_http = http
	_session = session
	_http.timeout = float(ScopeConfig.request_timeout())


func request_get(endpoint: String) -> ScopeResponse:
	return await _request(
		HTTPClient.METHOD_GET,
		endpoint
	)


func request_post(endpoint: String, body: Dictionary = {}) -> ScopeResponse:
	return await _request(
		HTTPClient.METHOD_POST,
		endpoint,
		body
	)


func request_put(endpoint: String, body: Dictionary = {}) -> ScopeResponse:
	return await _request(
		HTTPClient.METHOD_PUT,
		endpoint,
		body
	)


func request_patch(endpoint: String, body: Dictionary = {}) -> ScopeResponse:
	return await _request(
		HTTPClient.METHOD_PATCH,
		endpoint,
		body
	)


func request_delete(endpoint: String) -> ScopeResponse:
	return await _request(
		HTTPClient.METHOD_DELETE,
		endpoint
	)


func request_multipart_file(endpoint: String, file_path: String, fields: Dictionary = {}) -> ScopeResponse:
	var file_bytes := FileAccess.get_file_as_bytes(file_path)
	if file_bytes.is_empty() and not FileAccess.file_exists(file_path):
		return ScopeResponse.fail(400, "File could not be read")
	var boundary := "ScopeBoundary%d" % Time.get_ticks_msec()
	var filename := file_path.get_file()
	var body := PackedByteArray()
	for field_name in fields:
		body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
		body.append_array(("Content-Disposition: form-data; name=\"%s\"\r\n\r\n" % field_name).to_utf8_buffer())
		body.append_array(("%s\r\n" % str(fields[field_name])).to_utf8_buffer())
	body.append_array(("--%s\r\n" % boundary).to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"file\"; filename=\"%s\"\r\n" % filename).to_utf8_buffer())
	body.append_array("Content-Type: application/octet-stream\r\n\r\n".to_utf8_buffer())
	body.append_array(file_bytes)
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	return await _request_raw(
		HTTPClient.METHOD_POST,
		endpoint,
		"multipart/form-data; boundary=%s" % boundary,
		body,
		true
	)


func request_bytes(endpoint: String) -> ScopeResponse:
	return await _request_raw(
		HTTPClient.METHOD_GET,
		endpoint,
		"",
		PackedByteArray(),
		false
	)


func _request(
	method: HTTPClient.Method,
	endpoint: String,
	body: Dictionary = {}
) -> ScopeResponse:
	await _acquire_request()
	var result := await _request_unlocked(method, endpoint, body)
	_release_request()
	return result


func _acquire_request() -> void:
	while _request_active:
		await _request_released
	_request_active = true


func _release_request() -> void:
	_request_active = false
	_request_released.emit()


func _request_unlocked(
	method: HTTPClient.Method,
	endpoint: String,
	body: Dictionary = {}
) -> ScopeResponse:

	var headers: PackedStringArray = PackedStringArray()
	headers.append("Content-Type: application/json")
	if not ScopeConfig.application_id().is_empty():
		headers.append("X-Scope-Application-ID: " + ScopeConfig.application_id())
	if not ScopeConfig.public_key().is_empty():
		headers.append("X-Scope-Public-Key: " + ScopeConfig.public_key())

	if _session.is_logged_in():
		headers.append(
			"Authorization: Bearer " + _session.get_access_token()
		)

	var json := ""

	if method != HTTPClient.METHOD_GET and !body.is_empty():
		json = JSON.stringify(body)

	var err: Error = _http.request(
		_build_url(endpoint),
		headers,
		method,
		json
	)
	if ScopeConfig.debug_logging():
		print("[Scope] method=%d url=%s" % [method, _build_url(endpoint)])

	if err != OK:
		return ScopeResponse.fail(
			0,
			error_string(err)
		)

	var response: Array = await _http.request_completed

	var response_code: int = response[1]
	var body_bytes: PackedByteArray = response[3]
	var response_body: String = body_bytes.get_string_from_utf8()
	if ScopeConfig.debug_logging():
		print("[Scope] response %d" % response_code)

	var parsed: Variant = null

	if not response_body.is_empty():
		var response_json := JSON.new()
		if response_json.parse(response_body) == OK:
			parsed = response_json.data
		else:
			parsed = response_body

	if response_code >= 200 and response_code < 300:
		return ScopeResponse.ok(
			response_code,
			parsed
		)

	return ScopeResponse.fail(
		response_code,
		ScopeResponse.error_message(parsed, "HTTP request failed (%d)" % response_code)
	)


func _build_url(endpoint: String) -> String:
	if endpoint.begins_with("http://") or endpoint.begins_with("https://"):
		return endpoint
	return ScopeConfig.api_url() + "/" + endpoint.trim_prefix("/")


func _request_raw(method: HTTPClient.Method, endpoint: String, content_type: String, body: PackedByteArray, parse_json: bool) -> ScopeResponse:
	await _acquire_request()
	var result := await _request_raw_unlocked(method, endpoint, content_type, body, parse_json)
	_release_request()
	return result


func _request_raw_unlocked(method: HTTPClient.Method, endpoint: String, content_type: String, body: PackedByteArray, parse_json: bool) -> ScopeResponse:
	var headers: PackedStringArray = PackedStringArray()
	if not content_type.is_empty():
		headers.append("Content-Type: " + content_type)
	if not ScopeConfig.application_id().is_empty():
		headers.append("X-Scope-Application-ID: " + ScopeConfig.application_id())
	if not ScopeConfig.public_key().is_empty():
		headers.append("X-Scope-Public-Key: " + ScopeConfig.public_key())
	if _session.is_logged_in():
		headers.append("Authorization: Bearer " + _session.get_access_token())
	var err := _http.request_raw(_build_url(endpoint), headers, method, body)
	if err != OK:
		return ScopeResponse.fail(0, error_string(err))
	var response: Array = await _http.request_completed
	var response_code: int = response[1]
	var response_bytes: PackedByteArray = response[3]
	if response_code >= 200 and response_code < 300:
		if parse_json:
			var text := response_bytes.get_string_from_utf8()
			var parsed := JSON.parse_string(text) if not text.is_empty() else null
			return ScopeResponse.ok(response_code, parsed)
		return ScopeResponse.ok(response_code, response_bytes)
	var error_text := response_bytes.get_string_from_utf8()
	var parsed_error: Variant = null
	if not error_text.is_empty():
		var error_json := JSON.new()
		if error_json.parse(error_text) == OK:
			parsed_error = error_json.data
	return ScopeResponse.fail(response_code, ScopeResponse.error_message(parsed_error, error_text))
