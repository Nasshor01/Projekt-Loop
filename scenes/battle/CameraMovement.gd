# Soubor: CameraMovement.gd (Verze s vylepšenou diagnostikou)
extends Camera2D

@export var speed = 1.0
@export var zoom_speed = 0.1
@export var min_zoom = 0.5
@export var max_zoom = 2.0

func set_camera_limits(grid_width: int, grid_height: int, cell_size: Vector2):
	var map_size_pixels = Vector2(grid_width * cell_size.x, grid_height * cell_size.y)
	limit_left = 0
	limit_top = 0
	limit_right = int(map_size_pixels.x)
	limit_bottom = int(map_size_pixels.y)

func _unhandled_input(event: InputEvent):

	# POHYB KAMERY
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE or event.button_mask & MOUSE_BUTTON_MASK_RIGHT):
		position -= event.relative / zoom * speed
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var new_zoom_value = zoom / (1 + zoom_speed)
			zoom = new_zoom_value.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
			
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var new_zoom_value = zoom * (1 + zoom_speed)
			zoom = new_zoom_value.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
