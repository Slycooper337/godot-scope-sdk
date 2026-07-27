class_name BettingPanelService
extends RefCounted

func balance() -> ScopeResponse:
	return await Scope.wizards_wager.balance()

func current_bet() -> ScopeResponse:
	return await Scope.wizards_wager.current_bet()

func place_bet(amount: int, choice: String) -> ScopeResponse:
	return await Scope.wizards_wager.place_bet(amount, choice)
