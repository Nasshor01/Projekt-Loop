# Soubor: test/SkillTreeTester.gd
# Spusť tento script v editoru (Attach k nějakému nodu a zavolej funkce)
@tool
extends Node

func test_skill_tree_data():
	print("=== TESTOVÁNÍ SKILL TREE DAT ===")
	
	# Test 1: Zkontroluj PlayerData
	if PlayerData:
		print("✓ PlayerData existuje")
		print("  active_skill_tree: ", PlayerData.active_skill_tree)
		print("  selected_subclass: ", PlayerData.selected_subclass)
	else:
		print("✗ PlayerData neexistuje!")
		return
	
	# Test 2: Zkontroluj SaveManager
	if SaveManager:
		print("✓ SaveManager existuje")
		print("  skill_points: ", SaveManager.meta_progress.skill_points)
		print("  unlocked_skills: ", SaveManager.meta_progress.unlocked_skill_ids)
	else:
		print("✗ SaveManager neexistuje!")
		return
	
	# Test 3: Zkontroluj skill tree data
	var tree_path = "res://data/skill_tree/paladin/generated_paladin_tree.tres"
	if ResourceLoader.exists(tree_path):
		var tree = load(tree_path)
		if tree is PassiveSkillTreeData:
			print("✓ Skill tree načten: ", tree_path)
			print("  Počet uzlů: ", tree.skill_nodes.size())
			
			for i in range(min(3, tree.skill_nodes.size())):
				var node = tree.skill_nodes[i]
				if node:
					print("  Uzel %d: %s (cost: %d, pozice: %s)" % [i, node.skill_name, node.cost, node.position])
				else:
					print("  Uzel %d: NULL!" % i)
		else:
			print("✗ Soubor není PassiveSkillTreeData!")
	else:
		print("✗ Skill tree soubor neexistuje: ", tree_path)
	
	# Test 4: Zkontroluj scény
	var skill_ui_path = "res://scenes/ui/PassiveSkillUI.tscn"
	if ResourceLoader.exists(skill_ui_path):
		print("✓ PassiveSkillUI.tscn existuje")
	else:
		print("✗ PassiveSkillUI.tscn neexistuje!")

func give_test_skill_points():
	"""Přidá skill pointy pro testování"""
	SaveManager.meta_progress.skill_points = 10
	SaveManager.save_meta_progress()
	print("✓ Přidáno 10 skill pointů pro testování!")

func reset_skills():
	"""Resetuje všechny odemčené skills"""
	SaveManager.meta_progress.unlocked_skill_ids.clear()
	SaveManager.save_meta_progress()
	print("✓ Všechny skills resetovány!")

func create_test_skill_tree():
	"""Vytvoří jednoduchý test skill tree"""
	print("=== VYTVÁŘENÍ TEST SKILL TREE ===")
	
	var tree = PassiveSkillTreeData.new()
	var nodes: Array = []
	
	# Start node
	var start_node = PassiveSkillNode.new()
	start_node.id = &"test_start"
	start_node.skill_name = "Start"
	start_node.description = "Počátek cesty"
	start_node.cost = 0
	start_node.position = Vector2(400, 300)
	start_node.icon = load("res://art/icons/skills/136.png")
	start_node.effects = []
	nodes.append(start_node)
	
	# HP node
	var hp_node = PassiveSkillNode.new()
	hp_node.id = &"test_hp"
	hp_node.skill_name = "Extra HP"
	hp_node.description = "Získáš +20 HP"
	hp_node.cost = 1
	hp_node.position = Vector2(400, 200)
	hp_node.icon = load("res://art/icons/skills/119.png")
	hp_node.connected_nodes = PackedStringArray(["test_start"])
	start_node.connected_nodes = PackedStringArray(["test_hp"])
	
	var hp_effect = PassiveEffectData.new()
	hp_effect.effect_type = PassiveEffectData.EffectType.ADD_MAX_HP
	hp_effect.value = 20
	hp_node.effects = [hp_effect]
	nodes.append(hp_node)
	
	# Gold node  
	var gold_node = PassiveSkillNode.new()
	gold_node.id = &"test_gold"
	gold_node.skill_name = "Extra Gold"
	gold_node.description = "Začínáš s +50 zlatem"
	gold_node.cost = 1
	gold_node.position = Vector2(300, 300)
	gold_node.icon = load("res://art/icons/skills/237.png")
	gold_node.connected_nodes = PackedStringArray(["test_start"])
	start_node.connected_nodes.append("test_gold")
	
	var gold_effect = PassiveEffectData.new()
	gold_effect.effect_type = PassiveEffectData.EffectType.ADD_STARTING_GOLD
	gold_effect.value = 50
	gold_node.effects = [gold_effect]
	nodes.append(gold_node)
	
	tree.skill_nodes = nodes
	
	# Ulož test tree
	var save_path = "res://data/skill_tree/test_tree.tres"
	ResourceSaver.save(tree, save_path)
	print("✓ Test skill tree vytvořen: ", save_path)
	
	# Nastav jako aktivní
	PlayerData.active_skill_tree = tree
	print("✓ Test tree nastaven jako aktivní")

# Funkce pro snadné volání z editoru
func _ready():
	if Engine.is_editor_hint():
		print("SkillTreeTester připraven! Použij:")
		print("  test_skill_tree_data() - zkontroluje data")
		print("  create_test_skill_tree() - vytvoří test strom") 
		print("  give_test_skill_points() - přidá body")
		print("  reset_skills() - resetuje skills")
