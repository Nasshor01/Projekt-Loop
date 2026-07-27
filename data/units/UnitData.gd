# Soubor: res://data/units/UnitData.gd
class_name UnitData
extends Resource

enum Faction {
	PLAYER,
	ENEMY,
	NEUTRAL
}

# ENUM INTEGRITY RULE: NEVER insert new elements into the middle of enums in this file.
# New values MUST ALWAYS be added at the end to preserve integer indexes in existing .tres resources.
# Typy jednotek pro systém efektivity poškození
enum UnitType {
	HUMAN,      # Lidské bytosti
	UNDEAD,     # Nemrtví (skeleton, zombie, atd.)
	DEMON,      # Démoni
	BEAST,      # Zvířata
	ELEMENTAL,  # Elementální bytosti
	CONSTRUCT,  # Golemové, mechanické bytosti
	SPIRIT,     # Duchové, přízraky
	DRAGON,     # Draci
	OTHER       # Ostatní/nespecifikované
}

@export var unit_id: String = "unique_unit_id"
@export var unit_name: String = "Název Jednotky"
@export_multiline var description: String = "Popis jednotky."

@export var faction: Faction = Faction.PLAYER

# Typ jednotky pro systém efektivity poškození
@export var unit_type: UnitType = UnitType.OTHER

@export var max_health: int = 10
@export var attack_damage: int = 2
@export var movement_range: int = 3
@export var attack_range: int = 1
@export var initiative: int = 10  # ===== PŘIDÁNO: Iniciativa pro tahový systém =====

@export var sprite_texture: Texture2D
## Vizuální měřítko Sprite3D na boardu (1.0 = výchozí jako Paladin).
@export var sprite_display_scale: float = 1.0
## Vertikální offset Sprite3D v pixelech (výchozí 80). Vyšší = nohy výš nad zemí.
@export var sprite_offset_y: float = 80.0

# ===== PŘIDANÁ PROMĚNNÁ =====
@export var ai_script: Script = null
# ==============================


func _init(p_id: String = "", p_name: String = "Jednotka", p_max_health: int = 10, p_sprite: Texture2D = null):
	unit_id = p_id
	unit_name = p_name
	max_health = p_max_health
	sprite_texture = p_sprite

func get_localized_name() -> String:
	"""Vrátí lokalizovaný název jednotky"""
	return tr(unit_name)

func get_localized_description() -> String:
	"""Vrátí lokalizovaný popis jednotky"""
	return tr(description)

static func get_holy_damage_bonus(damage_type: int, target_type: UnitType) -> int:
	"""Returns additive bonus for Holy damage vs certain unit types (v0.2.0).
	Bonus is ONLY for UNDEAD and DEMON. SPIRIT, ORC, HUMAN, BEAST, etc. get 0."""
	# CardEffectData.DamageType.HOLY = 1
	if damage_type != 1:
		return 0
	# Explicit allowlist: only UNDEAD and DEMON receive holy bonus
	if target_type == UnitType.UNDEAD or target_type == UnitType.DEMON:
		return 5
	return 0
