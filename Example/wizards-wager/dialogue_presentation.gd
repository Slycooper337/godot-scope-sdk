class_name DialoguePresentation
extends Control

signal dialogue_action(action: String, session_id: String, conversation_id: String, node_id: String, choice_id: String)

var panel: PanelContainer
var speaker_label: Label
var portrait: TextureRect
var body_label: RichTextLabel
var choices: VBoxContainer
var continue_button: Button
var exit_button: Button
var message_label: Label
var confirmation: ConfirmationDialog

var session_id := ""
var conversation_id := ""
var node_id := ""
var current_revision := 0
var full_text := ""
var reveal_count := 0.0
var reveal_speed := 55.0
var pending_choice_id := ""
var session_active := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	hide_dialogue()


func _process(delta: float) -> void:
	if panel == null or not panel.visible or body_label.visible_characters < 0:
		return
	reveal_count += reveal_speed * delta
	body_label.visible_characters = mini(int(reveal_count), full_text.length())
	if body_label.visible_characters >= full_text.length():
		body_label.visible_characters = -1


func _unhandled_input(event: InputEvent) -> void:
	if not is_dialogue_open():
		return
	if event.is_action_pressed("ui_accept") and body_label.visible_characters >= 0:
		body_label.visible_characters = -1
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-410.0, -300.0)
	panel.size = Vector2(820.0, 270.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 20)
	content.add_child(speaker_label)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(96.0, 96.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.visible = false
	content.add_child(portrait)
	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.fit_content = false
	body_label.custom_minimum_size = Vector2(760.0, 92.0)
	body_label.scroll_active = false
	content.add_child(body_label)
	choices = VBoxContainer.new()
	content.add_child(choices)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.pressed.connect(_emit_continue)
	actions.add_child(continue_button)
	exit_button = Button.new()
	exit_button.text = "Leave"
	exit_button.pressed.connect(_emit_exit)
	actions.add_child(exit_button)
	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.modulate = Color(0.85, 0.85, 0.9)
	content.add_child(message_label)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Confirm Choice"
	confirmation.ok_button_text = "Choose"
	confirmation.confirmed.connect(_confirm_pending_choice)
	add_child(confirmation)


func show_node(data: Dictionary) -> void:
	var incoming_revision := int(data.get("dialogue_revision", data.get("revision", 0)))
	if incoming_revision > 0 and incoming_revision <= current_revision:
		return
	if incoming_revision > 0:
		current_revision = incoming_revision
	session_active = bool(data.get("active", true))
	session_id = str(data.get("dialogue_session_id", data.get("session_id", session_id)))
	conversation_id = str(data.get("conversation_id", conversation_id))
	node_id = str(data.get("node_id", node_id))
	var node_value: Variant = data.get("node", data)
	var node: Dictionary = node_value if node_value is Dictionary else data
	speaker_label.text = str(node.get("speaker_name", node.get("speaker_display_name", node.get("speaker_npc_id", ""))))
	var expression_id := str(node.get("expression_id", ""))
	if not expression_id.is_empty():
		speaker_label.text += "  [%s]" % expression_id
	var portrait_id := str(node.get("portrait_id", ""))
	portrait.texture = null
	if portrait_id.begins_with("res://") and ResourceLoader.exists(portrait_id):
		portrait.texture = load(portrait_id) as Texture2D
	portrait.visible = portrait.texture != null
	full_text = str(node.get("text", ""))
	body_label.text = full_text
	reveal_count = 0.0
	body_label.visible_characters = 0 if not full_text.is_empty() else -1
	message_label.text = str(data.get("message", ""))
	_clear_choices()
	var choice_values: Variant = data.get("choices", node.get("choices", []))
	if choice_values is Array:
		for choice_value in choice_values:
			if choice_value is Dictionary:
				_add_choice_button(choice_value)
	continue_button.visible = bool(data.get("can_continue", node.get("can_continue", false)))
	exit_button.text = "Leave" if session_active else "Close"
	exit_button.visible = not session_active or bool(data.get("player_may_exit", true))
	panel.visible = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_first_action()


func show_rejection(reason: String) -> void:
	if panel.visible:
		message_label.text = "Unavailable: %s" % reason


func show_message(message: String) -> void:
	if panel.visible:
		message_label.text = message


func hide_dialogue() -> void:
	if panel != null:
		panel.visible = false
	visible = false
	session_id = ""
	conversation_id = ""
	node_id = ""
	pending_choice_id = ""
	current_revision = 0
	session_active = false


func is_dialogue_open() -> bool:
	return panel != null and panel.visible


func _add_choice_button(value: Dictionary) -> void:
	var button := Button.new()
	var choice_id := str(value.get("choice_id", ""))
	var available := bool(value.get("available", value.get("enabled", true)))
	var disabled_reason := str(value.get("disabled_explanation", value.get("reason", "")))
	button.text = str(value.get("text", choice_id))
	if not available and not disabled_reason.is_empty():
		button.text += " — %s" % disabled_reason
	button.disabled = not available
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.set_meta("choice_id", choice_id)
	button.set_meta("requires_confirmation", bool(value.get("requires_confirmation", false)))
	button.pressed.connect(_on_choice_pressed.bind(button))
	choices.add_child(button)


func _on_choice_pressed(button: Button) -> void:
	if body_label.visible_characters >= 0:
		body_label.visible_characters = -1
		return
	var choice_id := str(button.get_meta("choice_id", ""))
	if bool(button.get_meta("requires_confirmation", false)):
		pending_choice_id = choice_id
		confirmation.dialog_text = "This choice may have a permanent consequence. Continue?"
		confirmation.popup_centered(Vector2i(520, 190))
		return
	_emit_choice(choice_id)


func _confirm_pending_choice() -> void:
	if pending_choice_id.is_empty():
		return
	var choice_id := pending_choice_id
	pending_choice_id = ""
	_emit_choice(choice_id)


func _emit_choice(choice_id: String) -> void:
	dialogue_action.emit("choose", session_id, conversation_id, node_id, choice_id)


func _emit_continue() -> void:
	if body_label.visible_characters >= 0:
		body_label.visible_characters = -1
		return
	dialogue_action.emit("continue", session_id, conversation_id, node_id, "")


func _emit_exit() -> void:
	if not session_active:
		hide_dialogue()
		return
	dialogue_action.emit("exit", session_id, conversation_id, node_id, "")


func _clear_choices() -> void:
	for child in choices.get_children():
		child.queue_free()


func _focus_first_action() -> void:
	for child in choices.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return
	if continue_button.visible:
		continue_button.grab_focus()
	elif exit_button.visible:
		exit_button.grab_focus()
