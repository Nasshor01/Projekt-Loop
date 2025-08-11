# Soubor: scenes/ui/PassiveSkillTree.gd (ENHANCED VERSION)
@tool
extends Node2D

const PassiveSkillUIScene = preload("res://scenes/ui/PassiveSkillUI.tscn")

## Přetáhni sem .tres soubor stromu, abys viděl jeho náhled v editoru.
@export var preview_tree_data: PassiveSkillTreeData = null

## Zaškrtni pro překreslení náhledu v editoru.
@export var refresh_preview: bool = false:
	set(value):
		if Engine.is_editor_hint():
			_draw_editor_preview()

## Zaškrtni pro uložení pozic z editoru zpět do .tres souborů.
@export var save_positions: bool = false:
	set(value):
		if Engine.is_editor_hint() and value:
			_save_positions_to_resources()
			save_positions = false

## NOVÉ: Automaticky vygeneruj strom pro Paladina
@export var generate_paladin_tree: bool = false:
	set(value):
		if Engine.is_editor_hint() and value:
			_generate_and_preview_paladin()
			generate_paladin_tree = false

## NOVÉ: Zobrazení pomocných čar pro tiery
@export var show_tier_lines: bool = true
@export var show_branch_lines: bool = true

# Proměnné pro běh hry
var active_skill_tree: PassiveSkillTreeData
@onready var skill_nodes_container = $SkillNodes
@onready var connection_lines_container = $ConnectionLines
var background_lines_container: Node2D  # Vytváří se dynamicky
var skill_ui_map: Dictionary = {}

func _ready():
	if not Engine.is_editor_hint():
		# Pouze ve hře, ne v editoru
		_refresh_tree()
		PlayerData.player_state_initialized.connect(_refresh_tree)

func _refresh_tree():
	active_skill_tree = PlayerData.active_skill_tree
	_clear_view()
	
	if not is_instance_valid(active_skill_tree):
		print("Pasivní strom: Žádný aktivní strom dovedností nenalezen.")
		return
	
	_generate_skill_nodes(false)
	_draw_background_lines()
	_draw_connections(false)

# --- NOVÉ FUNKCE PRO GENEROVÁNÍ ---

func _generate_and_preview_paladin():
	print("Generujem Paladin skill tree...")
	preview_tree_data = SkillTreeGenerator.generate_paladin_tree()
	_draw_editor_preview()
	print("Hotovo! Paladin tree vygenerován.")

# --- VYLEPŠENÉ FUNKCE ---

func _clear_view():
	if skill_nodes_container:
		for child in skill_nodes_container.get_children():
			child.queue_free()
	if connection_lines_container:
		for child in connection_lines_container.get_children():
			child.queue_free()
	if background_lines_container:
		for child in background_lines_container.get_children():
			child.queue_free()
	skill_ui_map.clear()

func _generate_skill_nodes(is_editor_preview: bool):
	var tree_data = preview_tree_data if is_editor_preview else active_skill_tree
	if not is_instance_valid(tree_data): return
	
	var unlocked_ids = [] if is_editor_preview else SaveManager.meta_progress.unlocked_skill_ids

	for skill_node in tree_data.skill_nodes:
		if not is_instance_valid(skill_node): continue
			
		var skill_ui: PassiveSkillUI = PassiveSkillUIScene.instantiate()
		skill_nodes_container.add_child(skill_ui)
		skill_ui.position = skill_node.position
		skill_ui_map[skill_node.id] = skill_ui
		
		# V editoru nezjišťujeme, co lze odemknout
		if is_editor_preview:
			skill_ui.display(skill_node, false, false)
		else:
			var is_unlocked = unlocked_ids.has(String(skill_node.id))
			var can_unlock = _can_unlock_node(skill_node, unlocked_ids)
			skill_ui.display(skill_node, is_unlocked, can_unlock)
			skill_ui.skill_selected.connect(_on_skill_unlocked)

func _draw_background_lines():
	if not background_lines_container:
		background_lines_container = Node2D.new()
		background_lines_container.name = "BackgroundLines"
		add_child(background_lines_container)
		move_child(background_lines_container, 0)  # Pošleme dozadu
	
	if not show_tier_lines and not show_branch_lines:
		return
	
	var tree_data = preview_tree_data if Engine.is_editor_hint() else active_skill_tree
	if not is_instance_valid(tree_data): return
	
	# Najdeme všechny použité tiery a větve
	var tiers = {}
	var branches = {}
	
	for node in tree_data.skill_nodes:
		if not is_instance_valid(node): continue
		tiers[node.tier] = true
		branches[node.branch] = true
	
	# Nakreslíme tier čáry (horizontální)
	if show_tier_lines:
		for tier in tiers.keys():
			var y = SkillTreeGenerator.get_tier_y_offset(tier)
			var line = Line2D.new()
			line.add_point(Vector2(-400, y))
			line.add_point(Vector2(1200, y))
			line.width = 2.0
			line.default_color = Color(0.3, 0.3, 0.3, 0.5)
			background_lines_container.add_child(line)
			
			# Přidáme label pro tier
			var label = Label.new()
			label.text = "Tier %d" % tier
			label.position = Vector2(-380, y - 10)
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			background_lines_container.add_child(label)
	
	# Nakreslíme branch čáry (vertikální) 
	if show_branch_lines:
		for branch in branches.keys():
			var x = SkillTreeGenerator.get_branch_x_offset(branch)
			var line = Line2D.new()
			line.add_point(Vector2(x, 0))
			line.add_point(Vector2(x, 800))
			line.width = 2.0
			line.default_color = Color(0.3, 0.3, 0.3, 0.3)
			background_lines_container.add_child(line)
			
			# Přidáme label pro branch
			var label = Label.new()
			label.text = branch.capitalize()
			label.position = Vector2(x - 30, -20)
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			background_lines_container.add_child(label)

func _draw_connections(is_editor_preview: bool):
	var tree_data = preview_tree_data if is_editor_preview else active_skill_tree
	if not is_instance_valid(tree_data): return

	var unlocked_ids = [] if is_editor_preview else SaveManager.meta_progress.unlocked_skill_ids

	for skill_node in tree_data.skill_nodes:
		if not is_instance_valid(skill_node) or not skill_ui_map.has(skill_node.id):
			continue
		
		var from_ui_node = skill_ui_map[skill_node.id]
		var from_pos = from_ui_node.position + from_ui_node.size / 2.0
		
		for to_id_string in skill_node.connected_nodes:
			if not skill_ui_map.has(to_id_string):
				continue
			
			var to_ui_node = skill_ui_map[to_id_string]
			var to_pos = to_ui_node.position + to_ui_node.size / 2.0
			
			var line = Line2D.new()
			line.add_point(from_pos)
			line.add_point(to_pos)
			
			# Různé tloušťky podle typu propojení
			var from_node = tree_data.skill_nodes.filter(func(n): return n.id == skill_node.id)[0]
			var to_node = tree_data.skill_nodes.filter(func(n): return n.id == to_id_string)[0]
			
			if from_node.tier == to_node.tier:
				line.width = 3.0  # Horizontální propojení v rámci tieru
			else:
				line.width = 5.0  # Vertikální propojení mezi tiery
			
			var is_connection_unlocked = unlocked_ids.has(String(skill_node.id)) and unlocked_ids.has(to_id_string)
			
			if is_connection_unlocked:
				line.default_color = Color.GOLD
			elif not is_editor_preview and (unlocked_ids.has(String(skill_node.id)) or unlocked_ids.has(to_id_string)):
				line.default_color = Color(0.8, 0.8, 0.4, 0.7)  # Částečně dostupné
			else:
				line.default_color = Color(0.5, 0.5, 0.5, 0.6)
			
			connection_lines_container.add_child(line)

# --- FUNKCE PRO EDITOR ---

func _draw_editor_preview():
	_clear_view()
	if not is_instance_valid(preview_tree_data):
		print("Editor náhled: Není přiřazen 'Preview Tree Data'.")
		return
	
	print("Kreslím náhled stromu v editoru...")
	_generate_skill_nodes(true)
	_draw_background_lines()
	_draw_connections(true)

func _save_positions_to_resources():
	print("Ukládám pozice uzlů...")
	var saved_count = 0
	for skill_ui_node in skill_nodes_container.get_children():
		var skill_data: PassiveSkillNode = skill_ui_node.skill_data
		if is_instance_valid(skill_data):
			if skill_data.position.is_equal_approx(skill_ui_node.position):
				continue

			skill_data.position = skill_ui_node.position
			ResourceSaver.save(skill_data)
			saved_count += 1
	
	print("Uloženo %d změn pozic." % saved_count)
	_draw_editor_preview()

# --- LOGIKA ODEMYKÁNÍ ---

func _can_unlock_node(skill_node: PassiveSkillNode, unlocked_ids: PackedStringArray) -> bool:
	if SaveManager.meta_progress.skill_points < skill_node.get_cost_for_tier():
		return false
	
	if unlocked_ids.has(String(skill_node.id)):
		return false
	
	# Starter může být vždy odemčen, pokud je prázdný strom
	if unlocked_ids.is_empty():
		return skill_node.is_starter
	
	# Kontrola prerekvizit
	if not skill_node.prerequisite_nodes.is_empty():
		for prereq in skill_node.prerequisite_nodes:
			if not unlocked_ids.has(prereq):
				return false
	
	# Kontrola propojených uzlů
	for connected_id in skill_node.connected_nodes:
		if unlocked_ids.has(connected_id):
			return true
	
	# Kontrola, jestli nějaký odemčený uzel míří na tento
	for unlocked_id in unlocked_ids:
		var unlocked_node = active_skill_tree.get_node_by_id(unlocked_id)
		if unlocked_node and unlocked_node.connected_nodes.has(String(skill_node.id)):
			return true
	
	return false

func _on_skill_unlocked(skill_data: PassiveSkillNode):
	var unlocked_ids = SaveManager.meta_progress.unlocked_skill_ids
	if not _can_unlock_node(skill_data, unlocked_ids):
		return
		
	SaveManager.meta_progress.skill_points -= skill_data.get_cost_for_tier()
	SaveManager.meta_progress.unlocked_skill_ids.append(String(skill_data.id))
	SaveManager.save_meta_progress()
	
	# Aplikujeme efekty skilu na PlayerData
	_apply_skill_effects(skill_data)
	
	_refresh_tree()

func _apply_skill_effects(skill_node: PassiveSkillNode):
	print("Aplikuji efekty skilu: %s" % skill_node.skill_name)
	# Tato funkce by měla být volána pokaždé, když se strom znovu načte
	# Actual aplikace se děje v PlayerData.apply_passive_skills()
	# Tady můžeme přidat speciální efekty, které nejsou v základní sadě
