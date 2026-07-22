class_name ScopeSession
extends RefCounted

signal logged_in
signal logged_out
signal session_changed

var access_token: String = ""
var current_user: ScopeUser = null
var logged_in: bool:
	get:
		return is_logged_in()

const SESSION_PATH := "user://scope/session.json"


func login(token: String, user: ScopeUser) -> void:
	access_token = token
	current_user = user
	_save()

	session_changed.emit()
	logged_in.emit()


func logout() -> void:
	access_token = ""
	current_user = null
	_delete_saved_session()

	session_changed.emit()
	logged_out.emit()


func is_logged_in() -> bool:
	return access_token != ""


func set_access_token(token: String) -> void:
	access_token = token
	session_changed.emit()
	_save()


func set_user(user: ScopeUser) -> void:
	current_user = user
	session_changed.emit()


func get_access_token() -> String:
	return access_token


func get_user() -> ScopeUser:
	return current_user


func restore() -> bool:
	if not FileAccess.file_exists(SESSION_PATH):
		return false
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or String(parsed.get("token", "")).is_empty():
		_delete_saved_session()
		return false
	access_token = String(parsed["token"])
	session_changed.emit()
	return true


func _save() -> void:
	if access_token.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://scope"))
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"token": access_token}))


func _delete_saved_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
