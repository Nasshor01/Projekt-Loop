# Soubor: res://scripts/resources/EventData.gd (NOVÁ VERZE)
class_name EventData
extends Resource

enum EventType { RISK_REWARD, TRADE, COMBAT, BENEFIT, STORY }
enum EventRarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var event_id: String = ""
@export var event_name: String = "Nový Event"
@export_multiline var description: String = "Popis eventu..."
@export var event_type: EventType = EventType.BENEFIT
@export var rarity: EventRarity = EventRarity.COMMON
@export var artwork: Texture2D

@export_group("Podmínky Spuštění")
@export var min_floor: int = 0
@export var max_floor: int = 99
@export var once_per_run: bool = false
## Unique story events: after the player goes through a choice, never appears again on this meta save.
@export var once_per_meta: bool = false

@export_group("Požadavky")
@export var required_gold: int = 0
@export var required_artifact: ArtifactsData = null
@export var required_class: String = ""
@export var required_flag: String = ""
@export var required_building_id: String = ""
@export var required_building_level: int = 0

@export_group("Volby")
@export var choices: Array[EventChoice] = []

func get_localized_name() -> String:
	"""Vrátí lokalizovaný název eventu"""
	return tr(event_name)

func get_localized_description() -> String:
	"""Vrátí lokalizovaný popis eventu"""
	return tr(description)
