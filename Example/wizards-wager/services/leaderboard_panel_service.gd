class_name LeaderboardPanelService
extends RefCounted

func top(metric: String, limit: int = 10) -> ScopeResponse:
	return await Scope.leaderboards.top(metric, limit)

func rank(metric: String) -> ScopeResponse:
	return await Scope.leaderboards.rank(metric)
