extends Node2D


func _ready() -> void:
	$VBoxContainer/Status.text = "Connecting..."
	$VBoxContainer/Retry.disabled = true
	$VBoxContainer/Quit.disabled = false
	$VBoxContainer/Retry.pressed.connect(_initialize_scope)
	$VBoxContainer/Quit.pressed.connect(_quit)
	await _initialize_scope()


func _initialize_scope() -> void:
	$VBoxContainer/Retry.disabled = true
	$VBoxContainer/Status.text = "Connecting..."
	var result := await Scope.initialize()
	if not result.success:
		$VBoxContainer/Status.text = "Unable to connect: %s" % result.error
		$VBoxContainer/Retry.disabled = false
		return

	if Scope.session.logged_in:
		load_game()
	else:
		show_login()


func load_game():
	get_tree().change_scene_to_file("res://game.tscn")
	pass
	
func show_login():
	get_tree().change_scene_to_file("res://login.tscn")


func _quit() -> void:
	get_tree().quit()
