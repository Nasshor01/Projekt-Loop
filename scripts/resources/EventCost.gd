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
		print("Odstraněna karta: %s" % card_to_remove.card_name)
	
	if remove_specific_card and PlayerData.master_deck.has(remove_specific_card):
		PlayerData.master_deck.erase(remove_specific_card)
		print("Odstraněna specifická karta: %s" % remove_specific_card.card_name)
	
	# Přidání curse
	if add_curse:
		var curse_card = curse_to_add
		if not curse_card:
			# Pokud není specifikována, použij základní curse
			curse_card = load("res://data/cards/curse/curse_basic.tres")
		if curse_card:
			PlayerData.master_deck.append(curse_card)
			print("Přidána curse karta: %s" % curse_card.card_name)
	
	# Odstranění artefaktu
	if remove_artifact:
		PlayerData.remove_artifact(remove_artifact)
		print("Odstraněn artefakt: %s" % remove_artifact.artifact_name)

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
		if curse_to_add:
			parts.append("[color=purple]Získáš prokletí: %s[/color]" % curse_to_add.card_name)
		else:
			parts.append("[color=purple]Získáš prokletí[/color]")
	if remove_random_card:
		parts.append("[color=gray]Ztratíš náhodnou kartu[/color]")
	if remove_specific_card:
		parts.append("[color=gray]Ztratíš kartu: %s[/color]" % remove_specific_card.card_name)
	if remove_artifact:
		parts.append("[color=orange]Ztratíš artefakt: %s[/color]" % remove_artifact.artifact_name)
	
	if parts.is_empty():
		return ""
	return ", ".join(PackedStringArray(parts))
