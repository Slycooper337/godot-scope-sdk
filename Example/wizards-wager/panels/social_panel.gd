class_name SocialPanel
extends DemoPanelBase

var service := SocialPanelService.new()

func build_content() -> void:
	label_node("Messages", "No unread messages.")
	label_node("Friends", "No friends yet.")
	var friend_actions := HBoxContainer.new()
	friend_actions.name = "FriendActions"
	content.add_child(friend_actions)
	var username := LineEdit.new()
	username.name = "Username"
	username.placeholder_text = "Username"
	friend_actions.add_child(username)
	var add_friend := Button.new()
	add_friend.name = "AddFriend"
	add_friend.text = "ADD FRIEND"
	friend_actions.add_child(add_friend)
	var message_actions := HBoxContainer.new()
	message_actions.name = "MessageActions"
	content.add_child(message_actions)
	var recipient := LineEdit.new()
	recipient.name = "Recipient"
	recipient.placeholder_text = "User ID"
	message_actions.add_child(recipient)
	var message := LineEdit.new()
	message.name = "Message"
	message.placeholder_text = "Message"
	message_actions.add_child(message)
	var send := Button.new()
	send.name = "SendMessage"
	send.text = "SEND"
	message_actions.add_child(send)
