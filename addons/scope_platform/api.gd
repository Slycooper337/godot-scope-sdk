class_name ScopeAPI
extends RefCounted

var _http: HTTPRequest
var _session: ScopeSession


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


func _request(
	method: HTTPClient.Method,
	endpoint: String,
	body: Dictionary = {}
) -> ScopeResponse:

	var headers: PackedStringArray = PackedStringArray()
	headers.append("Content-Type: application/json")
	if not _is_auth_endpoint(endpoint):
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

	if !response_body.is_empty():
		parsed = JSON.parse_string(response_body)

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


func _is_auth_endpoint(endpoint: String) -> bool:
	return endpoint.trim_prefix("/").begins_with("auth/")
