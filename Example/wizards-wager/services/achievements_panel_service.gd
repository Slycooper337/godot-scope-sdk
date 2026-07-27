class_name AchievementsPanelService
extends RefCounted

func list() -> ScopeResponse:
	return await Scope.achievements.list()
