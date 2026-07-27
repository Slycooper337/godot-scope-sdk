extends Node2D


var email: String = ""
var password: String = ""
var submitting := false
@onready var login_button: Button = $VBoxContainer/HBoxContainer/LogIn
@onready var create_account_button: Button = $VBoxContainer/HBoxContainer/CreateAccount

func show_error(message: String) -> void:
	$VBoxContainer/Status.text = message
	login_button.disabled = false
	create_account_button.disabled = false
	submitting = false


func login() -> void:
	if submitting:
		return
	email = String($VBoxContainer/Email.text).strip_edges()
	password = String($VBoxContainer/Password.text)
	if email.is_empty() or password.is_empty():
		show_error("Enter your email and password.")
		return
	submitting = true
	$VBoxContainer/Status.text = "Signing in..."
	login_button.disabled = true
	create_account_button.disabled = true
	var result := await Scope.auth.login(email, password)
	if not result.success:
		show_error(result.error)
		return

	var user: ScopeUser = result.data
	get_tree().change_scene_to_file("res://game.tscn")
	

func _on_log_in_pressed() -> void:
	login()


func _on_auth_submitted(_text: String) -> void:
	login()


func _on_create_account_pressed() -> void:
	get_tree().change_scene_to_file("res://register.tscn")
