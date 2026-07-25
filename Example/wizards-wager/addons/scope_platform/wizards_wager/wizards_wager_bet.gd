class_name ScopeWizardsWagerBet
extends RefCounted

var id: int = 0
var application_id: String = ""
var user_id: int = 0
var amount: int = 0
var choice: String = ""
var result: String = ""
var status: String = ""
var created_at: String = ""
var resolves_at: String = ""
var job_at: String = ""
var server_time: String = ""
var resolved_at: String = ""


static func from_json(value: Variant) -> ScopeWizardsWagerBet:
	var bet := ScopeWizardsWagerBet.new()
	if value is Dictionary:
		var data: Dictionary = value
		bet.id = int(data.get("id", 0))
		bet.application_id = String(data.get("application_id", ""))
		bet.user_id = int(data.get("user_id", 0))
		bet.amount = int(data.get("amount", 0))
		bet.choice = _first_string(data, ["choice", "bet_on", "selection", "prediction", "side", "bet_choice", "wager_choice", "coin_side"])
		bet.result = _first_string(data, ["result", "outcome"])
		bet.status = String(data.get("status", ""))
		bet.created_at = String(data.get("created_at", ""))
		bet.resolved_at = _first_string(data, ["resolved_at", "completed_at"])
		bet.resolves_at = _first_string(data, ["resolves_at", "resolve_at", "scheduled_at", "scheduled_for", "next_flip_at", "job_run_at", "next_run_at", "job_at", "flip_at", "expires_at"])
		bet.job_at = bet.resolves_at
		bet.server_time = _first_string(data, ["server_time", "server_now", "current_time", "now", "timestamp"])
	return bet


static func _first_string(data: Dictionary, keys: Array[String]) -> String:
	for key in keys:
		if data.has(key) and not String(data[key]).is_empty():
			return String(data[key])
	return ""
