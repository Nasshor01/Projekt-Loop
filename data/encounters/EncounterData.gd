# Soubor: res://data/encounters/EncounterData.gd (OPRAVENÁ VERZE)
class_name EncounterData
extends Resource

# PŘIDÁNO: Definice typů soubojů
enum EncounterType {
	NORMAL,
	ELITE,
	BOSS
}

# PŘIDÁNO: Exportovaná proměnná pro nastavení typu v editoru
@export var encounter_type: EncounterType = EncounterType.NORMAL
@export var xp_reward: int = 10

# Pole jednotlivých nepřátel v tomto souboji
@export var enemies: Array[EncounterEntry] = []
