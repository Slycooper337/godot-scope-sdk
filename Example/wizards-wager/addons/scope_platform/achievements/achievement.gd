class_name ScopeAchievement
extends RefCounted
var id: int = 0
var application_id: String = ""
var key: String = ""
var name: String = ""
var description: String = ""
var points: int = 0
var target: int = 0
var data: Dictionary = {}
var progress: int = 0
var unlocked_at: String = ""
static func from_json(value: Variant) -> ScopeAchievement:
	var item := ScopeAchievement.new()
	if value is Dictionary:
		var source: Dictionary = value
		item.id = int(source.get("id", 0)); item.application_id = str(source.get("application_id", "")); item.key = str(source.get("key", "")); item.name = str(source.get("name", "")); item.description = str(source.get("description", "")); item.points = int(source.get("points", 0)); item.target = int(source.get("target", 0)); item.data = source.get("data", {}) if source.get("data", {}) is Dictionary else {}; item.progress = int(source.get("progress", 0)); item.unlocked_at = str(source.get("unlocked_at", ""))
	return item
