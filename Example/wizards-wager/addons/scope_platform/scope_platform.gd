class_name ScopePlatform
extends Node

signal session_expired(message: String)

var session: ScopeSession
var api: ScopeAPI
var auth: ScopeAuth
var database: ScopeDatabase
var leaderboards: ScopeLeaderboards
var wizards_wager: ScopeWizardsWager
var storage: ScopeStorage
var notifications: ScopeNotifications
var friends: ScopeFriends
var messages: ScopeMessages
var achievements: ScopeAchievements
var analytics: ScopeAnalytics
var realtime: ScopeRealtime
var initialized: bool = false


func initialize() -> ScopeResponse:
	if initialized:
		return ScopeResponse.ok(200)

	if session == null:
		var http := HTTPRequest.new()
		http.name = "ScopeHTTPRequest"
		add_child(http)
		session = ScopeSession.new()
		api = ScopeAPI.new(http, session)
		api.authentication_failed.connect(_on_authentication_failed)
		auth = ScopeAuth.new(api, session)
		database = ScopeDatabase.new(api)
		leaderboards = ScopeLeaderboards.new(api)
		wizards_wager = ScopeWizardsWager.new(api)
		storage = ScopeStorage.new(api)
		notifications = ScopeNotifications.new(api)
		friends = ScopeFriends.new(api)
		messages = ScopeMessages.new(api)
		achievements = ScopeAchievements.new(api)
		analytics = ScopeAnalytics.new(api)
		realtime = ScopeRealtime.new(api)
		realtime.authentication_failed.connect(_on_realtime_authentication_failed)

	if session.restore():
		var validation := await auth.me()
		if not validation.success:
			if validation.status == 401 or validation.status == 403:
				session.logout()
			else:
				return validation

	initialized = true
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


func _on_authentication_failed(_status: int, message: String) -> void:
	if session == null or not session.is_logged_in():
		return
	if not initialized:
		session.logout()
		return
	if realtime != null:
		realtime.close()
	session.logout()
	session_expired.emit(message)


func _on_realtime_authentication_failed(message: String) -> void:
	_on_authentication_failed(401, message)
