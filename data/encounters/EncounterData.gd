# Soubor: res://data/encounters/EncounterData.gd (OPRAVENÁ VERZE)
class_name EncounterData
extends Resource

# PŘIDÁNO: Definice typů soubojů
enum EncounterType {
	NORMAL,
	ELITE,
	BOSS
}

## Úroveň obtížnosti = do kterého poolu encounter patří (losování v Map.gd).
## FIXED = jen napevno (první souboj, tutoriál), nikdy se nelosuje.
enum Tier {
	EASY,
	HARD_EARLY,
	HARD_LATE,
	ELITE,
	BOSS,
	FIXED
}

# PŘIDÁNO: Exportovaná proměnná pro nastavení typu v editoru
@export var encounter_type: EncounterType = EncounterType.NORMAL
@export var xp_reward: int = 10

# Pole jednotlivých nepřátel v tomto souboji
@export var enemies: Array[EncounterEntry] = []

@export_group("Pool")
## Unikátní ID pro anti-repeat v runu (nezávislé na cestě k souboru).
@export var encounter_id: String = ""
## Překladový klíč názvu („Čelíš: …“ při vstupu do boje).
@export var display_name: String = ""
@export var tier: Tier = Tier.EASY
## Rozsah pater mapy (row), kde se smí losovat.
@export var min_row: int = 0
@export var max_row: int = 99
## Hlavní tag (frakce) — losování preferuje jiný než v minulém souboji.
@export var main_tag: String = ""
## Tagy mechanik (smečka, střelci, podpora…). Hlavní tag sem nepatří.
@export var tags: Array[String] = []
@export var weight: float = 1.0

func get_encounter_id() -> String:
	if not encounter_id.is_empty():
		return encounter_id
	return resource_path.get_file().get_basename()

func fits_row(row: int) -> bool:
	return row >= min_row and row <= max_row
