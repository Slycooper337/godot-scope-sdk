extends Node2D

const LEADERBOARD_METRIC := "gold"
const REFRESH_SECONDS := 10.0
const CHOICE_CACHE_PATH := "user://wizards_wager/active_choice.json"
const SPRITE_CACHE_PATH := "user://wizards_wager/sprite_file.json"
const PLAYER_STATE_KEY := "player_state"
const MOVEMENT_CHANNEL := "match/movement-test"
const MOVEMENT_UPDATE_INTERVAL := 0.1
const WORLD_MAP_ID := "forest"

var active_bet: ScopeWizardsWagerBet = null
var refresh_elapsed := 0.0
var refreshing := false
var bet_end_unix: int = 0
var selected_choice: String = ""
var server_offset_seconds: int = 0
var realtime_subscribed := false
var selected_player_id: int = 0
var movement_elapsed: float = 0.0
var last_sent_position: Vector2 = Vector2.ZERO
var has_sent_position: bool = false
var remote_players: Dictionary = {}
var realtime_was_connected: bool = false
var movement_packets_sent: int = 0
var movement_packets_received: int = 0
var sprite_file_id: int = 0
var remote_sprite_file_ids: Dictionary = {}
var remote_sprite_loading: Dictionary = {}
var movable_panels: Array[Control] = []
var dragging_panel: Control = null
var drag_offset := Vector2.ZERO
var player_state_save_elapsed := 0.0
var saving_player_state := false
var world_join_requested := false
var world_map_id := ""
var last_world_sequence := 0
var world_attack_sequence := 0
var world_attack_prefix := ""
var pending_attack_mobs: Dictionary = {}
var player_stats_request_sent := false
var stat_transaction_sequence := 0
var pending_stat_transactions: Dictionary = {}
var authoritative_mobs: Dictionary = {}
var server_enemy_templates: Dictionary = {}
var player_game_over_finished := false
var player_revive_received := false
var pending_player_revive_data: Dictionary = {}


func _ready() -> void:
	_prepare_server_enemy_template()
	world_attack_prefix = "%s-%d" % [str(Scope.session.current_user.id), Time.get_ticks_usec()]
	$CanvasLayer/PlayerPanel/VBoxContainer/Username.text = "Player: " + Scope.session.current_user.username
	$Player.connect("level_up", _on_player_level_up)
	$Player.connect("stats_changed", _on_player_stats_changed)
	$Player.connect("game_over_finished", _on_player_game_over_finished)
	$CanvasLayer/PlayerPanel/VBoxContainer/StrengthButton.pressed.connect(_on_stat_button_pressed.bind("str"))
	$CanvasLayer/PlayerPanel/VBoxContainer/AgilityButton.pressed.connect(_on_stat_button_pressed.bind("agi"))
	$CanvasLayer/PlayerPanel/VBoxContainer/IntelligenceButton.pressed.connect(_on_stat_button_pressed.bind("int"))
	$CanvasLayer/PlayerPanel/VBoxContainer/LuckButton.pressed.connect(_on_stat_button_pressed.bind("luk"))
	$CanvasLayer/PlayerPanel/VBoxContainer/EnduranceButton.pressed.connect(_on_stat_button_pressed.bind("end"))
	selected_choice = _load_choice()
	sprite_file_id = _load_sprite_file_id()
	if sprite_file_id > 0:
		await _restore_local_sprite()
	await _restore_player_state()
	await _refresh_game_state()
	await _load_leaderboard()
	await _load_achievements()
	await _load_social()
	await _load_online_players()
	$CanvasLayer/SocialPanel/VBoxContainer/FriendActions/AddFriend.pressed.connect(_on_add_friend_pressed)
	$CanvasLayer/SocialPanel/VBoxContainer/MessageActions/SendMessage.pressed.connect(_on_send_message_pressed)
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Friend.pressed.connect(_on_profile_add_friend_pressed)
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/SendMessage.pressed.connect(_on_profile_send_message_pressed)
	$CanvasLayer/PlayerPanel/VBoxContainer/ChangeSprite.pressed.connect(_on_change_sprite_pressed)
	var menu: PopupMenu = $CanvasLayer/Controls/HBoxContainer/MenuButton.get_popup()
	menu.id_pressed.connect(_on_menu_option_selected)
	movable_panels = [$CanvasLayer/PlayerPanel, $CanvasLayer/LeaderboardPanel, $CanvasLayer/SocialPanel, $CanvasLayer/OnlinePanel, $CanvasLayer/AchievementsPanel, $CanvasLayer/BettingPanel, $CanvasLayer/BetHistoryPanel, $CanvasLayer/PlayerDetailsPanel]
	for panel: Control in movable_panels:
		var close_button: Button = panel.get_node_or_null("VBoxContainer/Close") as Button
		if close_button != null:
			close_button.pressed.connect(_close_window.bind(panel))
	_hide_all_windows()
	$CanvasLayer/CharacterFileDialog.file_selected.connect(_on_character_file_selected)
	_connect_realtime()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for panel: Control in movable_panels:
				if not panel.visible:
					continue
				var title: Control = panel.get_node_or_null("VBoxContainer/Title") as Control
				if title != null and title.get_global_rect().has_point(event.position):
					dragging_panel = panel
					drag_offset = event.position - panel.position
					panel.move_to_front()
					break
		else:
			dragging_panel = null
	elif event is InputEventMouseMotion and dragging_panel != null:
		dragging_panel.position = event.position - drag_offset


func _on_menu_option_selected(option_id: int) -> void:
	_hide_all_windows()
	match option_id:
		0:
			_show_window($CanvasLayer/PlayerPanel)
		1:
			_show_window($CanvasLayer/LeaderboardPanel)
		2:
			_show_window($CanvasLayer/SocialPanel)
		3:
			_show_window($CanvasLayer/OnlinePanel)
		4:
			_show_window($CanvasLayer/AchievementsPanel)
		5:
			_show_window($CanvasLayer/BettingPanel)
			_show_window($CanvasLayer/BetHistoryPanel)


func _hide_all_windows() -> void:
	for panel: Control in movable_panels:
		panel.visible = false


func _show_window(panel: Control) -> void:
	panel.visible = true
	panel.move_to_front()


func _close_window(panel: Control) -> void:
	panel.visible = false
	if panel == $CanvasLayer/PlayerDetailsPanel:
		selected_player_id = 0
	if dragging_panel == panel:
		dragging_panel = null


func _process(delta: float) -> void:
	refresh_elapsed += delta
	_update_player_status()
	player_state_save_elapsed += delta
	if player_state_save_elapsed >= 5.0 and not saving_player_state and bool($Player.call("is_state_dirty")):
		player_state_save_elapsed = 0.0
		saving_player_state = true
		await _save_player_state()
		saving_player_state = false
	Scope.realtime.poll()
	_process_movement_sync(delta)
	$CanvasLayer/OnlinePanel/VBoxContainer/Online.text = "You: online" if Scope.realtime.connected else "You: offline"
	if Scope.realtime.connected and not realtime_was_connected:
		realtime_was_connected = true
	elif not Scope.realtime.connected and realtime_was_connected:
		realtime_was_connected = false
		realtime_subscribed = false
		world_join_requested = false
		world_map_id = ""
		last_world_sequence = 0
		pending_attack_mobs.clear()
		player_stats_request_sent = false
		pending_stat_transactions.clear()
		_clear_authoritative_mobs()
		_clear_remote_players()
	if not realtime_subscribed and Scope.realtime.is_open():
		Scope.realtime.subscribe("leaderboard/gold")
		Scope.realtime.subscribe("player/%d" % Scope.session.current_user.id)
		Scope.realtime.subscribe("presence")
		Scope.realtime.subscribe(MOVEMENT_CHANNEL)
		realtime_subscribed = true
	if not world_join_requested and Scope.realtime.is_open():
		var join_result := Scope.realtime.send_command("join_area", {"map_id": WORLD_MAP_ID})
		if join_result.success:
			world_join_requested = true
	if not player_stats_request_sent and Scope.realtime.is_open():
		var stats_result := Scope.realtime.send_command("get_player_stats", {})
		if stats_result.success:
			player_stats_request_sent = true
	var countdown_finished := _update_countdown()
	if (countdown_finished or refresh_elapsed >= REFRESH_SECONDS) and not refreshing:
		refresh_elapsed = 0.0
		_refresh_game_state()


func _refresh_game_state() -> void:
	refreshing = true
	var wallet_result := await Scope.wizards_wager.balance()
	if wallet_result.success:
		var wallet: ScopeWizardsWagerWallet = wallet_result.data
		$CanvasLayer/PlayerPanel/VBoxContainer/Gold.text = "GOLD: %d" % wallet.gold
	else:
		_show_error(wallet_result.error)

	var bet_result := await Scope.wizards_wager.current_bet()
	if bet_result.success:
		active_bet = bet_result.data
		_sync_server_clock(active_bet.server_time)
		if active_bet.choice.is_empty() and not selected_choice.is_empty():
			active_bet.choice = selected_choice
		if not active_bet.choice.is_empty():
			selected_choice = active_bet.choice
			_save_choice(selected_choice)
		bet_end_unix = _get_bet_end_unix(active_bet)
		var choice_text: String = active_bet.choice.capitalize() if not active_bet.choice.is_empty() else "selection unavailable"
		$CanvasLayer/BettingPanel/VBoxContainer/BetStatus.text = "Bet: %d gold on %s (%s)" % [active_bet.amount, choice_text, active_bet.status]
		$CanvasLayer/BettingPanel/VBoxContainer/PlaceBet.disabled = true
	elif bet_result.status == 404:
		active_bet = null
		selected_choice = ""
		_clear_choice()
		bet_end_unix = 0
		$CanvasLayer/BettingPanel/VBoxContainer/BetStatus.text = "No active bet"
		$CanvasLayer/BettingPanel/VBoxContainer/PlaceBet.disabled = false
	else:
		_show_error(bet_result.error)
	await _load_bet_history()
	refreshing = false


func _load_leaderboard() -> void:
	var result := await Scope.leaderboards.top(LEADERBOARD_METRIC, 10)
	if result.success:
		$CanvasLayer/LeaderboardPanel/VBoxContainer/Leaderboard.text = _format_leaderboard(result.data)
		_populate_leaderboard_buttons(result.data)
	else:
		_show_error(result.error)
	var rank_result := await Scope.leaderboards.rank(LEADERBOARD_METRIC)
	if rank_result.success:
		$CanvasLayer/PlayerPanel/VBoxContainer/Rank.text = "Your rank: %s" % _rank_text(rank_result.data)
	else:
		$CanvasLayer/PlayerPanel/VBoxContainer/Rank.text = "Your rank: unavailable"


func _load_bet_history() -> void:
	var result := await Scope.wizards_wager.history(50)
	if not result.success:
		$CanvasLayer/BetHistoryPanel/VBoxContainer/History.text = "Bet history unavailable: " + result.error
		return
	var bets: Array[ScopeWizardsWagerBet] = result.data
	if bets.is_empty():
		$CanvasLayer/BetHistoryPanel/VBoxContainer/History.text = "No completed bets yet."
		return
	var lines: Array[String] = []
	for bet: ScopeWizardsWagerBet in bets:
		var choice_text: String = bet.choice.capitalize() if not bet.choice.is_empty() else "Unknown"
		var result_text: String = bet.result.capitalize() if not bet.result.is_empty() else "Unknown"
		var status_text: String = bet.status.capitalize() if not bet.status.is_empty() else "Unknown"
		lines.append("%d gold on %s - %s (%s)" % [bet.amount, choice_text, status_text, result_text])
	$CanvasLayer/BetHistoryPanel/VBoxContainer/History.text = "\n".join(lines)


func _load_achievements() -> void:
	var result := await Scope.achievements.list()
	if not result.success:
		$CanvasLayer/AchievementsPanel/VBoxContainer/Achievements.text = "Unable to load achievements: " + result.error
		return
	var lines: Array[String] = []
	var achievements: Array[ScopeAchievement] = result.data
	for achievement: ScopeAchievement in achievements:
		var state: String = "%d/%d" % [achievement.progress, achievement.target]
		if not achievement.unlocked_at.is_empty():
			state = "unlocked"
		lines.append("%s - %s (%s)" % [achievement.name, achievement.description, state])
	$CanvasLayer/AchievementsPanel/VBoxContainer/Achievements.text = "\n".join(lines) if not lines.is_empty() else "No achievements yet."


func _load_social() -> void:
	var notifications_result := await Scope.notifications.list(true)
	if notifications_result.success:
		var messages: Array[String] = ["Unread messages"]
		var notifications: Array[ScopeNotification] = notifications_result.data
		for notification: ScopeNotification in notifications:
			messages.append("%s: %s" % [notification.title, notification.body])
		$CanvasLayer/SocialPanel/VBoxContainer/Messages.text = "\n".join(messages) if messages.size() > 1 else "No unread messages."
	else:
		$CanvasLayer/SocialPanel/VBoxContainer/Messages.text = "Messages unavailable: " + notifications_result.error

	var friends_result := await Scope.friends.list()
	if friends_result.success:
		var friends: Array[String] = ["Friends"]
		var friend_items: Array[ScopeFriend] = friends_result.data
		for friend: ScopeFriend in friend_items:
			friends.append("%s (%s)" % [friend.username, friend.status])
		$CanvasLayer/SocialPanel/VBoxContainer/Friends.text = "\n".join(friends) if friends.size() > 1 else "No friends yet."
	else:
		$CanvasLayer/SocialPanel/VBoxContainer/Friends.text = "Friends unavailable: " + friends_result.error


func _load_online_players() -> void:
	var result := await Scope.realtime.online()
	if not result.success:
		$CanvasLayer/OnlinePanel/VBoxContainer/OnlinePlayers.text = "Online players unavailable: " + result.error
		return
	var users: Array[ScopeOnlineUser] = result.data
	var lines: Array[String] = ["Online players"]
	_clear_buttons($CanvasLayer/OnlinePanel/VBoxContainer/OnlineButtons)
	for user: ScopeOnlineUser in users:
		lines.append("Player %d (%d connection%s)" % [user.user_id, user.connections, "" if user.connections == 1 else "s"])
		_add_player_button($CanvasLayer/OnlinePanel/VBoxContainer/OnlineButtons, "Player %d (%d connection%s)" % [user.user_id, user.connections, "" if user.connections == 1 else "s"], user.user_id)
	$CanvasLayer/OnlinePanel/VBoxContainer/OnlinePlayers.text = "\n".join(lines) if users.size() > 0 else "No players online."


func _connect_realtime() -> void:
	Scope.realtime.message_received.connect(_on_realtime_message)
	var result := Scope.realtime.connect_with_session(Scope.session)
	if not result.success:
		$CanvasLayer/SocialPanel/VBoxContainer/Messages.text = "Realtime unavailable: " + result.error


func _on_realtime_message(message: Dictionary) -> void:
	var message_type := str(message.get("type", ""))
	if message_type in ["player_stats", "player_stats_changed", "player_stats_response", "player_stats_updated", "get_player_stats", "get_player_stats_response", "stat_point_spent", "stats_changed", "player_progression_changed", "experience_gained", "xp_gained"]:
		_handle_authoritative_stats_message(message_type, message)
		return
	if message_type in ["world_snapshot", "mob_snapshot", "mob_spawned", "mob_damaged", "mob_died", "player_damaged", "player_died", "player_revived", "player_respawned", "player_respawn", "player_xp_changed", "attack_rejected", "attack_ack", "player_power_up_activated", "player_power_up_rejected", "player_power_up_expired"]:
		_handle_world_message(message_type, message)
		return
	var channel := str(message.get("channel", ""))
	if channel == MOVEMENT_CHANNEL:
		_handle_movement_message(message)
	elif channel == "leaderboard/gold":
		_load_leaderboard()
	elif channel == "presence":
		_handle_presence_message(message)
		_load_online_players()
	elif channel.begins_with("player/"):
		_load_social()

func _handle_authoritative_stats_message(message_type: String, message: Dictionary) -> void:
	var data_value: Variant = message.get("data", {})
	if not data_value is Dictionary:
		return
	var data: Dictionary = data_value
	var transaction_id := str(data.get("transaction_id", ""))
	if not transaction_id.is_empty():
		pending_stat_transactions.erase(transaction_id)
	if data.has("success") and not bool(data.get("success")):
		return
	var authoritative_state := data
	var player_state_value: Variant = null
	if data.has("player"):
		player_state_value = data.get("player")
	elif data.has("player_state"):
		player_state_value = data.get("player_state")
	elif data.has("player_stats"):
		player_state_value = data.get("player_stats")
	if player_state_value is Dictionary and not (player_state_value as Dictionary).is_empty():
		authoritative_state = player_state_value
	if $Player.has_method("apply_authoritative_stats"):
		$Player.call("apply_authoritative_stats", authoritative_state)
	_update_level_up_panel()

func _handle_world_message(message_type: String, message: Dictionary) -> void:
	var data_value: Variant = message.get("data", {})
	if not data_value is Dictionary:
		return
	var data: Dictionary = data_value
	match message_type:
		"world_snapshot":
			_apply_world_snapshot(data)
		"mob_snapshot":
			if _accept_world_sequence(data):
				_apply_mob_snapshot(data)
		"mob_spawned":
			if _accept_world_sequence(data):
				_spawn_or_update_authoritative_mob(data)
		"mob_damaged":
			_apply_authoritative_mob_damage(data)
		"mob_died":
			_apply_authoritative_mob_death(data)
		"player_damaged":
			if int(data.get("player_id", 0)) == int(Scope.session.current_user.id):
				var knockback_value: Variant = data.get("knockback", data.get("velocity", {}))
				var knockback_data: Dictionary = knockback_value if knockback_value is Dictionary else {}
				if $Player.has_method("apply_authoritative_damage"):
					$Player.call("apply_authoritative_damage", int(data.get("damage", 0)), knockback_data, int(data.get("remaining_health", -1)))
		"player_died":
			if int(data.get("player_id", 0)) == int(Scope.session.current_user.id):
				if $Player.has_method("apply_authoritative_death"):
					$Player.call("apply_authoritative_death", data)
		"player_revived", "player_respawned", "player_respawn":
			if int(data.get("player_id", Scope.session.current_user.id)) == int(Scope.session.current_user.id):
				pending_player_revive_data = data
				player_revive_received = true
				_try_complete_player_revive()
		"player_xp_changed":
			if _accept_world_sequence(data):
				_apply_authoritative_xp(data)
		"attack_rejected":
			var rejected_attack_id := str(data.get("attack_id", ""))
			if not rejected_attack_id.is_empty():
				pending_attack_mobs.erase(rejected_attack_id)
		"attack_ack":
			var acknowledged_attack_id := str(data.get("attack_id", ""))
			var acknowledged_mob_id := str(data.get("mob_id", ""))
			var expected_mob_id := str(pending_attack_mobs.get(acknowledged_attack_id, ""))
			if not acknowledged_attack_id.is_empty() and expected_mob_id != acknowledged_mob_id:
				return
			if not acknowledged_attack_id.is_empty():
				pending_attack_mobs.erase(acknowledged_attack_id)
			_apply_authoritative_mob_damage(data)
			if data.has("experience") or data.has("level") or data.has("stats"):
				if $Player.has_method("apply_authoritative_stats"):
					$Player.call("apply_authoritative_stats", data)
		"player_power_up_activated":
			if int(data.get("player_id", Scope.session.current_user.id)) == int(Scope.session.current_user.id):
				$Player.call("apply_authoritative_power_up", data)
		"player_power_up_rejected":
			if int(data.get("player_id", Scope.session.current_user.id)) == int(Scope.session.current_user.id):
				$Player.call("apply_authoritative_power_up_rejected", data)
		"player_power_up_expired":
			if int(data.get("player_id", Scope.session.current_user.id)) == int(Scope.session.current_user.id):
				$Player.call("apply_authoritative_power_up_expired", data)

func _accept_world_sequence(data: Dictionary) -> bool:
	var sequence := int(data.get("sequence", 0))
	if sequence <= 0:
		return true
	if sequence <= last_world_sequence:
		return false
	last_world_sequence = sequence
	return true

func _request_world_resync() -> void:
	if not Scope.realtime.is_open() or world_map_id.is_empty():
		return
	world_join_requested = false
	var result := Scope.realtime.send_command("join_area", {"map_id": world_map_id})
	if result.success:
		world_join_requested = true

func _apply_world_snapshot(data: Dictionary) -> void:
	world_map_id = str(data.get("map_id", WORLD_MAP_ID))
	last_world_sequence = int(data.get("sequence", 0))
	var snapshot_ids: Dictionary = {}
	var snapshot_received_at := float(Time.get_ticks_msec()) / 1000.0
	var spawn_areas_value: Variant = data.get("spawn_areas", [])
	var spawn_area_count: int = 0
	if spawn_areas_value is Array:
		spawn_area_count = spawn_areas_value.size()
	var mobs_value: Variant = data.get("mobs", [])
	var mob_count: int = 0
	if mobs_value is Array:
		mob_count = mobs_value.size()
	if mobs_value is Array:
		for mob_value: Variant in mobs_value:
			if not mob_value is Dictionary:
				continue
			var mob_data: Dictionary = mob_value
			var mob_id := str(mob_data.get("mob_id", ""))
			if mob_id.is_empty():
				continue
			snapshot_ids[mob_id] = true
			_spawn_or_update_authoritative_mob(mob_data, snapshot_received_at)
	for mob_id_value: Variant in authoritative_mobs.keys():
		var mob_id := str(mob_id_value)
		if not snapshot_ids.has(mob_id):
			_remove_authoritative_mob(mob_id)

func _apply_mob_snapshot(data: Dictionary) -> void:
	var mobs_value: Variant = data.get("mobs", [])
	if not mobs_value is Array:
		return
	var snapshot_received_at := float(Time.get_ticks_msec()) / 1000.0
	for mob_value: Variant in mobs_value:
		if mob_value is Dictionary:
			_spawn_or_update_authoritative_mob(mob_value, snapshot_received_at)

func _prepare_server_enemy_template() -> void:
	var template_names: Dictionary = {"zombie": "Zombie", "goblin": "Goblin"}
	for mob_type_value: Variant in template_names.keys():
		var mob_type := str(mob_type_value)
		var template_name := str(template_names[mob_type_value])
		var existing_enemy: Node = $Enemies.get_node_or_null(template_name)
		if existing_enemy == null:
			if mob_type == "zombie":
				push_error("[World] No Zombie template found under Game/Enemies.")
			continue
		server_enemy_templates[mob_type] = existing_enemy.duplicate()
		existing_enemy.visible = false
		existing_enemy.set_physics_process(false)
		var original_body_collision := existing_enemy.get_node_or_null("BodyCollision") as CollisionShape2D
		if original_body_collision != null:
			original_body_collision.set_deferred("disabled", true)
		var original_enemy_collision := existing_enemy.get_node_or_null("EnemyArea/EnemyCollision") as CollisionShape2D
		if original_enemy_collision != null:
			original_enemy_collision.set_deferred("disabled", true)
		var original_bite_hitbox := existing_enemy.get_node_or_null("BiteHitbox") as Area2D
		if original_bite_hitbox != null:
			original_bite_hitbox.set_deferred("monitoring", false)

func _spawn_or_update_authoritative_mob(data: Dictionary, snapshot_received_at: float = -1.0) -> void:
	var mob_id := str(data.get("mob_id", ""))
	if mob_id.is_empty():
		push_warning("[World] Ignoring mob event without mob_id")
		return
	var mob_type := str(data.get("mob_type", "zombie")).to_lower()
	var enemy: Node = authoritative_mobs.get(mob_id)
	if enemy == null or not is_instance_valid(enemy):
		var selected_template: Node = server_enemy_templates.get(mob_type, server_enemy_templates.get("zombie"))
		if selected_template == null:
			push_error("[World] Cannot create mob %s because no enemy template is available." % mob_id)
			return
		if not server_enemy_templates.has(mob_type):
			push_warning("[World] No visual mapping for mob_type=%s; using the Zombie template." % mob_type)
		enemy = selected_template.duplicate()
		enemy.name = "Mob_%s" % mob_id
		$Enemies.add_child(enemy)
		if enemy.has_method("set_server_authoritative"):
			enemy.call("set_server_authoritative", mob_id)
		authoritative_mobs[mob_id] = enemy
	if enemy.has_method("apply_server_snapshot"):
		enemy.call("apply_server_snapshot", data, snapshot_received_at)

func _apply_authoritative_mob_damage(data: Dictionary) -> void:
	var mob_id := str(data.get("mob_id", ""))
	var enemy: Node = authoritative_mobs.get(mob_id)
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_server_damage"):
		enemy.call("apply_server_damage", data)

func _apply_authoritative_mob_death(data: Dictionary) -> void:
	var mob_id := str(data.get("mob_id", ""))
	var enemy: Node = authoritative_mobs.get(mob_id)
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_server_death"):
		enemy.call("apply_server_death", data)

func _on_player_game_over_finished() -> void:
	player_game_over_finished = true
	_try_complete_player_revive()

func _try_complete_player_revive() -> void:
	if not player_game_over_finished or not player_revive_received:
		return
	player_game_over_finished = false
	player_revive_received = false
	await _restore_player_state()
	if $Player.has_method("revive"):
		$Player.call("revive", pending_player_revive_data)
	pending_player_revive_data.clear()

func _apply_authoritative_xp(data: Dictionary) -> void:
	if int(data.get("player_id", 0)) != int(Scope.session.current_user.id):
		return
	if $Player.has_method("apply_authoritative_stats"):
		$Player.call("apply_authoritative_stats", data)

func _remove_authoritative_mob(mob_id: String) -> void:
	var enemy: Node = authoritative_mobs.get(mob_id)
	authoritative_mobs.erase(mob_id)
	if enemy != null and is_instance_valid(enemy):
		enemy.queue_free()

func _clear_authoritative_mobs() -> void:
	for mob_id_value: Variant in authoritative_mobs.keys():
		_remove_authoritative_mob(str(mob_id_value))
	authoritative_mobs.clear()

func request_player_power_up(activation_id: String, player_position: Vector2) -> void:
	if activation_id.is_empty() or not Scope.realtime.is_open() or world_map_id.is_empty():
		return
	Scope.realtime.send_command("activate_power_up", {
		"activation_id": activation_id,
		"client_position": {"x": player_position.x, "y": player_position.y}
	})


func request_mob_attack(mob_id: String, player_position: Vector2, facing: int, power_up_id: String = "", attack_swing_id: String = "") -> void:
	if not Scope.realtime.is_open() or world_map_id.is_empty():
		return
	world_attack_sequence += 1
	var attack_id := "%s-attack-%06d" % [world_attack_prefix, world_attack_sequence]
	pending_attack_mobs[attack_id] = mob_id
	var result := Scope.realtime.send_command("attack_mob", {
		"mob_id": mob_id,
		"attack_id": attack_id,
		"attack_type": "basic",
		"power_up_id": power_up_id,
		"attack_swing_id": attack_swing_id,
		"client_position": {"x": player_position.x, "y": player_position.y},
		"client_facing": 1 if facing >= 0 else -1
	})
	if not result.success:
		pending_attack_mobs.erase(attack_id)


func _process_movement_sync(delta: float) -> void:
	# Movement synchronization stays in the game layer. The SDK only transports
	# generic realtime events, so this can later be reused for entities, NPCs,
	# projectiles, prediction, interpolation, or an authoritative server.
	if not Scope.realtime.is_open() or not realtime_subscribed:
		return
	movement_elapsed += delta
	if movement_elapsed < MOVEMENT_UPDATE_INTERVAL:
		return
	movement_elapsed = 0.0
	var local_player: CharacterBody2D = $Player
	if has_sent_position and local_player.position == last_sent_position:
		return
	var payload := {
		"user_id": Scope.session.current_user.id,
		"position": {"x": local_player.position.x, "y": local_player.position.y},
		"rotation": local_player.rotation,
		"timestamp": Time.get_unix_time_from_system(),
		"sprite_file_id": sprite_file_id
	}
	var result := Scope.realtime.publish(MOVEMENT_CHANNEL, payload)
	if result.success:
		last_sent_position = local_player.position
		has_sent_position = true
		movement_packets_sent += 1


func _handle_movement_message(message: Dictionary) -> void:
	# This benchmark intentionally applies packets immediately. There is no
	# interpolation or client prediction so the raw realtime latency is visible.
	var data: Variant = message.get("data", {})
	if not data is Dictionary:
		return
	var movement: Dictionary = data
	var user_id: int = int(movement.get("user_id", 0))
	if user_id <= 0 or user_id == Scope.session.current_user.id:
		return
	var position_data: Variant = movement.get("position", {})
	if not position_data is Dictionary:
		return
	var position_dictionary: Dictionary = position_data
	var position := Vector2(float(position_dictionary.get("x", 0.0)), float(position_dictionary.get("y", 0.0)))
	var rotation: float = float(movement.get("rotation", 0.0))
	var incoming_sprite_file_id: int = int(movement.get("sprite_file_id", 0))
	var remote_entity: Node2D = remote_players.get(user_id)
	if remote_entity == null or not is_instance_valid(remote_entity):
		remote_entity = _create_remote_player(user_id)
	var previous_position: Vector2 = remote_entity.position
	remote_entity.position = position
	remote_entity.rotation = rotation
	var remote_sprite: AnimatedSprite2D = remote_entity.get_node("Sprite") as AnimatedSprite2D
	if incoming_sprite_file_id > 0:
		_ensure_remote_sprite(user_id, incoming_sprite_file_id, remote_entity)
	if previous_position.distance_to(position) > 0.01:
		remote_sprite.play("character_walk")
		if absf(position.x - previous_position.x) > 0.01:
			remote_sprite.flip_h = position.x < previous_position.x
	else:
		remote_sprite.play("character_idle")
	movement_packets_received += 1


func _handle_presence_message(message: Dictionary) -> void:
	var data: Variant = message.get("data", {})
	if not data is Dictionary:
		return
	var presence: Dictionary = data
	var user_id: int = int(presence.get("user_id", 0))
	if user_id <= 0 or user_id == Scope.session.current_user.id:
		return
	if not bool(presence.get("online", false)):
		_remove_remote_player(user_id)



func _create_remote_player(user_id: int) -> Node2D:
	# Remote visuals are created dynamically from the existing local player's
	# sprite resource, but do not copy player.gd, so they cannot accept local input.
	var remote_entity := Node2D.new()
	remote_entity.name = "RemotePlayer_%d" % user_id
	remote_entity.z_index = $Player.z_index
	remote_entity.scale = $Player.scale
	var remote_sprite := AnimatedSprite2D.new()
	remote_sprite.name = "Sprite"
	remote_sprite.sprite_frames = $Player/Visual.sprite_frames
	remote_sprite.scale = $Player/Visual.scale
	remote_sprite.animation = &"character_idle"
	remote_entity.add_child(remote_sprite)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = "Player %d" % user_id
	name_label.position = Vector2(-45.0, -48.0)
	name_label.z_index = 1
	name_label.modulate = Color(0.05, 0.05, 0.05, 1.0)
	remote_entity.add_child(name_label)
	add_child(remote_entity)
	remote_players[user_id] = remote_entity
	_load_remote_player_name(user_id, remote_entity)
	return remote_entity
func _load_remote_player_name(user_id: int, remote_entity: Node2D) -> void:
	var result := await Scope.wizards_wager.player_profile(user_id)
	if not result.success or not is_instance_valid(remote_entity):
		return
	var profile: ScopeWizardsWagerPlayerProfile = result.data
	var name_label: Label = remote_entity.get_node("Name") as Label
	if name_label != null:
		name_label.text = profile.username


func _remove_remote_player(user_id: int) -> void:
	var remote_player: Variant = remote_players.get(user_id)
	if remote_player is Node and is_instance_valid(remote_player):
		(remote_player as Node).queue_free()
	remote_players.erase(user_id)
	remote_sprite_file_ids.erase(user_id)
	remote_sprite_loading.erase(user_id)


func _clear_remote_players() -> void:
	for user_id: int in remote_players.keys():
		_remove_remote_player(user_id)


func _on_change_sprite_pressed() -> void:
	$CanvasLayer/CharacterFileDialog.popup_centered_ratio(0.8)


func _on_character_file_selected(path: String) -> void:
	$CanvasLayer/BettingPanel/VBoxContainer/Status.text = "Uploading character..."
	var result := await Scope.storage.upload(path, {"visibility": "application"})
	if not result.success:
		$CanvasLayer/BettingPanel/VBoxContainer/Status.text = "Character upload failed: " + result.error
		return
	var file: ScopeStorageFile = result.data
	sprite_file_id = file.id
	_save_sprite_file_id(sprite_file_id)
	if _apply_local_sprite(path):
		has_sent_position = false
		$CanvasLayer/BettingPanel/VBoxContainer/Status.text = "Character uploaded and shared."
	else:
		$CanvasLayer/BettingPanel/VBoxContainer/Status.text = "Character uploaded, but the sprite sheet could not be loaded."


func _ensure_remote_sprite(user_id: int, file_id: int, remote_entity: Node2D) -> void:
	if int(remote_sprite_file_ids.get(user_id, 0)) == file_id or int(remote_sprite_loading.get(user_id, 0)) == file_id:
		return
	remote_sprite_loading[user_id] = file_id
	var result := await Scope.storage.download(file_id)
	var current_entity: Variant = remote_players.get(user_id)
	if not is_instance_valid(remote_entity) or current_entity != remote_entity:
		remote_sprite_loading.erase(user_id)
		return
	if result.success and result.data is PackedByteArray:
		var frames: SpriteFrames = _sprite_frames_from_bytes(result.data)
		if frames != null:
			var remote_sprite: AnimatedSprite2D = remote_entity.get_node("Sprite") as AnimatedSprite2D
			remote_sprite.sprite_frames = frames
			remote_sprite.play("character_idle")
			remote_sprite_file_ids[user_id] = file_id
	remote_sprite_loading.erase(user_id)


func _apply_local_sprite(path: String) -> bool:
	var frames: SpriteFrames = _sprite_frames_from_bytes(FileAccess.get_file_as_bytes(path))
	if frames == null:
		return false
	$Player/Visual.sprite_frames = frames
	$Player/Visual.play("character_idle")
	return true


func _restore_local_sprite() -> void:
	var result := await Scope.storage.download(sprite_file_id)
	if not result.success or not result.data is PackedByteArray:
		return
	var frames: SpriteFrames = _sprite_frames_from_bytes(result.data)
	if frames != null:
		$Player/Visual.sprite_frames = frames
		$Player/Visual.play("character_idle")


func _sprite_frames_from_bytes(bytes: PackedByteArray) -> SpriteFrames:
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_sprite_animation(frames, "character_idle", texture, 36, 6, 5.0)
	_add_sprite_animation(frames, "character_walk", texture, 0, 6, 5.0)
	_add_sprite_animation(frames, "character_attack", texture, 108, 8, 5.0)
	_add_sprite_animation(frames, "character_die", texture, 216, 8, 5.0)
	_add_sprite_animation(frames, "character_power_up", texture, 252, 10, 5.0)
	return frames


func _add_sprite_animation(frames: SpriteFrames, animation_name: String, texture: Texture2D, row_y: int, frame_count: int, speed: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, animation_name not in ["character_attack", "character_die", "character_power_up"])
	frames.set_animation_speed(animation_name, speed)
	for index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(index * 36, row_y, 36, 36)
		frames.add_frame(animation_name, atlas)


func _save_sprite_file_id(file_id: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://wizards_wager"))
	var file := FileAccess.open(SPRITE_CACHE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"file_id": file_id}))


func _save_player_state() -> void:
	if not Scope.is_logged_in():
		return
	var player: CharacterBody2D = $Player
	var persistent_state: Dictionary = player.call("get_persistent_state") as Dictionary
	var result := await Scope.database.write(PLAYER_STATE_KEY, {
		"position": {"x": player.position.x, "y": player.position.y},
		"rotation": player.rotation,
		"sprite_file_id": sprite_file_id,
		"level": persistent_state.get("level", 1),
		"experience": persistent_state.get("experience", 0),
		"unspent_stat_points": persistent_state.get("unspent_stat_points", 0),
		"stats": persistent_state.get("stats", {}),
		"resources": persistent_state.get("resources", {})
	})
	if result.success:
		player.call("clear_state_dirty")


func _restore_player_state() -> void:
	if not Scope.is_logged_in():
		return
	var result := await Scope.database.read(PLAYER_STATE_KEY)
	if not result.success:
		return
	var record: ScopeDatabaseRecord = result.data
	var state: Dictionary = record.data
	var position_data: Variant = state.get("position", {})
	if position_data is Dictionary:
		var position_dictionary: Dictionary = position_data
		$Player.position = Vector2(float(position_dictionary.get("x", $Player.position.x)), float(position_dictionary.get("y", $Player.position.y)))
	$Player.rotation = float(state.get("rotation", $Player.rotation))
	var saved_sprite_file_id: int = int(state.get("sprite_file_id", 0))
	if saved_sprite_file_id > 0 and saved_sprite_file_id != sprite_file_id:
		sprite_file_id = saved_sprite_file_id
		await _restore_local_sprite()


func _update_player_status() -> void:
	var player: Node = $Player
	var health_bar: TextureProgressBar = $CanvasLayer/PlayerStatus/HealthProgressBar
	var stamina_bar: TextureProgressBar = $CanvasLayer/PlayerStatus/StaminaProgressBar
	var mana_bar: TextureProgressBar = $CanvasLayer/PlayerStatus/ManaProgressBar
	var experience_bar: TextureProgressBar = $CanvasLayer/PlayerStatus/ExperienceProgressBar
	var level: int = int(player.get("level"))
	var experience: int = int(player.get("experience"))
	var experience_to_next_level: int = int(player.call("get_experience_to_next_level"))
	health_bar.max_value = float(player.get("max_health"))
	health_bar.value = float(player.get("current_health"))
	stamina_bar.max_value = float(player.get("max_stamina"))
	stamina_bar.value = float(player.get("current_stamina"))
	mana_bar.max_value = float(player.get("max_mana"))
	mana_bar.value = float(player.get("current_mana"))
	experience_bar.max_value = experience_to_next_level
	experience_bar.value = experience
	$CanvasLayer/PlayerStatus/LevelLabel.text = "LV %d" % level


func _on_player_level_up(_new_level: int, _available_points: int) -> void:
	_update_level_up_panel()


func _on_player_stats_changed() -> void:
	_update_level_up_panel()


func _on_stat_button_pressed(stat_name: String) -> void:
	if not Scope.realtime.is_open():
		return
	stat_transaction_sequence += 1
	var transaction_id := "%s-stat-%06d" % [world_attack_prefix, stat_transaction_sequence]
	pending_stat_transactions[transaction_id] = stat_name
	var result := Scope.realtime.send_command("spend_stat_point", {
		"transaction_id": transaction_id,
		"stat": stat_name
	})
	if not result.success:
		pending_stat_transactions.erase(transaction_id)


func _on_level_up_panel_closed() -> void:
	$CanvasLayer/PlayerPanel.visible = false


func _update_level_up_panel() -> void:
	var player: Node = $Player
	var persistent_state: Dictionary = player.call("get_persistent_state") as Dictionary
	var stats: Dictionary = persistent_state.get("stats", {})
	var level: int = int(persistent_state.get("level", 1))
	var experience: int = int(persistent_state.get("experience", 0))
	var points: int = int(persistent_state.get("unspent_stat_points", 0))
	var next_level_experience: int = int(player.call("get_experience_to_next_level"))
	$CanvasLayer/PlayerPanel/VBoxContainer/Level.text = "Level %d" % level
	$CanvasLayer/PlayerPanel/VBoxContainer/Experience.text = "EXP: %d / %d" % [experience, next_level_experience]
	$CanvasLayer/PlayerPanel/VBoxContainer/Points.text = "Points available: %d" % points
	$CanvasLayer/PlayerPanel/VBoxContainer/StrengthButton.text = "STR - Strength: %d" % int(stats.get("str", 1))
	$CanvasLayer/PlayerPanel/VBoxContainer/AgilityButton.text = "AGI - Agility: %d" % int(stats.get("agi", 1))
	$CanvasLayer/PlayerPanel/VBoxContainer/IntelligenceButton.text = "INT - Intelligence: %d" % int(stats.get("int", 1))
	$CanvasLayer/PlayerPanel/VBoxContainer/LuckButton.text = "LUK - Luck: %d" % int(stats.get("luk", 1))
	$CanvasLayer/PlayerPanel/VBoxContainer/EnduranceButton.text = "END - Endurance: %d" % int(stats.get("end", 1))
	for stat_button_name: String in ["StrengthButton", "AgilityButton", "IntelligenceButton", "LuckButton", "EnduranceButton"]:
		var stat_button: Button = $CanvasLayer/PlayerPanel/VBoxContainer.get_node(stat_button_name) as Button
		stat_button.visible = true
		stat_button.disabled = points <= 0


func _load_sprite_file_id() -> int:
	if not FileAccess.file_exists(SPRITE_CACHE_PATH):
		return 0
	var file := FileAccess.open(SPRITE_CACHE_PATH, FileAccess.READ)
	if file == null:
		return 0
	var value: Variant = JSON.parse_string(file.get_as_text())
	return int(value.get("file_id", 0)) if value is Dictionary else 0


func _on_place_bet_pressed() -> void:
	if active_bet != null:
		return
	var amount: int = int($CanvasLayer/BettingPanel/VBoxContainer/BetAmount.text)
	var choice: String = $CanvasLayer/BettingPanel/VBoxContainer/Choice.get_item_text($CanvasLayer/BettingPanel/VBoxContainer/Choice.selected).to_lower()
	if amount <= 0:
		$CanvasLayer/BettingPanel/VBoxContainer/Status.text = "Enter a positive bet amount."
		return
	$CanvasLayer/BettingPanel/VBoxContainer/PlaceBet.disabled = true
	$CanvasLayer/BettingPanel/VBoxContainer/Status.text = "Placing bet..."
	var result := await Scope.wizards_wager.place_bet(amount, choice)
	if not result.success:
		$CanvasLayer/BettingPanel/VBoxContainer/PlaceBet.disabled = false
		_show_error(result.error)
		return
	$CanvasLayer/BettingPanel/VBoxContainer/BetAmount.text = ""
	selected_choice = choice
	_save_choice(selected_choice)
	$CanvasLayer/BettingPanel/VBoxContainer/Status.text = "Bet placed. The server resolves bets every 10 minutes."
	await _refresh_game_state()


func _on_add_friend_pressed() -> void:
	var username: String = $CanvasLayer/SocialPanel/VBoxContainer/FriendActions/Username.text.strip_edges()
	if username.is_empty():
		$CanvasLayer/SocialPanel/VBoxContainer/Friends.text = "Enter a username first."
		return
	var result := await Scope.friends.send_request(username)
	$CanvasLayer/SocialPanel/VBoxContainer/Friends.text = "Friend request sent to %s." % username if result.success else "Friend request failed: " + result.error
	if result.success:
		$CanvasLayer/SocialPanel/VBoxContainer/FriendActions/Username.text = ""


func _on_send_message_pressed() -> void:
	var recipient_text: String = $CanvasLayer/SocialPanel/VBoxContainer/MessageActions/Recipient.text.strip_edges()
	var message_text: String = $CanvasLayer/SocialPanel/VBoxContainer/MessageActions/Message.text.strip_edges()
	var recipient_id: int = int(recipient_text)
	if recipient_id <= 0 or message_text.is_empty():
		$CanvasLayer/SocialPanel/VBoxContainer/Messages.text = "Enter a numeric user ID and message."
		return
	var result := await Scope.messages.send(recipient_id, message_text)
	$CanvasLayer/SocialPanel/VBoxContainer/Messages.text = "Message sent." if result.success else "Message failed: " + result.error
	if result.success:
		$CanvasLayer/SocialPanel/VBoxContainer/MessageActions/Message.text = ""


func _on_player_selected(user_id: int) -> void:
	selected_player_id = user_id
	$CanvasLayer/PlayerDetailsPanel.visible = true
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Username.text = "Loading player..."
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Gold.text = "Gold: loading"
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Online.text = "Status: loading"
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Status.text = ""
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Messages.text = "Loading messages..."
	var profile_result := await Scope.wizards_wager.player_profile(user_id)
	if profile_result.success:
		var profile: ScopeWizardsWagerPlayerProfile = profile_result.data
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Username.text = profile.username
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Gold.text = "Gold: %d" % profile.gold
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Online.text = "Status: online" if profile.online else "Status: offline"
	else:
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Status.text = "Profile unavailable: " + profile_result.error
	var messages_result := await Scope.messages.list(user_id, 50)
	if messages_result.success:
		var messages: Array[ScopeMessage] = messages_result.data
		var message_lines: Array[String] = []
		for message: ScopeMessage in messages:
			message_lines.append("%s: %s" % [message.sender_username if not message.sender_username.is_empty() else "Message", message.text])
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Messages.text = "\n".join(message_lines) if not message_lines.is_empty() else "No messages yet."
	else:
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Messages.text = "Messages unavailable: " + messages_result.error


func _on_profile_add_friend_pressed() -> void:
	if selected_player_id <= 0:
		return
	var result := await Scope.friends.send_request($CanvasLayer/PlayerDetailsPanel/VBoxContainer/Username.text)
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Status.text = "Friend request sent." if result.success else "Friend request failed: " + result.error


func _on_profile_send_message_pressed() -> void:
	if selected_player_id <= 0:
		return
	var message_text: String = $CanvasLayer/PlayerDetailsPanel/VBoxContainer/Message.text.strip_edges()
	var result := await Scope.messages.send(selected_player_id, message_text)
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Status.text = "Message sent." if result.success else "Message failed: " + result.error
	if result.success:
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Message.text = ""
		await _on_player_selected(selected_player_id)


func _close_player_details() -> void:
	selected_player_id = 0
	$CanvasLayer/PlayerDetailsPanel.visible = false


func _on_logout_pressed() -> void:
	await _save_player_state()
	Scope.realtime.close()
	Scope.auth.logout()
	get_tree().change_scene_to_file("res://login.tscn")


func _get_bet_end_unix(bet: ScopeWizardsWagerBet) -> int:
	return _timestamp_from_string(bet.resolves_at) if not bet.resolves_at.is_empty() else 0


func _timestamp_from_string(value: String) -> int:
	var datetime: Dictionary = Time.get_datetime_dict_from_datetime_string(value, true)
	return int(Time.get_unix_time_from_datetime_dict(datetime))


func _sync_server_clock(server_time: String) -> void:
	if not server_time.is_empty():
		server_offset_seconds = _timestamp_from_string(server_time) - int(Time.get_unix_time_from_system())


func _update_countdown() -> bool:
	if active_bet == null or bet_end_unix <= 0:
		$CanvasLayer/BettingPanel/VBoxContainer/Countdown.text = "Flip time: waiting for server schedule"
		return false
	var server_now: int = int(Time.get_unix_time_from_system()) + server_offset_seconds
	var remaining: int = maxi(0, bet_end_unix - server_now)
	$CanvasLayer/BettingPanel/VBoxContainer/Countdown.text = "Flip in: %02d:%02d" % [remaining / 60, remaining % 60]
	return remaining <= 0


func _populate_leaderboard_buttons(value: Variant) -> void:
	var container: VBoxContainer = $CanvasLayer/LeaderboardPanel/VBoxContainer/LeaderboardButtons
	_clear_buttons(container)
	var entries: Array = value if value is Array else value.get("entries", []) if value is Dictionary else []
	for index in entries.size():
		var entry: Variant = entries[index]
		if entry is Dictionary:
			var data: Dictionary = entry
			var user_id: int = _entry_user_id(data)
			if user_id > 0:
				_add_player_button(container, "%d. %s - %s gold" % [index + 1, _entry_username(data), _entry_score(data)], user_id)


func _add_player_button(container: VBoxContainer, label_text: String, user_id: int) -> void:
	var button := Button.new()
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_on_player_selected.bind(user_id))
	container.add_child(button)


func _clear_buttons(container: Node) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _format_leaderboard(value: Variant) -> String:
	var entries: Array = value if value is Array else value.get("entries", []) if value is Dictionary else []
	if entries.is_empty(): return "Leaderboard\nNo scores yet."
	var lines: Array[String] = ["Leaderboard", "Rank   Player   Gold"]
	for index in entries.size():
		var entry: Variant = entries[index]
		if entry is Dictionary: lines.append("%d.    %s    %s" % [index + 1, _entry_username(entry), _entry_score(entry)])
	return "\n".join(lines)


func _entry_username(entry: Dictionary) -> String:
	for key in ["username", "user_name", "display_name", "name"]:
		if entry.has(key) and not str(entry[key]).is_empty(): return str(entry[key])
	if entry.get("user") is Dictionary: return str(entry["user"].get("username", "Player"))
	if int(entry.get("user_id", 0)) == Scope.session.current_user.id: return Scope.session.current_user.username
	return "Player %s" % entry.get("user_id", "?")


func _entry_user_id(entry: Dictionary) -> int:
	if entry.has("user_id"):
		return int(entry.get("user_id", 0))
	if entry.get("user") is Dictionary:
		return int(entry.get("user").get("id", entry.get("user").get("user_id", 0)))
	return 0


func _entry_score(entry: Dictionary) -> String: return str(entry.get("score", entry.get("gold", entry.get("value", 0))))

func _rank_text(value: Variant) -> String:
	if value is Dictionary: return str(int(value.get("rank", value.get("position", 0))))
	return str(value)

func _show_error(message: String) -> void:
	$CanvasLayer/BettingPanel/VBoxContainer/Status.text = message
	push_error(message)

func _save_choice(choice: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://wizards_wager"))
	var file := FileAccess.open(CHOICE_CACHE_PATH, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"choice": choice}))

func _load_choice() -> String:
	if not FileAccess.file_exists(CHOICE_CACHE_PATH): return ""
	var file := FileAccess.open(CHOICE_CACHE_PATH, FileAccess.READ)
	if file == null: return ""
	var value: Variant = JSON.parse_string(file.get_as_text())
	return str(value.get("choice", "")) if value is Dictionary else ""

func _clear_choice() -> void:
	if FileAccess.file_exists(CHOICE_CACHE_PATH): DirAccess.remove_absolute(ProjectSettings.globalize_path(CHOICE_CACHE_PATH))
