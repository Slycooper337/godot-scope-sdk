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
	var achievement := ScopeAchievement.new()
	if value is Dictionary:
		var source: Dictionary = value
		achievement.id = int(source.get("id", 0))
		achievement.application_id = str(source.get("application_id", ""))
		achievement.key = str(source.get("key", ""))
		achievement.name = str(source.get("name", ""))
		achievement.description = str(source.get("description", ""))
		achievement.points = int(source.get("points", 0))
		achievement.target = int(source.get("target", 0))
		achievement.data = source.get("data", {}) if source.get("data", {}) is Dictionary else {}
		achievement.progress = int(source.get("progress", 0))
		achievement.unlocked_at = str(source.get("unlocked_at", ""))
	return achievement
