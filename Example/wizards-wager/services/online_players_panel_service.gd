class_name OnlinePlayersPanelService
extends RefCounted

func online_players() -> ScopeResponse:
	return await Scope.realtime.online()
