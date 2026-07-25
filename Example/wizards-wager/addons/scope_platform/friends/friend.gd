class_name ScopeFriend
extends RefCounted
var id: int = 0
var user_id: int = 0
var username: String = ""
var status: String = ""
var created_at: String = ""
var updated_at: String = ""
static func from_json(value: Variant) -> ScopeFriend:
	var item := ScopeFriend.new()
	if value is Dictionary:
		var data: Dictionary = value
		item.id = int(data.get("id", 0)); item.user_id = int(data.get("user_id", 0)); item.username = str(data.get("username", "")); item.status = str(data.get("status", "")); item.created_at = str(data.get("created_at", "")); item.updated_at = str(data.get("updated_at", ""))
	return item
