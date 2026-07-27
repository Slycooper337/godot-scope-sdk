class_name PlayerPanelService
extends RefCounted

func save_state(player: Node, sprite_file_id: int) -> ScopeResponse:
	if not Scope.is_logged_in() or player == null:
		return ScopeResponse.fail(0, "Player session is unavailable")
	var state: Dictionary = player.call("get_persistent_state") as Dictionary
	return await Scope.database.write("player_state", {
		"position": {"x": player.position.x, "y": player.position.y},
		"rotation": player.rotation,
		"sprite_file_id": sprite_file_id,
		"level": state.get("level", 1),
		"experience": state.get("experience", 0),
		"unspent_stat_points": state.get("unspent_stat_points", 0),
		"stats": state.get("stats", {}),
		"resources": state.get("resources", {})
	})

func load_state() -> ScopeResponse:
	if not Scope.is_logged_in():
		return ScopeResponse.fail(0, "Player session is unavailable")
	return await Scope.database.read("player_state")

func upload_sprite(path: String) -> ScopeResponse:
	return await Scope.storage.upload(path, {"visibility": "application"})

func download_sprite(file_id: int) -> ScopeResponse:
	return await Scope.storage.download(file_id)

func spend_stat_point(stat_name: String, transaction_id: String) -> ScopeResponse:
	return Scope.realtime.send_command("spend_stat_point", {
		"stat": stat_name,
		"transaction_id": transaction_id
	})
