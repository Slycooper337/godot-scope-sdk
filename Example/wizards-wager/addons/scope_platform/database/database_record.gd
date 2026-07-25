class_name ScopeDatabaseRecord
extends RefCounted

var key: String = ""
var scope: String = "user"
var data: Dictionary = {}
var created_at: String = ""
var updated_at: String = ""


static func from_json(value: Variant, fallback_key: String = "") -> ScopeDatabaseRecord:
	var record := ScopeDatabaseRecord.new()
	if not value is Dictionary:
		record.key = fallback_key
		record.data = {"value": value}
		return record
	var dictionary: Dictionary = value
	record.key = String(dictionary.get("key", fallback_key))
	record.scope = String(dictionary.get("scope", "user"))
	record.data = dictionary.get("data", {}) if dictionary.get("data", {}) is Dictionary else {}
	record.created_at = String(dictionary.get("created_at", ""))
	record.updated_at = String(dictionary.get("updated_at", ""))
	return record
