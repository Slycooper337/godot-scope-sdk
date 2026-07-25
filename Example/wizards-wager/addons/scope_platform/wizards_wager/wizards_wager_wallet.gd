class_name ScopeWizardsWagerWallet
extends RefCounted

var application_id: String = ""
var user_id: int = 0
var gold: int = 0
var updated_at: String = ""


static func from_json(value: Variant) -> ScopeWizardsWagerWallet:
	var wallet := ScopeWizardsWagerWallet.new()
	if value is Dictionary:
		var data: Dictionary = value
		wallet.application_id = String(data.get("application_id", ""))
		wallet.user_id = int(data.get("user_id", 0))
		wallet.gold = int(data.get("gold", 0))
		wallet.updated_at = String(data.get("updated_at", ""))
	return wallet
