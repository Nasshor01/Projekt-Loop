# Soubor: res://data/skills/PassiveSkillNode.gd (ENHANCED VERSION)
@tool 
class_name PassiveSkillNode
extends Resource

# Základní identifikace
@export var id: StringName = &""
@export var skill_name: String = "Nová dovednost"
@export_multiline var description: String = "Popis dovednosti."

# Vizuální vlastnosti
@export var icon: Texture2D
@export var position: Vector2 = Vector2.ZERO

# NOVÉ: Tier systém jako v Path of Exile
enum SkillTier {
	TIER_1 = 1,    # Základní vylepšení
	TIER_2 = 2,    # Specializované vylepšení  
	TIER_3 = 3,    # Pokročilé schopnosti
	TIER_4 = 4,    # Mocné efekty
	TIER_5 = 5     # Ultimátní schopnosti
}

@export var tier: SkillTier = SkillTier.TIER_1

# NOVÉ: Typ uzlu pro vizuální rozlišení
enum NodeType {
	BASIC,         # Běžný uzel (malý kroužek)
	NOTABLE,       # Významný uzel (větší kroužek)  
	KEYSTONE,      # Klíčový uzel (osmiúhelník)
	MASTERY,       # Mistrovství (hvězda)
	STARTER        # Startovací uzel (speciální tvar)
}

@export var node_type: NodeType = NodeType.BASIC

# Náklady a propojení
@export var cost: int = 1
@export var connected_nodes: PackedStringArray = []
@export var prerequisite_nodes: PackedStringArray = []  # NOVÉ: Explicitní prerekvizity

# Efekty a vlastnosti
@export var effects: Array[PassiveEffectData] = []
@export var is_starter: bool = false
@export var max_allocations: int = 1  # NOVÉ: Kolikrát lze skill vzít (pro stackovatelné efekty)

# Runtime stav
var is_unlocked: bool = false
var allocation_count: int = 0

# NOVÉ: Pozičnímu automaticky podle tieru a branže
@export var branch: String = "main"  # "defense", "offense", "utility", "main"
@export var branch_position: int = 0  # Pozice v rámci branže

# NOVÉ: Podmínky pro odemčení
@export var unlock_conditions: Array[String] = []  # ["level_10", "complete_boss_fight", atd.]

# NOVÉ: Vizuální vlastnosti pro různé typy
func get_node_size() -> float:
	match node_type:
		NodeType.BASIC: return 32.0
		NodeType.NOTABLE: return 48.0
		NodeType.KEYSTONE: return 64.0
		NodeType.MASTERY: return 56.0
		NodeType.STARTER: return 40.0
		_: return 32.0

func get_node_color() -> Color:
	if not is_unlocked:
		return Color(0.3, 0.3, 0.3)  # Tmavě šedá pro zamčené
	
	match node_type:
		NodeType.BASIC: return Color.WHITE
		NodeType.NOTABLE: return Color.GOLD
		NodeType.KEYSTONE: return Color.CRIMSON
		NodeType.MASTERY: return Color.CYAN
		NodeType.STARTER: return Color.LIGHT_GREEN
		_: return Color.WHITE

func get_cost_for_tier() -> int:
	if cost > 0:
		return cost
	# Automatický výpočet nákladů podle tieru
	match tier:
		SkillTier.TIER_1: return 1
		SkillTier.TIER_2: return 2
		SkillTier.TIER_3: return 3
		SkillTier.TIER_4: return 4
		SkillTier.TIER_5: return 5
		_: return 1

func can_allocate() -> bool:
	return allocation_count < max_allocations

func get_formatted_description() -> String:
	var desc = description
	
	# Přidáme informace o tieru
	desc += "\n\n[color=yellow]Tier %d[/color]" % tier
	
	# Přidáme typ uzlu
	match node_type:
		NodeType.NOTABLE: desc += " [color=gold]• Notable[/color]"
		NodeType.KEYSTONE: desc += " [color=red]• Keystone[/color]"
		NodeType.MASTERY: desc += " [color=cyan]• Mastery[/color]"
	
	# Přidáme stackování pokud je možné
	if max_allocations > 1:
		desc += "\n[color=gray]Stackovatelné (%d/%d)[/color]" % [allocation_count, max_allocations]
	
	return desc
