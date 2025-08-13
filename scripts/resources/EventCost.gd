# Soubor: res://scripts/resources/EventCost.gd
class_name EventCost
extends Resource

@export_group("Základní Ceny")
@export var gold: int = 0
@export var hp: int = 0
@export var max_hp: int = 0

@export_group("Karty")
@export var remove_random_card: bool = false
@export var remove_specific_card: CardData = null
@export var add_curse: bool = false
@export var curse_to_add: CardData = null

@export_group("Artefakty")
@export var remove_artifact: ArtifactsData = null

func can_afford() -> bool:
	"""Zkontroluje, jestli hráč může zaplatit tuto cenu"""
	if gold > 0 and PlayerData.gold < gold:
		return false
	if hp > 0 and PlayerData.current_hp <= hp:
		return false
	if max_hp > 0 and PlayerData.max_hp <= max_hp + 10:
		return false
	# TODO: Kontrola artefaktů a karet
	return true

func apply_cost():
	"""Aplikuje cenu na hráče"""
	if gold > 0:
		PlayerData.spend_gold(gold)
	if hp > 0:
		PlayerData.take_damage(hp)
	if max_hp > 0:
		PlayerData.max_hp -= max_hp
		PlayerData.current_hp = min(PlayerData.current_hp, PlayerData.max_hp)
	# TODO: Implementovat remove_card, add_curse atd.

func get_cost_description() -> String:
	"""Vrátí textový popis ceny"""
	var parts = []
	if gold > 0:
		parts.append("[color=yellow]-%d Gold[/color]" % gold)
	if hp > 0:
		parts.append("[color=red]-%d HP[/color]" % hp)
	if max_hp > 0:
		parts.append("[color=darkred]-%d Max HP[/color]" % max_hp)
	if add_curse:
		parts.append("[color=purple]Získáš prokletí[/color]")
	if remove_random_card:
		parts.append("[color=gray]Ztratíš náhodnou kartu[/color]")
	
	if parts.is_empty():
		return ""
	return ", ".join(PackedStringArray(parts))
