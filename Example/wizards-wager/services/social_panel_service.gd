class_name SocialPanelService
extends RefCounted

func friends() -> ScopeResponse:
	return await Scope.friends.list()

func notifications() -> ScopeResponse:
	return await Scope.notifications.list(true)

func send_friend_request(username: String) -> ScopeResponse:
	return await Scope.friends.send_request(username)

func send_message(recipient_id: int, text: String) -> ScopeResponse:
	return await Scope.messages.send(recipient_id, text)

func messages(user_id: int, limit: int = 50) -> ScopeResponse:
	return await Scope.messages.list(user_id, limit)
