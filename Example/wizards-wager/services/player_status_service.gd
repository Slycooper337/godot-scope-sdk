class_name PlayerStatusService
extends RefCounted

func request_target_status(user_id: int) -> ScopeResponse:
	if user_id <= 0:
		return ScopeResponse.fail(0, "Invalid player target")
	return Scope.realtime.send_command("get_player_status", {"player_id": user_id})
