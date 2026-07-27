class_name DemoPanelBase
extends Panel

var content: VBoxContainer

func _ready() -> void:
	if get_node_or_null("VBoxContainer") != null:
		content = $VBoxContainer
		return
	custom_minimum_size = Vector2(260, 120)
	content = VBoxContainer.new()
	content.name = "VBoxContainer"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_theme_constant_override("separation", 6)
	add_child(content)
	var title := Label.new()
	title.name = "Title"
	title.text = name
	content.add_child(title)
	var close := Button.new()
	close.name = "Close"
	close.text = "CLOSE"
	content.add_child(close)
	build_content()

func build_content() -> void:
	pass

func label_node(node_name: String, text: String = "") -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(label)
	return label

func button_node(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	content.add_child(button)
	return button
