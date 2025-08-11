# Soubor: res://data/skills/SkillTreeGenerator.gd
# Automaticky generuje pozice uzlů podle tierů a branchí
class_name SkillTreeGenerator
extends RefCounted

const TIER_SPACING_Y = 150.0  # Vzdálenost mezi tiery
const BRANCH_SPACING_X = 200.0  # Vzdálenost mezi větvemi
const NODE_SPACING = 80.0  # Vzdálenost mezi uzly ve stejném tieru
const CENTER_X = 400.0  # Střed stromu

# Definice branchí pro různé archetypy
enum Branch {
	DEFENSE,    # Obranná větev (vlevo)
	OFFENSE,    # Útočná větev (vpravo) 
	UTILITY,    # Utility větev (nahoře)
	MAIN        # Hlavní cesta (střed)
}

static func generate_paladin_tree() -> PassiveSkillTreeData:
	var tree = PassiveSkillTreeData.new()
	var nodes: Array[PassiveSkillNode] = []
	
	# TIER 1 - Základy (Startovní bod a základní vylepšení)
	var starter = create_node("paladin_start", "Svatý Závazek", 
		"Startovní bod Paladina. Zvýší maximální zdraví o 5.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.MAIN, 0, PassiveSkillNode.NodeType.STARTER)
	starter.is_starter = true
	starter.cost = 0
	add_effect(starter, PassiveEffectData.EffectType.ADD_MAX_HP, 5)
	nodes.append(starter)
	
	# Defense Branch - Tier 1
	var shield_training = create_node("paladin_hp_1", "Výcvik se štítem",
		"Začni každý souboj s 3 body bloku.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.DEFENSE, 0)
	add_effect(shield_training, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 3)
	nodes.append(shield_training)
	
	var vitality = create_node("paladin_gold_1", "Vitalita",
		"Zvýší maximální zdraví o 8.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.DEFENSE, 1)
	add_effect(vitality, PassiveEffectData.EffectType.ADD_MAX_HP, 8)
	nodes.append(vitality)
	
	# Offense Branch - Tier 1  
	var righteous_anger = create_node("righteous_anger", "Spravedlivý hněv",
		"Všechny karty způsobí o 1 poškození navíc.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.OFFENSE, 0)
	add_effect(righteous_anger, PassiveEffectData.EffectType.ADD_CARD_DAMAGE, 1)
	nodes.append(righteous_anger)
	
	var swift_justice = create_node("swift_justice", "Rychlá spravedlnost",
		"Začni každý souboj s 1 extra energií.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.OFFENSE, 1)
	add_effect(swift_justice, PassiveEffectData.EffectType.ADD_MAX_ENERGY, 1)
	nodes.append(swift_justice)
	
	# TIER 2 - Specializace
	# Defense Branch - Tier 2
	var fortress = create_node("fortress", "Pevnost",
		"Začni každý souboj s 8 body bloku. Blok nad 5 se nepohbuje každý tah.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 0, PassiveSkillNode.NodeType.NOTABLE)
	add_effect(fortress, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 8)
	nodes.append(fortress)
	
	# Offense Branch - Tier 2
	var divine_wrath = create_node("divine_wrath", "Božský hněv",
		"Útoky mají 20% šanci způsobit kritický zásah (2x poškození).",
		PassiveSkillNode.SkillTier.TIER_2, Branch.OFFENSE, 0, PassiveSkillNode.NodeType.NOTABLE)
	add_effect(divine_wrath, PassiveEffectData.EffectType.CRITICAL_CHANCE_BONUS, 20)
	nodes.append(divine_wrath)
	
	# Main Branch - Tier 2
	var blessed_recovery = create_node("blessed_recovery", "Požehnaná obnova",
		"Na konci každého tahu se vyléč za 2 HP.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.MAIN, 0)
	add_effect(blessed_recovery, PassiveEffectData.EffectType.HEAL_END_OF_TURN, 2)
	nodes.append(blessed_recovery)
	
	# TIER 3 - Pokročilé schopnosti
	var divine_protection = create_node("divine_protection", "Božská ochrana", 
		"Jednou za souboj: když by měl umřít, místo toho se vyléč na 50% HP.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.DEFENSE, 0, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(divine_protection, PassiveEffectData.EffectType.GRANT_REVIVE, 1)
	nodes.append(divine_protection)
	
	# TIER 3 - Další defensive skill
	var sacred_thorns = create_node("sacred_thorns", "Svaté trny",
		"Když utrpíš poškození, útočník utrpí 3 poškození zpět.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.DEFENSE, 1, PassiveSkillNode.NodeType.NOTABLE)
	add_effect(sacred_thorns, PassiveEffectData.EffectType.THORNS_DAMAGE, 3)
	nodes.append(sacred_thorns)
	
	# TIER 3 - Offensive skill
	var righteous_fury = create_node("righteous_fury", "Spravedlivá zuřivost",
		"Získej 1 energii za každého zabitého nepřítele.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.OFFENSE, 0, PassiveSkillNode.NodeType.NOTABLE)
	add_effect(righteous_fury, PassiveEffectData.EffectType.ENERGY_ON_KILL, 1)
	nodes.append(righteous_fury)
	
	# TIER 4 - Mocné efekty
	var aura_mastery = create_node("aura_mastery", "Mistrovství aur",
		"Všechny aury jsou o 50% silnější.",
		PassiveSkillNode.SkillTier.TIER_4, Branch.MAIN, 0, PassiveSkillNode.NodeType.MASTERY)
	add_effect(aura_mastery, PassiveEffectData.EffectType.AURA_ENHANCEMENT, 50)
	nodes.append(aura_mastery)
	
	# TIER 5 - Ultimátní schopnost
	var avatar_of_light = create_node("avatar_of_light", "Avatár světla",
		"Na začátku souboje získej blok rovný 2x tvému maximálnímu zdraví.",
		PassiveSkillNode.SkillTier.TIER_5, Branch.MAIN, 0, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(avatar_of_light, PassiveEffectData.EffectType.AVATAR_STARTING_BLOCK, 2)
	nodes.append(avatar_of_light)
	
	# Nastavení propojení
	setup_connections(nodes)
	
	# Automatické generování pozic
	auto_position_nodes(nodes)
	
	tree.skill_nodes = nodes
	return tree

static func create_node(id: String, name: String, description: String, 
	tier: PassiveSkillNode.SkillTier, branch: Branch, branch_pos: int, 
	node_type: PassiveSkillNode.NodeType = PassiveSkillNode.NodeType.BASIC) -> PassiveSkillNode:
	
	var node = PassiveSkillNode.new()
	node.id = StringName(id)
	node.skill_name = name
	node.description = description
	node.tier = tier
	node.branch = Branch.keys()[branch].to_lower()
	node.branch_position = branch_pos
	node.node_type = node_type
	node.cost = node.get_cost_for_tier()
	
	return node

static func add_effect(node: PassiveSkillNode, effect_type: PassiveEffectData.EffectType, value: int):
	var effect = PassiveEffectData.new()
	effect.effect_type = effect_type
	effect.value = value
	node.effects.append(effect)

static func setup_connections(nodes: Array[PassiveSkillNode]):
	# Najdeme uzly podle ID pro snadnější propojování
	var node_map = {}
	for node in nodes:
		node_map[node.id] = node
	
	# Propojení - starter se všemi tier 1
	var starter = node_map.get("paladin_start")
	if starter:
		starter.connected_nodes = ["paladin_hp_1", "righteous_anger"]
	
	# Defense branch propojení
	if node_map.has("paladin_hp_1"):
		node_map["paladin_hp_1"].connected_nodes = ["paladin_gold_1", "fortress"]
	if node_map.has("paladin_gold_1"):
		node_map["paladin_gold_1"].connected_nodes = ["fortress"]
	if node_map.has("fortress"):
		node_map["fortress"].connected_nodes = ["divine_protection", "sacred_thorns"]
	if node_map.has("sacred_thorns"):
		node_map["sacred_thorns"].connected_nodes = ["divine_protection"]
	
	# Offense branch propojení
	if node_map.has("righteous_anger"):
		node_map["righteous_anger"].connected_nodes = ["swift_justice", "divine_wrath"]
	if node_map.has("swift_justice"):
		node_map["swift_justice"].connected_nodes = ["divine_wrath"]
	if node_map.has("divine_wrath"):
		node_map["divine_wrath"].connected_nodes = ["righteous_fury"]
	
	# Main branch propojení
	if starter:
		starter.connected_nodes.append("blessed_recovery")
	if node_map.has("blessed_recovery"):
		node_map["blessed_recovery"].connected_nodes = ["aura_mastery"]
	if node_map.has("aura_mastery"):
		node_map["aura_mastery"].connected_nodes = ["avatar_of_light"]
	
	# Cross-branch propojení
	if node_map.has("divine_protection"):
		node_map["divine_protection"].connected_nodes = ["aura_mastery"]
	if node_map.has("righteous_fury"):
		node_map["righteous_fury"].connected_nodes = ["aura_mastery"]
	if node_map.has("sacred_thorns"):
		node_map["sacred_thorns"].connected_nodes = ["aura_mastery"]

static func auto_position_nodes(nodes: Array[PassiveSkillNode]):
	# Seskupíme uzly podle branche a tieru
	var branch_groups = {}
	
	for node in nodes:
		var branch_key = node.branch
		if not branch_groups.has(branch_key):
			branch_groups[branch_key] = {}
		
		var tier_key = node.tier
		if not branch_groups[branch_key].has(tier_key):
			branch_groups[branch_key][tier_key] = []
		
		branch_groups[branch_key][tier_key].append(node)
	
	# Pozicionujeme uzly
	for branch_name in branch_groups.keys():
		var branch_data = branch_groups[branch_name]
		var branch_x = get_branch_x_offset(branch_name)
		
		for tier in branch_data.keys():
			var tier_nodes = branch_data[tier]
			var tier_y = get_tier_y_offset(tier)
			
			# Rozložíme uzly v tieru horizontálně
			var node_count = tier_nodes.size()
			var start_x = branch_x - (node_count - 1) * NODE_SPACING * 0.5
			
			for i in range(node_count):
				var node = tier_nodes[i]
				node.position = Vector2(start_x + i * NODE_SPACING, tier_y)

static func get_branch_x_offset(branch_name: String) -> float:
	match branch_name:
		"defense": return CENTER_X - BRANCH_SPACING_X
		"offense": return CENTER_X + BRANCH_SPACING_X
		"utility": return CENTER_X
		"main": return CENTER_X
		_: return CENTER_X

static func get_tier_y_offset(tier: PassiveSkillNode.SkillTier) -> float:
	return tier * TIER_SPACING_Y
