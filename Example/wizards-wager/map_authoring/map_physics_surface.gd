@tool
class_name MapPhysicsSurface
extends StaticBody2D

enum SurfaceShape { RECTANGLE, SEGMENT }

@export var surface_id := "ground_1"
@export_enum("floor", "platform", "ceiling", "wall", "solid") var surface_role := "solid"
@export var surface_shape: SurfaceShape = SurfaceShape.RECTANGLE
@export var size := Vector2(256.0, 32.0):

	set(value):
		size = value
		_rebuild_shape()

@export var one_way := false:

	set(value):
		one_way = value
		_rebuild_shape()

@export var collision_layer_value := 1
@export var collision_mask_value := 1

var _collision_shape: CollisionShape2D


func _ready() -> void:
	collision_layer = collision_layer_value
	collision_mask = collision_mask_value
	_rebuild_shape()
	queue_redraw()


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
	if surface_shape == SurfaceShape.SEGMENT:
		var segment := SegmentShape2D.new()
		segment.a = Vector2(-size.x * 0.5, 0.0)
		segment.b = Vector2(size.x * 0.5, 0.0)
		_collision_shape.shape = segment
	else:
		var rectangle := RectangleShape2D.new()
		rectangle.size = size
		_collision_shape.shape = rectangle
	_collision_shape.one_way_collision = one_way


func get_definition() -> Dictionary:
	return {
		"surface_id": surface_id,
		"surface_role": surface_role,
		"shape": "segment" if surface_shape == SurfaceShape.SEGMENT else "rectangle",
		"position": {"x": global_position.x, "y": global_position.y},
		"size": {"x": size.x, "y": size.y},
		"rotation": rotation,
		"one_way": one_way,
		"collision_layer": collision_layer_value,
		"collision_mask": collision_mask_value
	}


func _draw() -> void:
	var color := Color(0.15, 0.75, 1.0, 0.28) if Engine.is_editor_hint() else Color(0.16, 0.16, 0.18, 1.0)
	if surface_shape == SurfaceShape.SEGMENT:
		draw_line(Vector2(-size.x * 0.5, 0.0), Vector2(size.x * 0.5, 0.0), color, 8.0)
	else:
		draw_rect(Rect2(-size * 0.5, size), color, true)
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, Vector2(-size.x * 0.5, -size.y * 0.5 - 6.0), surface_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
