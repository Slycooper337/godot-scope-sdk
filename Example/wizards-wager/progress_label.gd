extends Label

var progress_bar = get_parent()



func _on_timer_timeout() -> void:
	text = "%d/%d" % [int(get_parent().value), int(get_parent().max_value)]
	self.get_parent().texture_progress.width = (get_parent().max_value/5)
	self.get_parent().texture_under.width = (get_parent().max_value/5)
	pass # Replace with function body.
