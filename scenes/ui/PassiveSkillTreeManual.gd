# PassiveSkillTreeManual.gd – vykresluje spojnice mezi uzly PassiveSkillNodeUI.
# Pravidlo: jedna čára = jedno propojení (uzel A → uzel B podle connected_nodes ve stromu).
# Každá hrana se kreslí jen jednou. Struktura (kdo na koho) je v SkillTreeGenerator.setup_connections_paladin_tiered().
@tool
class_name PassiveSkillTreeManual
extends Control

const LINE_WIDTH: float = 6.0
## Barvy viditelné na tmavém (vesmírném) pozadí i při přiblížení
const COLOR_PURCHASED: Color = Color(1.0, 0.85, 0.2)
const COLOR_LOCKED: Color = Color(0.55, 0.58, 0.65)
## V editoru: bílá s alphou, aby čáry nebyly černé na černém pozadí
const COLOR_LOCKED_EDITOR: Color = Color(1.0, 1.0, 1.0, 0.35)
var _cached_tree: PassiveSkillTreeData = null
var _editor_redraw_timer: float = 0.0

func _ready() -> void:
	show_behind_parent = true
	if Engine.is_editor_hint():
		queue_redraw()
	elif has_node("/root/SaveManager"):
		SaveManager.meta_progress_changed.connect(queue_redraw)

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_editor_redraw_timer += delta
	if _editor_redraw_timer >= 0.15:
		_editor_redraw_timer = 0.0
		queue_redraw()

## Zavolat z Builderu po dokončení generování pro okamžitý překres čar.
func force_draw() -> void:
	queue_redraw()

func _draw() -> void:
	# Hledat uzly v celé scéně (edited_scene_root v editoru), nejen v přímých dětech tohoto Control
	var root_node: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	if not is_instance_valid(root_node):
		root_node = self
	var ui_nodes := _collect_passive_skill_ui_nodes(root_node)
	if ui_nodes.is_empty():
		return
	# Použít STEJNÝ strom jako SkillTreeBuilder (uzly i čáry z jednoho zdroje – jinak propojení nesedí)
	var tree := _get_tree_for_drawing(root_node)
	if not tree:
		return
	var id_to_ui: Dictionary = {}
	for ui in ui_nodes:
		if ui is PassiveSkillNodeUI:
			id_to_ui[String(ui.skill_id)] = ui
	# Každá hrana A→B se kreslí právě jednou (kanonický klíč, bez podmínky id_a < id_b, aby se nevynechaly čáry).
	var drawn: Dictionary = {}
	for ui in ui_nodes:
		if not ui is PassiveSkillNodeUI:
			continue
		var skill_node := tree.get_node_by_id(ui.skill_id) as PassiveSkillNode
		if not skill_node:
			continue
		var id_a := String(ui.skill_id)
		var center_a := _get_center_in_local(ui)
		for conn_id in skill_node.connected_nodes:
			var id_b := String(conn_id)
			var target_ui = id_to_ui.get(id_b)
			if not is_instance_valid(target_ui):
				continue
			var lo := id_a if id_a < id_b else id_b
			var hi := id_b if id_a < id_b else id_a
			var edge_key := lo + "|" + hi
			if drawn.get(edge_key, false):
				continue
			drawn[edge_key] = true
			var center_b := _get_center_in_local(target_ui)
			var both_purchased := _is_purchased(ui) and _is_purchased(target_ui)
			var color: Color
			if Engine.is_editor_hint():
				color = COLOR_PURCHASED if both_purchased else COLOR_LOCKED_EDITOR
			else:
				color = COLOR_PURCHASED if both_purchased else COLOR_LOCKED
			_draw_thick_line(center_a, center_b, color)

func _get_tree_for_drawing(root: Node) -> PassiveSkillTreeData:
	var builder := _find_node_by_class(root, SkillTreeBuilder)
	if is_instance_valid(builder) and builder.has_method("get_skill_tree"):
		var t = builder.get_skill_tree()
		if is_instance_valid(t) and t.skill_nodes.size() > 0:
			return t
	if not _cached_tree:
		_cached_tree = SkillTreeGenerator.generate_paladin_tree()
	return _cached_tree

func _find_node_by_class(node: Node, type: Variant) -> Node:
	if not is_instance_valid(node):
		return null
	if is_instance_of(node, type):
		return node
	for child in node.get_children():
		var found = _find_node_by_class(child, type)
		if is_instance_valid(found):
			return found
	return null

func _collect_passive_skill_ui_nodes(node: Node) -> Array:
	var out: Array = []
	if not is_instance_valid(node):
		return out
	for child in node.get_children():
		if child is PassiveSkillNodeUI:
			out.append(child)
		else:
			out.append_array(_collect_passive_skill_ui_nodes(child))
	return out

## Střed ikony v lokálních souřadnicích tohoto Control (LineLayer). Čáry začínají/končí přesně ve středu uzlů.
func _get_center_in_local(ui: Control) -> Vector2:
	return (ui.global_position + ui.size * 0.5) - global_position

func _is_purchased(ui: PassiveSkillNodeUI) -> bool:
	if not Engine.is_editor_hint():
		if has_node("/root/SaveManager") and SaveManager and SaveManager.meta_progress:
			return SaveManager.meta_progress.allocated_skills.get(String(ui.skill_id), 0) > 0
	return false

func _draw_thick_line(from: Vector2, to: Vector2, color: Color) -> void:
	var diff := to - from
	var len := diff.length()
	if len < 0.001:
		return
	var dir := diff / len
	var perp := Vector2(-dir.y, dir.x) * (LINE_WIDTH * 0.5)
	var points := PackedVector2Array([
		from + perp,
		from - perp,
		to - perp,
		to + perp
	])
	draw_colored_polygon(points, color)
