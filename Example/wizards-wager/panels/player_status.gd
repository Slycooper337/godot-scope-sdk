class_name PlayerStatus
extends Control

signal target_friend_requested
signal target_message_requested
signal target_inspect_requested
signal target_cleared

var service := PlayerStatusService.new()
var self_name_label: Label
var self_meta_label: Label
var target_name_label: Label
var target_meta_label: Label
var target_frame: PanelContainer
var self_health: ProgressBar
var self_stamina: ProgressBar
var self_mana: ProgressBar
var experience_bar: ProgressBar
var target_health: ProgressBar
var target_stamina: ProgressBar
var target_mana: ProgressBar
var target_health_text: Label
var target_stamina_text: Label
var target_mana_text: Label
var target_actions: HBoxContainer
var enemy_target: Node

func _ready() -> void:
	_build_ui()
	target_frame.visible = false

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "Frames"
	root.position = Vector2(18, 18)
	root.size = Vector2(360, 300)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var self_frame := _make_frame("SELF FRAME")
	root.add_child(self_frame)
	self_name_label = self_frame.get_node("Body/Header/Name") as Label
	self_meta_label = self_frame.get_node("Body/Meta") as Label
	var self_bars: VBoxContainer = self_frame.get_node("Body/Bars")
	self_health = _add_bar(self_bars, "Health", Color("d34b55"))
	self_stamina = _add_bar(self_bars, "Stamina", Color("e0b84f"))
	self_mana = _add_bar(self_bars, "Mana", Color("4d8edb"))
	experience_bar = _add_experience_bar()

	target_frame = _make_frame("TARGET FRAME")
	root.add_child(target_frame)
	target_name_label = target_frame.get_node("Body/Header/Name") as Label
	target_meta_label = target_frame.get_node("Body/Meta") as Label
	var target_bars: VBoxContainer = target_frame.get_node("Body/Bars")
	target_health = _add_bar(target_bars, "Health", Color("d34b55"))
	target_health_text = target_health.get_node("Value") as Label
	target_stamina = _add_bar(target_bars, "Stamina", Color("e0b84f"))
	target_stamina_text = target_stamina.get_node("Value") as Label
	target_mana = _add_bar(target_bars, "Mana", Color("4d8edb"))
	target_mana_text = target_mana.get_node("Value") as Label
	target_actions = HBoxContainer.new()
	target_actions.name = "Actions"
	(target_frame.get_node("Body") as VBoxContainer).add_child(target_actions)
	_add_action(target_actions, "Inspect", target_inspect_requested)
	_add_action(target_actions, "Message", target_message_requested)
	_add_action(target_actions, "Friend", target_friend_requested)
	_add_action(target_actions, "Clear", target_cleared)

func _make_frame(title: String) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(330, 138)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 3)
	frame.add_child(body)
	var header := HBoxContainer.new()
	header.name = "Header"
	body.add_child(header)
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(name_label)
	var meta := Label.new()
	meta.name = "Meta"
	meta.visible = false
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(meta)
	var bars := VBoxContainer.new()
	bars.name = "Bars"
	body.add_child(bars)
	return frame

func _add_bar(parent: VBoxContainer, label_text: String, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = label_text
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(Color("202735"), 4))
	bar.add_theme_stylebox_override("fill", _style(color, 4))
	var label := Label.new()
	label.name = "Value"
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(label)
	parent.add_child(bar)
	return bar

func _add_experience_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = "Experience"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 18.0
	bar.offset_top = -24.0
	bar.offset_right = -18.0
	bar.offset_bottom = -8.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(Color("202735"), 4))
	bar.add_theme_stylebox_override("fill", _style(Color("8b62c9"), 4))
	var label := Label.new()
	label.name = "Value"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(label)
	add_child(bar)
	return bar

func _add_action(parent: HBoxContainer, text: String, callback: Signal) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: callback.emit())
	parent.add_child(button)

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func set_local_player(player: Node, username: String) -> void:
	if player == null:
		return
	self_name_label.text = username
	self_meta_label.visible = true
	self_meta_label.text = "Level %d" % int(player.get("level"))
	_set_bar(self_health, float(player.get("current_health")), float(player.get("max_health")), true)
	_set_bar(self_stamina, float(player.get("current_stamina")), float(player.get("max_stamina")), true)
	_set_bar(self_mana, float(player.get("current_mana")), float(player.get("max_mana")), true)
	var experience := float(player.get("experience"))
	var next_level := float(player.call("get_experience_to_next_level"))
	_set_bar(experience_bar, experience, next_level, false)
	(experience_bar.get_node("Value") as Label).text = "Experience  %d / %d" % [int(experience), int(next_level)]

func set_target_status(username: String, online: bool, data: Dictionary) -> void:
	enemy_target = null
	target_actions.visible = true
	target_stamina.visible = true
	target_mana.visible = true
	target_stamina.modulate = Color.WHITE
	target_mana.modulate = Color.WHITE
	target_frame.visible = true
	target_name_label.text = username
	target_meta_label.visible = true
	target_meta_label.text = "Level %d  •  %s" % [int(data.get("level", 1)), "Online" if online else "Offline"]
	var resources: Dictionary = data.get("resources", {}) if data.get("resources", {}) is Dictionary else {}
	var health := float(resources.get("health", data.get("health", 0)))
	var derived: Dictionary = data.get("derived", {}) if data.get("derived", {}) is Dictionary else {}
	var max_health := float(derived.get("max_health", data.get("max_health", 100)))
	var stamina := float(resources.get("stamina", data.get("stamina", 0)))
	var max_stamina := float(derived.get("max_stamina", data.get("max_stamina", 100)))
	_set_bar(target_health, health, max_health, false)
	_set_bar(target_stamina, stamina, max_stamina, false)
	var mana := float(resources.get("mana", data.get("mana", 0)))
	var max_mana := float(derived.get("max_mana", data.get("max_mana", 100)))
	_set_bar(target_mana, mana, max_mana, false)
	target_health_text.text = "%d / %d" % [int(health), int(max_health)]
	target_stamina_text.text = "%d / %d" % [int(stamina), int(max_stamina)]
	target_mana_text.text = "%d / %d" % [int(mana), int(max_mana)]

func set_enemy_target(enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	enemy_target = enemy
	target_frame.visible = true
	target_actions.visible = false
	target_name_label.text = _enemy_name(enemy)
	target_meta_label.visible = true
	_update_enemy_target()

func _process(_delta: float) -> void:
	if enemy_target != null:
		if is_instance_valid(enemy_target):
			_update_enemy_target()
		else:
			enemy_target = null
			target_frame.visible = false

func _update_enemy_target() -> void:
	var enemy_health := float(enemy_target.get("health"))
	var enemy_max_health := float(enemy_target.get("max_health"))
	_set_bar(target_health, enemy_health, enemy_max_health, false)
	target_health_text.text = "%d / %d" % [int(enemy_health), int(enemy_max_health)]
	target_stamina.visible = true
	target_mana.visible = true
	target_health.visible = true
	target_stamina.modulate = Color(0.55, 0.55, 0.6, 1.0)
	target_mana.modulate = Color(0.55, 0.55, 0.6, 1.0)
	target_stamina_text.text = "N/A"
	target_mana_text.text = "N/A"
	target_meta_label.text = _enemy_relationship_text(enemy_target)


func _enemy_relationship_text(enemy: Node) -> String:
	if bool(enemy.get("dying")):
		return "Defeated"
	var faction_id := str(enemy.get("faction_id"))
	var relationship := str(enemy.get("relationship_to_player"))
	if faction_id.is_empty():
		faction_id = "enemy"
	if relationship.is_empty():
		relationship = "hostile"
	var attack_value: Variant = enemy.get("attack_legal")
	var attack_is_legal := true if attack_value == null else bool(attack_value)
	var lines := PackedStringArray([
		"%s - %s - %s" % [
			faction_id.replace("_", " ").capitalize(),
			relationship.replace("_", " ").capitalize(),
			"Attack allowed" if attack_is_legal else "Attack blocked"
		]
	])
	var reputation_value: Variant = enemy.get("reputation_effects")
	if reputation_value is Dictionary and not (reputation_value as Dictionary).is_empty():
		var effects: PackedStringArray = []
		for effect_faction_value: Variant in (reputation_value as Dictionary).keys():
			var amount := int((reputation_value as Dictionary)[effect_faction_value])
			effects.append("%s %s%d" % [str(effect_faction_value).capitalize(), "+" if amount >= 0 else "", amount])
		lines.append("On defeat: %s" % ", ".join(effects))
	return "\n".join(lines)

func _enemy_name(enemy: Node) -> String:
	var visual_id := str(enemy.get("visual_id"))
	if not visual_id.is_empty():
		return visual_id.replace("_", " ").capitalize()
	return enemy.name.replace("Mob_", "").replace("_", " ").capitalize()

func clear_target() -> void:
	enemy_target = null
	target_frame.visible = false

func _set_bar(bar: ProgressBar, value: float, maximum: float, show_text: bool) -> void:
	bar.max_value = maxf(maximum, 1.0)
	bar.value = clampf(value, 0.0, bar.max_value)
	if show_text:
		(bar.get_node("Value") as Label).text = "%d / %d" % [int(value), int(maximum)]
