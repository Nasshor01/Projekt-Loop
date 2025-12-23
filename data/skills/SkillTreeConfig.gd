# Soubor: res://data/skills/SkillTreeConfig.gd
# Konfigurační systém pro skill tree - umožňuje definovat skill tree pomocí dat
@tool
class_name SkillTreeConfig
extends Resource

## Identifikace skill tree
@export var tree_id: String = ""
@export var subclass_id: String = ""
@export var tree_name: String = "Skill Tree"

## Starter node - startovní uzel stromu
@export_group("Starter Node")
@export var starter_node_id: String = ""
@export var starter_node_name: String = "Start"
@export_multiline var starter_node_description: String = ""

# Runtime proměnné (nepoužívají @export, protože Godot nepodporuje Array[Dictionary])
# Tyto se nastaví programově pomocí create_paladin_config() nebo podobných funkcí
var starter_node_effects: Array[Dictionary] = []
var tier_1_nodes: Array[Dictionary] = []
var tier_2_nodes: Array[Dictionary] = []
var tier_3_nodes: Array[Dictionary] = []
var tier_4_nodes: Array[Dictionary] = []
var tier_5_nodes: Array[Dictionary] = []
var connections: Array[Dictionary] = []
var clusters: Array[Dictionary] = []

## Vizuální nastavení
@export_group("Visual Settings")
@export var branch_colors: Dictionary = {}  # {"defense": Color.BLUE, "offense": Color.RED, ...}
@export var tree_theme: String = "default"  # Pro různé vizuální styly

# Pomocné funkce pro validaci
func validate() -> bool:
	"""Zkontroluje, jestli je konfigurace validní"""
	if tree_id == "":
		printerr("SkillTreeConfig: tree_id není nastaven!")
		return false
	
	if starter_node_id == "":
		printerr("SkillTreeConfig: starter_node_id není nastaven!")
		return false
	
	# Zkontrolujeme, jestli všechny uzly mají ID
	var all_nodes = tier_1_nodes + tier_2_nodes + tier_3_nodes + tier_4_nodes + tier_5_nodes
	var node_ids = {}
	node_ids[starter_node_id] = true
	
	for node_dict in all_nodes:
		if not node_dict.has("id") or node_dict["id"] == "":
			printerr("SkillTreeConfig: Uzel bez ID nalezen!")
			return false
		
		var node_id = node_dict["id"]
		if node_ids.has(node_id):
			printerr("SkillTreeConfig: Duplicitní ID uzlu: %s" % node_id)
			return false
		node_ids[node_id] = true
	
	# Zkontrolujeme propojení
	for conn in connections:
		if not conn.has("from") or not conn.has("to"):
			printerr("SkillTreeConfig: Neplatné propojení!")
			return false
		
		var from_id = conn["from"]
		var to_id = conn["to"]
		
		if not node_ids.has(from_id) and from_id != starter_node_id:
			printerr("SkillTreeConfig: Propojení z neexistujícího uzlu: %s" % from_id)
			return false
		
		if not node_ids.has(to_id) and to_id != starter_node_id:
			printerr("SkillTreeConfig: Propojení do neexistujícího uzlu: %s" % to_id)
			return false
	
	return true

# Struktura node dictionary:
# {
#     "id": "unique_node_id",
#     "name": "Název uzlu",
#     "description": "Popis uzlu",
#     "node_type": "BASIC",  # BASIC, NOTABLE, KEYSTONE, MASTERY, STARTER
#     "branch": "defense",  # defense, offense, utility, main
#     "branch_position": 0,  # Pozice v rámci branže
#     "cost": 1,  # Volitelné, pokud není, použije se automatický podle tieru
#     "effects": [
#         {
#             "type": "ADD_MAX_HP",  # Název z PassiveEffectData.EffectType
#             "value": 10,
#             "string_value": "",  # Volitelné
#             "secondary_value": 0  # Volitelné
#         }
#     ],
#     "prerequisites": [],  # Volitelné: ["node_id1", "node_id2"]
#     "cluster_id": "",  # Volitelné: ID clusteru, do kterého patří
#     "cluster_position": 0  # Volitelné: Pozice v clusteru (0 = střed)
# }

# Struktura connection dictionary:
# {
#     "from": "node_id",
#     "to": "node_id"
# }

# Struktura cluster dictionary:
# {
#     "center_id": "notable_node_id",
#     "basic_node_ids": ["basic1", "basic2", "basic3", "basic4"],
#     "radius": 100.0  # Vzdálenost od středu
# }
