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
	var item := ScopeNotification.new()
	if value is Dictionary:
		var source: Dictionary = value
		item.id = int(source.get("id", 0)); item.application_id = str(source.get("application_id", "")); item.user_id = int(source.get("user_id", 0)); item.type = str(source.get("type", "")); item.title = str(source.get("title", "")); item.body = str(source.get("body", "")); item.data = source.get("data", {}) if source.get("data", {}) is Dictionary else {}; item.created_at = str(source.get("created_at", "")); item.read_at = str(source.get("read_at", ""))
	return item
