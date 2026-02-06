# Soubor: res://scripts/resources/EventReward.gd (KOMPLETNÍ VERZE)
class_name EventReward
extends Resource

# --- Přidáme si nahoře preload poolu ---
const EVENT_ARTIFACT_POOL = preload("res://data/artifacts/pool/event_reward_pool.tres")

@export_group("Základní Odměny")
@export var gold: int = 0
@export var heal: int = 0  # 999 = full heal
@export var max_hp: int = 0

@export_group("Karty")
@export var add_card: CardData = null
@export var add_random_card: bool = false
@export var card_rarity: CardData.CardRarity = CardData.CardRarity.COMMON
@export var remove_card: bool = false  # Otevře card removal screen
@export var remove_specific_card: CardData = null  # Odstraní konkrétní kartu
@export var upgrade_random_card: bool = false
@export var upgrade_specific_card: CardData = null
@export var upgrade_all_cards: bool = false
@export var transform_card: bool = false  # Promění kartu v jinou stejné rarity

@export_group("Artefakty")
@export var add_artifact: ArtifactsData = null # Odměna konkrétního artefaktu
@export var add_random_basic_artifact: bool = false # Přejmenováno z add_random_artifact
@export var add_random_event_artifact: bool = false # NOVÁ MOŽNOST

@export_group("Speciální")
@export var buff_next_combat: String = ""
@export var unlock_character: String = ""
@export var trigger_event: String = ""
@export var opens_card_selection: bool = false  # Otevře výběr karet jako reward screen

var pending_card_removal: bool = false
var pending_card_upgrade: bool = false

func apply_reward(results_log: Array = []):
	"""Aplikuje odměnu na hráče"""
	if gold > 0:
		PlayerData.add_gold(gold)
		results_log.append("[color=yellow]" + TranslationHelper.tr_format("event.reward.gain_gold", {"value": gold}) + "[/color]")
	
	if heal > 0:
		var actual_heal = heal
		if heal == 999:  # Full heal
			actual_heal = PlayerData.max_hp - PlayerData.current_hp
		actual_heal = min(actual_heal, PlayerData.max_hp - PlayerData.current_hp)
		PlayerData.heal(actual_heal)
		results_log.append("[color=green]" + TranslationHelper.tr_format("event.reward.heal_hp", {"value": actual_heal}) + "[/color]")
	
	if max_hp != 0:
		PlayerData.change_max_hp(max_hp) # Voláme novou funkci
		if max_hp > 0:
			results_log.append("[color=green]" + TranslationHelper.tr_format("event.reward.max_hp_gain", {"value": max_hp}) + "[/color]")
		else:
			results_log.append("[color=red]" + TranslationHelper.tr_format("event.reward.max_hp_loss", {"value": abs(max_hp)}) + "[/color]")
	
	# Přidání karty
	if add_card:
		PlayerData.master_deck.append(add_card)
		results_log.append("[color=cyan]" + TranslationHelper.tr_format("event.reward.card", {"name": add_card.get_localized_name()}) + "[/color]")
	
	if add_random_card:
		var random_card = _get_random_card_by_rarity(card_rarity)
		if random_card:
			PlayerData.master_deck.append(random_card)
			results_log.append("[color=cyan]" + TranslationHelper.tr_format("event.reward.random_card", {"name": random_card.get_localized_name()}) + "[/color]")
	
	# Upgrade karet
	if upgrade_random_card:
		_upgrade_random_card(results_log)
	
	if upgrade_specific_card:
		_upgrade_specific_card(upgrade_specific_card, results_log)
	
	if upgrade_all_cards:
		_upgrade_all_cards(results_log)
	
	# Remove karet
	if remove_card:
		pending_card_removal = true
		results_log.append("[color=gray]" + tr("event.reward.remove_card_select") + "[/color]")
	
	if remove_specific_card:
		if PlayerData.master_deck.has(remove_specific_card):
			PlayerData.master_deck.erase(remove_specific_card)
			results_log.append("[color=gray]" + TranslationHelper.tr_format("event.reward.remove_card", {"name": remove_specific_card.get_localized_name()}) + "[/color]")
	
	# Transform karet
	if transform_card:
		_transform_random_card(results_log)
	
	# --- ZMĚNA V SEKCI PRO ARTEFAKTY ---
	if add_artifact:
		if PlayerData.add_artifact(add_artifact):
			results_log.append("[color=orange]" + TranslationHelper.tr_format("event.reward.artifact", {"name": add_artifact.get_localized_name()}) + "[/color]")
	
	if add_random_basic_artifact:
		var random_artifact = _get_random_basic_artifact()
		if random_artifact and PlayerData.add_artifact(random_artifact):
			results_log.append("[color=orange]" + TranslationHelper.tr_format("event.reward.random_artifact", {"name": random_artifact.get_localized_name()}) + "[/color]")
	
	if add_random_event_artifact:
		var available = EVENT_ARTIFACT_POOL.artifacts.filter(func(art): return PlayerData.can_gain_artifact(art))
		if not available.is_empty():
			var event_artifact = available.pick_random()
			if PlayerData.add_artifact(event_artifact):
				results_log.append("[color=gold]" + TranslationHelper.tr_format("event.reward.special_artifact", {"name": event_artifact.get_localized_name()}) + "[/color]")
	# --- KONEC ZMĚN ---
	
	# Speciální akce
	if buff_next_combat != "":
		EventManager.add_combat_buff(buff_next_combat)
		results_log.append("[color=blue]" + tr("event.reward.next_combat_buff") + "[/color]")
	
	if opens_card_selection:
		results_log.append("[color=cyan]" + tr("event.reward.pick_card") + "[/color]")

func _upgrade_random_card(results_log: Array):
	"""Vylepší náhodnou kartu v balíčku"""
	var upgradeable_cards = []
	for card in PlayerData.master_deck:
		if card and not card.is_upgraded and card.upgraded_version:
			upgradeable_cards.append(card)
	
	if upgradeable_cards.is_empty():
		results_log.append("[color=gray]" + tr("event.reward.upgrade_none") + "[/color]")
		return
	
	var card_to_upgrade = upgradeable_cards.pick_random()
	var index = PlayerData.master_deck.find(card_to_upgrade)
	if index != -1:
		PlayerData.master_deck[index] = card_to_upgrade.upgraded_version
		results_log.append("[color=cyan]" + TranslationHelper.tr_format("event.reward.upgraded_card", {"from": card_to_upgrade.get_localized_name(), "to": card_to_upgrade.upgraded_version.get_localized_name()}) + "[/color]")

func _upgrade_specific_card(card: CardData, results_log: Array):
	"""Vylepší konkrétní kartu"""
	if not card or not card.upgraded_version:
		return
	
	var index = PlayerData.master_deck.find(card)
	if index != -1:
		PlayerData.master_deck[index] = card.upgraded_version
		results_log.append("[color=cyan]" + TranslationHelper.tr_format("event.reward.upgraded_card", {"from": card.get_localized_name(), "to": card.upgraded_version.get_localized_name()}) + "[/color]")

func _upgrade_all_cards(results_log: Array):
	"""Vylepší všechny karty v balíčku"""
	var upgraded_count = 0
	for i in range(PlayerData.master_deck.size()):
		var card = PlayerData.master_deck[i]
		if card and not card.is_upgraded and card.upgraded_version:
			PlayerData.master_deck[i] = card.upgraded_version
			upgraded_count += 1
	
	if upgraded_count > 0:
		results_log.append("[color=cyan]" + TranslationHelper.tr_format("event.reward.upgraded_count", {"value": upgraded_count}) + "[/color]")
	else:
		results_log.append("[color=gray]" + tr("event.reward.upgrade_none") + "[/color]")

func _transform_random_card(results_log: Array):
	"""Promění náhodnou kartu v jinou stejné rarity"""
	if PlayerData.master_deck.is_empty():
		return
	
	var card_to_transform = PlayerData.master_deck.pick_random()
	var new_card = _get_random_card_by_rarity(card_to_transform.rarity)
	
	if new_card and new_card != card_to_transform:
		var index = PlayerData.master_deck.find(card_to_transform)
		if index != -1:
			PlayerData.master_deck[index] = new_card
			results_log.append("[color=purple]" + TranslationHelper.tr_format("event.reward.transformed_card", {"from": card_to_transform.get_localized_name(), "to": new_card.get_localized_name()}) + "[/color]")

func _get_random_card_by_rarity(rarity: CardData.CardRarity) -> CardData:
	"""Získá náhodnou kartu podle rarity"""
	var card_pool = load("res://data/cards/reward_card_pool.tres")
	if not card_pool:
		return null
	
	# Použijeme filtrovaný pool podle třídy a odemčených karet
	var available_cards = card_pool.get_available_cards(
		PlayerData.selected_class,
		PlayerData.selected_subclass,
		PlayerData.unlocked_cards
	)
	
	var filtered_cards = []
	for card in available_cards:
		if card.rarity == rarity:
			filtered_cards.append(card)
	
	if filtered_cards.is_empty():
		return null
	
	return filtered_cards.pick_random()

func _get_random_basic_artifact() -> ArtifactsData:
	"""Získá náhodný artefakt z běžného poolu (např. ze shopu)"""
	var artifact_pool = load("res://data/artifacts/pool/shop_pool.tres")
	if not artifact_pool or artifact_pool.artifacts.is_empty():
		return null
	
	var available = artifact_pool.artifacts.filter(func(art): return PlayerData.can_gain_artifact(art))
	if not available.is_empty():
		return available.pick_random()
	
	return null

func get_reward_description() -> String:
	"""Vrátí textový popis odměny"""
	var parts = []
	if gold > 0:
		parts.append(TranslationHelper.tr_format("event.reward.desc_gold", {"value": gold}))
	if heal > 0:
		if heal == 999:
			parts.append(tr("event.reward.desc_full_heal"))
		else:
			parts.append(TranslationHelper.tr_format("event.reward.desc_heal", {"value": heal}))
	if max_hp > 0:
		parts.append(TranslationHelper.tr_format("event.reward.desc_max_hp", {"value": max_hp}))
	if add_card:
		parts.append(TranslationHelper.tr_format("event.reward.desc_card", {"name": add_card.get_localized_name()}))
	if add_random_card:
		parts.append(TranslationHelper.tr_format("event.reward.desc_random_card", {"rarity": tr("card.rarity." + CardData.CardRarity.keys()[card_rarity].to_lower())}))
	if upgrade_random_card:
		parts.append(tr("event.reward.desc_upgrade_random"))
	if upgrade_all_cards:
		parts.append(tr("event.reward.desc_upgrade_all"))
	if remove_card:
		parts.append(tr("event.reward.desc_remove_card"))
	if transform_card:
		parts.append(tr("event.reward.desc_transform_card"))
	if add_artifact:
		parts.append(TranslationHelper.tr_format("event.reward.desc_artifact", {"name": add_artifact.get_localized_name()}))
	if add_random_basic_artifact:
		parts.append(tr("event.reward.desc_random_artifact"))
	if add_random_event_artifact:
		parts.append("[color=gold]" + tr("event.reward.desc_random_special_artifact") + "[/color]")
	
	if parts.is_empty():
		return tr("event.reward.desc_none")
	return ", ".join(PackedStringArray(parts))
