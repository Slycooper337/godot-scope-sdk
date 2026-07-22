class_name ScopePlatform
extends Node

var session: ScopeSession
var api: ScopeAPI
var auth: ScopeAuth
var database: ScopeDatabase
var ready: bool = false


func initialize() -> ScopeResponse:
	if ready:
		return ScopeResponse.ok(200)

	var http := HTTPRequest.new()
	http.name = "ScopeHTTPRequest"
	add_child(http)
	session = ScopeSession.new()
	api = ScopeAPI.new(http, session)
	auth = ScopeAuth.new(api, session)
	database = ScopeDatabase.new(api)

	if session.restore():
		var validation := await auth.me()
		if not validation.success:
			if validation.status == 401 or validation.status == 403:
				session.logout()
			else:
				return validation

	ready = true
	return ScopeResponse.ok(200)


func login(email: String, password: String) -> ScopeResponse:
	return await auth.login(email, password)


func register(email: String, username: String, password: String) -> ScopeResponse:
	return await auth.register(email, username, password)


func logout() -> void:
	auth.logout()


func me() -> ScopeResponse:
	return await auth.me()


func is_logged_in() -> bool:
	return session != null and session.is_logged_in()


func current_user() -> ScopeUser:
	return session.get_user() if session != null else null
