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
		results_log.append("[color=yellow]Získal jsi %d zlata![/color]" % gold)
	
	if heal > 0:
		var actual_heal = heal
		if heal == 999:  # Full heal
			actual_heal = PlayerData.max_hp - PlayerData.current_hp
		actual_heal = min(actual_heal, PlayerData.max_hp - PlayerData.current_hp)
		PlayerData.heal(actual_heal)
		results_log.append("[color=green]Vyléčil jsi %d HP[/color]" % actual_heal)
	
	if max_hp != 0:
		PlayerData.change_max_hp(max_hp) # Voláme novou funkci
		if max_hp > 0:
			results_log.append("[color=green]Získal jsi +%d Max HP![/color]" % max_hp)
		else:
			results_log.append("[color=red]Ztratil jsi %d Max HP[/color]" % abs(max_hp))
	
	# Přidání karty
	if add_card:
		PlayerData.master_deck.append(add_card)
		results_log.append("[color=cyan]Získal jsi kartu: %s[/color]" % add_card.card_name)
	
	if add_random_card:
		var random_card = _get_random_card_by_rarity(card_rarity)
		if random_card:
			PlayerData.master_deck.append(random_card)
			results_log.append("[color=cyan]Získal jsi náhodnou kartu: %s[/color]" % random_card.card_name)
	
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
		results_log.append("[color=gray]Vyber kartu k odstranění...[/color]")
	
	if remove_specific_card:
		if PlayerData.master_deck.has(remove_specific_card):
			PlayerData.master_deck.erase(remove_specific_card)
			results_log.append("[color=gray]Odstraněna karta: %s[/color]" % remove_specific_card.card_name)
	
	# Transform karet
	if transform_card:
		_transform_random_card(results_log)
	
	# --- ZMĚNA V SEKCI PRO ARTEFAKTY ---
	if add_artifact:
		if PlayerData.add_artifact(add_artifact):
			results_log.append("[color=orange]Získal jsi artefakt: %s[/color]" % add_artifact.artifact_name)
	
	if add_random_basic_artifact:
		var random_artifact = _get_random_basic_artifact()
		if random_artifact and PlayerData.add_artifact(random_artifact):
			results_log.append("[color=orange]Získal jsi náhodný artefakt: %s[/color]" % random_artifact.artifact_name)
	
	if add_random_event_artifact:
		var available = EVENT_ARTIFACT_POOL.artifacts.filter(func(art): return PlayerData.can_gain_artifact(art))
		if not available.is_empty():
			var event_artifact = available.pick_random()
			if PlayerData.add_artifact(event_artifact):
				results_log.append("[color=gold]Získal jsi speciální artefakt: %s[/color]" % event_artifact.artifact_name)
	# --- KONEC ZMĚN ---
	
	# Speciální akce
	if buff_next_combat != "":
		EventManager.add_combat_buff(buff_next_combat)
		results_log.append("[color=blue]Získal jsi bonus pro příští souboj![/color]")
	
	if opens_card_selection:
		results_log.append("[color=cyan]Vyber si kartu...[/color]")

func _upgrade_random_card(results_log: Array):
	"""Vylepší náhodnou kartu v balíčku"""
	var upgradeable_cards = []
	for card in PlayerData.master_deck:
		if card and not card.is_upgraded and card.upgraded_version:
			upgradeable_cards.append(card)
	
	if upgradeable_cards.is_empty():
		results_log.append("[color=gray]Žádné karty nelze vylepšit[/color]")
		return
	
	var card_to_upgrade = upgradeable_cards.pick_random()
	var index = PlayerData.master_deck.find(card_to_upgrade)
	if index != -1:
		PlayerData.master_deck[index] = card_to_upgrade.upgraded_version
		results_log.append("[color=cyan]Vylepšena karta: %s → %s[/color]" % [
			card_to_upgrade.card_name,
			card_to_upgrade.upgraded_version.card_name
		])

func _upgrade_specific_card(card: CardData, results_log: Array):
	"""Vylepší konkrétní kartu"""
	if not card or not card.upgraded_version:
		return
	
	var index = PlayerData.master_deck.find(card)
	if index != -1:
		PlayerData.master_deck[index] = card.upgraded_version
		results_log.append("[color=cyan]Vylepšena karta: %s → %s[/color]" % [
			card.card_name,
			card.upgraded_version.card_name
		])

func _upgrade_all_cards(results_log: Array):
	"""Vylepší všechny karty v balíčku"""
	var upgraded_count = 0
	for i in range(PlayerData.master_deck.size()):
		var card = PlayerData.master_deck[i]
		if card and not card.is_upgraded and card.upgraded_version:
			PlayerData.master_deck[i] = card.upgraded_version
			upgraded_count += 1
	
	if upgraded_count > 0:
		results_log.append("[color=cyan]Vylepšeno %d karet![/color]" % upgraded_count)
	else:
		results_log.append("[color=gray]Žádné karty nelze vylepšit[/color]")

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
			results_log.append("[color=purple]Proměna: %s → %s[/color]" % [
				card_to_transform.card_name,
				new_card.card_name
			])

func _get_random_card_by_rarity(rarity: CardData.CardRarity) -> CardData:
	"""Získá náhodnou kartu podle rarity"""
	var card_pool = load("res://data/cards/reward_card_pool.tres")
	if not card_pool:
		return null
	
	var filtered_cards = []
	for card in card_pool.cards:
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
	if add_random_card:
		parts.append("Náhodná %s karta" % CardData.CardRarity.keys()[card_rarity])
	if upgrade_random_card:
		parts.append("Vylepšení náhodné karty")
	if upgrade_all_cards:
		parts.append("Vylepšení všech karet")
	if remove_card:
		parts.append("Odstranění karty")
	if transform_card:
		parts.append("Proměna karty")
	if add_artifact:
		parts.append("Artefakt: %s" % add_artifact.artifact_name)
	if add_random_basic_artifact:
		parts.append("Náhodný artefakt")
	if add_random_event_artifact:
		parts.append("[color=gold]Náhodný speciální artefakt[/color]")
	
	if parts.is_empty():
		return "Žádná odměna"
	return ", ".join(PackedStringArray(parts))
