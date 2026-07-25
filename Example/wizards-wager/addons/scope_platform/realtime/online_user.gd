class_name ScopeOnlineUser
extends RefCounted

var user_id: int = 0
var connections: int = 0

static func from_json(value: Variant) -> ScopeOnlineUser:
	var user := ScopeOnlineUser.new()
	if value is Dictionary:
		var data: Dictionary = value
		user.user_id = int(data.get("user_id", 0))
		user.connections = int(data.get("connections", 0))
	return user
