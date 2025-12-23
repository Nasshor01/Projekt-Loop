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
