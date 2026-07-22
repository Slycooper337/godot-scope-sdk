class_name ScopeConfig
extends RefCounted

const API_URL_SETTING := "scope_platform/api_url"
const APPLICATION_ID_SETTING := "scope_platform/application_id"
const PUBLIC_KEY_SETTING := "scope_platform/public_key"
const REQUEST_TIMEOUT_SETTING := "scope_platform/request_timeout"
const DEBUG_SETTING := "scope_platform/debug_logging"


static func api_url() -> String:
	return String(ProjectSettings.get_setting(API_URL_SETTING, "http://localhost:8080")).trim_suffix("/")


static func application_id() -> String:
	return String(ProjectSettings.get_setting(APPLICATION_ID_SETTING, ""))


static func public_key() -> String:
	return String(ProjectSettings.get_setting(PUBLIC_KEY_SETTING, ""))


static func request_timeout() -> int:
	return int(ProjectSettings.get_setting(REQUEST_TIMEOUT_SETTING, 30))


static func debug_logging() -> bool:
	return bool(ProjectSettings.get_setting(DEBUG_SETTING, true))
