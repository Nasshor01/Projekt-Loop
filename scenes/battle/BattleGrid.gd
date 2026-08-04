class_name BattleGrid
extends Node3D

# --- 3D NASTAVENÍ ---
@export var cell_size_3d: float = 2.0
@export var floor_mesh: Mesh 
@export var cursor_mesh: Mesh

# --- VZHLED MŘÍŽKY ---
@export_group("Grid Appearance")
@export var material_light: StandardMaterial3D # Fallback světlé políčko
@export var material_dark: StandardMaterial3D  # Fallback tmavé políčko
@export_group("Arena Floor")
## 3D arena namalovaná v editoru (ArenaDefault). Null = fallback light/dark.
@export var arena_floor_scene: PackedScene
@export var floor_atlas: Texture2D
@export var floor_tile_pixel_size: int = 64
@export var floor_tint: Color = Color(0.85, 0.82, 0.78, 1.0)
# ----------------------------------

# --- PŮVODNÍ NASTAVENÍ ---
@export var grid_columns: int = 15
@export var grid_rows: int = 10

@export var grid_line_color: Color = Color(0.5, 0.5, 0.5, 0.5)
@export var highlight_color: Color = Color(1, 1, 0, 0.35)
# Přehled barev overlay: zelená = pohyb hráče, modrá = pohyb nepřítele, červená = útok
@export var movement_highlight_color: Color = Color(0.15, 0.88, 0.25, 0.5)   # zelená – move player
@export var attack_highlight_color: Color = Color(0.95, 0.15, 0.15, 0.55)    # červená – attack
@export var support_highlight_color: Color = Color(0.2, 0.5, 1.0, 0.45)
@export var aoe_highlight_color: Color = Color(0.8, 0.2, 1.0, 0.4)
@export var player_spawn_highlight_color: Color = Color(0.2, 0.9, 0.9, 0.45)
@export var movement_warning_color: Color = Color(0.9, 0.75, 0.1, 0.45)
@export var danger_zone_color: Color = Color(0.85, 0.2, 0.2, 0.4)
@export var enemy_range_highlight_color: Color = Color(0.2, 0.45, 0.95, 0.5) # modrá – move enemy
@export var initiative_hover_color: Color = Color(1.0, 0.82, 0.08, 0.78) # zlatá – hover v initiative baru
@export var artifact_throne_color: Color = Color(0.98, 0.82, 0.12, 0.85)
@export var artifact_crown_color: Color = Color(0.82, 0.35, 1.0, 0.85)
@export var artifact_line_color: Color = Color(1.0, 0.88, 0.15, 0.72)
@export var artifact_grove_color: Color = Color(0.25, 0.85, 0.35, 0.7)

@onready var units_container: Node3D = $UnitsContainer
var _terrain_container: Node3D
var _highlights_container: Node3D
var _artifact_markers_container: Node3D
var _tex_throne_marker: Texture2D
var _tex_crown_marker: Texture2D
## Flat ground decals use the same Sprite3D path as mud (AXIS_Y).

var camera: Camera3D

var _active_cells: Dictionary = {}
var _grid_objects: Dictionary = {}
var terrain_layer: Dictionary = {}
## Sprite3D overlays for placed terrain (keyed by grid cell). Separate from floor tiles in _terrain_container.
var _terrain_visuals: Dictionary = {}
## Floor tile meshes for tint highlights (keyed by grid cell).
var _floor_tiles: Dictionary = {}
var _floor_tile_is_light: Dictionary = {}
## Base material per cell — used when resetting / tinting.
var _floor_base_materials: Dictionary = {}
## Cache: atlas coord -> StandardMaterial3D
var _materials_by_atlas_coord: Dictionary = {}
var _floor_atlas_image: Image = null
## Namalovaná arena (data); vizuály floor tiles se staví do _terrain_container.
var _arena_floor: ArenaFloor = null
## Flat trap sprites that yaw-follow the camera.
var _yaw_follow_sprites: Array[Sprite3D] = []
var _highlight_tweens: Array[Tween] = []
var _mouse_over_cell: Vector2i = Vector2i(-1, -1)

var _movable_cells: Array[Vector2i] = []
var _targetable_cells: Array[Vector2i] = []
var _aoe_cells: Array[Vector2i] = []
var _player_spawn_cells: Array[Vector2i] = []
var _warning_cells: Array[Vector2i] = []
var _danger_cells: Array[Vector2i] = []
var _enemy_range_cells: Array[Vector2i] = []       # modrá = kam může nepřítel dojít (move)
var _enemy_attack_range_cells: Array[Vector2i] = [] # červená = kam může nepřítel udeřit (attack)
var _targetable_cells_color: Color = attack_highlight_color
var _spawn_highlight_nodes: Array[MeshInstance3D] = []
var _spawn_pulse_active: bool = false
var _enemy_overlap_pulse_nodes: Array[MeshInstance3D] = []  # buňky kde move == attack (modrá ↔ červená)
# Coop: vybrané spawn buňky – Dictionary { Vector2i -> Color }
var _coop_selected_spawns: Dictionary = {}
var _initiative_hover_cell: Vector2i = Vector2i(-1, -1)
## Persistent artifact zones: cell -> {kind, charges, max_charges}
var _artifact_zones: Dictionary = {}
## Gilded Dragonheart line tint cells
var _artifact_line_cells: Array[Vector2i] = []

func _ready():
	_terrain_container = Node3D.new()
	_terrain_container.name = "TerrainContainer"
	add_child(_terrain_container)
	
	_highlights_container = Node3D.new()
	_highlights_container.name = "HighlightsContainer"
	add_child(_highlights_container)

	_artifact_markers_container = Node3D.new()
	_artifact_markers_container.name = "ArtifactMarkersContainer"
	add_child(_artifact_markers_container)
	_tex_throne_marker = load("res://art/icons/artifact_fx/throne_marker.png") as Texture2D
	_tex_crown_marker = load("res://art/icons/artifact_fx/crown_marker.png") as Texture2D
	
	if not units_container:
		units_container = Node3D.new()
		units_container.name = "UnitsContainer"
		add_child(units_container)
	
	set_process_input(true)
	set_process(true)

func set_camera(cam_ref: Camera3D):
	self.camera = cam_ref

func _process(_delta: float) -> void:
	if not camera or _yaw_follow_sprites.is_empty():
		return
	var yaw := camera.global_rotation.y
	for i in range(_yaw_follow_sprites.size() - 1, -1, -1):
		var spr := _yaw_follow_sprites[i]
		if not is_instance_valid(spr):
			_yaw_follow_sprites.remove_at(i)
			continue
		spr.rotation.y = yaw

func set_mouse_over_cell(cell: Vector2i):
	if cell != _mouse_over_cell:
		_mouse_over_cell = cell
		update_visual_highlights()

func build_from_shape(shape_array: Array):
	_active_cells.clear()
	terrain_layer.clear()
	_floor_tiles.clear()
	_floor_tile_is_light.clear()
	_floor_base_materials.clear()
	_materials_by_atlas_coord.clear()
	_floor_atlas_image = null
	_yaw_follow_sprites.clear()
	_artifact_zones.clear()
	_artifact_line_cells.clear()
	for spr in _terrain_visuals.values():
		if is_instance_valid(spr):
			spr.queue_free()
	_terrain_visuals.clear()
	
	if _terrain_container:
		for child in _terrain_container.get_children():
			child.queue_free()
	if is_instance_valid(_artifact_markers_container):
		for child in _artifact_markers_container.get_children():
			child.queue_free()	
	grid_rows = shape_array.size()
	if grid_rows > 0:
		grid_columns = shape_array[0].length()
	else:
		grid_columns = 0

	_ensure_arena_floor()
	_ensure_floor_atlas_image()

	for y in range(grid_rows):
		var row_string = shape_array[y]
		for x in range(row_string.length()):
			if row_string[x] == "1":
				var pos = Vector2i(x, y)
				_active_cells[pos] = true
				
				if floor_mesh and _terrain_container:
					var tile = MeshInstance3D.new()
					tile.mesh = floor_mesh
					tile.name = "Tile_%d_%d" % [x, y]
					
					var is_light := (x + y) % 2 == 0
					_floor_tile_is_light[pos] = is_light
					var base_mat := _make_floor_material_for_cell(pos, is_light)
					_floor_base_materials[pos] = base_mat
					if base_mat:
						tile.material_override = base_mat
					
					_terrain_container.add_child(tile)
					tile.position = Vector3(x * cell_size_3d, -0.01, y * cell_size_3d)
					_floor_tiles[pos] = tile

func _ensure_arena_floor() -> void:
	if is_instance_valid(_arena_floor):
		return
	if arena_floor_scene == null:
		return
	var inst := arena_floor_scene.instantiate()
	if inst is ArenaFloor:
		_arena_floor = inst
		# Jen data — nepřidáváme do stromu (vizuál si staví BattleGrid).
	else:
		inst.queue_free()

func _ensure_floor_atlas_image() -> void:
	if _floor_atlas_image != null:
		return
	var atlas: Texture2D = floor_atlas
	if atlas == null and is_instance_valid(_arena_floor):
		atlas = _arena_floor.floor_atlas
	if atlas == null:
		return
	_floor_atlas_image = atlas.get_image()
	if _floor_atlas_image == null:
		push_warning("BattleGrid: floor atlas get_image() selhalo.")
		return
	if _floor_atlas_image.is_compressed():
		_floor_atlas_image.decompress()

func _arena_coord_for_shape_cell(cell: Vector2i) -> Vector2i:
	if not is_instance_valid(_arena_floor):
		return Vector2i(0, 0) if (cell.x + cell.y) % 2 == 0 else Vector2i(1, 0)
	var aw: int = _arena_floor.grid_width
	var ah: int = _arena_floor.grid_height
	var ox: int = int(floor(float(aw - grid_columns) * 0.5))
	var oy: int = int(floor(float(ah - grid_rows) * 0.5))
	return _arena_floor.get_atlas_coord(Vector2i(cell.x + ox, cell.y + oy))

func _material_for_atlas_coord(coord: Vector2i) -> StandardMaterial3D:
	if _materials_by_atlas_coord.has(coord):
		return _materials_by_atlas_coord[coord]
	if _floor_atlas_image == null:
		return null
	var px: int = floor_tile_pixel_size
	if is_instance_valid(_arena_floor):
		px = _arena_floor.tile_pixel_size
	var region := Rect2i(coord.x * px, coord.y * px, px, px)
	if not Rect2i(Vector2i.ZERO, _floor_atlas_image.get_size()).encloses(region):
		return null
	var tile_img: Image = _floor_atlas_image.get_region(region)
	var tex := ImageTexture.create_from_image(tile_img)
	var mat := StandardMaterial3D.new()
	var tint := floor_tint
	if is_instance_valid(_arena_floor):
		tint = _arena_floor.floor_tint
	mat.albedo_color = tint
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.9
	_materials_by_atlas_coord[coord] = mat
	return mat

func _make_floor_material_for_cell(cell: Vector2i, is_light: bool) -> StandardMaterial3D:
	if is_instance_valid(_arena_floor) or floor_atlas != null:
		var atlas_coord := _arena_coord_for_shape_cell(cell)
		var mat := _material_for_atlas_coord(atlas_coord)
		if mat:
			return mat
	return material_light if is_light else material_dark

func _get_base_floor_material(cell: Vector2i) -> StandardMaterial3D:
	if _floor_base_materials.has(cell):
		return _floor_base_materials[cell]
	var is_light: bool = _floor_tile_is_light.get(cell, false)
	return _make_floor_material_for_cell(cell, is_light)

func is_cell_active(grid_position: Vector2i) -> bool:
	return _active_cells.has(grid_position)

func get_all_active_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in _active_cells.keys():
		cells.append(cell)
	return cells

func get_world_position_for_cell(grid_position: Vector2i) -> Vector3:
	return Vector3(grid_position.x * cell_size_3d, 0.0, grid_position.y * cell_size_3d)

func place_object_on_cell(object_node: Node3D, grid_position: Vector2i, is_moving: bool = false, move_duration: float = 0.3) -> bool:
	if not is_instance_valid(object_node):
		return false
	# Pozn.: HP se nenastavuje tady — při spawně je current_health ještě 0 (před _ready).
	# Mrtvé jednotky se po pasti nepokládají přes BattleScene._move_unit_along_path.
	if not is_cell_active(grid_position) or _grid_objects.has(grid_position): return false
	
	if object_node.get_parent() != units_container:
		if object_node.get_parent(): object_node.get_parent().remove_child(object_node)
		units_container.add_child(object_node)
	
	var target_pos_3d = Vector3(grid_position.x * cell_size_3d, 0.0, grid_position.y * cell_size_3d)
	
	if is_moving:
		var tween = create_tween()
		tween.tween_property(object_node, "position", target_pos_3d, maxf(0.01, move_duration)).set_trans(Tween.TRANS_SINE)
	else:
		object_node.position = target_pos_3d
	
	if "grid_position" in object_node:
		object_node.grid_position = grid_position
	
	_grid_objects[grid_position] = object_node
	return true

func remove_object_by_instance(object_node: Node):
	var keys_to_remove: Array = []
	for cell in _grid_objects.keys():
		var obj = _grid_objects[cell]
		if not is_instance_valid(obj) or obj == object_node:
			keys_to_remove.append(cell)
	for cell in keys_to_remove:
		_grid_objects.erase(cell)

func get_distance(cell_a: Vector2i, cell_b: Vector2i) -> int: 
	return abs(cell_a.x - cell_b.x) + abs(cell_a.y - cell_b.y)

func is_valid_grid_position(grid_position: Vector2i) -> bool:
	return grid_position.x >= 0 and grid_position.x < grid_columns and grid_position.y >= 0 and grid_position.y < grid_rows

func get_object_on_cell(grid_position: Vector2i) -> Node:
	if not _grid_objects.has(grid_position):
		return null
	var obj = _grid_objects[grid_position]
	if not is_instance_valid(obj):
		_grid_objects.erase(grid_position)
		return null
	return obj

func get_all_objects_on_grid() -> Array:
	var units = []
	for unit in _grid_objects.values():
		if is_instance_valid(unit): units.append(unit)
	return units

func update_visual_highlights():
	_kill_highlight_tweens()
	_reset_floor_tile_materials()
	_spawn_highlight_nodes.clear()
	_enemy_overlap_pulse_nodes.clear()
	# Plane overlay už nepoužíváme — zvýrazníme přímo blok podlahy
	for child in _highlights_container.get_children():
		child.queue_free()

	# cell -> { color, emit, spawn, pulse }
	var tints: Dictionary = {}
	var put := func(cell: Vector2i, color: Color, emit: float = 1.0, is_spawn: bool = false, pulse: bool = false):
		if not is_cell_active(cell):
			return
		tints[cell] = {"color": color, "emit": emit, "spawn": is_spawn, "pulse": pulse}

	# Artifact zones / line under combat highlights (combat tints overwrite).
	for cell in _artifact_line_cells:
		put.call(cell, artifact_line_color, 1.35)
	for cell in _artifact_zones.keys():
		var info: Dictionary = _artifact_zones[cell]
		var kind: String = String(info.get("kind", ""))
		match kind:
			"throne":
				put.call(cell, artifact_throne_color, 2.0)
			"crown":
				put.call(cell, artifact_crown_color, 2.0)
			_:
				put.call(cell, artifact_throne_color, 1.5)
	# Living Grove roots share mud/stone terrain path — tint their cells too.
	for cell in terrain_layer.keys():
		var td: TerrainData = terrain_layer[cell] as TerrainData
		if td != null and td.terrain_id == "living_grove_root":
			put.call(cell, artifact_grove_color, 1.6)

	for cell in _danger_cells:
		put.call(cell, danger_zone_color, 1.0)
	for cell in _enemy_range_cells:
		if not _enemy_attack_range_cells.has(cell):
			put.call(cell, enemy_range_highlight_color, 1.15)
	for cell in _enemy_attack_range_cells:
		if _enemy_range_cells.has(cell):
			put.call(cell, attack_highlight_color, 1.3, false, true)
		else:
			put.call(cell, attack_highlight_color, 1.25)
	for cell in _movable_cells:
		put.call(cell, movement_highlight_color, 1.15)
	for cell in _warning_cells:
		put.call(cell, movement_warning_color, 1.0)
	for cell in _player_spawn_cells:
		if _coop_selected_spawns.has(cell):
			continue
		put.call(cell, player_spawn_highlight_color, 1.0, true)
	for cell in _coop_selected_spawns:
		put.call(cell, _coop_selected_spawns[cell], 2.0)
	for cell in _targetable_cells:
		put.call(cell, _targetable_cells_color, 1.25)
	for cell in _aoe_cells:
		put.call(cell, aoe_highlight_color, 1.1)

	if is_valid_grid_position(_mouse_over_cell) and is_cell_active(_mouse_over_cell):
		put.call(_mouse_over_cell, highlight_color, 1.35)
	if _initiative_hover_cell != Vector2i(-1, -1) and is_cell_active(_initiative_hover_cell):
		put.call(_initiative_hover_cell, initiative_hover_color, 2.5)

	for cell in tints:
		_apply_floor_tint(cell, tints[cell])

func _kill_highlight_tweens() -> void:
	for tw in _highlight_tweens:
		if is_instance_valid(tw):
			tw.kill()
	_highlight_tweens.clear()

func _reset_floor_tile_materials() -> void:
	for cell in _floor_tiles:
		var tile: MeshInstance3D = _floor_tiles[cell]
		if not is_instance_valid(tile):
			continue
		var base: StandardMaterial3D = _get_base_floor_material(cell)
		if base:
			tile.material_override = base

func _apply_floor_tint(cell: Vector2i, info: Dictionary) -> void:
	var tile: MeshInstance3D = _floor_tiles.get(cell)
	if not is_instance_valid(tile):
		return
	var base: StandardMaterial3D = _get_base_floor_material(cell)
	if not base:
		return
	var mat := base.duplicate() as StandardMaterial3D
	var c: Color = info.color
	var blend := clampf(c.a + 0.2, 0.4, 0.85)
	mat.albedo_color = base.albedo_color.lerp(Color(c.r, c.g, c.b), blend)
	mat.emission_enabled = true
	var emit_str: float = float(info.get("emit", 1.0))
	mat.emission = Color(c.r, c.g, c.b) * (0.55 * emit_str)
	mat.emission_energy_multiplier = 1.0
	tile.material_override = mat

	if info.get("spawn", false):
		_spawn_highlight_nodes.append(tile)
		if _spawn_pulse_active:
			_start_spawn_pulse_on_mesh(tile)
	if info.get("pulse", false):
		_enemy_overlap_pulse_nodes.append(tile)
		_start_enemy_overlap_pulse_on_mesh(tile)

func show_initiative_hover_cell(cell: Vector2i) -> void:
	if not is_cell_active(cell):
		return
	if _initiative_hover_cell == cell:
		return
	_initiative_hover_cell = cell
	update_visual_highlights()

func hide_initiative_hover_cell(cell: Vector2i) -> void:
	if _initiative_hover_cell != cell:
		return
	_initiative_hover_cell = Vector2i(-1, -1)
	update_visual_highlights()

func _start_enemy_overlap_pulse_on_mesh(mesh_inst: MeshInstance3D) -> void:
	if not is_instance_valid(mesh_inst):
		return
	var mat := mesh_inst.material_override as StandardMaterial3D
	if not is_instance_valid(mat):
		return
	var tween := create_tween().set_loops()
	tween.tween_property(mat, "emission_energy_multiplier", 1.45, 0.5)
	tween.tween_property(mat, "emission_energy_multiplier", 1.0, 0.5)
	_highlight_tweens.append(tween)

func start_spawn_pulse():
	_spawn_pulse_active = true
	for mesh_inst in _spawn_highlight_nodes:
		_start_spawn_pulse_on_mesh(mesh_inst)

func _start_spawn_pulse_on_mesh(mesh_inst: MeshInstance3D):
	if not is_instance_valid(mesh_inst):
		return
	var mat := mesh_inst.material_override as StandardMaterial3D
	if not is_instance_valid(mat):
		return
	var base_col := mat.albedo_color
	var pulse_col := base_col.lerp(Color(0.45, 0.55, 1.0), 0.55)
	var tween := create_tween().set_loops()
	tween.tween_property(mat, "albedo_color", pulse_col, 0.7)
	tween.tween_property(mat, "albedo_color", base_col, 0.7)
	_highlight_tweens.append(tween)

func show_targetable_cells(cells: Array[Vector2i], is_attack: bool):
	_targetable_cells = cells
	_targetable_cells_color = attack_highlight_color if is_attack else support_highlight_color
	update_visual_highlights()

func hide_targetable_cells():
	_targetable_cells.clear()
	update_visual_highlights()
func show_enemy_range(enemy_node: Node):
	_enemy_range_cells.clear()
	_enemy_attack_range_cells.clear()
	_accumulate_enemy_range(enemy_node)
	update_visual_highlights()

func show_all_enemy_move_previews(enemies: Array) -> void:
	"""All-Seeing Eye: union of all living enemies' move + attack ranges + destination arrows."""
	_enemy_range_cells.clear()
	_enemy_attack_range_cells.clear()
	_clear_move_preview_arrows()
	for enemy_v in enemies:
		var enemy: Node = enemy_v as Node
		_accumulate_enemy_range(enemy)
		_spawn_move_preview_arrow(enemy)
	update_visual_highlights()

func _accumulate_enemy_range(enemy_node: Node) -> void:
	if not is_instance_valid(enemy_node) or not is_instance_valid(enemy_node.get("unit_data")):
		return
	var start_cell = enemy_node.grid_position
	var move_range = enemy_node.get_current_movement_range() if enemy_node.has_method("get_current_movement_range") else 0
	var attack_range = clampi(int(enemy_node.unit_data.attack_range), 0, 15)

	var costs = {start_cell: 0}
	var to_visit = [start_cell]
	while not to_visit.is_empty():
		var current_cell = to_visit[0]
		for cell in to_visit:
			if costs[cell] < costs[current_cell]:
				current_cell = cell
		to_visit.erase(current_cell)
		var cost_to_current = costs[current_cell]
		for neighbor_offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor_cell = current_cell + neighbor_offset
			if not is_cell_active(neighbor_cell) or get_object_on_cell(neighbor_cell):
				continue
			var terrain = get_terrain_on_cell(neighbor_cell)
			if terrain and not terrain.is_walkable:
				continue
			var cost_to_enter = 1
			if terrain:
				cost_to_enter = terrain.movement_cost
			var new_cost = cost_to_current + cost_to_enter
			if new_cost <= move_range and (not costs.has(neighbor_cell) or new_cost < costs[neighbor_cell]):
				costs[neighbor_cell] = new_cost
				if not to_visit.has(neighbor_cell):
					to_visit.append(neighbor_cell)
	costs.erase(start_cell)
	for cell in costs.keys():
		if not _enemy_range_cells.has(cell):
			_enemy_range_cells.append(cell)

	if attack_range > 0:
		for dx in range(-attack_range, attack_range + 1):
			for dy in range(-attack_range, attack_range + 1):
				if abs(dx) + abs(dy) <= attack_range:
					var cell = start_cell + Vector2i(dx, dy)
					if cell == start_cell:
						continue
					if is_cell_active(cell) and not _enemy_attack_range_cells.has(cell):
						_enemy_attack_range_cells.append(cell)

func _clear_move_preview_arrows() -> void:
	if not is_instance_valid(_artifact_markers_container):
		return
	for child in _artifact_markers_container.get_children():
		if child.has_meta("move_preview_arrow"):
			child.queue_free()

func _spawn_move_preview_arrow(enemy_node: Node) -> void:
	"""Simple destination telegraph: arrow on nearest empty cell toward the closest player."""
	if not is_instance_valid(enemy_node) or not is_instance_valid(_artifact_markers_container):
		return
	var players: Array = get_tree().get_nodes_in_group("player") if is_inside_tree() else []
	var target_pos: Vector2i = enemy_node.grid_position
	var best_dist := 999
	for p in players:
		if is_instance_valid(p) and "grid_position" in p:
			var d: int = get_distance(enemy_node.grid_position, p.grid_position)
			if d < best_dist:
				best_dist = d
				target_pos = p.grid_position
	var from: Vector2i = enemy_node.grid_position
	var delta := Vector2i(
		clampi(target_pos.x - from.x, -1, 1),
		clampi(target_pos.y - from.y, -1, 1)
	)
	# Prefer cardinal step toward player
	if abs(target_pos.x - from.x) >= abs(target_pos.y - from.y):
		delta = Vector2i(clampi(target_pos.x - from.x, -1, 1), 0)
	else:
		delta = Vector2i(0, clampi(target_pos.y - from.y, -1, 1))
	var dest: Vector2i = from + delta
	if delta == Vector2i.ZERO or not is_cell_active(dest) or get_object_on_cell(dest) != null:
		return
	var arrow := Label3D.new()
	arrow.text = "▼"
	arrow.font_size = 64
	arrow.modulate = Color(0.35, 0.75, 1.0, 1)
	arrow.outline_modulate = Color(0, 0, 0, 1)
	arrow.outline_size = 8
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.position = Vector3(dest.x * cell_size_3d, 1.4, dest.y * cell_size_3d)
	arrow.set_meta("move_preview_arrow", true)
	_artifact_markers_container.add_child(arrow)

func hide_enemy_range():
	if not _enemy_range_cells.is_empty() or not _enemy_attack_range_cells.is_empty():
		_enemy_range_cells.clear()
		_enemy_attack_range_cells.clear()
		_clear_move_preview_arrows()
		update_visual_highlights()

func show_movable_range(unit: Node):
	hide_movable_range()
	if not is_instance_valid(unit) or not is_instance_valid(unit.unit_data):
		return

	var move_range = unit.get_current_movement_range()
	var start_cell = unit.grid_position
	var costs = {start_cell: 0}
	var to_visit = [start_cell]

	while not to_visit.is_empty():
		var current_cell = to_visit[0]
		for cell in to_visit:
			if costs[cell] < costs[current_cell]:
				current_cell = cell
		
		to_visit.erase(current_cell)
		var cost_to_current = costs[current_cell]

		for neighbor_offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor_cell = current_cell + neighbor_offset

			if not is_cell_active(neighbor_cell) or get_object_on_cell(neighbor_cell):
				continue
			var terrain = get_terrain_on_cell(neighbor_cell)
			if terrain and not terrain.is_walkable:
				continue

			var cost_to_enter = 1
			if terrain:
				cost_to_enter = terrain.movement_cost

			var new_cost = cost_to_current + cost_to_enter

			if new_cost <= move_range and (not costs.has(neighbor_cell) or new_cost < costs[neighbor_cell]):
				costs[neighbor_cell] = new_cost
				if not to_visit.has(neighbor_cell):
					to_visit.append(neighbor_cell)

	costs.erase(start_cell)
	for cell in costs.keys():
		var terrain = get_terrain_on_cell(cell)
		if terrain and terrain.movement_cost > 1:
			if not _warning_cells.has(cell): _warning_cells.append(cell)
		else:
			if not _movable_cells.has(cell): _movable_cells.append(cell)

	update_visual_highlights()

func hide_movable_range():
	_movable_cells.clear()
	_warning_cells.clear()
	update_visual_highlights()

func is_cell_movable(cell: Vector2i) -> bool:
	return _movable_cells.has(cell) or _warning_cells.has(cell)

func show_aoe_highlight(cells: Array[Vector2i]):
	_aoe_cells = cells
	update_visual_highlights()

func hide_aoe_highlight():
	if not _aoe_cells.is_empty(): 
		_aoe_cells.clear()
		update_visual_highlights()

## zones: Array of {cell: Vector2i, kind: "throne"|"crown", charges: int, max_charges: int}
## Replaces only the kinds present in `zones` so multiple artifacts can share the layer.
func set_artifact_zones(zones: Array) -> void:
	var kinds_updated: Dictionary = {}
	for entry_v in zones:
		if entry_v is Dictionary:
			kinds_updated[String((entry_v as Dictionary).get("kind", "throne"))] = true
	if kinds_updated.is_empty() and zones.is_empty():
		# Explicit empty array from a single artifact — caller should use clear_artifact_zones_of_kind.
		pass
	var to_erase: Array = []
	for cell in _artifact_zones.keys():
		var existing_kind: String = String(_artifact_zones[cell].get("kind", ""))
		if kinds_updated.has(existing_kind):
			to_erase.append(cell)
	for cell in to_erase:
		_artifact_zones.erase(cell)
	var placed := 0
	for entry_v in zones:
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		var cell: Vector2i = entry.get("cell", Vector2i(-1, -1)) as Vector2i
		if cell.x < 0 or not is_cell_active(cell):
			push_warning("BattleGrid.set_artifact_zones: skip inactive/invalid cell %s" % str(cell))
			continue
		_artifact_zones[cell] = {
			"kind": String(entry.get("kind", "throne")),
			"charges": int(entry.get("charges", 0)),
			"max_charges": int(entry.get("max_charges", 3)),
		}
		placed += 1
	_rebuild_artifact_markers()
	update_visual_highlights()
	if placed > 0 or not kinds_updated.is_empty():
		print("BattleGrid: artifact zones sync kinds=%s placed=%d total=%d" % [
			str(kinds_updated.keys()), placed, _artifact_zones.size()
		])

func clear_artifact_zones_of_kind(kind: String) -> void:
	var to_erase: Array = []
	for cell in _artifact_zones.keys():
		if String(_artifact_zones[cell].get("kind", "")) == kind:
			to_erase.append(cell)
	for cell in to_erase:
		_artifact_zones.erase(cell)
	_rebuild_artifact_markers()
	update_visual_highlights()

func set_artifact_line_highlight(cells: Array[Vector2i]) -> void:
	_artifact_line_cells = cells.duplicate()
	update_visual_highlights()
	print("BattleGrid: artifact line highlight cells=%d" % _artifact_line_cells.size())

func clear_artifact_zones() -> void:
	_artifact_zones.clear()
	_artifact_line_cells.clear()
	_rebuild_artifact_markers()
	update_visual_highlights()

func _rebuild_artifact_markers() -> void:
	"""Throne/Crown markers use the SAME flat Sprite3D path as mud (AXIS_Y on floor)."""
	if not is_instance_valid(_artifact_markers_container):
		return
	for child in _artifact_markers_container.get_children():
		if child.has_meta("move_preview_arrow"):
			continue
		var yaw_idx := _yaw_follow_sprites.find(child)
		if yaw_idx >= 0:
			_yaw_follow_sprites.remove_at(yaw_idx)
		child.queue_free()
	for cell in _artifact_zones.keys():
		var info: Dictionary = _artifact_zones[cell]
		var kind: String = String(info.get("kind", "throne"))
		var tex: Texture2D = _tex_throne_marker if kind == "throne" else _tex_crown_marker
		if tex == null:
			push_warning("BattleGrid: missing artifact marker texture for '%s'" % kind)
			continue
		var marker := _make_flat_ground_sprite(tex, cell, 0.95)
		marker.name = "ArtifactMarker_%s_%d_%d" % [kind, cell.x, cell.y]
		marker.modulate = Color(1.25, 1.2, 1.05, 1.0) if kind == "throne" else Color(1.15, 1.05, 1.35, 1.0)
		_artifact_markers_container.add_child(marker)

		var charges: int = int(info.get("charges", 0))
		var max_charges: int = int(info.get("max_charges", 3))
		var label := Label3D.new()
		label.text = "%d/%d" % [charges, max_charges]
		label.font_size = 72
		label.modulate = Color(1, 0.95, 0.45, 1)
		label.outline_modulate = Color(0, 0, 0, 1)
		label.outline_size = 12
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(cell.x * cell_size_3d, 1.35, cell.y * cell_size_3d)
		label.render_priority = 2
		label.name = "ArtifactCharges_%s_%d_%d" % [kind, cell.x, cell.y]
		_artifact_markers_container.add_child(label)

func _make_flat_ground_sprite(tex: Texture2D, grid_position: Vector2i, cover: float = 0.85) -> Sprite3D:
	"""Same rendering as mud: flat on floor (AXIS_Y), no billboard — readable from battle camera."""
	var terrain_sprite := Sprite3D.new()
	terrain_sprite.texture = tex
	terrain_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	terrain_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	terrain_sprite.axis = Vector3.AXIS_Y
	terrain_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	terrain_sprite.centered = true
	terrain_sprite.shaded = false
	terrain_sprite.double_sided = true
	var tex_w: float = float(tex.get_width())
	var tex_h: float = float(tex.get_height())
	var max_px: float = maxf(tex_w, tex_h)
	terrain_sprite.pixel_size = (cell_size_3d * cover) / max_px if max_px > 0.0 else 0.01
	# Slightly above floor tiles (y=-0.01) and mud (y=0.02).
	terrain_sprite.position = Vector3(grid_position.x * cell_size_3d, 0.04, grid_position.y * cell_size_3d)
	terrain_sprite.render_priority = 1
	return terrain_sprite

func get_cells_for_aoe(origin_cell: Vector2i, aoe_type: CardEffectData.AreaOfEffectType, param_x: int, param_y: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match aoe_type:
		CardEffectData.AreaOfEffectType.ROW:
			# param_y = row thickness (1 = single row, 3 = center ±1, …)
			var row_span: int = maxi(1, param_y)
			var row_radius: int = row_span >> 1
			for dy in range(-row_radius, row_radius + 1):
				var row_y: int = origin_cell.y + dy
				if row_y < 0 or row_y >= grid_rows:
					continue
				for x in range(grid_columns):
					cells.append(Vector2i(x, row_y))
		CardEffectData.AreaOfEffectType.COLUMN:
			# param_x = column thickness (1 = single column, 3 = center ±1, …)
			var col_span: int = maxi(1, param_x)
			var col_radius: int = col_span >> 1
			for dx in range(-col_radius, col_radius + 1):
				var col_x: int = origin_cell.x + dx
				if col_x < 0 or col_x >= grid_columns:
					continue
				for y in range(grid_rows):
					cells.append(Vector2i(col_x, y))
		CardEffectData.AreaOfEffectType.SQUARE_X_BY_Y:
			for y in range(origin_cell.y, origin_cell.y + param_y):
				for x in range(origin_cell.x, origin_cell.x + param_x):
					var cell = Vector2i(x, y)
					if is_valid_grid_position(cell): cells.append(cell)
		CardEffectData.AreaOfEffectType.ALL_ON_GRID:
			var all_units = get_all_objects_on_grid();
			for unit in all_units:
				if unit.unit_data.faction == UnitData.Faction.ENEMY: cells.append(unit.grid_position)
	return cells

func get_cells_for_centered_aoe(center_cell: Vector2i, aoe_type: CardEffectData.AreaOfEffectType, param_x: int, param_y: int) -> Array[Vector2i]:
	"""Vypočítá AOE buňky CENTROVANÉ na center_cell (pro player-centered karty).
	SQUARE je vycentrovaný, ROW/COLUMN zůstává stejný (řádek/sloupec center_cell)."""
	match aoe_type:
		CardEffectData.AreaOfEffectType.SQUARE_X_BY_Y:
			var offset_x: int = param_x >> 1
			var offset_y: int = param_y >> 1
			var origin = Vector2i(center_cell.x - offset_x, center_cell.y - offset_y)
			return get_cells_for_aoe(origin, aoe_type, param_x, param_y)
		_:
			# ROW, COLUMN, ALL_ON_GRID — center_cell stačí jako origin
			return get_cells_for_aoe(center_cell, aoe_type, param_x, param_y)

func place_terrain(grid_position: Vector2i, terrain_data: TerrainData):
	if not is_cell_active(grid_position): return
	remove_terrain(grid_position)
	terrain_layer[grid_position] = terrain_data
	
	if terrain_data.sprite:
		var terrain_sprite: Sprite3D
		# --- ROZHODOVÁNÍ PODLE TYPU TERÉNU ---
		if terrain_data.terrain_id == "living_grove_root":
			# Same flat path as mud — root art is top-down like bahno.
			terrain_sprite = _make_flat_ground_sprite(terrain_data.sprite, grid_position, 0.92)
			terrain_sprite.modulate = Color(1.2, 1.35, 1.1, 1.0)
			terrain_sprite.name = "GroveRoot_%d_%d" % [grid_position.x, grid_position.y]
		elif terrain_data.is_flat_on_ground:
			# A) Bahno / pasti — leží na zemi; pasti ještě yaw-follow kameru
			terrain_sprite = _make_flat_ground_sprite(terrain_data.sprite, grid_position, 0.75)
			if terrain_data.follow_camera_yaw:
				_yaw_follow_sprites.append(terrain_sprite)
				if camera:
					terrain_sprite.rotation.y = camera.global_rotation.y
		else:
			# B) Kámen / strom — původní stojící billboard
			terrain_sprite = Sprite3D.new()
			terrain_sprite.texture = terrain_data.sprite
			terrain_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			terrain_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			terrain_sprite.pixel_size = 0.04
			terrain_sprite.axis = Vector3.AXIS_Z
			terrain_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			terrain_sprite.centered = true
			terrain_sprite.position = Vector3(grid_position.x * cell_size_3d, 0.7, grid_position.y * cell_size_3d)

		_terrain_container.add_child(terrain_sprite)
		_terrain_visuals[grid_position] = terrain_sprite
		if terrain_data.terrain_id == "living_grove_root":
			update_visual_highlights()
			print("BattleGrid: living_grove_root placed at %s" % str(grid_position))

func remove_terrain(grid_position: Vector2i) -> void:
	var was_grove := false
	var existing: TerrainData = terrain_layer.get(grid_position) as TerrainData
	if existing != null and existing.terrain_id == "living_grove_root":
		was_grove = true
	terrain_layer.erase(grid_position)
	if _terrain_visuals.has(grid_position):
		var spr = _terrain_visuals[grid_position]
		_terrain_visuals.erase(grid_position)
		var idx := _yaw_follow_sprites.find(spr)
		if idx >= 0:
			_yaw_follow_sprites.remove_at(idx)
		if is_instance_valid(spr):
			spr.queue_free()
	if was_grove:
		update_visual_highlights()

func get_terrain_on_cell(grid_position: Vector2i) -> TerrainData:
	return terrain_layer.get(grid_position, null)

func find_path(from_cell: Vector2i, to_cell: Vector2i, moving_unit: Node = null) -> Array[Vector2i]:
	"""BFS 4-dir path. Returns [from, ..., to] or empty if unreachable."""
	var empty: Array[Vector2i] = []
	if not is_cell_active(from_cell) or not is_cell_active(to_cell):
		return empty
	if from_cell == to_cell:
		return [from_cell]
	var parents: Dictionary = {}
	var queue: Array[Vector2i] = [from_cell]
	var visited: Dictionary = {from_cell: true}
	var found := false
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next_cell: Vector2i = current + offset
			if visited.has(next_cell) or not is_cell_active(next_cell):
				continue
			var obj = get_object_on_cell(next_cell)
			if is_instance_valid(obj) and obj != moving_unit:
				continue
			var terrain = get_terrain_on_cell(next_cell)
			if terrain and not terrain.is_walkable:
				continue
			visited[next_cell] = true
			parents[next_cell] = current
			if next_cell == to_cell:
				found = true
				queue.clear()
				break
			queue.append(next_cell)
	if not found:
		return empty
	var path: Array[Vector2i] = []
	var walk: Vector2i = to_cell
	while true:
		path.push_front(walk)
		if walk == from_cell:
			break
		walk = parents[walk]
	return path

func get_player_spawn_points(num_columns: int) -> Array[Vector2i]:
	var spawn_points: Array[Vector2i] = []
	for y in range(grid_rows):
		for x in range(num_columns):
			var cell = Vector2i(x, y)
			if is_cell_active(cell) and get_object_on_cell(cell) == null:
				var terrain = get_terrain_on_cell(cell)
				if not terrain or terrain.is_walkable:
					spawn_points.append(cell)
	return spawn_points

func show_player_spawn_points(cells: Array[Vector2i]):
	_player_spawn_cells = cells
	update_visual_highlights()

func hide_player_spawn_points():
	if not _player_spawn_cells.is_empty():
		_player_spawn_cells.clear()
		_coop_selected_spawns.clear()
		update_visual_highlights()

func is_cell_a_valid_spawn_point(cell: Vector2i) -> bool:
	return _player_spawn_cells.has(cell)

func set_coop_selected_spawn(cell: Vector2i, color: Color):
	"""Coop: označí buňku jako vybraný spawn s danou barvou."""
	_coop_selected_spawns[cell] = color
	update_visual_highlights()

func clear_coop_selected_spawns():
	_coop_selected_spawns.clear()
	update_visual_highlights()

func show_danger_zone(enemy_units: Array):
	_danger_cells.clear()
	var danger_dict = {}
	for enemy in enemy_units:
		if not is_instance_valid(enemy): continue
		var enemy_data = enemy.get_unit_data()
		if not is_instance_valid(enemy_data): continue
		
		var attack_range = enemy_data.attack_range
		for x in range(-attack_range, attack_range + 1):
			for y in range(-attack_range, attack_range + 1):
				if abs(x) + abs(y) <= attack_range:
					var cell = enemy.grid_position + Vector2i(x, y)
					if is_cell_active(cell):
						danger_dict[cell] = true

	var new_danger_cells: Array[Vector2i] = []
	for cell_key in danger_dict.keys():
		new_danger_cells.append(cell_key)
	
	_danger_cells = new_danger_cells
	update_visual_highlights()

func hide_danger_zone():
	_danger_cells.clear()
	update_visual_highlights()

func get_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var line_points: Array[Vector2i] = []
	var x0 = from_cell.x; var y0 = from_cell.y
	var x1 = to_cell.x; var y1 = to_cell.y
	
	var dx = abs(x1 - x0)
	var dy = -abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx + dy
	
	while true:
		line_points.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
			
	return line_points

func has_line_of_sight(from_cell: Vector2i, to_cell: Vector2i, exclude_target_unit: Node = null) -> bool:
	"""Zkontroluje, zda je přímá viditelnost mezi buňkami. Pro ranged karty.
	Blokuje: terén s blocks_line_of_sight, jednotky mezi from a to (kromě cílové)."""
	if from_cell == to_cell:
		return true
	var line_cells = get_line(from_cell, to_cell)
	for i in range(1, line_cells.size() - 1):
		var cell = line_cells[i]
		var terrain = get_terrain_on_cell(cell)
		if terrain and terrain.blocks_line_of_sight:
			return false
		var unit_on_cell = get_object_on_cell(cell)
		if is_instance_valid(unit_on_cell) and unit_on_cell != exclude_target_unit:
			return false
	return true
