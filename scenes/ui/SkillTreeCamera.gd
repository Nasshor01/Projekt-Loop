# Soubor: scenes/ui/SkillTreeCamera.gd (FINÁLNÍ A ZJEDNODUŠENÁ OPRAVA)
extends Camera2D

@export var pan_speed: float = 1.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0

func _unhandled_input(event: InputEvent):
	# --- ZJEDNODUŠENÁ KONTROLA ---
	# Pokud zrovna interagujeme s nějakým jiným UI prvkem
	# (jako je tlačítko nebo LineEdit), tak kamerou nehýbeme.
	if get_viewport().gui_get_focus_owner() != null:
		return
	# -----------------------------

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = zoom / (1.0 + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = zoom * (1.0 + zoom_speed)
		zoom = zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		position -= event.relative / zoom * pan_speed
