class_name ScopeAuth
extends RefCounted

var _api: ScopeAPI
var _session: ScopeSession


func _init(api: ScopeAPI, session: ScopeSession) -> void:
	_api = api
	_session = session


func register(email: String, username: String, password: String) -> ScopeResponse:
	var result := await _api.request_post(
		"/auth/register",
		{
			"email": email,
			"username": username,
			"password": password
		}
	)

	if result.success:
		var data: Dictionary = result.data

		var user := ScopeUser.from_json(data.get("user", data))

		_session.login(
			data["token"],
			user
		)
		result.data = user

	return result


func login(email: String, password: String) -> ScopeResponse:
	var result := await _api.request_post(
		"/auth/login",
		{
			"email": email,
			"password": password
		}
	)

	if result.success:
		var data: Dictionary = result.data

		var user := ScopeUser.from_json(data.get("user", data))

		_session.login(
			data["token"],
			user
		)
		result.data = user

	return result


func me() -> ScopeResponse:
	var result := await _api.request_get("/auth/me")

	if result.success:
		var user := ScopeUser.from_json(result.data)
		_session.set_user(user)
		result.data = user

	return result


func username_available(username: String) -> ScopeResponse:
	return await _api.request_get(
		"/auth/username-available?username=%s" % username.uri_encode()
	)


func logout() -> void:
	_session.logout()
