# Soubor: res://data/units/UnitData.gd
class_name UnitData
extends Resource

enum Faction {
	PLAYER,
	ENEMY,
	NEUTRAL
}

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

static func get_damage_effectiveness(damage_type: int, target_type: UnitType) -> float:
	"""Vrátí multiplikátor efektivity poškození (1.0 = normální, >1.0 = efektivní, <1.0 = neefektivní)"""
	# Mapování typů poškození (z CardEffectData.DamageType)
	# HOLY = 1
	var is_holy = damage_type == 1  # CardEffectData.DamageType.HOLY
	
	if is_holy:
		match target_type:
			UnitType.UNDEAD:
				return 1.5  # +50% poškození proti nemrtvým
			UnitType.DEMON:
				return 1.5  # +50% poškození proti démonům
			UnitType.SPIRIT:
				return 1.25  # +25% poškození proti duchům
			_:
				return 1.0  # Normální poškození
	
	return 1.0  # Normální poškození
