class_name BettingPanel
extends DemoPanelBase

var service := BettingPanelService.new()

func build_content() -> void:
	var amount := LineEdit.new()
	amount.name = "BetAmount"
	amount.placeholder_text = "Bet amount"
	content.add_child(amount)
	var choice := OptionButton.new()
	choice.name = "Choice"
	choice.add_item("Choose side")
	choice.add_item("Knights")
	choice.add_item("Rivals")
	content.add_child(choice)
	button_node("PlaceBet", "PLACE BET")
	label_node("BetStatus", "No active bet")
	label_node("Countdown", "")
	label_node("Status", "")
