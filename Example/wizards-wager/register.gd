extends Node2D


func show_error(message: String) -> void:
	print(message)
	$VBoxContainer/Status.text = message


func _on_create_account_pressed() -> void:
	var username: String = String($VBoxContainer/Username.text).strip_edges()
	var email: String = String($VBoxContainer/Email.text).strip_edges()
	var password: String = String($VBoxContainer/Password.text)
	var confirmation: String = String($VBoxContainer/PasswordConfirm.text)

	if username.is_empty() or email.is_empty() or password.is_empty():
		show_error("Enter a username, email, and password.")
		return
	if password != confirmation:
		show_error("Passwords do not match.")
		return

	var result := await Scope.auth.register(email, username, password)
	if not result.success:
		show_error(result.error)
		return

	get_tree().change_scene_to_file("res://game.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://login.tscn")
