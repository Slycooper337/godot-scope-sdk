extends Node2D

@export var radius := 13.0
@export var color := Color(1.0, 0.86, 0.25, 0.95)
var pulse := 0.0

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var thickness := 2.0 + sin(pulse * 5.0) * 0.5
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, thickness, true)
	draw_line(Vector2(-5, -radius - 7), Vector2(0, -radius - 12), color, thickness, true)
	draw_line(Vector2(0, -radius - 12), Vector2(5, -radius - 7), color, thickness, true)
