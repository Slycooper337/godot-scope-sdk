extends Node2D

const LEADERBOARD_METRIC := "gold"
const REFRESH_SECONDS := 10.0
const CHOICE_CACHE_PATH := "user://wizards_wager/active_choice.json"
const SPRITE_CACHE_PATH := "user://wizards_wager/sprite_file.json"
const PLAYER_STATE_KEY := "player_state"
const MOVEMENT_CHANNEL := "match/movement-test"
const MOVEMENT_UPDATE_INTERVAL := 0.1
const WORLD_MAP_ID := "forest"
const RESOURCE_BAR_GROWTH_PER_STAT_POINT := 10.0
const REMOTE_PLAYER_SCRIPT := preload("res://remote_player.gd")
const CHAT_BUBBLE_SCRIPT := preload("res://chat_bubble.gd")
const TARGET_INDICATOR_SCRIPT := preload("res://target_indicator.gd")

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
var realtime_reconnect_elapsed := 0.0
var realtime_reconnect_attempting := false
var realtime_reconnect_delay := 3.0
var movement_packets_sent: int = 0
var movement_packets_received: int = 0
var movement_sequence := 0
var last_sent_velocity := Vector2.ZERO
var last_sent_rotation := 0.0
var last_sent_facing := 0
var last_sent_grounded := false
var last_sent_movement_state := ""
var last_sent_map_id := ""
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
var resource_bar_min_widths: Dictionary = {}
var chat_dock: LocalChatDock
var chat_message_sequence := 0
var delivered_chat_message_ids: Dictionary = {}
var chat_history_scope_id := ""
var target_mode_enabled := false
var current_target: Node = null
var faction_state: Dictionary = {}
var faction_choice_container: VBoxContainer
var faction_choice_title: Label
var faction_choice_rows: Dictionary = {}


func _ready() -> void:
	Scope.session.session_logged_out.connect(_on_session_logged_out)
	_setup_chat()
	_ensure_faction_choice_display()
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
	$CanvasLayer/SettingsPanel.settings_applied.connect(_on_settings_applied)
	$CanvasLayer/PlayerStatusFrame.target_friend_requested.connect(_on_target_friend_requested)
	$CanvasLayer/PlayerStatusFrame.target_message_requested.connect(_on_target_message_requested)
	$CanvasLayer/PlayerStatusFrame.target_inspect_requested.connect(_on_target_inspect_requested)
	$CanvasLayer/PlayerStatusFrame.target_cleared.connect(_on_target_cleared)
	$CanvasLayer/PlayerPanel/VBoxContainer/ChangeSprite.pressed.connect(_on_change_sprite_pressed)
	$CanvasLayer/BettingPanel/VBoxContainer/PlaceBet.pressed.connect(_on_place_bet_pressed)
	var menu: PopupMenu = $CanvasLayer/LocalChatDock/VBoxContainer/Footer/MenuButton.get_popup()
	menu.id_pressed.connect(_on_menu_option_selected)
	$CanvasLayer/LocalChatDock/VBoxContainer/Footer/TargetButton.toggled.connect(_on_target_mode_toggled)
	movable_panels = [$CanvasLayer/PlayerPanel, $CanvasLayer/LeaderboardPanel, $CanvasLayer/SocialPanel, $CanvasLayer/OnlinePanel, $CanvasLayer/AchievementsPanel, $CanvasLayer/BettingPanel, $CanvasLayer/BetHistoryPanel, $CanvasLayer/PlayerDetailsPanel, $CanvasLayer/SettingsPanel]
	for panel: Control in movable_panels:
		var close_button: Button = panel.get_node_or_null("VBoxContainer/Close") as Button
		if close_button != null:
			close_button.pressed.connect(_close_window.bind(panel))
	_hide_all_windows()
	$CanvasLayer/CharacterFileDialog.file_selected.connect(_on_character_file_selected)
	_connect_realtime()


func _input(event: InputEvent) -> void:
	if _handle_target_cycle_event(event):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if target_mode_enabled and _pointer_is_over_ui():
				return
			if target_mode_enabled:
				_select_world_target(get_global_mouse_position())
				_set_target_mode(false)
				get_viewport().set_input_as_handled()
				return
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


func _on_target_mode_toggled(enabled: bool) -> void:
	_set_target_mode(enabled)


func _handle_target_cycle_event(event: InputEvent) -> bool:
	if _target_input_is_blocked():
		return false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_TAB:
			_release_target_focus()
			_cycle_target(1)
			get_viewport().set_input_as_handled()
			return true
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if button_event.pressed and button_event.button_index == 10:
			_release_target_focus()
			_cycle_target(1)
			get_viewport().set_input_as_handled()
			return true
		if button_event.pressed and button_event.button_index == 9:
			_release_target_focus()
			_cycle_target(-1)
			get_viewport().set_input_as_handled()
			return true
	return false


func _release_target_focus() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		focus_owner.release_focus()


func _target_input_is_blocked() -> bool:
	return $CanvasLayer/SettingsPanel.visible


func _set_target_mode(enabled: bool) -> void:
	target_mode_enabled = enabled
	var button := $CanvasLayer/LocalChatDock/VBoxContainer/Footer/TargetButton as Button
	button.button_pressed = enabled
	button.text = "CANCEL TARGET" if enabled else "SELECT TARGET"


func _pointer_is_over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _cycle_target(direction: int) -> void:
	_validate_current_target()
	var candidates: Array[Node] = _visible_target_candidates()
	if candidates.is_empty():
		_clear_current_target()
		return
	candidates.sort_custom(_sort_targets_by_distance)
	var next_index: int = 0
	var current_index: int = candidates.find(current_target)
	if current_index >= 0:
		next_index = posmod(current_index + direction, candidates.size())
	_select_target_entity(candidates[next_index])


func _validate_current_target() -> void:
	if current_target == null or not is_instance_valid(current_target):
		if current_target != null:
			_clear_current_target()
		return
	var dying_value: Variant = current_target.get("dying")
	var health_value: Variant = current_target.get("health")
	if (dying_value != null and bool(dying_value)) or (health_value != null and int(health_value) <= 0):
		_clear_current_target()


func _clear_current_target() -> void:
	_set_current_target(null)
	$CanvasLayer/PlayerStatusFrame.clear_target()


func _visible_target_candidates() -> Array[Node]:
	var candidates: Array[Node] = []
	var screen_rect: Rect2 = get_viewport().get_visible_rect()
	var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
	for mob_value: Variant in authoritative_mobs.values():
		if not is_instance_valid(mob_value):
			continue
		var mob := mob_value as Node2D
		if _is_visible_target(mob, screen_rect, canvas_transform):
			candidates.append(mob)
	for enemy in $Enemies.get_children():
		var local_enemy := enemy as Node2D
		if local_enemy == null or authoritative_mobs.values().has(local_enemy):
			continue
		if _is_visible_target(local_enemy, screen_rect, canvas_transform):
			candidates.append(local_enemy)
	for remote_value: Variant in remote_players.values():
		if not is_instance_valid(remote_value):
			continue
		var remote := remote_value as Node2D
		if _is_visible_target(remote, screen_rect, canvas_transform):
			candidates.append(remote)
	return candidates


func _is_visible_target(entity: Node2D, screen_rect: Rect2, canvas_transform: Transform2D) -> bool:
	if entity == null or not is_instance_valid(entity) or entity.is_queued_for_deletion() or not entity.visible:
		return false
	var dying_value: Variant = entity.get("dying")
	var health_value: Variant = entity.get("health")
	if (dying_value != null and bool(dying_value)) or (health_value != null and int(health_value) <= 0):
		return false
	return screen_rect.grow(-8.0).has_point(canvas_transform * entity.global_position)


func _sort_targets_by_distance(left: Node, right: Node) -> bool:
	var left_node := left as Node2D
	var right_node := right as Node2D
	return $Player.global_position.distance_squared_to(left_node.global_position) < $Player.global_position.distance_squared_to(right_node.global_position)


func _select_target_entity(target: Node) -> void:
	_set_current_target(target)
	if remote_players.values().has(target):
		for user_id_value: Variant in remote_players.keys():
			if remote_players[user_id_value] == target:
				_on_player_selected(int(user_id_value))
				return
	$CanvasLayer/PlayerStatusFrame.set_enemy_target(target)
	selected_player_id = 0
	$CanvasLayer/PlayerDetailsPanel.visible = false


func is_targeted_entity(entity: Node) -> bool:
	return current_target == entity


func _set_current_target(target: Node) -> void:
	_remove_target_indicators(current_target)
	current_target = target
	if target == null or not is_instance_valid(target):
		return
	var indicator: Node2D = TARGET_INDICATOR_SCRIPT.new() as Node2D
	indicator.name = "TargetIndicator"
	indicator.position = Vector2(0, -18)
	var target_scale: Vector2 = target.global_scale
	indicator.scale = Vector2(
		1.0 / maxf(absf(target_scale.x), 0.001),
		1.0 / maxf(absf(target_scale.y), 0.001)
	)
	indicator.z_index = 50
	target.add_child(indicator)


func _remove_target_indicators(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	for child: Node in target.get_children():
		if child.get_script() != TARGET_INDICATOR_SCRIPT:
			continue
		# Freeing is deferred, so release the canonical name immediately in case
		# this same entity is selected again before the end of the frame.
		child.name = "RetiringTargetIndicator_%d" % child.get_instance_id()
		child.queue_free()


func _select_world_target(world_position: Vector2) -> void:
	var nearest: Node = null
	var nearest_distance := INF
	var selection_radius := 42.0
	var local_distance: float = $Player.global_position.distance_to(world_position)
	if local_distance <= selection_radius:
		nearest = $Player
		nearest_distance = local_distance
	for mob_value: Variant in authoritative_mobs.values():
		var mob := mob_value as Node2D
		if mob == null or not is_instance_valid(mob) or not mob.visible:
			continue
		var distance: float = mob.global_position.distance_to(world_position)
		if distance <= selection_radius and distance < nearest_distance:
			nearest = mob
			nearest_distance = distance
	for enemy in $Enemies.get_children():
		var local_enemy := enemy as Node2D
		if local_enemy == null or not is_instance_valid(local_enemy) or not local_enemy.visible or authoritative_mobs.values().has(local_enemy):
			continue
		var enemy_distance: float = local_enemy.global_position.distance_to(world_position)
		if enemy_distance <= selection_radius and enemy_distance < nearest_distance:
			nearest = local_enemy
			nearest_distance = enemy_distance
	for user_id_value: Variant in remote_players.keys():
		var remote := remote_players[user_id_value] as Node2D
		if remote == null or not is_instance_valid(remote):
			continue
		var remote_distance: float = remote.global_position.distance_to(world_position)
		if remote_distance <= selection_radius and remote_distance < nearest_distance:
			nearest = remote
			nearest_distance = remote_distance
	if nearest == null:
		return
	_set_current_target(nearest)
	if nearest == $Player:
		_show_window($CanvasLayer/PlayerPanel)
	elif remote_players.values().has(nearest):
		for user_id_value: Variant in remote_players.keys():
			if remote_players[user_id_value] == nearest:
				_on_player_selected(int(user_id_value))
				return
	else:
		$CanvasLayer/PlayerStatusFrame.set_enemy_target(nearest)
		selected_player_id = 0
		$CanvasLayer/PlayerDetailsPanel.visible = false


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
		6:
			_show_window($CanvasLayer/SettingsPanel)
		7:
			_on_logout_pressed()


func _on_settings_applied() -> void:
	$CanvasLayer/SettingsPanel.move_to_front()


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
		$CanvasLayer/PlayerStatusFrame.clear_target()
	if dragging_panel == panel:
		dragging_panel = null


func _process(delta: float) -> void:
	_validate_current_target()
	refresh_elapsed += delta
	_update_player_status()
	player_state_save_elapsed += delta
	if player_state_save_elapsed >= 5.0 and not saving_player_state and bool($Player.call("is_state_dirty")):
		player_state_save_elapsed = 0.0
		saving_player_state = true
		await _save_player_state()
		saving_player_state = false
	Scope.realtime.poll()
	var realtime_connected_now := Scope.realtime.is_open()
	if realtime_connected_now and not realtime_was_connected:
		realtime_was_connected = true
		realtime_reconnect_elapsed = 0.0
		realtime_reconnect_attempting = false
		$CanvasLayer/OnlinePanel/VBoxContainer/Online.text = "You: online"
	elif not realtime_connected_now and realtime_was_connected:
		realtime_was_connected = false
		realtime_reconnect_elapsed = 0.0
		realtime_reconnect_attempting = false
		realtime_subscribed = false
		world_join_requested = false
		world_map_id = ""
		chat_history_scope_id = ""
		_reset_movement_send_state()
		last_world_sequence = 0
		pending_attack_mobs.clear()
		player_stats_request_sent = false
		pending_stat_transactions.clear()
		_clear_authoritative_mobs()
		_clear_remote_players()
	if not realtime_connected_now:
		realtime_reconnect_elapsed += delta
		if realtime_reconnect_elapsed >= realtime_reconnect_delay and not realtime_reconnect_attempting:
			_attempt_realtime_reconnect()
	_process_movement_sync(delta)
	if Scope.realtime.connected:
		$CanvasLayer/OnlinePanel/VBoxContainer/Online.text = "You: online"
	elif not realtime_reconnect_attempting:
		$CanvasLayer/OnlinePanel/VBoxContainer/Online.text = "You: offline"
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
	var betting_service: BettingPanelService = $CanvasLayer/BettingPanel.get("service")
	var wallet_result := await betting_service.balance()
	if wallet_result.success:
		var wallet: ScopeWizardsWagerWallet = wallet_result.data
		$CanvasLayer/PlayerPanel/VBoxContainer/Gold.text = "GOLD: %d" % wallet.gold
	else:
		_show_error(wallet_result.error)

	var bet_result := await betting_service.current_bet()
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
	var leaderboard_service: LeaderboardPanelService = $CanvasLayer/LeaderboardPanel.get("service")
	var result := await leaderboard_service.top(LEADERBOARD_METRIC, 10)
	if result.success:
		$CanvasLayer/LeaderboardPanel/VBoxContainer/Leaderboard.text = _format_leaderboard(result.data)
		_populate_leaderboard_buttons(result.data)
	else:
		_show_error(result.error)
	var rank_result := await leaderboard_service.rank(LEADERBOARD_METRIC)
	if rank_result.success:
		$CanvasLayer/PlayerPanel/VBoxContainer/Rank.text = "Your rank: %s" % _rank_text(rank_result.data)
	else:
		$CanvasLayer/PlayerPanel/VBoxContainer/Rank.text = "Your rank: unavailable"


func _load_bet_history() -> void:
	var history_service: BetHistoryPanelService = $CanvasLayer/BetHistoryPanel.get("service")
	var result := await history_service.history(50)
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
	var achievement_service: AchievementsPanelService = $CanvasLayer/AchievementsPanel.get("service")
	var result := await achievement_service.list()
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
	var social_service: SocialPanelService = $CanvasLayer/SocialPanel.get("service")
	var notifications_result := await social_service.notifications()
	if notifications_result.success:
		var messages: Array[String] = ["Unread messages"]
		var notifications: Array[ScopeNotification] = notifications_result.data
		for notification: ScopeNotification in notifications:
			messages.append("%s: %s" % [notification.title, notification.body])
		$CanvasLayer/SocialPanel/VBoxContainer/Messages.text = "\n".join(messages) if messages.size() > 1 else "No unread messages."
	else:
		$CanvasLayer/SocialPanel/VBoxContainer/Messages.text = "Messages unavailable: " + notifications_result.error

	var friends_result := await social_service.friends()
	if friends_result.success:
		var friends: Array[String] = ["Friends"]
		var friend_items: Array[ScopeFriend] = friends_result.data
		for friend: ScopeFriend in friend_items:
			friends.append("%s (%s)" % [friend.username, friend.status])
		$CanvasLayer/SocialPanel/VBoxContainer/Friends.text = "\n".join(friends) if friends.size() > 1 else "No friends yet."
	else:
		$CanvasLayer/SocialPanel/VBoxContainer/Friends.text = "Friends unavailable: " + friends_result.error


func _load_online_players() -> void:
	var online_service: OnlinePlayersPanelService = $CanvasLayer/OnlinePanel.get("service")
	var result := await online_service.online_players()
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
	if not Scope.realtime.message_received.is_connected(_on_realtime_message):
		Scope.realtime.message_received.connect(_on_realtime_message)
	var result := Scope.realtime.connect_with_session(Scope.session)
	if not result.success:
		$CanvasLayer/SocialPanel/VBoxContainer/Messages.text = "Realtime unavailable: " + result.error


func _attempt_realtime_reconnect() -> void:
	realtime_reconnect_attempting = true
	realtime_reconnect_elapsed = 0.0
	$CanvasLayer/OnlinePanel/VBoxContainer/Online.text = "Reconnecting..."
	_connect_realtime()
	realtime_reconnect_attempting = false


func _on_session_logged_out() -> void:
	if get_tree().current_scene != self:
		return
	get_tree().change_scene_to_file("res://login.tscn")


func _setup_chat() -> void:
	chat_dock = $CanvasLayer/LocalChatDock as LocalChatDock
	chat_dock.message_submitted.connect(_send_chat_message)


func _send_chat_message(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	chat_message_sequence += 1
	var chat_service: ChatPanelService = chat_dock.get("service")
	var result := await chat_service.send(trimmed, chat_message_sequence)
	if not result.success:
		chat_dock.show_status("Message failed: " + result.error, true)
		return
	chat_dock.clear_input()
	chat_dock.show_status("Sending...")


func _handle_chat_message(message: Dictionary) -> void:
	var data_value: Variant = message.get("data", {})
	if not data_value is Dictionary:
		return
	var data: Dictionary = data_value
	_display_chat_message(data, true)


func _display_chat_message(data: Dictionary, show_bubble: bool) -> void:
	if str(data.get("channel_type", "")) != "general":
		return
	var message_id := str(data.get("message_id", ""))
	if not message_id.is_empty() and delivered_chat_message_ids.has(message_id):
		return
	if not message_id.is_empty():
		delivered_chat_message_ids[message_id] = true
		while delivered_chat_message_ids.size() > 150:
			delivered_chat_message_ids.erase(delivered_chat_message_ids.keys()[0])
	var sender_id := int(data.get("sender_id", 0))
	var sender_username := str(data.get("sender_username", "Unknown"))
	var text := str(data.get("text", "")).strip_edges()
	if sender_id <= 0 or text.is_empty():
		return
	chat_dock.add_chat_message(sender_username, text)
	if not show_bubble:
		return
	var bubble_lifetime := 6.0
	var bubble_value: Variant = data.get("bubble", {})
	if bubble_value is Dictionary:
		var bubble: Dictionary = bubble_value
		if not bool(bubble.get("enabled", true)):
			return
		bubble_lifetime = clampf(float(bubble.get("lifetime_seconds", bubble_lifetime)), 1.0, 12.0)
	_show_chat_bubble(sender_id, sender_username, text, bubble_lifetime)


func _handle_available_chat_channels(message: Dictionary) -> void:
	var data_value: Variant = message.get("data", {})
	if not data_value is Dictionary or not Scope.realtime.is_open():
		return
	var data: Dictionary = data_value
	var channels_value: Variant = data.get("channels", [])
	if not channels_value is Array:
		return
	for value: Variant in channels_value:
		if not value is Dictionary:
			continue
		var channel: Dictionary = value
		if str(channel.get("channel_type", "")) != "general":
			continue
		var scope_id := str(channel.get("scope_id", ""))
		if scope_id.is_empty() or scope_id == chat_history_scope_id:
			return
		chat_history_scope_id = scope_id
		var chat_service: ChatPanelService = chat_dock.get("service")
		chat_service.request_history()
		return


func _handle_chat_history(message: Dictionary) -> void:
	var data_value: Variant = message.get("data", {})
	if not data_value is Dictionary:
		return
	var data: Dictionary = data_value
	var channel_value: Variant = data.get("channel", {})
	if not channel_value is Dictionary or str((channel_value as Dictionary).get("channel_type", "")) != "general":
		return
	var messages_value: Variant = data.get("messages", [])
	if not messages_value is Array:
		return
	for value: Variant in messages_value:
		if value is Dictionary:
			_display_chat_message(value as Dictionary, false)


func _handle_chat_history_rejected(message: Dictionary) -> void:
	var data_value: Variant = message.get("data", {})
	if not data_value is Dictionary or chat_dock == null:
		return
	var data: Dictionary = data_value
	chat_dock.show_status(str(data.get("message", "Unable to load chat history.")), true)


func _handle_chat_message_accepted(message: Dictionary) -> void:
	if chat_dock != null:
		chat_dock.show_status("")


func _handle_chat_message_rejected(message: Dictionary) -> void:
	var data_value: Variant = message.get("data", {})
	if not data_value is Dictionary or chat_dock == null:
		return
	var data: Dictionary = data_value
	var reason := str(data.get("message", "Message rejected."))
	chat_dock.show_status(reason, true)


func _show_chat_bubble(sender_id: int, sender_username: String, text: String, lifetime_seconds: float) -> void:
	var actor: Node2D = $Player if sender_id == Scope.session.current_user.id else remote_players.get(sender_id)
	if actor == null or not is_instance_valid(actor):
		return
	var bubble := actor.get_node_or_null("ChatBubble") as LocalChatBubble
	if bubble == null:
		bubble = CHAT_BUBBLE_SCRIPT.new() as LocalChatBubble
		bubble.name = "ChatBubble"
		actor.add_child(bubble)
	bubble.show_chat_message(sender_username, text, lifetime_seconds)


func _on_realtime_message(message: Dictionary) -> void:
	var message_type := str(message.get("type", ""))
	if message_type == "chat_message":
		_handle_chat_message(message)
		return
	if message_type == "chat_message_accepted":
		_handle_chat_message_accepted(message)
		return
	if message_type == "chat_message_rejected":
		_handle_chat_message_rejected(message)
		return
	if message_type == "chat_channels_available":
		_handle_available_chat_channels(message)
		return
	if message_type == "chat_history":
		_handle_chat_history(message)
		return
	if message_type == "chat_history_rejected":
		_handle_chat_history_rejected(message)
		return
	if message_type == "player_faction_reputation_changed":
		_handle_faction_reputation_changed(message)
		return
	if message_type == "player_status":
		_handle_player_status_message(message)
		return
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


func _handle_faction_reputation_changed(message: Dictionary) -> void:
	var data_value: Variant = message.get("data", {})
	if data_value is Dictionary:
		# The event contains the complete, absolute PlayerFactionState. Do not
		# apply its deltas locally; attack acknowledgements carry the same state.
		_apply_faction_state(data_value)


func _apply_faction_state(value: Variant) -> void:
	if not value is Dictionary:
		return
	var incoming_state: Dictionary = value
	if not incoming_state.has("standings"):
		return
	var player_id := int(incoming_state.get("player_id", 0))
	if player_id > 0 and player_id != int(Scope.session.current_user.id):
		return
	var standings_value: Variant = incoming_state.get("standings", [])
	if not standings_value is Array:
		return
	faction_state = incoming_state.duplicate(true)
	_update_faction_choice_display()


func _ensure_faction_choice_display() -> void:
	if faction_choice_container != null:
		return
	var player_panel_content := $CanvasLayer/PlayerPanel/VBoxContainer as VBoxContainer
	faction_choice_container = VBoxContainer.new()
	faction_choice_container.name = "FactionChoice"
	faction_choice_container.add_theme_constant_override("separation", 3)
	player_panel_content.add_child(faction_choice_container)
	faction_choice_title = Label.new()
	faction_choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	faction_choice_container.add_child(faction_choice_title)
	faction_choice_container.visible = false


func _update_faction_choice_display() -> void:
	_ensure_faction_choice_display()
	if faction_state.is_empty():
		faction_choice_container.visible = false
		return
	faction_choice_container.visible = true
	var choice_locked := bool(faction_state.get("choice_locked", false))
	var committed_faction_id := str(faction_state.get("committed_faction_id", ""))
	if choice_locked:
		faction_choice_title.text = "Faction: %s" % (committed_faction_id.capitalize() if not committed_faction_id.is_empty() else "Committed")
		for row_value: Variant in faction_choice_rows.values():
			(row_value as Control).visible = false
		return
	faction_choice_title.text = "Faction choice — defeat Knights to support their rival"
	var threshold := maxf(float(faction_state.get("choice_threshold", 100)), 1.0)
	var visible_rows: Dictionary = {}
	var standings_value: Variant = faction_state.get("standings", [])
	if standings_value is Array:
		for standing_value: Variant in standings_value:
			if not standing_value is Dictionary:
				continue
			var standing: Dictionary = standing_value
			var faction_id := str(standing.get("faction_id", ""))
			if faction_id.is_empty():
				continue
			visible_rows[faction_id] = true
			var row := _faction_choice_row(faction_id)
			row.visible = true
			var display_name := str(standing.get("display_name", faction_id.capitalize()))
			var reputation := float(standing.get("reputation", 0))
			var relationship := str(standing.get("relationship", "hostile")).capitalize()
			var label := row.get_node("Label") as Label
			var progress := row.get_node("Progress") as ProgressBar
			label.text = "%s: %d / %d (%s)" % [display_name, int(reputation), int(threshold), relationship]
			progress.max_value = threshold
			progress.value = clampf(reputation, 0.0, threshold)
	for faction_id_value: Variant in faction_choice_rows.keys():
		var faction_id := str(faction_id_value)
		if not visible_rows.has(faction_id):
			(faction_choice_rows[faction_id] as Control).visible = false


func _faction_choice_row(faction_id: String) -> VBoxContainer:
	var existing: Variant = faction_choice_rows.get(faction_id)
	if existing is VBoxContainer:
		return existing as VBoxContainer
	var row := VBoxContainer.new()
	row.name = "%sRow" % faction_id.capitalize()
	var label := Label.new()
	label.name = "Label"
	row.add_child(label)
	var progress := ProgressBar.new()
	progress.name = "Progress"
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(180.0, 14.0)
	row.add_child(progress)
	faction_choice_container.add_child(row)
	faction_choice_rows[faction_id] = row
	return row


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
	_apply_faction_state(data.get("faction_state", {}))
	if authoritative_state is Dictionary:
		_apply_faction_state((authoritative_state as Dictionary).get("faction_state", {}))
	var target_player_id := int(data.get("player_id", 0))
	if authoritative_state is Dictionary:
		target_player_id = int((authoritative_state as Dictionary).get("player_id", target_player_id))
	if target_player_id > 0 and target_player_id != int(Scope.session.current_user.id):
		return
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
			# attack_ack describes the target and therefore its health may be zero.
			# Player progression is applied only from player_stats_changed, which
			# carries the player's complete authoritative state.
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
	_apply_faction_state(data.get("faction_state", {}))
	var incoming_map_id := str(data.get("map_id", WORLD_MAP_ID))
	if not world_map_id.is_empty() and incoming_map_id != world_map_id:
		_clear_remote_players()
	world_map_id = incoming_map_id
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
	var combatants_value: Variant = data.get("combatants", [])
	var presented_mobs: Array = []
	if mobs_value is Array:
		presented_mobs.append_array(mobs_value)
	if combatants_value is Array:
		presented_mobs.append_array(combatants_value)
	for mob_value: Variant in presented_mobs:
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
	var combatants_value: Variant = data.get("combatants", [])
	var snapshot_received_at := float(Time.get_ticks_msec()) / 1000.0
	if mobs_value is Array:
		for mob_value: Variant in mobs_value:
			if mob_value is Dictionary:
				_spawn_or_update_authoritative_mob(mob_value, snapshot_received_at)
	if combatants_value is Array:
		for combatant_value: Variant in combatants_value:
			if combatant_value is Dictionary:
				_spawn_or_update_authoritative_mob(combatant_value, snapshot_received_at)

func _prepare_server_enemy_template() -> void:
	var template_names: Dictionary = {
		"zombie": "Zombie",
		"goblin": "Goblin",
		"skeleton": "Skeleton",
		"justice_knight": "NPC",
		"avenger_knight": "NPC"
	}
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
		var original_attack_hitbox := existing_enemy.get_node_or_null("BiteHitbox") as Area2D
		if original_attack_hitbox == null:
			original_attack_hitbox = existing_enemy.get_node_or_null("AttackHitbox") as Area2D
		if original_attack_hitbox != null:
			original_attack_hitbox.set_deferred("monitoring", false)
			original_attack_hitbox.set_deferred("monitorable", false)
	for enemy in $Enemies.get_children():
		_connect_enemy_target(enemy)


func _connect_enemy_target(enemy: Node) -> void:
	if enemy == null:
		return
	var enemy_area := enemy.get_node_or_null("EnemyArea") as Area2D
	if enemy_area == null or enemy_area.input_event.is_connected(_on_enemy_area_input_event):
		return
	enemy_area.input_pickable = true
	enemy_area.input_event.connect(_on_enemy_area_input_event.bind(enemy))


func _on_enemy_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, enemy: Node) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (event as InputEventMouseButton).pressed:
		_set_current_target(enemy)
		$CanvasLayer/PlayerStatusFrame.set_enemy_target(enemy)
		selected_player_id = 0
		$CanvasLayer/PlayerDetailsPanel.visible = false

func _spawn_or_update_authoritative_mob(data: Dictionary, snapshot_received_at: float = -1.0) -> void:
	var mob_id := str(data.get("mob_id", ""))
	if mob_id.is_empty():
		push_warning("[World] Ignoring mob event without mob_id")
		return
	var mob_type := str(data.get("mob_type", "zombie")).to_lower()
	var visual_id := str(data.get("visual_id", "")).to_lower()
	var template_key := visual_id if server_enemy_templates.has(visual_id) else mob_type
	var enemy: Node = authoritative_mobs.get(mob_id)
	if enemy == null or not is_instance_valid(enemy):
		var selected_template: Node = server_enemy_templates.get(template_key, server_enemy_templates.get("zombie"))
		if selected_template == null:
			push_error("[World] Cannot create mob %s because no enemy template is available." % mob_id)
			return
		if not server_enemy_templates.has(template_key):
			push_warning("[World] No visual mapping for mob_type=%s visual_id=%s; using the Zombie template." % [mob_type, visual_id])
		enemy = selected_template.duplicate()
		enemy.name = "Mob_%s" % mob_id
		enemy.visible = true
		$Enemies.add_child(enemy)
		if enemy.has_method("set_server_authoritative"):
			enemy.call("set_server_authoritative", mob_id)
		_connect_enemy_target(enemy)
		authoritative_mobs[mob_id] = enemy
		enemy.tree_exited.connect(_on_authoritative_mob_tree_exited.bind(mob_id, enemy), CONNECT_ONE_SHOT)
	if enemy.has_method("apply_server_snapshot"):
		enemy.call("apply_server_snapshot", data, snapshot_received_at)


func _on_authoritative_mob_tree_exited(mob_id: String, enemy: Node) -> void:
	if authoritative_mobs.get(mob_id) == enemy:
		authoritative_mobs.erase(mob_id)


func _apply_authoritative_mob_damage(data: Dictionary) -> void:
	var mob_id := str(data.get("mob_id", ""))
	var enemy: Node = authoritative_mobs.get(mob_id)
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_server_damage"):
		enemy.call("apply_server_damage", data)
	if int(data.get("remaining_health", 1)) <= 0 and enemy != null and is_instance_valid(enemy):
		_remove_target_indicators(enemy)
		if current_target == enemy:
			_clear_current_target()

func _apply_authoritative_mob_death(data: Dictionary) -> void:
	var mob_id := str(data.get("mob_id", ""))
	var enemy: Node = authoritative_mobs.get(mob_id)
	if enemy != null and is_instance_valid(enemy) and enemy.has_method("apply_server_death"):
		enemy.call("apply_server_death", data)
	if enemy != null and is_instance_valid(enemy):
		_remove_target_indicators(enemy)
		if current_target == enemy:
			_clear_current_target()

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
		if current_target == enemy:
			_clear_current_target()
		if $CanvasLayer/PlayerStatusFrame.get("enemy_target") == enemy:
			$CanvasLayer/PlayerStatusFrame.clear_target()
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
	var local_player: CharacterBody2D = $Player
	var local_velocity := local_player.velocity
	var local_facing := 1 if float(local_player.get("facing_direction")) >= 0.0 else -1
	var local_grounded := local_player.is_on_floor()
	var movement_state := _local_player_movement_state(local_player)
	var local_map_id := world_map_id if not world_map_id.is_empty() else WORLD_MAP_ID
	var position_changed := not has_sent_position or not local_player.position.is_equal_approx(last_sent_position)
	var teleporting := has_sent_position and (
		local_player.position.distance_to(last_sent_position) > 250.0
		or (not last_sent_map_id.is_empty() and local_map_id != last_sent_map_id)
	)
	var state_changed := (
		not is_equal_approx(local_player.rotation, last_sent_rotation)
		or local_facing != last_sent_facing
		or local_grounded != last_sent_grounded
		or movement_state != last_sent_movement_state
		or local_map_id != last_sent_map_id
		or teleporting
	)
	var cadence_due := movement_elapsed >= MOVEMENT_UPDATE_INTERVAL
	if not cadence_due and not state_changed:
		return
	if cadence_due:
		movement_elapsed = 0.0
	if not position_changed and not state_changed:
		return
	var next_sequence := movement_sequence + 1
	var payload := {
		"user_id": Scope.session.current_user.id,
		"position": {"x": local_player.position.x, "y": local_player.position.y},
		"velocity": {"x": local_velocity.x, "y": local_velocity.y},
		"rotation": local_player.rotation,
		"facing": local_facing,
		"grounded": local_grounded,
		"movement_state": movement_state,
		"sequence": next_sequence,
		"timestamp": Time.get_unix_time_from_system(),
		"sprite_file_id": sprite_file_id,
		"map_id": local_map_id,
		"teleport": teleporting
	}
	var result := Scope.realtime.publish(MOVEMENT_CHANNEL, payload)
	if result.success:
		movement_sequence = next_sequence
		last_sent_position = local_player.position
		last_sent_velocity = local_velocity
		last_sent_rotation = local_player.rotation
		last_sent_facing = local_facing
		last_sent_grounded = local_grounded
		last_sent_movement_state = movement_state
		last_sent_map_id = local_map_id
		has_sent_position = true
		movement_packets_sent += 1


func _handle_movement_message(message: Dictionary) -> void:
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
	var incoming_sprite_file_id: int = int(movement.get("sprite_file_id", 0))
	var remote_entity: Node2D = remote_players.get(user_id)
	if remote_entity == null or not is_instance_valid(remote_entity):
		remote_entity = _create_remote_player(user_id)
	if incoming_sprite_file_id > 0:
		_ensure_remote_sprite(user_id, incoming_sprite_file_id, remote_entity)
	remote_entity.call("push_movement_snapshot", movement)
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
	remote_entity.set_script(REMOTE_PLAYER_SCRIPT)
	remote_entity.name = "RemotePlayer_%d" % user_id
	remote_entity.z_index = $Player.z_index
	remote_entity.scale = $Player.scale
	var remote_sprite := AnimatedSprite2D.new()
	remote_sprite.name = "Sprite"
	remote_sprite.sprite_frames = $Player/Visual.sprite_frames
	remote_sprite.scale = $Player/Visual.scale
	remote_sprite.animation = &"character_idle"
	remote_entity.add_child(remote_sprite)
	add_child(remote_entity)
	remote_players[user_id] = remote_entity
	return remote_entity


func _remove_remote_player(user_id: int) -> void:
	var remote_player: Variant = remote_players.get(user_id)
	if current_target == remote_player:
		_set_current_target(null)
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
	var player_service: PlayerPanelService = $CanvasLayer/PlayerPanel.get("service")
	var result := await player_service.upload_sprite(path)
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
	var player_service: PlayerPanelService = $CanvasLayer/PlayerPanel.get("service")
	var result := await player_service.download_sprite(file_id)
	var current_entity: Variant = remote_players.get(user_id)
	if not is_instance_valid(remote_entity) or current_entity != remote_entity:
		remote_sprite_loading.erase(user_id)
		return
	if result.success and result.data is PackedByteArray:
		var frames: SpriteFrames = _sprite_frames_from_bytes(result.data)
		if frames != null:
			remote_entity.call("set_sprite_frames", frames)
			remote_sprite_file_ids[user_id] = file_id
	remote_sprite_loading.erase(user_id)


func _local_player_movement_state(local_player: CharacterBody2D) -> String:
	if bool(local_player.get("dead")):
		return "death"
	if bool(local_player.get("powering_up")):
		return "power_up"
	if bool(local_player.get("attacking")):
		return "attack"
	if float(local_player.get("hit_stun_timer")) > 0.0:
		return "hit"
	if not local_player.is_on_floor():
		return "jump"
	if absf(local_player.velocity.x) > 5.0:
		return "walk"
	return "idle"


func _reset_movement_send_state() -> void:
	movement_elapsed = 0.0
	has_sent_position = false
	last_sent_position = Vector2.ZERO
	last_sent_velocity = Vector2.ZERO
	last_sent_rotation = 0.0
	last_sent_facing = 0
	last_sent_grounded = false
	last_sent_movement_state = ""
	last_sent_map_id = ""


func _apply_local_sprite(path: String) -> bool:
	var frames: SpriteFrames = _sprite_frames_from_bytes(FileAccess.get_file_as_bytes(path))
	if frames == null:
		return false
	$Player/Visual.sprite_frames = frames
	$Player/Visual.play("character_idle")
	return true


func _restore_local_sprite() -> void:
	var player_service: PlayerPanelService = $CanvasLayer/PlayerPanel.get("service")
	var result := await player_service.download_sprite(sprite_file_id)
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
	var player: Node = $Player
	var player_service: PlayerPanelService = $CanvasLayer/PlayerPanel.get("service")
	var result := await player_service.save_state(player, sprite_file_id)
	if result.success:
		player.call("clear_state_dirty")


func _restore_player_state() -> void:
	if not Scope.is_logged_in():
		return
	var player_service: PlayerPanelService = $CanvasLayer/PlayerPanel.get("service")
	var result := await player_service.load_state()
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
	$CanvasLayer/PlayerStatusFrame.set_local_player(player, Scope.session.current_user.username)


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
	var player_service: PlayerPanelService = $CanvasLayer/PlayerPanel.get("service")
	var result := player_service.spend_stat_point(stat_name, transaction_id)
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
	var betting_service: BettingPanelService = $CanvasLayer/BettingPanel.get("service")
	var result := await betting_service.place_bet(amount, choice)
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
	var social_service: SocialPanelService = $CanvasLayer/SocialPanel.get("service")
	var result := await social_service.send_friend_request(username)
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
	var social_service: SocialPanelService = $CanvasLayer/SocialPanel.get("service")
	var result := await social_service.send_message(recipient_id, message_text)
	$CanvasLayer/SocialPanel/VBoxContainer/Messages.text = "Message sent." if result.success else "Message failed: " + result.error
	if result.success:
		$CanvasLayer/SocialPanel/VBoxContainer/MessageActions/Message.text = ""


func _on_player_selected(user_id: int) -> void:
	selected_player_id = user_id
	$CanvasLayer/PlayerStatusFrame.clear_target()
	$CanvasLayer/PlayerDetailsPanel.visible = true
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Username.text = "Loading player..."
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Gold.text = "Gold: loading"
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Online.text = "Status: loading"
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Status.text = ""
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Messages.text = "Loading messages..."
	var details_service: PlayerDetailsPanelService = $CanvasLayer/PlayerDetailsPanel.get("service")
	var profile_result := await details_service.profile(user_id)
	if profile_result.success:
		var profile: ScopeWizardsWagerPlayerProfile = profile_result.data
		$CanvasLayer/PlayerStatusFrame.set_target_status(profile.username, profile.online, {})
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Username.text = profile.username
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Gold.text = "Gold: %d" % profile.gold
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Online.text = "Status: online" if profile.online else "Status: offline"
	else:
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Status.text = "Profile unavailable: " + profile_result.error
	var status_service: PlayerStatusService = $CanvasLayer/PlayerStatusFrame.get("service")
	status_service.request_target_status(user_id)
	var messages_result := await details_service.messages(user_id, 50)
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
	var details_service: PlayerDetailsPanelService = $CanvasLayer/PlayerDetailsPanel.get("service")
	var result := await details_service.friends($CanvasLayer/PlayerDetailsPanel/VBoxContainer/Username.text)
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Status.text = "Friend request sent." if result.success else "Friend request failed: " + result.error


func _on_profile_send_message_pressed() -> void:
	if selected_player_id <= 0:
		return
	var message_text: String = $CanvasLayer/PlayerDetailsPanel/VBoxContainer/Message.text.strip_edges()
	var details_service: PlayerDetailsPanelService = $CanvasLayer/PlayerDetailsPanel.get("service")
	var result := await details_service.send_message(selected_player_id, message_text)
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Status.text = "Message sent." if result.success else "Message failed: " + result.error
	if result.success:
		$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Message.text = ""
		await _on_player_selected(selected_player_id)


func _close_player_details() -> void:
	selected_player_id = 0
	$CanvasLayer/PlayerDetailsPanel.visible = false
	$CanvasLayer/PlayerStatusFrame.clear_target()


func _handle_player_status_message(message: Dictionary) -> void:
	var data_value: Variant = message.get("data", {})
	if selected_player_id <= 0 or not data_value is Dictionary:
		return
	var data: Dictionary = data_value
	if int(data.get("player_id", 0)) != selected_player_id:
		return
	$CanvasLayer/PlayerStatusFrame.set_target_status($CanvasLayer/PlayerDetailsPanel/VBoxContainer/Username.text, bool(data.get("online", false)), data)


func _on_target_friend_requested() -> void:
	_on_profile_add_friend_pressed()


func _on_target_message_requested() -> void:
	$CanvasLayer/PlayerDetailsPanel.visible = true
	$CanvasLayer/PlayerDetailsPanel/VBoxContainer/Message.grab_focus()


func _on_target_inspect_requested() -> void:
	$CanvasLayer/PlayerDetailsPanel.visible = true


func _on_target_cleared() -> void:
	_close_player_details()


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
