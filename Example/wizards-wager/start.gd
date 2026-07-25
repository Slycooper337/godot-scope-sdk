extends Node2D


func _ready() -> void:
	var result := await Scope.initialize()
	if not result.success:
		push_error(result.error)
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
	pass
