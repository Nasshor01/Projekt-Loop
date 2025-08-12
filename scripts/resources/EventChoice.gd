# Soubor: res://scripts/resources/EventChoice.gd
class_name EventChoice
extends Resource

@export var choice_text: String = "Pokračovat"
@export_multiline var choice_tooltip: String = ""

@export_group("Cena Volby")
@export var costs: Dictionary = {} # např. {"gold": 50, "hp": 10, "add_curse": true}

@export_group("Odměna za Úspěch")
@export var rewards: Dictionary = {} # např. {"gold": 100, "heal": 20, "artifact": "artifact_id"}

@export_group("Risk & Selhání")
@export_range(0.0, 1.0) var success_chance: float = 1.0 # Šance od 0.0 (0%) do 1.0 (100%)
@export var failure_penalty: Dictionary = {} # Co se stane při neúspěchu

@export_group("Speciální Akce")
@export var triggers_combat: bool = false
@export var combat_encounter: EncounterData # Odkaz na .tres souboj
