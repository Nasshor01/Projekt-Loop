# Village plateau in world space. Camera pans/zooms over the stretched layout.
class_name VillageWorld
extends Node2D

## Uniform scale of the layout sheet (512×343). Keep large — camera starts zoomed in.
@export var layout_scale: float = 4.0
## Godot 2D: higher zoom = closer. Extra cover so the plateau fills the viewport.
@export var camera_zoom: float = 1.55
@export var pan_speed: float = 900.0
@export var zoom_min: float = 0.9
@export var zoom_max: float = 2.4
@export var zoom_step: float = 0.12

const LAYOUT_SIZE := Vector2(512, 343)
const DRAG_BUTTONS := [
	MOUSE_BUTTON_MIDDLE,
	MOUSE_BUTTON_RIGHT,
]

@onready var plateau: Node2D = $Plateau
@onready var camera: Camera2D = $Camera2D

var camera_locked: bool = false
var _dragging: bool = false
var _drag_button: int = 0


func _ready() -> void:
	_apply_view()
	camera.enabled = true
	camera.make_current()
	# Area2D hover/click on ruins needs viewport picking (off by default in Godot 4).
	var vp := get_viewport()
	if vp:
		vp.physics_object_picking = true


func _apply_view() -> void:
	if plateau:
		plateau.scale = Vector2(layout_scale, layout_scale)
	if camera:
		camera.position = LAYOUT_SIZE * 0.5 * layout_scale
		camera.zoom = Vector2(camera_zoom, camera_zoom)
		_clamp_camera()


func _process(delta: float) -> void:
	if camera_locked or camera == null or _dragging:
		return
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir == Vector2.ZERO:
		return
	var zoom_x := maxf(camera.zoom.x, 0.001)
	camera.position += dir * pan_speed * delta / zoom_x
	_clamp_camera()


func _unhandled_input(event: InputEvent) -> void:
	if camera_locked or camera == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index in DRAG_BUTTONS:
			_dragging = true
			_drag_button = mouse.button_index
			get_viewport().set_input_as_handled()
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_cursor(camera.zoom.x + zoom_step)
			get_viewport().set_input_as_handled()
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_cursor(camera.zoom.x - zoom_step)
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed and mouse.button_index == _drag_button:
			_dragging = false
			_drag_button = 0
			return
	if camera_locked or camera == null or not _dragging:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var zoom_x := maxf(camera.zoom.x, 0.001)
		camera.position -= motion.relative / zoom_x
		_clamp_camera()
		get_viewport().set_input_as_handled()


func _zoom_at_cursor(target_zoom: float) -> void:
	var new_zoom := clampf(target_zoom, zoom_min, zoom_max)
	if is_equal_approx(new_zoom, camera.zoom.x):
		return
	var before := get_global_mouse_position()
	camera.zoom = Vector2(new_zoom, new_zoom)
	var after := get_global_mouse_position()
	camera.position += before - after
	_clamp_camera()


func _clamp_camera() -> void:
	if camera == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var zoom := Vector2(maxf(camera.zoom.x, 0.001), maxf(camera.zoom.y, 0.001))
	var half := vp / (zoom * 2.0)
	var world_min := Vector2.ZERO
	var world_max := LAYOUT_SIZE * layout_scale
	camera.position.x = _clamp_axis(camera.position.x, world_min.x, world_max.x, half.x)
	camera.position.y = _clamp_axis(camera.position.y, world_min.y, world_max.y, half.y)


func _clamp_axis(value: float, world_min: float, world_max: float, half: float) -> float:
	var lo := world_min + half
	var hi := world_max - half
	if lo > hi:
		return (world_min + world_max) * 0.5
	return clampf(value, lo, hi)


func get_building_slots() -> Array[VillageBuildingSlot]:
	var slots: Array[VillageBuildingSlot] = []
	var root := get_node_or_null("Plateau/Buildings")
	if root == null:
		return slots
	for child in root.get_children():
		if child is VillageBuildingSlot:
			slots.append(child)
	return slots
