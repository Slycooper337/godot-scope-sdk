class_name ScopeWizardsWager
extends RefCounted

var _api: ScopeAPI


func _init(api: ScopeAPI) -> void:
	_api = api


func place_bet(amount: int, choice: String) -> ScopeResponse:
	var normalized_choice := choice.to_lower()
	if normalized_choice != "heads" and normalized_choice != "tails":
		return ScopeResponse.fail(400, "Choice must be heads or tails")
	var result := await _api.request_post(
		"/wizards-wager/bets",
		{"amount": amount, "choice": normalized_choice}
	)
	if result.success:
		result.data = ScopeWizardsWagerBet.from_json(result.data)
	return result


func balance() -> ScopeResponse:
	var result := await _api.request_get("/wizards-wager/balance")
	if result.success:
		result.data = ScopeWizardsWagerWallet.from_json(result.data)
	return result


func current_bet() -> ScopeResponse:
	var result := await _api.request_get("/wizards-wager/bets/current")
	if result.success:
		result.data = ScopeWizardsWagerBet.from_json(result.data)
	return result

func history(limit: int = 50) -> ScopeResponse:
	var result := await _api.request_get("/wizards-wager/bets/history?limit=%d" % clampi(limit, 1, 100))
	if result.success:
		var bets: Array[ScopeWizardsWagerBet] = []
		if result.data is Array:
			for item in result.data: bets.append(ScopeWizardsWagerBet.from_json(item))
		result.data = bets
	return result

func player_profile(user_id: int) -> ScopeResponse:
	if user_id <= 0: return ScopeResponse.fail(400, "User is required")
	var result := await _api.request_get("/wizards-wager/players/%d" % user_id)
	if result.success: result.data = ScopeWizardsWagerPlayerProfile.from_json(result.data)
	return result
