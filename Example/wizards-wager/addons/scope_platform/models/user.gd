class_name ScopeUser
extends RefCounted

var id: int
var email: String
var username: String
var created_at: String


static func from_json(data: Dictionary) -> ScopeUser:
	var user := ScopeUser.new()

	user.id = int(data.get("id", 0))
	user.email = String(data.get("email", ""))
	user.username = String(data.get("username", ""))
	user.created_at = String(data.get("created_at", ""))

	return user
