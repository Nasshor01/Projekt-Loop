# MapNode.gd
extends Area2D
class_name MapNode

var node_data: MapNodeResource
var _collision_shape: CollisionShape2D

signal node_clicked(map_node)
signal node_hovered(map_node)
signal node_exited(map_node)

func _ready():
	input_pickable = true
	_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_interactive(enabled: bool) -> void:
	input_pickable = enabled
	if _collision_shape != null:
		_collision_shape.disabled = not enabled

func set_data(data: MapNodeResource):
	node_data = data
	position = node_data.position


func sync_collision_from_sprite() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if sprite == null or col == null or sprite.texture == null:
		return
	_collision_shape = col
	var shape := col.shape as CircleShape2D
	if shape == null:
		shape = CircleShape2D.new()
		col.shape = shape
	col.scale = Vector2.ONE
	var tex_size := sprite.texture.get_size() * sprite.scale.abs()
	shape.radius = minf(maxf(tex_size.x, tex_size.y) * 0.42, 52.0)

# Oprava varování: Přidání podtržítek k parametrům, které se ve funkci nepoužívají.
func _on_input_event(_viewport, event, _shape_idx):
	if not input_pickable:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		emit_signal("node_clicked", self)
		get_viewport().set_input_as_handled()

func _on_mouse_entered():
	if not input_pickable:
		return
	emit_signal("node_hovered", self)

func _on_mouse_exited():
	if not input_pickable:
		return
	emit_signal("node_exited", self)
