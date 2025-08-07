# Soubor: scenes/ui/PassiveSkillTree.gd (FINÁLNÍ VERZE)
extends Node2D

const PassiveSkillUIScene = preload("res://scenes/ui/PassiveSkillUI.tscn")

var active_skill_tree: PassiveSkillTreeData

@onready var skill_nodes_container = $SkillNodes
@onready var connection_lines_container = $ConnectionLines

# Slovník pro mapování ID uzlu na jeho UI instanci
var skill_ui_map: Dictionary = {}

func _ready():
	# Místo okamžitého kreslení se jen přihlásíme k odběru signálu.
	# Strom bude trpělivě čekat.
	PlayerData.player_initialized.connect(_on_player_initialized)

func _on_player_initialized():
	# Tato funkce se spustí, až když PlayerData zavolá emit_signal.
	# AŽ TEĎ bezpečně načteme strom a vygenerujeme ho.
	active_skill_tree = PlayerData.active_skill_tree
	_generate_tree()

func _generate_tree():
	if not is_instance_valid(active_skill_tree):
		print("Pasivní strom: Žádný aktivní strom dovedností nenalezen.")
		return
	
	_generate_skill_nodes()
	_draw_connections()

func _generate_skill_nodes():
	var unlocked_ids: PackedStringArray = SaveManager.meta_progress.unlocked_skill_ids
	
	for skill_node in active_skill_tree.skill_nodes:
		if not is_instance_valid(skill_node): continue
			
		var skill_ui: PassiveSkillUI = PassiveSkillUIScene.instantiate()
		skill_nodes_container.add_child(skill_ui)
		skill_ui.position = skill_node.position
		# Mapujeme pomocí ID, je to spolehlivější
		skill_ui_map[skill_node.id] = skill_ui
		
		var is_unlocked = unlocked_ids.has(skill_node.id)
		var can_unlock = _can_unlock_node(skill_node, unlocked_ids)

		skill_ui.display(skill_node, is_unlocked, can_unlock)
		skill_ui.skill_selected.connect(_on_skill_unlocked)

func _can_unlock_node(skill_node: PassiveSkillNode, unlocked_ids: PackedStringArray) -> bool:
	# Podmínky pro odemčení:
	# 1. Hráč má dostatek bodů.
	# 2. Uzel ještě není odemčený.
	if SaveManager.meta_progress.skill_points < skill_node.cost or unlocked_ids.has(skill_node.id):
		return false
	
	# 3. Pokud hráč ještě nemá žádný skill, může odemknout jakýkoliv uzel s cenou 0 (nebo 1, dle tvé volby).
	#    Toto funguje jako startovací podmínka.
	if unlocked_ids.is_empty():
		# Můžeš si upravit, zda první uzel má být zdarma (cost == 0) nebo stát 1 bod (cost <= 1)
		return skill_node.cost <= 1 
	
	# 4. Pokud už má nějaký skill, musí být tento napojen na již odemčený.
	for connected_id in skill_node.connected_nodes:
		if unlocked_ids.has(connected_id):
			return true # Našli jsme spojení s již odemčeným uzlem
	
	return false # Není napojen na nic odemčeného

func _draw_connections():
	var unlocked_ids: PackedStringArray = SaveManager.meta_progress.unlocked_skill_ids
	
	for skill_node in active_skill_tree.skill_nodes:
		if not is_instance_valid(skill_node): continue
		
		var from_id = skill_node.id
		if not skill_ui_map.has(from_id): continue # Pojistka, kdyby UI neexistovalo
		
		var from_pos = skill_ui_map[from_id].position
		
		for to_id_string in skill_node.connected_nodes:
			# Důležité: Kreslíme jen v jednom směru, abychom neměli duplicitní čáry
			# a ujistíme se, že cílový uzel existuje v mapě.
			
			# ZDE JE OPRAVA: Převedeme oba identifikátory na String, než je porovnáme.
			if String(from_id) > to_id_string or not skill_ui_map.has(to_id_string):
				continue
				
			var to_pos = skill_ui_map[to_id_string].position
			
			var line = Line2D.new()
			line.add_point(from_pos)
			line.add_point(to_pos)
			line.width = 5.0
			
			# Zde také používáme to_id_string pro kontrolu
			if unlocked_ids.has(from_id) and unlocked_ids.has(to_id_string):
				line.default_color = Color.GOLD
			else:
				line.default_color = Color(0.5, 0.5, 0.5)
			
			connection_lines_container.add_child(line)


func _on_skill_unlocked(skill_data: PassiveSkillNode):
	# Zkontrolujeme znovu, jestli je odemčení stále platné
	var unlocked_ids = SaveManager.meta_progress.unlocked_skill_ids
	if not _can_unlock_node(skill_data, unlocked_ids):
		return
		
	SaveManager.meta_progress.skill_points -= skill_data.cost
	SaveManager.meta_progress.unlocked_skill_ids.append(skill_data.id)
	SaveManager.save_meta_progress()
	
	# Nemusíme volat signál, protože SaveManager ho volá sám.
	# Stačí se připojit v RunPrepScreen na signál ze SaveManageru.
	_refresh_tree()

func _refresh_tree():
	# Vyčistíme staré uzly a čáry
	for child in skill_nodes_container.get_children():
		child.queue_free()
	for child in connection_lines_container.get_children():
		child.queue_free()
	skill_ui_map.clear()
	
	# A vygenerujeme vše znovu s aktuálními daty
	_generate_tree()
