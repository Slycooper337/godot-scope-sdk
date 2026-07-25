class_name ScopeNotification
extends RefCounted

var id: int = 0
var application_id: String = ""
var user_id: int = 0
var type: String = ""
var title: String = ""
var body: String = ""
var data: Dictionary = {}
var created_at: String = ""
var read_at: String = ""

static func from_json(value: Variant) -> ScopeNotification:
	var notification := ScopeNotification.new()
	if value is Dictionary:
		var source: Dictionary = value
		notification.id = int(source.get("id", 0))
		notification.application_id = str(source.get("application_id", ""))
		notification.user_id = int(source.get("user_id", 0))
		notification.type = str(source.get("type", ""))
		notification.title = str(source.get("title", ""))
		notification.body = str(source.get("body", ""))
		notification.data = source.get("data", {}) if source.get("data", {}) is Dictionary else {}
		notification.created_at = str(source.get("created_at", ""))
		notification.read_at = str(source.get("read_at", ""))
	return notification
