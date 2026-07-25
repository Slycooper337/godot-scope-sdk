extends Node2D


var email: String = ""
var password: String = ""

func show_error(message: String) -> void:
	print(message)
	$VBoxContainer/Status.text = message


func login() -> void:
	var result := await Scope.auth.login(email, password)
	if not result.success:
		show_error(result.error)
		return

	var user: ScopeUser = result.data
	get_tree().change_scene_to_file("res://game.tscn")
	

func _on_log_in_pressed() -> void:
	email = get_node("VBoxContainer/Email").text
	password = get_node("VBoxContainer/Password").text
	login()


func _on_create_account_pressed() -> void:
	get_tree().change_scene_to_file("res://register.tscn")
