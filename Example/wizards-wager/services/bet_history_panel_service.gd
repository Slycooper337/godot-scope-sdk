class_name BetHistoryPanelService
extends RefCounted

func history(limit: int = 50) -> ScopeResponse:
	return await Scope.wizards_wager.history(limit)
