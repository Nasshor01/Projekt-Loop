# Soubor: res://scripts/resources/EventChoice.gd (NOVÁ VERZE)
class_name EventChoice
extends Resource

@export var choice_text: String = "Pokračovat"
@export_multiline var choice_tooltip: String = ""

@export_group("Cena a Odměny")
@export var cost: EventCost = null
@export var reward: EventReward = null

@export_group("Risk & Reward")
@export_range(0.0, 1.0) var success_chance: float = 1.0
@export var show_success_chance: bool = true
@export var failure_cost: EventCost = null
@export var failure_reward: EventReward = null

@export_group("Speciální Akce")
@export var triggers_combat: bool = false
@export var combat_encounter: EncounterData = null
@export var opens_shop: bool = false
@export var triggers_next_event: String = ""
@export var sets_flag: String = ""

func can_afford() -> bool:
	"""Zkontroluje dostupnost volby"""
	if cost:
		return cost.can_afford()
	return true

func get_full_text() -> String:
	"""Vrátí kompletní text pro tlačítko"""
	var text = choice_text
	
	# Přidej cenu
	if cost:
		var cost_desc = cost.get_cost_description()
		if cost_desc != "":
			text += "\n[font_size=16]" + cost_desc + "[/font_size]"
	
	# Přidej šanci
	if success_chance < 1.0 and show_success_chance:
		text += " [color=gray](%d%%)[/color]" % int(success_chance * 100)
	
	return text

func get_tooltip() -> String:
	"""Vrátí tooltip text"""
	if choice_tooltip != "":
		return choice_tooltip
	
	# Automaticky vygeneruj tooltip z rewards
	if reward:
		return "Možné odměny: " + reward.get_reward_description()
	
	return ""
