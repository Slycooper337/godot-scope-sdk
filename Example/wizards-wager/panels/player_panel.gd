class_name PlayerPanel
extends DemoPanelBase

var service := PlayerPanelService.new()

func build_content() -> void:
	label_node("Username", "Player")
	label_node("Gold", "GOLD: 0")
	label_node("Rank", "Your rank: unavailable")
	button_node("ChangeSprite", "CHANGE SPRITE")
	label_node("Level", "Level: 1")
	label_node("Experience", "Experience: 0")
	label_node("Points", "Points: 0")
	for stat in ["Strength", "Agility", "Intelligence", "Luck", "Endurance"]:
		button_node("%sButton" % stat, "+ %s" % stat)
