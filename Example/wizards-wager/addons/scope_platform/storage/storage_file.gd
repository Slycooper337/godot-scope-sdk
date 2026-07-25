class_name ScopeStorageFile
extends RefCounted
var id: int = 0
var application_id: String = ""
var user_id: int = 0
var name: String = ""
var mime_type: String = ""
var size_bytes: int = 0
var visibility: String = "private"
var created_at: String = ""
static func from_json(value: Variant) -> ScopeStorageFile:
	var file := ScopeStorageFile.new()
	if value is Dictionary:
		var data: Dictionary = value
		file.id = int(data.get("id", 0)); file.application_id = str(data.get("application_id", "")); file.user_id = int(data.get("user_id", 0)); file.name = str(data.get("name", "")); file.mime_type = str(data.get("mime_type", "")); file.size_bytes = int(data.get("size_bytes", 0)); file.visibility = str(data.get("visibility", "private")); file.created_at = str(data.get("created_at", ""))
	return file
