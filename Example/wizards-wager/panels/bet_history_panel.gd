class_name BetHistoryPanel
extends DemoPanelBase

var service := BetHistoryPanelService.new()

func build_content() -> void:
	label_node("History", "No completed bets yet.")
