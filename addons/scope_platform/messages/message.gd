class_name ScopeMessage
extends RefCounted

var id: int = 0
var sender_id: int = 0
var sender_username: String = ""
var recipient_id: int = 0
var text: String = ""
var created_at: String = ""

static func from_json(value: Variant) -> ScopeMessage:
	var message := ScopeMessage.new()
	if value is Dictionary:
		var data: Dictionary = value
		message.id = int(data.get("id", 0))
		message.sender_id = int(data.get("sender_id", 0))
		message.sender_username = str(data.get("sender_username", data.get("username", "")))
		message.recipient_id = int(data.get("recipient_id", 0))
		message.text = str(data.get("text", ""))
		message.created_at = str(data.get("created_at", ""))
	return message
