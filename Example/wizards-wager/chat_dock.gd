class_name LocalChatDock
extends PanelContainer

signal message_submitted(text: String)

const MAX_TRANSCRIPT_LINES := 100

@onready var _transcript: TextEdit = $VBoxContainer/Transcript
@onready var _input: LineEdit = $VBoxContainer/Input
@onready var _status: Label = $VBoxContainer/Status
@onready var _minimize_button: Button = $VBoxContainer/Minimize
@onready var _header: Label = $VBoxContainer/Header
var _lines: Array[String] = []
var _minimized := false
var _expanded_offset_top := 0.0


func _ready() -> void:
	# Only the message input should participate in keyboard focus. The
	# minimize/show control must not steal focus while gameplay keys are held.
	_minimize_button.focus_mode = Control.FOCUS_NONE
	_header.focus_mode = Control.FOCUS_NONE
	_transcript.focus_mode = Control.FOCUS_NONE
	_input.text_submitted.connect(_submit)
	_minimize_button.pressed.connect(_toggle_minimized)
	_expanded_offset_top = offset_top


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		if not _input.has_focus():
			_input.grab_focus()
			get_viewport().set_input_as_handled()


func add_chat_message(sender_username: String, text: String) -> void:
	var safe_sender := sender_username.strip_edges()
	if safe_sender.is_empty():
		safe_sender = "Unknown"
	_lines.append("[%s] %s" % [safe_sender, text])
	while _lines.size() > MAX_TRANSCRIPT_LINES:
		_lines.pop_front()
	_transcript.text = "\n".join(_lines)
	_transcript.scroll_vertical = _transcript.get_line_count()
	_status.text = ""


func show_status(message: String, is_error: bool = false) -> void:
	_status.text = message
	_status.modulate = Color(1.0, 0.55, 0.55) if is_error else Color(0.8, 0.85, 0.95)


func _submit(_submitted_text: String) -> void:
	var text := _input.text.strip_edges()
	if text.is_empty():
		return
	message_submitted.emit(text)


func clear_input() -> void:
	_input.clear()


func _toggle_minimized() -> void:
	_minimized = not _minimized
	_header.visible = not _minimized
	_transcript.visible = not _minimized
	_status.visible = not _minimized
	_input.visible = true
	_minimize_button.text = "SHOW CHAT" if _minimized else "MINIMIZE"
	# Bottom anchors remain fixed; retain the input while collapsing chat display.
	offset_top = -84.0 if _minimized else _expanded_offset_top
