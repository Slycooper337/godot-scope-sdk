extends Label

func _physics_process(delta: float) -> void:
	text = "%d/%d" % [int(get_parent().value), int(get_parent().max_value)]
