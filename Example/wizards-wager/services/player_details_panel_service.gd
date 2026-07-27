class_name PlayerDetailsPanelService
extends RefCounted

func profile(user_id: int) -> ScopeResponse:
	return await Scope.wizards_wager.player_profile(user_id)

func friends(username: String) -> ScopeResponse:
	return await Scope.friends.send_request(username)

func messages(user_id: int, limit: int = 50) -> ScopeResponse:
	return await Scope.messages.list(user_id, limit)

func send_message(user_id: int, text: String) -> ScopeResponse:
	return await Scope.messages.send(user_id, text)
