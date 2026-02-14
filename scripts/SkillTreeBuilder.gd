# SkillTreeBuilder.gd – @tool pro automatické osazení scény uzly PassiveSkillNodeUI a uložení stromu do .tres
@tool
class_name SkillTreeBuilder
extends Node

const PassiveSkillNodeUIScene = preload("res://scenes/ui/PassiveSkillNodeUI.tscn")

## Zaškrtni pro vygenerování uzlů podle aktivního stromu. Po buildu se sám zruší.
var _build_now_backing: bool = false
@export var build_tree_now: bool = false:
	get:
		return _build_now_backing
	set(v):
		_build_now_backing = v
		if v and Engine.is_editor_hint():
			build_tree()
		_build_now_backing = false

## Cesta pro uložení stromu (.tres). Přiřaď pak v Paladin.tres do passive_skill_tree.
@export_file var save_tree_path: String = "res://data/skills/paladin_skill_tree_manual.tres"

## Zaškrtni pro uložení aktuálního rozložení uzlů do .tres. Po uložení se sám zruší.
var _save_now_backing: bool = false
@export var save_tree_now: bool = false:
	get:
		return _save_now_backing
	set(v):
		_save_now_backing = v
		if v and Engine.is_editor_hint() and save_tree_path:
			save_tree_to_tres(save_tree_path)
		_save_now_backing = false

## V editoru (když není PlayerData): přiřaď strom zde, nebo se použije vygenerovaný Paladin strom.
@export var fallback_tree: PassiveSkillTreeData = null

## Vrátí strom, který Builder používá pro build (stejný zdroj jako pro uzly). LineLayer z něj kreslí čáry.
func get_skill_tree() -> PassiveSkillTreeData:
	return _get_skill_tree()

func build_tree() -> void:
	var tree := _get_skill_tree()
	if not tree or tree.skill_nodes.is_empty():
		push_warning("SkillTreeBuilder: Žádný strom nebo prázdné skill_nodes. V editoru přiřaď Fallback Tree nebo spusť hru.")
		return

	_remove_existing_ui_nodes()
	var count := 0
	for skill_node in tree.skill_nodes:
		if not is_instance_valid(skill_node):
			continue
		var ui: Control = PassiveSkillNodeUIScene.instantiate()
		if not ui is PassiveSkillNodeUI:
			ui.queue_free()
			continue
		var node_ui: PassiveSkillNodeUI = ui as PassiveSkillNodeUI
		node_ui.set_skill_id(skill_node.id)
		node_ui.position = skill_node.position
		add_child(ui)
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			ui.set_owner(get_tree().edited_scene_root)
		count += 1

	if Engine.is_editor_hint():
		print("SkillTreeBuilder: Přidáno %d uzlů. (Pouze v editoru.)" % count)
		_find_and_refresh_line_layer()

func _get_skill_tree() -> PassiveSkillTreeData:
	if Engine.is_editor_hint():
		if is_instance_valid(fallback_tree) and fallback_tree.skill_nodes.size() > 0:
			return fallback_tree
		# V editoru nemáme PlayerData – vygeneruj Paladin strom
		return SkillTreeGenerator.generate_paladin_tree()
	if has_node("/root/PlayerData") and PlayerData and is_instance_valid(PlayerData.active_skill_tree):
		return PlayerData.active_skill_tree
	if is_instance_valid(fallback_tree):
		return fallback_tree
	return SkillTreeGenerator.generate_paladin_tree()

func _find_and_refresh_line_layer() -> void:
	var root_node: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	if not is_instance_valid(root_node):
		return
	var line_layer = _find_node_by_class(root_node, PassiveSkillTreeManual)
	if is_instance_valid(line_layer) and line_layer.has_method("force_draw"):
		line_layer.force_draw()

func _find_node_by_class(node: Node, type: Variant) -> Node:
	if is_instance_of(node, type):
		return node
	for child in node.get_children():
		var found = _find_node_by_class(child, type)
		if is_instance_valid(found):
			return found
	return null

func _remove_existing_ui_nodes() -> void:
	var to_remove: Array[Node] = []
	for child in get_children():
		if child is PassiveSkillNodeUI:
			to_remove.append(child)
	for node in to_remove:
		remove_child(node)
		node.queue_free()

func _collect_all_ui_nodes(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		if child is PassiveSkillNodeUI:
			out.append(child)
		else:
			out.append_array(_collect_all_ui_nodes(child))
	return out

## Uloží strom do .tres: vezme Paladin strom, nastaví pozice z UI uzlů v této scéně, uloží.
## Pak v editoru přiřaď tento .tres do Paladin.tres → passive_skill_tree.
func save_tree_to_tres(path: String) -> void:
	var root_node: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	if not is_instance_valid(root_node):
		push_warning("SkillTreeBuilder: Žádný root scény.")
		return
	var ui_nodes := _collect_all_ui_nodes(root_node)
	var id_to_ui: Dictionary = {}
	for ui in ui_nodes:
		if ui is PassiveSkillNodeUI:
			id_to_ui[String(ui.skill_id)] = ui
	var tree := SkillTreeGenerator.generate_paladin_tree()
	if not tree or tree.skill_nodes.is_empty():
		push_warning("SkillTreeBuilder: Žádný strom k uložení.")
		return
	var tree_save: PassiveSkillTreeData = tree.duplicate(true)
	for sn in tree_save.skill_nodes:
		if not is_instance_valid(sn):
			continue
		var ui = id_to_ui.get(String(sn.id))
		if is_instance_valid(ui) and ui is Control:
			sn.position = ui.position
	var err := ResourceSaver.save(tree_save, path)
	if err != OK:
		push_error("SkillTreeBuilder: Nepodařilo se uložit strom do %s (err %d)" % [path, err])
	else:
		print("SkillTreeBuilder: Strom uložen do %s – přiřaď ho v Paladin.tres do passive_skill_tree." % path)
