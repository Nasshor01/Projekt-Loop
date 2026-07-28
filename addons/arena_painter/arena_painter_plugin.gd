@tool
extends EditorPlugin

const AtlasPickerPanel = preload("res://addons/arena_painter/atlas_picker_panel.gd")

var _picker: Control
var _dock_title := "Arena Brush"

func _enter_tree() -> void:
	set_input_event_forwarding_always_enabled()
	_picker = AtlasPickerPanel.new()
	_picker.name = "ArenaBrushPicker"
	_picker.tile_selected.connect(_on_tile_selected)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _picker)
	# Skryj dok, dokud není vybraná ArenaFloor.
	_picker.visible = false

func _exit_tree() -> void:
	if _picker:
		remove_control_from_docks(_picker)
		_picker.queue_free()
		_picker = null

func _handles(object: Object) -> bool:
	return object is ArenaFloor

func _edit(object: Object) -> void:
	var arena := object as ArenaFloor
	if arena == null:
		_picker.visible = false
		return
	_picker.visible = true
	_picker.setup(arena.floor_atlas, arena.tile_pixel_size, arena.brush_atlas_coord)

func _make_visible(visible: bool) -> void:
	if _picker:
		_picker.visible = visible and _selected_arena() != null

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	var arena := _selected_arena()
	if arena == null or not arena.brush_enabled:
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton \
		and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: Vector2i = arena.pick_cell_from_camera(camera, event.position)
		if cell.x >= 0:
			arena.paint_cell(cell)
			arena.notify_property_list_changed()
			get_editor_interface().mark_scene_as_unsaved()
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event is InputEventMouseMotion \
		and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var cell: Vector2i = arena.pick_cell_from_camera(camera, event.position)
		if cell.x >= 0:
			arena.paint_cell(cell)
			get_editor_interface().mark_scene_as_unsaved()
			return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _on_tile_selected(coord: Vector2i) -> void:
	var arena := _selected_arena()
	if arena == null:
		return
	arena.brush_atlas_coord = coord
	arena.notify_property_list_changed()

func _selected_arena() -> ArenaFloor:
	var sel := get_editor_interface().get_selection().get_selected_nodes()
	if sel.is_empty():
		return null
	var node: Node = sel[0]
	if node is ArenaFloor:
		return node
	return null
