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
@export var curse_to_add: CardData = null  # Konkrétní curse, nebo null pro náhodnou

@export_group("Artefakty")
@export var remove_artifact: ArtifactsData = null

## Set by apply_cost when a curse card is added (for EventScene result visuals).
var last_added_curse: CardData = null

func can_afford() -> bool:
	"""Zkontroluje, jestli hráč může zaplatit tuto cenu"""
	if gold > 0 and PlayerData.gold < gold:
		return false
	if hp > 0 and PlayerData.current_hp <= hp:
		return false
	if max_hp > 0 and PlayerData.max_hp <= max_hp + 10:
		return false
	
	# Kontrola, jestli má kartu k odstranění
	if remove_random_card and PlayerData.master_deck.is_empty():
		return false
	if remove_specific_card and not PlayerData.master_deck.has(remove_specific_card):
		return false
	
	# Kontrola artefaktu
	if remove_artifact and not PlayerData.artifacts.has(remove_artifact):
		return false
	
	return true

func apply_cost():
	"""Aplikuje cenu na hráče"""
	last_added_curse = null
	if gold > 0:
		PlayerData.spend_gold(gold)
	if hp > 0:
		PlayerData.take_damage(hp)
	if max_hp > 0:
		PlayerData.change_max_hp(-max_hp) # Voláme novou funkci se zápornou hodnotoux_hp)
	
	# Odstranění karty
	if remove_random_card and not PlayerData.master_deck.is_empty():
		var card_to_remove = PlayerData.master_deck.pick_random()
		PlayerData.master_deck.erase(card_to_remove)
		print(TranslationHelper.tr_format("event.cost.removed_card", {"name": card_to_remove.get_localized_name()}))
	
	if remove_specific_card and PlayerData.master_deck.has(remove_specific_card):
		PlayerData.master_deck.erase(remove_specific_card)
		print(TranslationHelper.tr_format("event.cost.removed_specific_card", {"name": remove_specific_card.get_localized_name()}))
	
	# Přidání curse
	if add_curse:
		var curse_card = curse_to_add
		if not curse_card:
			# Pokud není specifikována, použij základní curse
			curse_card = load("res://data/cards/curse/curse_basic.tres")
		if curse_card:
			var curse_copy = PlayerData.duplicate_card_for_deck(curse_card)
			PlayerData.master_deck.append(curse_copy)
			last_added_curse = curse_copy
			print(TranslationHelper.tr_format("event.cost.added_curse", {"name": curse_copy.get_localized_name()}))
	
	# Odstranění artefaktu
	if remove_artifact:
		PlayerData.remove_artifact(remove_artifact)
		print(TranslationHelper.tr_format("event.cost.removed_artifact", {"name": remove_artifact.get_localized_name()}))

func get_cost_description() -> String:
	"""Vrátí textový popis ceny"""
	var parts = []
	if gold > 0:
		parts.append("[color=yellow]" + TranslationHelper.tr_format("event.cost.gold", {"value": gold}) + "[/color]")
	if hp > 0:
		parts.append("[color=red]" + TranslationHelper.tr_format("event.cost.hp", {"value": hp}) + "[/color]")
	if max_hp > 0:
		parts.append("[color=darkred]" + TranslationHelper.tr_format("event.cost.max_hp", {"value": max_hp}) + "[/color]")
	if add_curse:
		if curse_to_add:
			parts.append("[color=purple]" + TranslationHelper.tr_format("event.cost.curse_named", {"name": curse_to_add.get_localized_name()}) + "[/color]")
		else:
			parts.append("[color=purple]" + tr("event.cost.curse") + "[/color]")
	if remove_random_card:
		parts.append("[color=gray]" + tr("event.cost.remove_random_card") + "[/color]")
	if remove_specific_card:
		parts.append("[color=gray]" + TranslationHelper.tr_format("event.cost.remove_specific_card", {"name": remove_specific_card.get_localized_name()}) + "[/color]")
	if remove_artifact:
		parts.append("[color=orange]" + TranslationHelper.tr_format("event.cost.remove_artifact", {"name": remove_artifact.get_localized_name()}) + "[/color]")
	
	if parts.is_empty():
		return ""
	return ", ".join(PackedStringArray(parts))
