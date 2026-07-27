class_name AchievementsPanel
extends DemoPanelBase

var service := AchievementsPanelService.new()

func build_content() -> void:
	label_node("Achievements", "Loading achievements...")
