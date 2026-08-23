@tool
class_name QuestArea
extends Area2D

@export var area_id := "quest_area_1"
@export var display_name := "Quest Area"
@export var size := Vector2(320.0, 180.0):
	set(value):
		size = Vector2(maxf(value.x, 16.0), maxf(value.y, 16.0))
		_rebuild_shape()
		queue_redraw()
@export var runtime_visible := false
@export_multiline var interaction_text := ""
@export var authored_object_id := ""

var _collision_shape: CollisionShape2D


func _ready() -> void:
	_rebuild_shape()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _rebuild_shape() -> void:
	if not is_inside_tree():
		return
	if _collision_shape == null:
		_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
		_collision_shape.owner = owner
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	_collision_shape.shape = rectangle


func get_definition() -> Dictionary:
	return {
		"area_id": area_id,
		"display_name": display_name,
		"position": {"x": global_position.x, "y": global_position.y},
		"size": {"x": size.x, "y": size.y},
		"runtime_visible": runtime_visible,
		"interaction_text": interaction_text,
		"authored_object_id": authored_object_id
	}


func _draw() -> void:
	if not Engine.is_editor_hint() and not runtime_visible:
		return
	var fill := Color(0.95, 0.75, 0.2, 0.12)
	var line := Color(1.0, 0.85, 0.3, 0.9)
	draw_rect(Rect2(-size * 0.5, size), fill, true)
	draw_rect(Rect2(-size * 0.5, size), line, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-size.x * 0.5, -size.y * 0.5 - 8.0), "%s [%s]" % [display_name, area_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
