@tool
extends Node3D
class_name ArenaFloor
## 3D bojiště 15×10. V editoru maluj dlaždice (plugin Arena Painter / tool buttons).
## BattleGrid z toho čte atlas coords — negeneruje vzhled náhodně.

const DEFAULT_W := 15
const DEFAULT_H := 10

@export var cell_size: float = 2.0
@export var grid_width: int = DEFAULT_W
@export var grid_height: int = DEFAULT_H
@export var floor_atlas: Texture2D
@export var tile_pixel_size: int = 64
@export var floor_tint: Color = Color(0.85, 0.82, 0.78, 1.0)
## Uložený layout: size = width*height, hodnoty = atlas (x,y).
@export var atlas_coords: PackedVector2Array = PackedVector2Array()

@export_group("Brush")
@export var brush_atlas_coord: Vector2i = Vector2i(0, 0)
@export var brush_enabled: bool = true

@warning_ignore("unused_private_class_variable")
@export_tool_button("Rebuild 3D grid") var _btn_rebuild: Callable = rebuild_grid
@warning_ignore("unused_private_class_variable")
@export_tool_button("Paint soft checker") var _btn_checker: Callable = paint_soft_checker
@warning_ignore("unused_private_class_variable")
@export_tool_button("Paint center path") var _btn_path: Callable = paint_center_path

var _cells: Dictionary = {} # Vector2i -> MeshInstance3D
var _atlas_image: Image = null
var _mat_cache: Dictionary = {} # Vector2i -> StandardMaterial3D

func _ready() -> void:
	if atlas_coords.is_empty():
		_init_default_coords()
	rebuild_grid()

func _init_default_coords() -> void:
	atlas_coords = PackedVector2Array()
	atlas_coords.resize(grid_width * grid_height)
	for y in range(grid_height):
		for x in range(grid_width):
			var i := _index(x, y)
			atlas_coords[i] = Vector2(0, 0) if (x + y) % 2 == 0 else Vector2(1, 0)

func _index(x: int, y: int) -> int:
	return y * grid_width + x

func get_atlas_coord(cell: Vector2i) -> Vector2i:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_width or cell.y >= grid_height:
		return Vector2i(0, 0)
	if atlas_coords.size() != grid_width * grid_height:
		_init_default_coords()
	var v: Vector2 = atlas_coords[_index(cell.x, cell.y)]
	return Vector2i(int(v.x), int(v.y))

func set_atlas_coord(cell: Vector2i, coord: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= grid_width or cell.y >= grid_height:
		return
	if atlas_coords.size() != grid_width * grid_height:
		_init_default_coords()
	atlas_coords[_index(cell.x, cell.y)] = Vector2(coord.x, coord.y)
	_apply_cell_visual(cell)

func paint_cell(cell: Vector2i) -> void:
	set_atlas_coord(cell, brush_atlas_coord)

func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local := to_local(world_pos)
	var x := int(floor((local.x / cell_size) + 0.5))
	var y := int(floor((local.z / cell_size) + 0.5))
	if x < 0 or y < 0 or x >= grid_width or y >= grid_height:
		return Vector2i(-1, -1)
	return Vector2i(x, y)

func pick_cell_from_camera(camera: Camera3D, screen_pos: Vector2) -> Vector2i:
	if camera == null:
		return Vector2i(-1, -1)
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector2i(-1, -1)
	# Rovína y = global y of this arena (cells at y=0 local).
	var plane_y := global_position.y
	var t := (plane_y - from.y) / dir.y
	if t < 0.0:
		return Vector2i(-1, -1)
	var hit := from + dir * t
	return world_to_cell(hit)

func rebuild_grid() -> void:
	for child in get_children():
		child.queue_free()
	_cells.clear()
	_mat_cache.clear()
	_atlas_image = null
	if atlas_coords.size() != grid_width * grid_height:
		_init_default_coords()
	for y in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, y)
			var mesh_inst := MeshInstance3D.new()
			mesh_inst.name = "Cell_%d_%d" % [x, y]
			var plane := PlaneMesh.new()
			plane.size = Vector2(cell_size * 0.98, cell_size * 0.98)
			mesh_inst.mesh = plane
			mesh_inst.position = Vector3(x * cell_size, 0.0, y * cell_size)
			add_child(mesh_inst)
			_cells[cell] = mesh_inst
			_apply_cell_visual(cell)

func _ensure_atlas_image() -> void:
	if _atlas_image != null or floor_atlas == null:
		return
	_atlas_image = floor_atlas.get_image()
	if _atlas_image and _atlas_image.is_compressed():
		_atlas_image.decompress()

func _material_for_coord(coord: Vector2i) -> StandardMaterial3D:
	if _mat_cache.has(coord):
		return _mat_cache[coord]
	_ensure_atlas_image()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = floor_tint
	mat.roughness = 0.9
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if _atlas_image:
		var px := tile_pixel_size
		var region := Rect2i(coord.x * px, coord.y * px, px, px)
		if Rect2i(Vector2i.ZERO, _atlas_image.get_size()).encloses(region):
			var tex := ImageTexture.create_from_image(_atlas_image.get_region(region))
			mat.albedo_texture = tex
	_mat_cache[coord] = mat
	return mat

func _apply_cell_visual(cell: Vector2i) -> void:
	var mesh_inst: MeshInstance3D = _cells.get(cell)
	if mesh_inst == null:
		return
	mesh_inst.material_override = _material_for_coord(get_atlas_coord(cell))

func paint_soft_checker() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			var coord := Vector2i(0, 0) if (x + y) % 2 == 0 else Vector2i(1, 0)
			set_atlas_coord(Vector2i(x, y), coord)
	notify_property_list_changed()

func paint_center_path() -> void:
	for y in range(grid_height):
		for x in range(grid_width):
			var coord: Vector2i
			var on_path := x >= 5 and x <= 9
			var on_edge := x == 0 or y == 0 or x == grid_width - 1 or y == grid_height - 1
			if on_path:
				coord = Vector2i(2, 0)
			elif on_edge:
				coord = Vector2i(5, 1)
			else:
				coord = Vector2i(0, 0) if (x + y) % 2 == 0 else Vector2i(1, 0)
			set_atlas_coord(Vector2i(x, y), coord)
	notify_property_list_changed()
