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
	TIER_0 = 0,    # Starter node (na samém začátku)
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
@export var connected_nodes: PackedStringArray = []  # POUZE VIZUÁLNÍ - pro kreslení linek
@export var prerequisite_nodes: PackedStringArray = []  # POUZE LOGIKA - pro odemykání
@export var max_allocations: int = 1  # Kolikrát lze skill vzít (pro stackovatelné efekty)

# Efekty a vlastnosti
@export var effects: Array[PassiveEffectData] = []
@export var is_starter: bool = false

# POZNÁMKA: Runtime stav (is_unlocked, allocation_count) byl odstraněn!
# Používej SaveManager.meta_progress.allocated_skills místo toho

# NOVÉ: Pozičnímu automaticky podle tieru a branže
@export var branch: String = "main"  # "defense", "offense", "utility", "main"
@export var branch_position: int = 0  # Pozice v rámci branže

# NOVÉ: Podmínky pro odemčení
@export var unlock_conditions: Array[String] = []  # ["level_10", "complete_boss_fight", atd.]

# NOVÉ: Vizuální vlastnosti pro různé typy
func get_node_size() -> float:
	match node_type:
		NodeType.BASIC: return 36.0  # Zvýšeno z 32
		NodeType.NOTABLE: return 56.0  # Zvýšeno z 48
		NodeType.KEYSTONE: return 80.0  # Zvýšeno z 64
		NodeType.MASTERY: return 64.0  # Zvýšeno z 56
		NodeType.STARTER: return 50.0  # Zvýšeno z 40
		_: return 36.0

func get_node_color() -> Color:
	# POZNÁMKA: is_unlocked byl odstraněn - použij SaveManager pro kontrolu
	# Tato funkce vrací základní barvu podle typu uzlu
	# Skutečný stav (odemčeno/zamčeno) se řeší v UI
	
	# Barvy podle větve a typu uzlu
	var branch_color = get_branch_color()
	
	match node_type:
		NodeType.BASIC: return branch_color.lerp(Color.WHITE, 0.3)  # Světlejší podle větve
		NodeType.NOTABLE: return Color.GOLD
		NodeType.KEYSTONE: return Color(1.0, 0.2, 0.2)  # Jasně červená
		NodeType.MASTERY: return Color(0.2, 0.8, 1.0)  # Jasně cyan
		NodeType.STARTER: return Color(0.4, 1.0, 0.4)  # Jasně zelená
		_: return branch_color

func get_branch_color() -> Color:
	"""Vrátí barvu podle větve"""
	match branch.to_lower():
		"defense": return Color(0.3, 0.5, 0.9)  # Modrá
		"offense": return Color(0.9, 0.3, 0.3)  # Červená
		"utility": return Color(0.5, 0.9, 0.5)  # Zelená
		"main": return Color(0.9, 0.8, 0.3)  # Zlatá
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

# POZNÁMKA: can_allocate() byl odstraněn - použij SaveManager pro kontrolu
# Příklad: SaveManager.meta_progress.allocated_skills.get(String(id), 0) < max_allocations

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
		# POZNÁMKA: allocation_count byl odstraněn - použij SaveManager
		# Příklad: var count = SaveManager.meta_progress.allocated_skills.get(String(id), 0)
		desc += "\n[color=gray]Stackovatelné (max %d)[/color]" % max_allocations
	
	return desc
