# Soubor: data/cards/CardPool.gd (NOVÝ SKRIPT)
class_name CardPool
extends Resource

@export var cards: Array[CardData] = []

# NOVÉ: Metoda pro získání dostupných karet podle třídy a odemčených karet
func get_available_cards(player_class: ClassData = null, player_subclass: SubclassData = null, unlocked_cards: Array[String] = []) -> Array[CardData]:
	"""
	Vrátí pole karet, které jsou dostupné pro hráče.
	Filtruje podle:
	- Třídy/podtřídy hráče
	- Odemčených karet (pro subclass-specifické karty)
	- Rarity (BASIC karty se neobjevují v odměnách)
	"""
	var available: Array[CardData] = []
	
	for card in cards:
		if not is_instance_valid(card):
			continue
		
		# Filtruj podle třídy/podtřídy
		if not card.can_be_used_by(player_class, player_subclass):
			continue
		
		# BASIC karty se neobjevují v odměnách/obchodě
		if card.rarity == CardData.CardRarity.BASIC:
			continue
		
		# Pokud je karta specifická pro subclassu:
		# - Pokud existuje seznam odemčených karet, použij ho
		# - Pokud je seznam prázdný, považuj všechny subclass karty za dostupné (bez gates)
		if card.required_subclass != null:
			if not unlocked_cards.is_empty() and not unlocked_cards.has(card.card_id):
				continue
		
		available.append(card)
	
	return available

# Pomocná metoda pro získání karet podle rarity
func get_cards_by_rarity(rarity: CardData.CardRarity, player_class: ClassData = null, player_subclass: SubclassData = null, unlocked_cards: Array[String] = []) -> Array[CardData]:
	"""Vrátí karty dané rarity, které jsou dostupné pro hráče."""
	var available = get_available_cards(player_class, player_subclass, unlocked_cards)
	var result: Array[CardData] = []
	for card in available:
		if card.rarity == rarity:
			result.append(card)
	return result

# Weighted random selection for rewards/shop. rare_card_chance = chance for Rare (default 0.1), rest split Common/Uncommon
func pick_weighted_cards(count: int, rare_card_chance: float, player_class: ClassData = null, player_subclass: SubclassData = null, unlocked_cards: Array[String] = []) -> Array[CardData]:
	var available = get_available_cards(player_class, player_subclass, unlocked_cards)
	if available.is_empty():
		return []
	var by_rarity: Dictionary = {}
	for card in available:
		var r = card.rarity
		if not by_rarity.has(r):
			by_rarity[r] = []
		by_rarity[r].append(card)
	var common: Array = (by_rarity.get(CardData.CardRarity.COMMON, [])).duplicate()
	var uncommon: Array = (by_rarity.get(CardData.CardRarity.UNCOMMON, [])).duplicate()
	var rare: Array = (by_rarity.get(CardData.CardRarity.RARE, [])).duplicate()
	var result: Array[CardData] = []
	var uncommon_chance = 0.35
	for i in range(count):
		var roll = randf()
		var pool: Array = common
		if roll < rare_card_chance and not rare.is_empty():
			pool = rare
		elif roll < rare_card_chance + uncommon_chance and not uncommon.is_empty():
			pool = uncommon
		if pool.is_empty():
			pool = common if not common.is_empty() else available
		if pool.is_empty():
			continue
		var card: CardData = pool.pick_random()
		result.append(card)
		pool.erase(card)
	return result
