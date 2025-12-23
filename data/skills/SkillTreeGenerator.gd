# Soubor: res://data/skills/SkillTreeGenerator.gd
# Automaticky generuje pozice uzlů podle tierů a branchí
class_name SkillTreeGenerator
extends RefCounted

# ===== NASTAVENÍ ROZESTUPŮ - ZMĚŇ TYTO HODNOTY PRO ÚPRAVU LAYOUTU =====
const TIER_SPACING_Y = 400.0  # Vzdálenost mezi tiery (vertikální rozestup) - ZVÝŠENO
const BRANCH_SPACING_X = 600.0  # Vzdálenost mezi větvemi (horizontální rozestup) - ZVÝŠENO
const NODE_SPACING = 250.0  # Vzdálenost mezi uzly ve stejném tieru - ZVÝŠENO
const CENTER_X = 1000.0  # Střed stromu (X pozice) - ZVÝŠENO
const STARTER_Y_OFFSET = -250.0  # Starter je výše nad tier 1 - ZVÝŠENO
const NODE_OFFSET_IN_TIER = 80.0  # Horizontální offset pro více uzlů ve stejném tieru - ZVÝŠENO

# Definice branchí pro různé archetypy
enum Branch {
	DEFENSE,    # Obranná větev (vlevo)
	OFFENSE,    # Útočná větev (vpravo) 
	UTILITY,    # Utility větev (střed)
	MAIN        # Hlavní cesta (střed)
}

# --- NOVÝ ČISTÝ DESIGN ---

static func generate_paladin_tree() -> PassiveSkillTreeData:
	"""Nový čistý Paladin skill tree s lineární strukturou"""
	var tree = PassiveSkillTreeData.new()
	var nodes: Array[PassiveSkillNode] = []
	
	# ===== TIER 0 - Starter =====
	var starter = PassiveSkillNode.new()
	starter.id = StringName("paladin_start")
	starter.skill_name = "Svatý Závazek"
	starter.description = "Startovní bod Paladina. Zvýší maximální zdraví o 5."
	starter.tier = PassiveSkillNode.SkillTier.values()[0]  # TIER_0
	starter.branch = "main"
	starter.branch_position = 0
	starter.node_type = PassiveSkillNode.NodeType.STARTER
	starter.is_starter = true
	starter.cost = 0
	add_effect(starter, PassiveEffectData.EffectType.ADD_MAX_HP, 5)
	nodes.append(starter)
	
	# ===== TIER 1 - Základní vylepšení (3 větve, více uzlů) =====
	# Defense Branch (4 uzly)
	var shield_training = create_node("paladin_block_1", "Výcvik se štítem",
		"Začni každý souboj s 3 body bloku.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.DEFENSE, 0)
	add_effect(shield_training, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 3)
	nodes.append(shield_training)
	
	var vitality = create_node("paladin_hp_1", "Vitalita",
		"Zvýší maximální zdraví o 8.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.DEFENSE, 1)
	add_effect(vitality, PassiveEffectData.EffectType.ADD_MAX_HP, 8)
	nodes.append(vitality)
	
	var iron_skin = create_node("iron_skin", "Železná kůže",
		"Zvýší maximální zdraví o 6.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.DEFENSE, 2)
	add_effect(iron_skin, PassiveEffectData.EffectType.ADD_MAX_HP, 6)
	nodes.append(iron_skin)
	
	var defensive_stance = create_node("defensive_stance", "Obranný postoj",
		"Začni každý souboj s 2 body bloku navíc.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.DEFENSE, 3)
	add_effect(defensive_stance, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 2)
	nodes.append(defensive_stance)
	
	# Offense Branch (4 uzly)
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
	
	var holy_power = create_node("holy_power", "Svatá síla",
		"Všechny karty způsobí o 1 poškození navíc.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.OFFENSE, 2)
	add_effect(holy_power, PassiveEffectData.EffectType.ADD_CARD_DAMAGE, 1)
	nodes.append(holy_power)
	
	var battle_fervor = create_node("battle_fervor", "Bojové nadšení",
		"Začni každý souboj s 1 extra energií.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.OFFENSE, 3)
	add_effect(battle_fervor, PassiveEffectData.EffectType.ADD_MAX_ENERGY, 1)
	nodes.append(battle_fervor)
	
	# Utility Branch (3 uzly)
	var blessed_gold = create_node("blessed_gold", "Požehnané zlato",
		"Začni každý souboj s 10 zlatem navíc.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.UTILITY, 0)
	add_effect(blessed_gold, PassiveEffectData.EffectType.ADD_STARTING_GOLD, 10)
	nodes.append(blessed_gold)
	
	var divine_insight = create_node("divine_insight", "Božský vhled",
		"Líznutí karty navíc v prvním kole.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.UTILITY, 1)
	add_effect(divine_insight, PassiveEffectData.EffectType.DRAW_CARD_FIRST_TURN, 1)
	nodes.append(divine_insight)
	
	var sacred_wisdom = create_node("sacred_wisdom", "Svatá moudrost",
		"Začni každý souboj s 5 zlatem navíc.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.UTILITY, 2)
	add_effect(sacred_wisdom, PassiveEffectData.EffectType.ADD_STARTING_GOLD, 5)
	nodes.append(sacred_wisdom)
	
	# ===== TIER 2 - Specializace (více uzlů, větvení) =====
	# Defense Branch (5 uzlů)
	var fortress = create_node("fortress", "Pevnost",
		"Začni každý souboj s 8 body bloku.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 0, PassiveSkillNode.NodeType.NOTABLE)
	add_effect(fortress, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 8)
	nodes.append(fortress)
	
	var iron_will = create_node("iron_will", "Železná vůle",
		"Zvýší maximální zdraví o 10.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 1)
	add_effect(iron_will, PassiveEffectData.EffectType.ADD_MAX_HP, 10)
	nodes.append(iron_will)
	
	var unbreakable = create_node("unbreakable", "Nezlomný",
		"Zvýší maximální zdraví o 12.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 2)
	add_effect(unbreakable, PassiveEffectData.EffectType.ADD_MAX_HP, 12)
	nodes.append(unbreakable)
	
	var shield_mastery = create_node("shield_mastery", "Mistrovství se štítem",
		"Začni každý souboj s 5 body bloku navíc.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 3)
	add_effect(shield_mastery, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 5)
	nodes.append(shield_mastery)
	
	var guardian_spirit = create_node("guardian_spirit", "Ochranný duch",
		"Začni každý souboj s 4 body bloku navíc.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 4)
	add_effect(guardian_spirit, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 4)
	nodes.append(guardian_spirit)
	
	# Offense Branch (5 uzlů)
	var divine_wrath = create_node("divine_wrath", "Božský hněv",
		"Všechny karty způsobí o 2 poškození navíc.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.OFFENSE, 0, PassiveSkillNode.NodeType.NOTABLE)
	add_effect(divine_wrath, PassiveEffectData.EffectType.ADD_CARD_DAMAGE, 2)
	nodes.append(divine_wrath)
	
	var holy_strike = create_node("holy_strike", "Svatý úder",
		"Začni každý souboj s 2 extra energií.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.OFFENSE, 1)
	add_effect(holy_strike, PassiveEffectData.EffectType.ADD_MAX_ENERGY, 2)
	nodes.append(holy_strike)
	
	var smiting_power = create_node("smiting_power", "Síla trestu",
		"Všechny karty způsobí o 2 poškození navíc.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.OFFENSE, 2)
	add_effect(smiting_power, PassiveEffectData.EffectType.ADD_CARD_DAMAGE, 2)
	nodes.append(smiting_power)
	
	var consecrated_blade = create_node("consecrated_blade", "Požehnaná čepel",
		"Začni každý souboj s 1 extra energií.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.OFFENSE, 3)
	add_effect(consecrated_blade, PassiveEffectData.EffectType.ADD_MAX_ENERGY, 1)
	nodes.append(consecrated_blade)
	
	var wrathful_strike = create_node("wrathful_strike", "Hněvivý úder",
		"Všechny karty způsobí o 1 poškození navíc.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.OFFENSE, 4)
	add_effect(wrathful_strike, PassiveEffectData.EffectType.ADD_CARD_DAMAGE, 1)
	nodes.append(wrathful_strike)
	
	# Utility Branch (4 uzly)
	var divine_favor = create_node("divine_favor", "Božská přízeň",
		"Líznutí karty navíc v prvním kole.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.UTILITY, 0, PassiveSkillNode.NodeType.NOTABLE)
	add_effect(divine_favor, PassiveEffectData.EffectType.DRAW_CARD_FIRST_TURN, 1)
	nodes.append(divine_favor)
	
	var golden_touch = create_node("golden_touch", "Zlatý dotek",
		"Začni každý souboj s 15 zlatem navíc.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.UTILITY, 1)
	add_effect(golden_touch, PassiveEffectData.EffectType.ADD_STARTING_GOLD, 15)
	nodes.append(golden_touch)
	
	var blessed_hand = create_node("blessed_hand", "Požehnaná ruka",
		"Líznutí karty navíc v prvním kole.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.UTILITY, 2)
	add_effect(blessed_hand, PassiveEffectData.EffectType.DRAW_CARD_FIRST_TURN, 1)
	nodes.append(blessed_hand)
	
	var divine_prosperity = create_node("divine_prosperity", "Božský blahobyt",
		"Začni každý souboj s 12 zlatem navíc.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.UTILITY, 3)
	add_effect(divine_prosperity, PassiveEffectData.EffectType.ADD_STARTING_GOLD, 12)
	nodes.append(divine_prosperity)
	
	# ===== TIER 3 - Pokročilé schopnosti (více keystones) =====
	# Defense Branch (3 uzly)
	var divine_protection = create_node("divine_protection", "Božská ochrana",
		"Začni každý souboj s 15 body bloku.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.DEFENSE, 0, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(divine_protection, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 15)
	nodes.append(divine_protection)
	
	var sacred_thorns = create_node("sacred_thorns", "Svaté trny",
		"Začni každý souboj s 10 body bloku. Nepřátelé, kteří tě zasáhnou, utrpí 2 poškození.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.DEFENSE, 1, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(sacred_thorns, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 10)
	nodes.append(sacred_thorns)
	
	var immovable_fortress = create_node("immovable_fortress", "Nepohnutelná pevnost",
		"Zvýší maximální zdraví o 20. Začni každý souboj s 5 body bloku.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.DEFENSE, 2, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(immovable_fortress, PassiveEffectData.EffectType.ADD_MAX_HP, 20)
	add_effect(immovable_fortress, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 5)
	nodes.append(immovable_fortress)
	
	# Offense Branch (3 uzly)
	var righteous_fury = create_node("righteous_fury", "Spravedlivá zuřivost",
		"Všechny karty způsobí o 3 poškození navíc.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.OFFENSE, 0, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(righteous_fury, PassiveEffectData.EffectType.ADD_CARD_DAMAGE, 3)
	nodes.append(righteous_fury)
	
	var divine_retribution = create_node("divine_retribution", "Božská odplata",
		"Všechny karty způsobí o 4 poškození navíc. Začni každý souboj s 1 extra energií.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.OFFENSE, 1, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(divine_retribution, PassiveEffectData.EffectType.ADD_CARD_DAMAGE, 4)
	add_effect(divine_retribution, PassiveEffectData.EffectType.ADD_MAX_ENERGY, 1)
	nodes.append(divine_retribution)
	
	var holy_avenger = create_node("holy_avenger", "Svatý mstitel",
		"Všechny karty způsobí o 3 poškození navíc. Začni každý souboj s 2 extra energií.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.OFFENSE, 2, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(holy_avenger, PassiveEffectData.EffectType.ADD_CARD_DAMAGE, 3)
	add_effect(holy_avenger, PassiveEffectData.EffectType.ADD_MAX_ENERGY, 2)
	nodes.append(holy_avenger)
	
	# Utility Branch (2 uzly)
	var blessed_recovery = create_node("blessed_recovery", "Požehnané uzdravení",
		"Začni každý souboj s 20 zlatem navíc.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.UTILITY, 0, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(blessed_recovery, PassiveEffectData.EffectType.ADD_STARTING_GOLD, 20)
	nodes.append(blessed_recovery)
	
	var divine_wealth = create_node("divine_wealth", "Božské bohatství",
		"Začni každý souboj s 25 zlatem navíc. Líznutí karty navíc v prvním kole.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.UTILITY, 1, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(divine_wealth, PassiveEffectData.EffectType.ADD_STARTING_GOLD, 25)
	add_effect(divine_wealth, PassiveEffectData.EffectType.DRAW_CARD_FIRST_TURN, 1)
	nodes.append(divine_wealth)
	
	# ===== TIER 4 - Mistrovství =====
	var aura_mastery = create_node("aura_mastery", "Mistrovství aur",
		"Všechny aury jsou o 50% silnější.",
		PassiveSkillNode.SkillTier.TIER_4, Branch.MAIN, 0, PassiveSkillNode.NodeType.MASTERY)
	add_effect(aura_mastery, PassiveEffectData.EffectType.AURA_ENHANCEMENT, 50)
	nodes.append(aura_mastery)
	
	# ===== TIER 5 - Ultimátní schopnost =====
	var avatar_of_light = create_node("avatar_of_light", "Avatár světla",
		"Na začátku souboje získej blok rovný 2x tvému maximálnímu zdraví. Vyžaduje všechny ostatní uzly odemčené.",
		PassiveSkillNode.SkillTier.TIER_5, Branch.MAIN, 0, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(avatar_of_light, PassiveEffectData.EffectType.AVATAR_STARTING_BLOCK, 2)
	# Speciální podmínka - musí mít všechny ostatní uzly odemčené
	avatar_of_light.unlock_conditions.clear()
	avatar_of_light.unlock_conditions.append("all_nodes_unlocked")
	nodes.append(avatar_of_light)
	
	# ===== PROPOJENÍ - ČISTÁ LINEÁRNÍ STRUKTURA =====
	setup_connections_clean(nodes)
	
	# ===== POZICOVÁNÍ - NOVÝ ČISTÝ LAYOUT =====
	auto_position_nodes_clean(nodes)
	
	tree.skill_nodes = nodes
	tree.rebuild()  # ✅ OPRAVENO: Rebuild lookup dictionary po generování
	print("✅ Čistý Paladin skill tree vytvořen: %d uzlů" % nodes.size())
	return tree

static func setup_connections_clean(nodes: Array[PassiveSkillNode]):
	"""Nastaví propojení pro rozšířený strom s více větvením"""
	var node_map = {}
	for node in nodes:
		node_map[node.id] = node
	
	var starter = node_map.get("paladin_start")
	if not starter:
		return
	
	# Starter → 3 hlavní větve (Tier 1)
	starter.connected_nodes = ["paladin_block_1", "righteous_anger", "blessed_gold"]
	
	# ===== DEFENSE BRANCH =====
	# Tier 1 → Tier 2
	if node_map.has("paladin_block_1"):
		node_map["paladin_block_1"].connected_nodes = ["paladin_hp_1", "iron_skin", "fortress"]
	if node_map.has("paladin_hp_1"):
		node_map["paladin_hp_1"].connected_nodes = ["iron_skin", "defensive_stance", "fortress"]
	if node_map.has("iron_skin"):
		node_map["iron_skin"].connected_nodes = ["defensive_stance", "fortress"]
	if node_map.has("defensive_stance"):
		node_map["defensive_stance"].connected_nodes = ["fortress"]
	
	# Tier 2 → Tier 3
	if node_map.has("fortress"):
		node_map["fortress"].connected_nodes = ["iron_will", "unbreakable", "divine_protection"]
	if node_map.has("iron_will"):
		node_map["iron_will"].connected_nodes = ["unbreakable", "shield_mastery", "divine_protection"]
	if node_map.has("unbreakable"):
		node_map["unbreakable"].connected_nodes = ["shield_mastery", "guardian_spirit", "divine_protection"]
	if node_map.has("shield_mastery"):
		node_map["shield_mastery"].connected_nodes = ["guardian_spirit", "divine_protection"]
	if node_map.has("guardian_spirit"):
		node_map["guardian_spirit"].connected_nodes = ["divine_protection"]
	
	# Tier 3 → Tier 4
	if node_map.has("divine_protection"):
		node_map["divine_protection"].connected_nodes = ["sacred_thorns", "immovable_fortress", "aura_mastery"]
	if node_map.has("sacred_thorns"):
		node_map["sacred_thorns"].connected_nodes = ["immovable_fortress", "aura_mastery"]
	if node_map.has("immovable_fortress"):
		node_map["immovable_fortress"].connected_nodes = ["aura_mastery"]
	
	# ===== OFFENSE BRANCH =====
	# Tier 1 → Tier 2
	if node_map.has("righteous_anger"):
		node_map["righteous_anger"].connected_nodes = ["swift_justice", "holy_power", "divine_wrath"]
	if node_map.has("swift_justice"):
		node_map["swift_justice"].connected_nodes = ["holy_power", "battle_fervor", "divine_wrath"]
	if node_map.has("holy_power"):
		node_map["holy_power"].connected_nodes = ["battle_fervor", "divine_wrath"]
	if node_map.has("battle_fervor"):
		node_map["battle_fervor"].connected_nodes = ["divine_wrath"]
	
	# Tier 2 → Tier 3
	if node_map.has("divine_wrath"):
		node_map["divine_wrath"].connected_nodes = ["holy_strike", "smiting_power", "righteous_fury"]
	if node_map.has("holy_strike"):
		node_map["holy_strike"].connected_nodes = ["smiting_power", "consecrated_blade", "righteous_fury"]
	if node_map.has("smiting_power"):
		node_map["smiting_power"].connected_nodes = ["consecrated_blade", "wrathful_strike", "righteous_fury"]
	if node_map.has("consecrated_blade"):
		node_map["consecrated_blade"].connected_nodes = ["wrathful_strike", "righteous_fury"]
	if node_map.has("wrathful_strike"):
		node_map["wrathful_strike"].connected_nodes = ["righteous_fury"]
	
	# Tier 3 → Tier 4
	if node_map.has("righteous_fury"):
		node_map["righteous_fury"].connected_nodes = ["divine_retribution", "holy_avenger", "aura_mastery"]
	if node_map.has("divine_retribution"):
		node_map["divine_retribution"].connected_nodes = ["holy_avenger", "aura_mastery"]
	if node_map.has("holy_avenger"):
		node_map["holy_avenger"].connected_nodes = ["aura_mastery"]
	
	# ===== UTILITY BRANCH =====
	# Tier 1 → Tier 2
	if node_map.has("blessed_gold"):
		node_map["blessed_gold"].connected_nodes = ["divine_insight", "sacred_wisdom", "divine_favor"]
	if node_map.has("divine_insight"):
		node_map["divine_insight"].connected_nodes = ["sacred_wisdom", "divine_favor"]
	if node_map.has("sacred_wisdom"):
		node_map["sacred_wisdom"].connected_nodes = ["divine_favor"]
	
	# Tier 2 → Tier 3
	if node_map.has("divine_favor"):
		node_map["divine_favor"].connected_nodes = ["golden_touch", "blessed_hand", "blessed_recovery"]
	if node_map.has("golden_touch"):
		node_map["golden_touch"].connected_nodes = ["blessed_hand", "divine_prosperity", "blessed_recovery"]
	if node_map.has("blessed_hand"):
		node_map["blessed_hand"].connected_nodes = ["divine_prosperity", "blessed_recovery"]
	if node_map.has("divine_prosperity"):
		node_map["divine_prosperity"].connected_nodes = ["blessed_recovery"]
	
	# Tier 3 → Tier 4
	if node_map.has("blessed_recovery"):
		node_map["blessed_recovery"].connected_nodes = ["divine_wealth", "aura_mastery"]
	if node_map.has("divine_wealth"):
		node_map["divine_wealth"].connected_nodes = ["aura_mastery"]
	
	# ===== TIER 4 → TIER 5 =====
	# Všechny větve → Aura Mastery → Avatar
	if node_map.has("aura_mastery"):
		node_map["aura_mastery"].connected_nodes = ["avatar_of_light"]

static func auto_position_nodes_clean(nodes: Array[PassiveSkillNode]):
	"""Nový čistý layout algoritmus - lineární větve s jasnou hierarchií"""
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
	
	# Pozicujeme starter (Tier 0)
	var starter = null
	for node in nodes:
		if node.is_starter:
			starter = node
			break
	
	if starter:
		starter.position = Vector2(CENTER_X, STARTER_Y_OFFSET)
	
	# Pozicujeme každou větev lineárně
	for branch_name in branch_groups.keys():
		if branch_name == "main" and branch_groups[branch_name].size() > 0:
			# Main branch (Aura Mastery, Avatar) - uprostřed
			var branch_data = branch_groups[branch_name]
			var branch_x = CENTER_X
			
			# Seřadíme tiery
			var sorted_tiers = branch_data.keys()
			sorted_tiers.sort()
			
			for tier in sorted_tiers:
				if tier == PassiveSkillNode.SkillTier.values()[0]:  # Skip TIER_0
					continue
				var tier_nodes = branch_data[tier]
				var tier_y = get_tier_y_offset_clean(tier)
				
				# Main branch uzly jsou uprostřed
				for node in tier_nodes:
					node.position = Vector2(branch_x, tier_y)
		else:
			# Ostatní větve - lineární layout
			var branch_data = branch_groups[branch_name]
			var branch_x = get_branch_x_offset_clean(branch_name)
			
			# Seřadíme tiery
			var sorted_tiers = branch_data.keys()
			sorted_tiers.sort()
			
			for tier in sorted_tiers:
				if tier == PassiveSkillNode.SkillTier.values()[0]:  # Skip TIER_0
					continue
				var tier_nodes = branch_data[tier]
				var tier_y = get_tier_y_offset_clean(tier)
				
				# Pro každý tier v branchi - lineární vertikální layout
				# Uzly jsou pod sebou, ne vedle sebe
				for i in range(tier_nodes.size()):
					var node = tier_nodes[i]
					# Horizontální offset pro více uzlů ve stejném tieru
					# Používá NODE_OFFSET_IN_TIER konstantu - můžeš změnit výše
					var x_offset = (i - (tier_nodes.size() - 1) * 0.5) * NODE_OFFSET_IN_TIER
					node.position = Vector2(branch_x + x_offset, tier_y)

static func get_branch_x_offset_clean(branch_name: String) -> float:
	"""Vrátí X pozici pro branch v novém čistém layoutu"""
	match branch_name:
		"defense": return CENTER_X - BRANCH_SPACING_X
		"offense": return CENTER_X + BRANCH_SPACING_X
		"utility": return CENTER_X
		"main": return CENTER_X
		_: return CENTER_X

static func get_tier_y_offset_clean(tier: PassiveSkillNode.SkillTier) -> float:
	"""Vrátí Y pozici pro tier v novém čistém layoutu"""
	# Tier 0 (starter) je na STARTER_Y_OFFSET
	if tier == PassiveSkillNode.SkillTier.values()[0]:  # TIER_0
		return STARTER_Y_OFFSET
	# Ostatní tiery začínají od 0
	return (tier - 1) * TIER_SPACING_Y

# --- ZPĚTNÁ KOMPATIBILITA - funkce pro PassiveSkillTree.gd ---

static func get_tier_y_offset(tier: PassiveSkillNode.SkillTier) -> float:
	"""ZPĚTNÁ KOMPATIBILITA - pro PassiveSkillTree.gd"""
	return get_tier_y_offset_clean(tier)

static func get_branch_x_offset(branch_name: String) -> float:
	"""ZPĚTNÁ KOMPATIBILITA - pro PassiveSkillTree.gd"""
	return get_branch_x_offset_clean(branch_name)

# --- POMOCNÉ FUNKCE ---

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

static func add_effect(node: PassiveSkillNode, effect_type: PassiveEffectData.EffectType, value: int, string_val: String = ""):
	var effect = PassiveEffectData.new()
	effect.effect_type = effect_type
	effect.value = value
	if string_val != "":
		effect.string_value = string_val
	node.effects.append(effect)

# --- KONFIGURAČNÍ SYSTÉM (pro testování) ---

static func create_paladin_config() -> SkillTreeConfig:
	"""Vytvoří konfiguraci pro Paladina - pro testování konfiguračního systému"""
	var config = SkillTreeConfig.new()
	config.tree_id = "paladin_tree"
	config.subclass_id = "paladin"
	config.tree_name = "Paladin Skill Tree"
	
	# Starter node
	config.starter_node_id = "paladin_start"
	config.starter_node_name = "Svatý Závazek"
	config.starter_node_description = "Startovní bod Paladina. Zvýší maximální zdraví o 5."
	config.starter_node_effects = [
		{"type": "ADD_MAX_HP", "value": 5}
	]
	
	# Tier 1 Nodes
	config.tier_1_nodes = [
		{
			"id": "paladin_block_1",
			"name": "Výcvik se štítem",
			"description": "Začni každý souboj s 3 body bloku.",
			"node_type": "BASIC",
			"branch": "defense",
			"branch_position": 0,
			"effects": [
				{"type": "ADD_RETAINED_BLOCK", "value": 3}
			]
		},
		{
			"id": "paladin_hp_1",
			"name": "Vitalita",
			"description": "Zvýší maximální zdraví o 8.",
			"node_type": "BASIC",
			"branch": "defense",
			"branch_position": 1,
			"effects": [
				{"type": "ADD_MAX_HP", "value": 8}
			]
		},
		{
			"id": "righteous_anger",
			"name": "Spravedlivý hněv",
			"description": "Všechny karty způsobí o 1 poškození navíc.",
			"node_type": "BASIC",
			"branch": "offense",
			"branch_position": 0,
			"effects": [
				{"type": "ADD_CARD_DAMAGE", "value": 1}
			]
		},
		{
			"id": "swift_justice",
			"name": "Rychlá spravedlnost",
			"description": "Začni každý souboj s 1 extra energií.",
			"node_type": "BASIC",
			"branch": "offense",
			"branch_position": 1,
			"effects": [
				{"type": "ADD_MAX_ENERGY", "value": 1}
			]
		}
	]
	
	# Tier 2 Nodes
	config.tier_2_nodes = [
		{
			"id": "fortress",
			"name": "Pevnost",
			"description": "Začni každý souboj s 8 body bloku.",
			"node_type": "NOTABLE",
			"branch": "defense",
			"branch_position": 0,
			"effects": [
				{"type": "ADD_RETAINED_BLOCK", "value": 8}
			]
		},
		{
			"id": "divine_wrath",
			"name": "Božský hněv",
			"description": "Všechny karty způsobí o 2 poškození navíc.",
			"node_type": "NOTABLE",
			"branch": "offense",
			"branch_position": 0,
			"effects": [
				{"type": "ADD_CARD_DAMAGE", "value": 2}
			]
		}
	]
	
	# Tier 3 Nodes
	config.tier_3_nodes = [
		{
			"id": "divine_protection",
			"name": "Božská ochrana",
			"description": "Začni každý souboj s 15 body bloku.",
			"node_type": "KEYSTONE",
			"branch": "defense",
			"branch_position": 0,
			"effects": [
				{"type": "ADD_RETAINED_BLOCK", "value": 15}
			]
		},
		{
			"id": "righteous_fury",
			"name": "Spravedlivá zuřivost",
			"description": "Všechny karty způsobí o 3 poškození navíc.",
			"node_type": "KEYSTONE",
			"branch": "offense",
			"branch_position": 0,
			"effects": [
				{"type": "ADD_CARD_DAMAGE", "value": 3}
			]
		}
	]
	
	# Tier 4 Nodes
	config.tier_4_nodes = [
		{
			"id": "aura_mastery",
			"name": "Mistrovství aur",
			"description": "Všechny aury jsou o 50% silnější.",
			"node_type": "MASTERY",
			"branch": "main",
			"branch_position": 0,
			"effects": [
				{"type": "AURA_ENHANCEMENT", "value": 50}
			]
		}
	]
	
	# Tier 5 Nodes
	config.tier_5_nodes = [
		{
			"id": "avatar_of_light",
			"name": "Avatár světla",
			"description": "Na začátku souboje získej blok rovný 2x tvému maximálnímu zdraví.",
			"node_type": "KEYSTONE",
			"branch": "main",
			"branch_position": 0,
			"effects": [
				{"type": "AVATAR_STARTING_BLOCK", "value": 2}
			]
		}
	]
	
	# Propojení
	config.connections = [
		{"from": "paladin_start", "to": "paladin_hp_1"},
		{"from": "paladin_start", "to": "righteous_anger"},
		{"from": "paladin_hp_1", "to": "paladin_block_1"},
		{"from": "paladin_hp_1", "to": "fortress"},
		{"from": "paladin_block_1", "to": "fortress"},
		{"from": "fortress", "to": "divine_protection"},
		{"from": "righteous_anger", "to": "swift_justice"},
		{"from": "righteous_anger", "to": "divine_wrath"},
		{"from": "swift_justice", "to": "divine_wrath"},
		{"from": "divine_wrath", "to": "righteous_fury"},
		{"from": "divine_protection", "to": "aura_mastery"},
		{"from": "righteous_fury", "to": "aura_mastery"},
		{"from": "aura_mastery", "to": "avatar_of_light"}
	]
	
	return config

static func generate_tree_from_config(config: SkillTreeConfig) -> PassiveSkillTreeData:
	"""Generuje skill tree z konfigurace - pro testování"""
	if not config.validate():
		printerr("SkillTreeGenerator: Neplatná konfigurace!")
		return null
	
	var tree = PassiveSkillTreeData.new()
	var nodes: Array[PassiveSkillNode] = []
	var node_map = {}
	
	# Starter node
	var starter = create_node_from_dict({
		"id": config.starter_node_id,
		"name": config.starter_node_name,
		"description": config.starter_node_description,
		"node_type": "STARTER",
		"branch": "main",
		"branch_position": 0,
		"tier": 0,
		"cost": 0,
		"effects": config.starter_node_effects,
		"is_starter": true
	})
	nodes.append(starter)
	node_map[starter.id] = starter
	
	# Tier nodes
	var tier_configs = [
		{"tier": 1, "nodes": config.tier_1_nodes},
		{"tier": 2, "nodes": config.tier_2_nodes},
		{"tier": 3, "nodes": config.tier_3_nodes},
		{"tier": 4, "nodes": config.tier_4_nodes},
		{"tier": 5, "nodes": config.tier_5_nodes}
	]
	
	for tier_config in tier_configs:
		for node_dict in tier_config.nodes:
			var node = create_node_from_dict(node_dict, tier_config.tier)
			if node:
				nodes.append(node)
				node_map[node.id] = node
	
	# Propojení
	setup_connections_from_config(nodes, config.connections, node_map)
	
	# Pozicování
	auto_position_nodes_clean(nodes)
	
	tree.skill_nodes = nodes
	return tree

static func create_node_from_dict(node_dict: Dictionary, tier: int = 1) -> PassiveSkillNode:
	"""Vytvoří PassiveSkillNode z dictionary"""
	if not node_dict.has("id") or node_dict["id"] == "":
		printerr("SkillTreeGenerator: Uzel bez ID!")
		return null
	
	var node = PassiveSkillNode.new()
	node.id = StringName(node_dict["id"])
	node.skill_name = node_dict.get("name", "Nová dovednost")
	node.description = node_dict.get("description", "")
	
	# Tier
	var node_tier = node_dict.get("tier", tier)
	match node_tier:
		0: node.tier = PassiveSkillNode.SkillTier.values()[0]  # TIER_0
		1: node.tier = PassiveSkillNode.SkillTier.TIER_1
		2: node.tier = PassiveSkillNode.SkillTier.TIER_2
		3: node.tier = PassiveSkillNode.SkillTier.TIER_3
		4: node.tier = PassiveSkillNode.SkillTier.TIER_4
		5: node.tier = PassiveSkillNode.SkillTier.TIER_5
		_: node.tier = PassiveSkillNode.SkillTier.TIER_1
	
	# Node type
	var node_type_str = node_dict.get("node_type", "BASIC").to_upper()
	match node_type_str:
		"BASIC": node.node_type = PassiveSkillNode.NodeType.BASIC
		"NOTABLE": node.node_type = PassiveSkillNode.NodeType.NOTABLE
		"KEYSTONE": node.node_type = PassiveSkillNode.NodeType.KEYSTONE
		"MASTERY": node.node_type = PassiveSkillNode.NodeType.MASTERY
		"STARTER": node.node_type = PassiveSkillNode.NodeType.STARTER
		_: node.node_type = PassiveSkillNode.NodeType.BASIC
	
	# Branch
	node.branch = node_dict.get("branch", "main")
	node.branch_position = node_dict.get("branch_position", 0)
	
	# Starter
	if node_dict.get("is_starter", false):
		node.is_starter = true
	
	# Cost
	node.cost = node_dict.get("cost", node.get_cost_for_tier())
	
	# Efekty
	if node_dict.has("effects"):
		for effect_dict in node_dict["effects"]:
			var effect = create_effect_from_dict(effect_dict)
			if effect:
				node.effects.append(effect)
	
	return node

static func create_effect_from_dict(effect_dict: Dictionary) -> PassiveEffectData:
	"""Vytvoří PassiveEffectData z dictionary"""
	var effect = PassiveEffectData.new()
	
	var effect_type_str = effect_dict.get("type", "").to_upper()
	var effect_type = get_effect_type_from_string(effect_type_str)
	if effect_type == -1:
		printerr("SkillTreeGenerator: Neznámý typ efektu: %s" % effect_type_str)
		return null
	
	effect.effect_type = effect_type
	effect.value = effect_dict.get("value", 0)
	effect.string_value = effect_dict.get("string_value", "")
	effect.secondary_value = effect_dict.get("secondary_value", 0)
	
	return effect

static func get_effect_type_from_string(type_str: String) -> int:
	"""Převede string na PassiveEffectData.EffectType enum"""
	for i in range(PassiveEffectData.EffectType.size()):
		var enum_name = PassiveEffectData.EffectType.keys()[i]
		if enum_name == type_str:
			return i
	return -1

static func setup_connections_from_config(_nodes: Array[PassiveSkillNode], connections: Array[Dictionary], node_map: Dictionary):
	"""Nastaví propojení mezi uzly z konfigurace"""
	for conn in connections:
		var from_id = conn.get("from", "")
		var to_id = conn.get("to", "")
		
		if from_id == "" or to_id == "":
			continue
		
		var from_node = node_map.get(from_id)
		var to_node = node_map.get(to_id)
		
		if not from_node or not to_node:
			printerr("SkillTreeGenerator: Propojení z/do neexistujícího uzlu: %s -> %s" % [from_id, to_id])
			continue
		
		if not from_node.connected_nodes.has(to_id):
			from_node.connected_nodes.append(to_id)

# --- ZPĚTNÁ KOMPATIBILITA (staré funkce pro referenci) ---

static func generate_paladin_tree_old() -> PassiveSkillTreeData:
	"""Stará verze - zachována pro referenci"""
	return generate_paladin_tree()
