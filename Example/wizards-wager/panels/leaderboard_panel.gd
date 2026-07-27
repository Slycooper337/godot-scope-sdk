class_name LeaderboardPanel
extends DemoPanelBase

var service := LeaderboardPanelService.new()

func build_content() -> void:
	label_node("Leaderboard", "Loading leaderboard...")
	var buttons := VBoxContainer.new()
	buttons.name = "LeaderboardButtons"
	content.add_child(buttons)
