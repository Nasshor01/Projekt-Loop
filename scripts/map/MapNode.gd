# MapNode.gd
# OPRAVENO: Přidána podtržítka k nepoužitým parametrům.
extends Area2D
class_name MapNode

var node_data: MapNodeResource

signal node_clicked(map_node)
signal node_hovered(map_node)
signal node_exited(map_node)

func _ready():
	input_pickable = true
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func set_data(data: MapNodeResource):
	node_data = data
	position = node_data.position

# Oprava varování: Přidání podtržítek k parametrům, které se ve funkci nepoužívají.
func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		emit_signal("node_clicked", self)
		get_viewport().set_input_as_handled()

func _on_mouse_entered():
	emit_signal("node_hovered", self)

func _on_mouse_exited():
	emit_signal("node_exited", self)
