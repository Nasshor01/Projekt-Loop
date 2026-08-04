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

# --- RADIAL LAYOUT ---
const RADIAL_TIER_RADIUS: Array = [0, 300, 600, 900, 1200]  # index = tier (0=starter, 1-4=tiery)
const RADIAL_CLUSTER_RADIUS: float = 80.0  # poloměr malého kruhu kolem Center uzlu v clusteru
const RADIAL_DEFENSE_ANGLE: float = -90.0   # výseč -120° až -60° (střed)
const RADIAL_UTILITY_ANGLE: float = 0.0     # výseč -30° až 30° (nahoře)
const RADIAL_OFFENSE_ANGLE: float = 90.0    # výseč 60° až 120° (vpravo)
const RADIAL_MAIN_ANGLE: float = 0.0        # main = jako utility

# Definice branchí pro různé archetypy
enum Branch {
	DEFENSE,    # Obranná větev (vlevo)
	OFFENSE,    # Útočná větev (vpravo) 
	UTILITY,    # Utility větev (střed)
	MAIN        # Hlavní cesta (střed)
}

# --- TIERED DESIGN (GDD v0.2.0) ---
# Tier 1: Utility (Gold, Card Draw, Movement) — bez ADD_CARD_DAMAGE a ADD_MAX_ENERGY
# Tier 2: Defense (HP, Block, Heal)
# Tier 3: Synergy (Energy, fixní Holy Damage, Energy on kill, Aura)
# Tier 4: Keystones (Avatar of Light + unikátní mechaniky)
# Hodnoty dle hard-caps (konzervativní pro raný akt).

static func generate_paladin_tree() -> PassiveSkillTreeData:
	"""Paladin skill tree – striktní tiered hierarchie (GDD v0.2.0)."""
	var tree = PassiveSkillTreeData.new()
	var nodes: Array[PassiveSkillNode] = []
	
	# ===== TIER 0 - Starter =====
	var starter = PassiveSkillNode.new()
	starter.id = StringName("paladin_start")
	starter.skill_name = "Svatý Závazek"
	starter.description = "Startovní bod Paladina. Zvýší maximální zdraví o 5."
	starter.tier = PassiveSkillNode.SkillTier.values()[0]
	starter.branch = "main"
	starter.branch_position = 0
	starter.node_type = PassiveSkillNode.NodeType.STARTER
	starter.is_starter = true
	starter.cost = 0
	add_effect(starter, PassiveEffectData.EffectType.ADD_MAX_HP, 5)
	nodes.append(starter)
	
	# ===== TIER 1 - Utility (Gold, Card Draw, Movement) — ŽÁDNÝ ADD_CARD_DAMAGE / ADD_MAX_ENERGY =====
	var blessed_gold = create_node("blessed_gold", "Požehnané zlato",
		"Začni každý souboj s 8 zlatem navíc.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.UTILITY, 0)
	add_effect(blessed_gold, PassiveEffectData.EffectType.ADD_STARTING_GOLD, 8)
	nodes.append(blessed_gold)
	
	var divine_insight = create_node("divine_insight", "Božský vhled",
		"Líznutí 1 karty navíc v prvním kole.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.UTILITY, 1)
	add_effect(divine_insight, PassiveEffectData.EffectType.DRAW_CARD_FIRST_TURN, 1)
	nodes.append(divine_insight)
	
	var sacred_step = create_node("sacred_step", "Svatý krok",
		"+1 pohyb na mapě.",
		PassiveSkillNode.SkillTier.TIER_1, Branch.UTILITY, 2)
	add_effect(sacred_step, PassiveEffectData.EffectType.MOVEMENT_BONUS, 1)
	nodes.append(sacred_step)
	
	# ===== TIER 2 - Defense (HP, Block, Heal) =====
	var vitality = create_node("paladin_hp_1", "Vitalita",
		"Zvýší maximální zdraví o 8.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 0)
	add_effect(vitality, PassiveEffectData.EffectType.ADD_MAX_HP, 8)
	nodes.append(vitality)
	
	var shield_training = create_node("paladin_block_1", "Výcvik se štítem",
		"Začni každý souboj s 3 body bloku.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 1)
	add_effect(shield_training, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 3)
	nodes.append(shield_training)
	
	var iron_skin = create_node("iron_skin", "Železná kůže",
		"Zvýší maximální zdraví o 6.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 2)
	add_effect(iron_skin, PassiveEffectData.EffectType.ADD_MAX_HP, 6)
	nodes.append(iron_skin)
	
	var defensive_stance = create_node("defensive_stance", "Obranný postoj",
		"Začni každý souboj s 2 body bloku navíc.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 3)
	add_effect(defensive_stance, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 2)
	nodes.append(defensive_stance)
	
	var holy_light_heal = create_node("holy_light_heal", "Světlo uzdravení",
		"Na konci každého tahu se vyléč o 1 HP.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 4)
	add_effect(holy_light_heal, PassiveEffectData.EffectType.HEAL_END_OF_TURN, 1)
	nodes.append(holy_light_heal)
	
	var fortress = create_node("fortress", "Pevnost",
		"Začni každý souboj s 8 body bloku.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 5, PassiveSkillNode.NodeType.NOTABLE)
	add_effect(fortress, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 8)
	nodes.append(fortress)
	
	var iron_will = create_node("iron_will", "Železná vůle",
		"Zvýší maximální zdraví o 10.",
		PassiveSkillNode.SkillTier.TIER_2, Branch.DEFENSE, 6)
	add_effect(iron_will, PassiveEffectData.EffectType.ADD_MAX_HP, 10)
	nodes.append(iron_will)
	
	# ===== TIER 3 - Synergy (Energy, fixní Holy Damage, Energy on kill, Aura) =====
	var holy_strike = create_node("holy_strike", "Svatý úder",
		"Začni každý souboj s 1 extra energií.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.OFFENSE, 0)
	add_effect(holy_strike, PassiveEffectData.EffectType.ADD_MAX_ENERGY, 1)
	nodes.append(holy_strike)
	
	var righteous_fury = create_node("righteous_fury", "Spravedlivá zuřivost",
		"Svaté (Holy) poškození z karet způsobí o 3 poškození navíc. Nepůsobí na běžné útoky.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.OFFENSE, 1, PassiveSkillNode.NodeType.NOTABLE)
	add_effect(righteous_fury, PassiveEffectData.EffectType.ADD_HOLY_DAMAGE, 3)
	nodes.append(righteous_fury)
	
	var consecrated_blade = create_node("consecrated_blade", "Požehnaná čepel",
		"Získej 1 energii za každého zabitého nepřítele.",
		PassiveSkillNode.SkillTier.TIER_3, Branch.OFFENSE, 2)
	add_effect(consecrated_blade, PassiveEffectData.EffectType.ENERGY_ON_KILL, 1)
	nodes.append(consecrated_blade)
	
	var aura_synergy = create_node("aura_synergy", "Synergie aur",
		"Aury jsou o 25% silnější (síla, nikoliv dosah).",
		PassiveSkillNode.SkillTier.TIER_3, Branch.UTILITY, 0)
	add_effect(aura_synergy, PassiveEffectData.EffectType.AURA_ENHANCEMENT, 25)
	nodes.append(aura_synergy)
	
	# ===== TIER 4 - Keystones (Avatar of Light + unikátní mechaniky) =====
	var divine_protection = create_node("divine_protection", "Božská ochrana",
		"Začni každý souboj s 12 body bloku.",
		PassiveSkillNode.SkillTier.TIER_4, Branch.DEFENSE, 0, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(divine_protection, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 12)
	nodes.append(divine_protection)
	
	var sacred_thorns = create_node("sacred_thorns", "Svaté trny",
		"Nepřátelé, kteří tě zasáhnou, utrpí 2 poškození.",
		PassiveSkillNode.SkillTier.TIER_4, Branch.DEFENSE, 1, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(sacred_thorns, PassiveEffectData.EffectType.THORNS_DAMAGE, 2)
	nodes.append(sacred_thorns)
	
	var immovable_fortress = create_node("immovable_fortress", "Nepohnutelná pevnost",
		"Zvýší maximální zdraví o 15. Začni každý souboj s 5 body bloku.",
		PassiveSkillNode.SkillTier.TIER_4, Branch.DEFENSE, 2, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(immovable_fortress, PassiveEffectData.EffectType.ADD_MAX_HP, 15)
	add_effect(immovable_fortress, PassiveEffectData.EffectType.ADD_RETAINED_BLOCK, 5)
	nodes.append(immovable_fortress)
	
	var avatar_of_light = create_node("avatar_of_light", "Avatár světla",
		"Na začátku souboje získej blok rovný 2× tvému maximálnímu zdraví. Vyžaduje všechny ostatní uzly odemčené.",
		PassiveSkillNode.SkillTier.TIER_4, Branch.MAIN, 0, PassiveSkillNode.NodeType.KEYSTONE)
	add_effect(avatar_of_light, PassiveEffectData.EffectType.AVATAR_STARTING_BLOCK, 2)
	avatar_of_light.unlock_conditions.clear()
	avatar_of_light.unlock_conditions.append("all_nodes_unlocked")
	nodes.append(avatar_of_light)
	
	setup_connections_paladin_tiered(nodes)
	auto_position_nodes_clean(nodes)
	
	tree.skill_nodes = nodes
	tree.rebuild()
	return tree

static func setup_connections_paladin_tiered(nodes: Array[PassiveSkillNode]):
	"""Propojení dle definice: Tier 0 → T1 → T2 → T3 → T4 → avatar_of_light. Jedna čára = jedno A→B."""
	var node_map = {}
	for node in nodes:
		node_map[node.id] = node
	
	# Tier 0 (Start)
	if node_map.has("paladin_start"):
		node_map["paladin_start"].connected_nodes = ["blessed_gold", "divine_insight", "sacred_step"]
	
	# Tier 1 (Utility) → Tier 2 (Defense)
	if node_map.has("blessed_gold"):
		node_map["blessed_gold"].connected_nodes = ["paladin_hp_1", "paladin_block_1"]
	if node_map.has("divine_insight"):
		node_map["divine_insight"].connected_nodes = ["iron_skin", "defensive_stance", "holy_light_heal"]
	if node_map.has("sacred_step"):
		node_map["sacred_step"].connected_nodes = ["fortress", "iron_will"]
	
	# Tier 2 (Defense) → Tier 3 (Synergy)
	if node_map.has("paladin_hp_1"):
		node_map["paladin_hp_1"].connected_nodes = ["holy_strike", "righteous_fury"]
	if node_map.has("paladin_block_1"):
		node_map["paladin_block_1"].connected_nodes = ["holy_strike", "consecrated_blade"]
	if node_map.has("iron_skin"):
		node_map["iron_skin"].connected_nodes = ["righteous_fury", "consecrated_blade"]
	if node_map.has("defensive_stance"):
		node_map["defensive_stance"].connected_nodes = ["consecrated_blade", "aura_synergy"]
	if node_map.has("holy_light_heal"):
		node_map["holy_light_heal"].connected_nodes = ["holy_strike", "aura_synergy"]
	if node_map.has("fortress"):
		node_map["fortress"].connected_nodes = ["consecrated_blade", "aura_synergy", "righteous_fury"]
	if node_map.has("iron_will"):
		node_map["iron_will"].connected_nodes = ["holy_strike", "aura_synergy"]
	
	# Tier 3 (Synergy) → Tier 4 (Keystones)
	if node_map.has("holy_strike"):
		node_map["holy_strike"].connected_nodes = ["divine_protection", "sacred_thorns"]
	if node_map.has("righteous_fury"):
		node_map["righteous_fury"].connected_nodes = ["sacred_thorns", "immovable_fortress"]
	if node_map.has("consecrated_blade"):
		node_map["consecrated_blade"].connected_nodes = ["immovable_fortress", "sacred_thorns"]
	if node_map.has("aura_synergy"):
		node_map["aura_synergy"].connected_nodes = ["divine_protection", "immovable_fortress"]
	
	# Tier 4 (Keystones) → Finální uzel
	if node_map.has("divine_protection"):
		node_map["divine_protection"].connected_nodes = ["avatar_of_light"]
	if node_map.has("sacred_thorns"):
		node_map["sacred_thorns"].connected_nodes = ["avatar_of_light"]
	if node_map.has("immovable_fortress"):
		node_map["immovable_fortress"].connected_nodes = ["avatar_of_light"]
	# avatar_of_light → (konec cesty, prázdné connected_nodes)
	if node_map.has("avatar_of_light"):
		node_map["avatar_of_light"].connected_nodes = []

static func setup_connections_clean(_nodes: Array[PassiveSkillNode]):
	"""Zastaralé: pro Paladin strom se používá setup_connections_paladin_tiered(). Pro generování z config slouží setup_connections_from_config()."""
	pass

static func auto_position_nodes_clean(nodes: Array[PassiveSkillNode]):
	"""Radial (kruhový) layout: Starter v [0,0], tiery na kružnicích, větve ve výsečích, clustery na malém kruhu."""
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
	
	# Starter (Tier 0) v bodě [0, 0]
	for node in nodes:
		if node.is_starter:
			node.position = Vector2(0, 0)
			break
	
	# Poloměr kružnice pro daný tier (Tier 1–4)
	var tier_radius = func(tier: PassiveSkillNode.SkillTier) -> float:
		var idx = int(tier)
		if idx >= 0 and idx < RADIAL_TIER_RADIUS.size():
			return float(RADIAL_TIER_RADIUS[idx])
		return 300.0
	
	# Střední úhel pro větev (ve stupních; 0° = nahoru)
	var branch_angle = func(branch_name: String) -> float:
		match branch_name.to_lower():
			"defense": return RADIAL_DEFENSE_ANGLE
			"offense": return RADIAL_OFFENSE_ANGLE
			"utility": return RADIAL_UTILITY_ANGLE
			"main": return RADIAL_MAIN_ANGLE
			_: return RADIAL_UTILITY_ANGLE
	
	# Bod na kružnici: úhel ve stupních, 0° = nahoru (záporné Y)
	var point_on_circle = func(radius: float, angle_deg: float) -> Vector2:
		var rad = deg_to_rad(angle_deg)
		return Vector2(radius * sin(rad), -radius * cos(rad))
	
	for branch_name in branch_groups.keys():
		var branch_data = branch_groups[branch_name]
		var sorted_tiers = branch_data.keys()
		sorted_tiers.sort()
		var center_angle = branch_angle.call(branch_name)
		for tier in sorted_tiers:
			if tier == PassiveSkillNode.SkillTier.values()[0]:
				continue
			var tier_nodes = branch_data[tier]
			var r = tier_radius.call(tier)
			var center_pos = point_on_circle.call(r, center_angle)
			if tier_nodes.size() == 1:
				tier_nodes[0].position = center_pos
			else:
				# Cluster: uzly na malém kruhu (poloměr RADIAL_CLUSTER_RADIUS) kolem center_pos
				for i in range(tier_nodes.size()):
					var angle_step = TAU / tier_nodes.size()
					var node_angle_rad = i * angle_step
					var offset = Vector2(RADIAL_CLUSTER_RADIUS * cos(node_angle_rad), -RADIAL_CLUSTER_RADIUS * sin(node_angle_rad))
					tier_nodes[i].position = center_pos + offset

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
