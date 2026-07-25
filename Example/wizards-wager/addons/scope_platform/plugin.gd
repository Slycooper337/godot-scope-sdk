@tool
extends EditorPlugin

const API_URL_SETTING := "scope_platform/api_url"
const APPLICATION_ID_SETTING := "scope_platform/application_id"
const PUBLIC_KEY_SETTING := "scope_platform/public_key"
const REQUEST_TIMEOUT_SETTING := "scope_platform/request_timeout"
const DEBUG_SETTING := "scope_platform/debug_logging"
const AUTOLOAD_NAME := "Scope"
const AUTOLOAD_PATH := "res://addons/scope_platform/scope_platform.gd"


func _enter_tree() -> void:
	_register_setting(
		API_URL_SETTING,
		"http://localhost:8080",
		TYPE_STRING
	)

	_register_setting(APPLICATION_ID_SETTING, "", TYPE_STRING)
	_register_setting(PUBLIC_KEY_SETTING, "", TYPE_STRING)

	_register_setting(
		REQUEST_TIMEOUT_SETTING,
		30,
		TYPE_INT
	)

	_register_setting(
		DEBUG_SETTING,
		true,
		TYPE_BOOL
	)

	if not ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _exit_tree() -> void:
	if ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)


func _register_setting(name: String, default_value: Variant, type: int) -> void:
	var info := {
		"name": name,
		"type": type
	}

	ProjectSettings.add_property_info(info)
	if not ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default_value)
		ProjectSettings.set_initial_value(name, default_value)
	ProjectSettings.save()
