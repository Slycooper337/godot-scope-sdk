class_name LocalChatBubble
extends Node2D

const MAX_VISIBLE_MESSAGES := 3
const MAX_CHARACTERS_PER_LINE := 12
const BOTTOM_CLEARANCE := 15.0
const FADE_DURATION := 1.5

@export_range(0.05, 1.0, 0.05) var display_scale := 0.1

var _panel: PanelContainer
var _label: Label
var _messages: Array[String] = []
var _hide_tween: Tween


func _ready() -> void:
	z_index = 50
	scale = Vector2.ONE * display_scale
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.96)
	style.border_color = Color(0.16, 0.16, 0.19, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(0.04, 0.04, 0.05))
	_label.add_theme_font_size_override("font_size", 42)
	_panel.add_child(_label)


func show_chat_message(_sender_username: String, text: String, lifetime_seconds: float = 6.0) -> void:
	_messages.append(text)
	while _messages.size() > MAX_VISIBLE_MESSAGES:
		_messages.pop_front()
	_label.text = _formatted_messages()
	_update_bubble_layout()
	modulate.a = 1.0
	if _hide_tween != null and _hide_tween.is_valid():
		_hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.tween_interval(maxf(lifetime_seconds - FADE_DURATION, 0.1))
	_hide_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_hide_tween.tween_callback(queue_free)


func _update_bubble_layout() -> void:
	# Use Godot's real font metrics instead of estimated word/line dimensions.
	_panel.size = _panel.get_combined_minimum_size()
	# Keep the bottom of the bubble above the character as its text grows.
	_panel.position = Vector2(-_panel.size.x * 0.5, -BOTTOM_CLEARANCE - _panel.size.y)


func _formatted_messages() -> String:
	var formatted: Array[String] = []
	for message: String in _messages:
		formatted.append(_wrap_text(message))
	return "\n".join(formatted)


func _wrap_text(message: String) -> String:
	var lines: Array[String] = []
	var current_line := ""
	for word: String in message.split(" ", false):
		if not current_line.is_empty() and current_line.length() + 1 + word.length() > MAX_CHARACTERS_PER_LINE:
			lines.append(current_line)
			current_line = ""
		current_line += (" " if not current_line.is_empty() else "") + word
	if not current_line.is_empty():
		lines.append(current_line)
	return "\n".join(lines)
