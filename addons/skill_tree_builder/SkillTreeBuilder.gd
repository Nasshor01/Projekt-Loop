# Soubor: addons/skill_tree_builder/SkillTreeBuilder.gd (DEBUG VERZE)
@tool
extends EditorScript

func _run():
	print("=== GENERUJI SKILL TREE PRO PALADINA ===")
	
	var tree = create_paladin_tree()
	
	# VALIDACE: Zkontrolujeme, že všechny objekty jsou správného typu
	print("=== VALIDACE STROMU ===")
	for i in range(tree.skill_nodes.size()):
		var node = tree.skill_nodes[i]
		if node is PassiveSkillNode:
			print("Node %d: ✓ PassiveSkillNode - %s" % [i, node.skill_name])
		else:
			print("Node %d: ✗ CHYBA! Typ: %s" % [i, node.get_class()])
	
	# Ujistíme se, že složka existuje
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("data"):
		dir.make_dir("data")
	if not dir.dir_exists("data/skill_tree"):
		dir.make_dir("data/skill_tree")
	if not dir.dir_exists("data/skill_tree/paladin"):
		dir.make_dir("data/skill_tree/paladin")
	
	var save_path = "res://data/skill_tree/paladin/generated_paladin_tree.tres"
	
	var result = ResourceSaver.save(tree, save_path)
	if result == OK:
		print("✓ Strom uložen do: ", save_path)
	else:
		print("✗ Chyba při ukládání! Kód: ", result)
	
	print("=== HOTOVO ===")

func create_paladin_tree() -> PassiveSkillTreeData:
	var tree = PassiveSkillTreeData.new()
	var nodes: Array = []
	
	# 1. STARTOVNÍ UZEL
	print("Vytvářím startovní uzel...")
	var start_node = create_safe_node(
		"paladin_start",
		"Počátek cesty",
		"Základní uzel Paladina. Odtud začíná tvoje cesta.",
		Vector2(0, 0),
		0,
		[]
	)
	if start_node:
		nodes.append(start_node)
	
	# 2. HP UZEL
	print("Vytvářím HP uzel...")
	var hp_node = create_safe_node(
		"paladin_hp_basic",
		"Ocelové zdraví",
		"Zvýší tvou odolnost o 15 životů.",
		Vector2(0, -120),
		1,
		["paladin_start"]
	)
	if hp_node:
		var hp_effect = create_safe_effect(PassiveEffectData.EffectType.ADD_MAX_HP, 15)
		if hp_effect:
			hp_node.effects.append(hp_effect)
		nodes.append(hp_node)
	
	# 3. GOLD UZEL
	print("Vytvářím Gold uzel...")
	var gold_node = create_safe_node(
		"paladin_gold_basic",
		"Desátek",
		"Začínáš s 25 zlatými navíc.",
		Vector2(-150, 0),
		1,
		["paladin_start"]
	)
	if gold_node:
		var gold_effect = create_safe_effect(PassiveEffectData.EffectType.ADD_STARTING_GOLD, 25)
		if gold_effect:
			gold_node.effects.append(gold_effect)
		nodes.append(gold_node)
	
	# 4. DAMAGE UZEL
	print("Vytvářím Damage uzel...")
	var damage_node = create_safe_node(
		"paladin_damage_basic",
		"Světelná zbraň",
		"Tvé útoky jsou požehnané světlem (+2 damage).",
		Vector2(150, 0),
		1,
		["paladin_start"]
	)
	if damage_node:
		var damage_effect = create_safe_effect(PassiveEffectData.EffectType.ADD_CARD_DAMAGE, 2)
		if damage_effect:
			damage_node.effects.append(damage_effect)
		nodes.append(damage_node)
	
	# PŘIŘADÍME UZLY DO STROMU
	tree.skill_nodes = nodes
	
	print("=== VÝSLEDEK ===")
	print("Celkem uzlů: ", nodes.size())
	for i in range(nodes.size()):
		var node = nodes[i]
		print("Uzel %d: %s (typ: %s)" % [i, node.skill_name, node.get_class()])
	
	return tree

func create_safe_node(id: String, name: String, description: String, pos: Vector2, cost: int, connections: Array) -> PassiveSkillNode:
	print("  Vytvářím uzel: %s" % name)
	
	var node = PassiveSkillNode.new()
	if not is_instance_valid(node):
		print("  CHYBA: Nepodařilo se vytvořit PassiveSkillNode!")
		return null
	
	node.id = StringName(id)
	node.skill_name = name
	node.description = description
	node.position = pos
	node.cost = cost
	node.connected_nodes = PackedStringArray(connections)
	node.is_notable = false
	node.effects = []  # Prázdné pole pro začátek
	
	# Přiřadíme ikonu
	var default_icon = load("res://art/icons/skills/136.png") as Texture2D
	if default_icon:
		node.icon = default_icon
	
	print("  ✓ Uzel vytvořen: %s" % node.skill_name)
	return node

func create_safe_effect(type: PassiveEffectData.EffectType, value: int) -> PassiveEffectData:
	print("    Vytvářím efekt: %s = %d" % [type, value])
	
	var effect = PassiveEffectData.new()
	if not is_instance_valid(effect):
		print("    CHYBA: Nepodařilo se vytvořit PassiveEffectData!")
		return null
	
	effect.effect_type = type
	effect.value = value
	
	print("    ✓ Efekt vytvořen: %s" % effect.get_class())
	return effect
