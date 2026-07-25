class_name ScopeFriend
extends RefCounted

var id: int = 0
var user_id: int = 0
var username: String = ""
var status: String = ""
var created_at: String = ""
var updated_at: String = ""

static func from_json(value: Variant) -> ScopeFriend:
	var friend := ScopeFriend.new()
	if value is Dictionary:
		var data: Dictionary = value
		friend.id = int(data.get("id", 0))
		friend.user_id = int(data.get("user_id", 0))
		friend.username = str(data.get("username", ""))
		friend.status = str(data.get("status", ""))
		friend.created_at = str(data.get("created_at", ""))
		friend.updated_at = str(data.get("updated_at", ""))
	return friend
