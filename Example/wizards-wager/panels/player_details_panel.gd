class_name PlayerDetailsPanel
extends DemoPanelBase

var service := PlayerDetailsPanelService.new()

func build_content() -> void:
	label_node("Username", "Player")
	label_node("Gold", "Gold: unavailable")
	label_node("Online", "Status: unavailable")
	label_node("Status", "")
	label_node("Messages", "")
	button_node("Friend", "ADD FRIEND")
	var message := LineEdit.new()
	message.name = "Message"
	message.placeholder_text = "Message"
	content.add_child(message)
	button_node("SendMessage", "SEND MESSAGE")
