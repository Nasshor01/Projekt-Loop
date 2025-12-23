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

## Automaticky vygeneruj strom pro Paladina (pro náhled v editoru)
@export var generate_paladin_tree: bool = false:
	set(value):
		if Engine.is_editor_hint() and value:
			_generate_and_preview_paladin()
			generate_paladin_tree = false

## NOVÉ: Zobrazení pomocných čar pro tiery
@export var show_tier_lines: bool = true
@export var show_branch_lines: bool = true


@export_group("Barvy Propojovacích Čar")
## Čára mezi dvěma ODEMČENÝMI skilly.
@export var unlocked_connection_color: Color = Color.PALE_GREEN
## Čára mezi ODEMČENÝM a ZAMČENÝM skillem (dostupná cesta).
@export var available_connection_color: Color = Color.INDIAN_RED
## Čára mezi dvěma ZAMČENÝMI skilly.
@export var locked_connection_color: Color = Color(0.5, 0.5, 0.5, 0.6)

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
	print("=== GENEROVÁNÍ PALADIN SKILL TREE ===")
	preview_tree_data = SkillTreeGenerator.generate_paladin_tree()
	if not is_instance_valid(preview_tree_data):
		printerr("❌ Chyba při generování stromu!")
		return
	print("✅ Strom vygenerován! Počet uzlů: %d" % preview_tree_data.skill_nodes.size())
	_draw_editor_preview()
	print("✅ Náhled vykreslen!")



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
	
	# ✅ OPRAVENO: Používáme allocated_skills místo unlocked_skill_ids
	var allocated_skills: Dictionary = {} if is_editor_preview else SaveManager.meta_progress.allocated_skills

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
			var skill_id = String(skill_node.id)
			var allocation_count = allocated_skills.get(skill_id, 0)
			var is_unlocked = allocation_count > 0
			var can_unlock = _can_unlock_node(skill_node, allocated_skills)
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
	
	# Nakreslíme tier čáry (horizontální) - rozšířeno pro větší strom
	if show_tier_lines:
		for tier in tiers.keys():
			var y = SkillTreeGenerator.get_tier_y_offset(tier)
			var line = Line2D.new()
			line.add_point(Vector2(-800, y))  # Rozšířeno doleva (uprav podle potřeby)
			line.add_point(Vector2(2800, y))  # Rozšířeno doprava (uprav podle potřeby)
			line.width = 2.0
			line.default_color = Color(0.3, 0.3, 0.3, 0.5)
			background_lines_container.add_child(line)
			
			# Přidáme label pro tier
			var label = Label.new()
			label.text = "Tier %d" % tier
			label.position = Vector2(-380, y - 10)
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			background_lines_container.add_child(label)
	
	# Nakreslíme branch čáry (vertikální) - rozšířeno pro větší strom
	if show_branch_lines:
		for branch in branches.keys():
			var x = SkillTreeGenerator.get_branch_x_offset(branch)
			var line = Line2D.new()
			line.add_point(Vector2(x, -200))  # Začátek výš (uprav podle potřeby)
			line.add_point(Vector2(x, 2000))  # Konec níž (uprav podle potřeby)
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

	# ✅ OPRAVENO: Používáme allocated_skills místo unlocked_skill_ids
	var allocated_skills: Dictionary = {} if is_editor_preview else SaveManager.meta_progress.allocated_skills

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
			
			var from_node = tree_data.get_node_by_id(skill_node.id)
			var to_node = tree_data.get_node_by_id(to_id_string)
			
			# NOVÝ ČISTÝ DESIGN - jednodušší spojení
			var line = Line2D.new()
			
			# Pokud jsou uzly ve stejném tieru (horizontální spojení), použijeme přímou čáru
			if from_node and to_node and from_node.tier == to_node.tier:
				line.width = 3.0
				line.add_point(from_pos)
				line.add_point(to_pos)
			# Pokud jsou uzly ve stejné větvi (vertikální spojení), použijeme přímou čáru
			elif from_node and to_node and from_node.branch == to_node.branch:
				line.width = 4.0
				line.add_point(from_pos)
				line.add_point(to_pos)
			# Cross-branch spojení (např. do Aura Mastery) - mírná křivka
			else:
				line.width = 5.0
				var mid_x = (from_pos.x + to_pos.x) / 2.0
				var mid_y = (from_pos.y + to_pos.y) / 2.0
				var curve_offset = 30.0  # Menší oblouk pro čistší vzhled
				var direction = 1.0 if from_pos.x < to_pos.x else -1.0
				var mid_point = Vector2(mid_x + curve_offset * direction, mid_y)
				
				# Jednoduchá křivka s méně body
				for i in range(7):  # Méně bodů = jednodušší křivka
					var t = i / 6.0
					var point = from_pos.lerp(mid_point, t).lerp(to_pos.lerp(mid_point, 1.0 - t), t)
					line.add_point(point)
			
			# --- ZMĚNA ZDE: POUŽÍVÁME NOVÉ @export PROMĚNNÉ ---
			var from_count = allocated_skills.get(String(skill_node.id), 0)
			var to_count = allocated_skills.get(to_id_string, 0)
			var from_is_unlocked = from_count > 0
			var to_is_unlocked = to_count > 0
			
			if from_is_unlocked and to_is_unlocked:
				line.default_color = unlocked_connection_color
			elif not is_editor_preview and (from_is_unlocked or to_is_unlocked):
				line.default_color = available_connection_color
			else:
				line.default_color = locked_connection_color

			# --- KONEC ZMĚNY ---

			connection_lines_container.add_child(line)

# --- FUNKCE PRO EDITOR ---

func _draw_editor_preview():
	_clear_view()
	_generate_skill_nodes(true)
	_draw_background_lines()
	_draw_connections(true)

func _save_positions_to_resources():
	var saved_count = 0
	for skill_ui_node in skill_nodes_container.get_children():
		var skill_data: PassiveSkillNode = skill_ui_node.skill_data
		if is_instance_valid(skill_data):
			if skill_data.position.is_equal_approx(skill_ui_node.position):
				continue

			skill_data.position = skill_ui_node.position
			ResourceSaver.save(skill_data)
			saved_count += 1
	
	print("Uloženo %d pozic skill uzlů do .tres souborů" % saved_count)
	_draw_editor_preview()

# --- LOGIKA ODEMYKÁNÍ ---

func _can_unlock_node(skill_node: PassiveSkillNode, allocated_skills_dict: Dictionary) -> bool:
	# ✅ OPRAVENO: Používáme allocated_skills místo unlocked_skill_ids
	if SaveManager.meta_progress.skill_points < skill_node.get_cost_for_tier():
		return false
	
	# Kontrola, jestli už není na maximu
	var current_count = SaveManager.meta_progress.allocated_skills.get(String(skill_node.id), 0)
	if current_count >= skill_node.max_allocations:
		return false
	
	# Starter může být vždy odemčen, pokud je prázdný strom
	if allocated_skills_dict.is_empty():
		return skill_node.is_starter
	
	# NOVÉ: Kontrola unlock_conditions (např. "all_nodes_unlocked", "level_10", atd.)
	if not skill_node.unlock_conditions.is_empty():
		for condition in skill_node.unlock_conditions:
			if not _check_unlock_condition(condition, allocated_skills_dict, skill_node):
				return false
	
	# ✅ OPRAVENO: Používáme POUZE prerequisite_nodes pro logiku odemykání
	# connected_nodes slouží POUZE pro vizuální kreslení linek
	
	# Kontrola prerekvizit (hlavní logika)
	if not skill_node.prerequisite_nodes.is_empty():
		for prereq in skill_node.prerequisite_nodes:
			var prereq_id = String(prereq)
			# Kontrola, jestli je prerekvizita odemčená
			var prereq_count = SaveManager.meta_progress.allocated_skills.get(prereq_id, 0)
			if prereq_count == 0:
				return false
	else:
		# Pokud nemá explicitní prerekvizity, použijeme connected_nodes jako fallback
		# (pro zpětnou kompatibilitu se starými stromy)
		var has_connected_unlocked = false
		for connected_id in skill_node.connected_nodes:
			var conn_id = String(connected_id)
			var conn_count = SaveManager.meta_progress.allocated_skills.get(conn_id, 0)
			if conn_count > 0:
				has_connected_unlocked = true
				break
		
		# Kontrola, jestli nějaký odemčený uzel míří na tento
		if not has_connected_unlocked:
			for allocated_id in SaveManager.meta_progress.allocated_skills.keys():
				var allocated_node = active_skill_tree.get_node_by_id(allocated_id)
				if allocated_node and allocated_node.connected_nodes.has(String(skill_node.id)):
					has_connected_unlocked = true
					break
		
		if not has_connected_unlocked:
			return false
	
	# Kontrola, jestli už není na maximu
	var skill_id_str = String(skill_node.id)
	var current_allocation = SaveManager.meta_progress.allocated_skills.get(skill_id_str, 0)
	if current_allocation >= skill_node.max_allocations:
		return false
	
	return true

func _check_unlock_condition(condition: String, allocated_skills_dict: Dictionary, skill_node: PassiveSkillNode) -> bool:
	"""Kontroluje speciální podmínky pro odemčení"""
	match condition:
		"all_nodes_unlocked":
			# Všechny uzly kromě tohoto musí být odemčené (allocation count > 0)
			var all_nodes = active_skill_tree.skill_nodes
			for node in all_nodes:
				if String(node.id) == String(skill_node.id) or node.is_starter:
					continue
				var node_id_str = String(node.id)
				var allocation_count = allocated_skills_dict.get(node_id_str, 0)
				if allocation_count == 0:
					return false
			return true
		"all_tier_3_unlocked":
			# Všechny Tier 3 uzly musí být odemčené (allocation count > 0)
			for node in active_skill_tree.skill_nodes:
				if node.tier == PassiveSkillNode.SkillTier.TIER_3:
					var node_id_str = String(node.id)
					var allocation_count = allocated_skills_dict.get(node_id_str, 0)
					if allocation_count == 0:
						return false
			return true
		"all_keystones_unlocked":
			# Všechny keystone uzly musí být odemčené (allocation count > 0)
			for node in active_skill_tree.skill_nodes:
				if node.node_type == PassiveSkillNode.NodeType.KEYSTONE:
					var node_id_str = String(node.id)
					var allocation_count = allocated_skills_dict.get(node_id_str, 0)
					if allocation_count == 0:
						return false
			return true
		_:
			# Další podmínky (level, boss fight, atd.) - lze rozšířit
			return true

func _on_skill_unlocked(skill_data: PassiveSkillNode):
	# ✅ OPRAVENO: Používáme allocated_skills místo unlocked_skill_ids
	var skill_id = String(skill_data.id)
	var allocated_skills_dict = SaveManager.meta_progress.allocated_skills
	
	if not _can_unlock_node(skill_data, allocated_skills_dict):
		return
		
	SaveManager.meta_progress.skill_points -= skill_data.get_cost_for_tier()
	
	# Zvýšíme allocation count
	var current_count = SaveManager.meta_progress.allocated_skills.get(skill_id, 0)
	SaveManager.meta_progress.allocated_skills[skill_id] = current_count + 1
	
	# NOVÉ: Odemkneme kartu, pokud je to první alokace a skill má unlocks_card nastaveno
	if current_count == 0 and skill_data.unlocks_card != "":
		if not PlayerData.unlocked_cards.has(skill_data.unlocks_card):
			PlayerData.unlocked_cards.append(skill_data.unlocks_card)
			print("Odemčena karta: %s" % skill_data.unlocks_card)
			# Uložíme odemčené karty do meta progress
			SaveManager.meta_progress.unlocked_cards = PlayerData.unlocked_cards.duplicate()
			SaveManager.save_meta_progress()  # Uložíme změny
	
	SaveManager.save_meta_progress()
	
	# Aplikujeme efekty skilu na PlayerData
	_apply_skill_effects(skill_data)
	
	_refresh_tree()

func _apply_skill_effects(skill_node: PassiveSkillNode):
	print("Aplikuji efekty skilu: %s" % skill_node.skill_name)
	# Tato funkce by měla být volána pokaždé, když se strom znovu načte
	# Actual aplikace se děje v PlayerData.apply_passive_skills()
	# Tady můžeme přidat speciální efekty, které nejsou v základní sadě
