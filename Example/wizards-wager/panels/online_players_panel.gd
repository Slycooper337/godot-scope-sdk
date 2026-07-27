class_name OnlinePlayersPanel
extends DemoPanelBase

var service := OnlinePlayersPanelService.new()

func build_content() -> void:
	label_node("Online", "You: offline")
	label_node("OnlinePlayers", "No players online.")
	var buttons := VBoxContainer.new()
	buttons.name = "OnlineButtons"
	content.add_child(buttons)
