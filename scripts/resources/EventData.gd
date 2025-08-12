# Soubor: res://scripts/resources/EventData.gd
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
@export var once_per_run: bool = false # Může se event stát jen jednou za run?
@export var requirements: Dictionary = {} # např. {"min_gold": 50, "required_class": "Tank"}

@export_group("Volby")
@export var choices: Array[EventChoice] = []
