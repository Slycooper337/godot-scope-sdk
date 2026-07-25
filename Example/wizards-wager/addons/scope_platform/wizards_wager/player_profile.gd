class_name ScopeWizardsWagerPlayerProfile
extends RefCounted
var user_id: int = 0
var username: String = ""
var gold: int = 0
var online: bool = false
static func from_json(value: Variant) -> ScopeWizardsWagerPlayerProfile:
	var profile := ScopeWizardsWagerPlayerProfile.new()
	if value is Dictionary:
		var data: Dictionary = value
		profile.user_id = int(data.get("user_id", 0)); profile.username = str(data.get("username", "")); profile.gold = int(data.get("gold", 0)); profile.online = bool(data.get("online", false))
	return profile
