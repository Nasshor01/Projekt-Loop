# Soubor: res://scripts/resources/EventReward.gd
class_name EventReward
extends Resource

@export_group("Základní Odměny")
@export var gold: int = 0
@export var heal: int = 0  # 999 = full heal
@export var max_hp: int = 0

@export_group("Karty")
@export var add_card: CardData = null
@export var add_random_card: bool = false
@export var card_rarity: String = "common"  # common/uncommon/rare
@export var remove_card: bool = false
@export var upgrade_random_card: bool = false
@export var upgrade_all_cards: bool = false

@export_group("Artefakty")
@export var add_artifact: ArtifactsData = null
@export var add_random_artifact: bool = false

@export_group("Speciální")
@export var buff_next_combat: String = ""
@export var unlock_character: String = ""
@export var trigger_event: String = ""

func apply_reward(results_log: Array = []):
	"""Aplikuje odměnu na hráče"""
	if gold > 0:
		PlayerData.add_gold(gold)
		results_log.append("[color=yellow]Získal jsi %d zlata![/color]" % gold)
	
	if heal > 0:
		var actual_heal = heal
		if heal == 999:  # Full heal
			actual_heal = PlayerData.max_hp - PlayerData.current_hp
		actual_heal = min(actual_heal, PlayerData.max_hp - PlayerData.current_hp)
		PlayerData.heal(actual_heal)
		results_log.append("[color=green]Vyléčil jsi %d HP[/color]" % actual_heal)
	
	if max_hp != 0:
		if max_hp > 0:
			PlayerData.max_hp += max_hp
			PlayerData.current_hp += max_hp
			results_log.append("[color=green]Získal jsi +%d Max HP![/color]" % max_hp)
		else:
			PlayerData.max_hp += max_hp
			PlayerData.current_hp = min(PlayerData.current_hp, PlayerData.max_hp)
			results_log.append("[color=red]Ztratil jsi %d Max HP[/color]" % abs(max_hp))
	
	if add_card:
		PlayerData.master_deck.append(add_card)
		results_log.append("[color=cyan]Získal jsi kartu: %s[/color]" % add_card.card_name)
	
	if add_artifact:
		PlayerData.add_artifact(add_artifact)
		results_log.append("[color=orange]Získal jsi artefakt: %s[/color]" % add_artifact.artifact_name)
	
	if buff_next_combat != "":
		EventManager.add_combat_buff(buff_next_combat)
		results_log.append("[color=blue]Získal jsi bonus pro příští souboj![/color]")

func get_reward_description() -> String:
	"""Vrátí textový popis odměny"""
	var parts = []
	if gold > 0:
		parts.append("+%d Gold" % gold)
	if heal > 0:
		if heal == 999:
			parts.append("Plné vyléčení")
		else:
			parts.append("+%d HP" % heal)
	if max_hp > 0:
		parts.append("+%d Max HP" % max_hp)
	if add_card:
		parts.append("Karta: %s" % add_card.card_name)
	if add_artifact:
		parts.append("Artefakt: %s" % add_artifact.artifact_name)
	
	if parts.is_empty():
		return "Žádná odměna"
	return ", ".join(PackedStringArray(parts))
