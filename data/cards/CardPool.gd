# Soubor: data/cards/CardPool.gd
class_name CardPool
extends Resource

@export var cards: Array[CardData] = []

func get_available_cards(player_class: ClassData = null, player_subclass: SubclassData = null, _unlocked_cards: Array[String] = []) -> Array[CardData]:
	"""
	Vrátí pole karet dostupných pro hráče.
	Filtruje podle class/subclass. BASIC a (legacy) odměny bez BASIC.
	"""
	var available: Array[CardData] = []
	for card in cards:
		if not is_instance_valid(card):
			continue
		if not card.can_be_used_by(player_class, player_subclass):
			continue
		if card.rarity == CardData.CardRarity.BASIC:
			continue
		if VillageBonuses.is_reward_gated_card(card.card_id) and not VillageBonuses.is_gated_card_unlocked(card.card_id):
			continue
		available.append(card)
	return available

func get_cards_by_rarity(rarity: CardData.CardRarity, player_class: ClassData = null, player_subclass: SubclassData = null, unlocked_cards: Array[String] = []) -> Array[CardData]:
	var available = get_available_cards(player_class, player_subclass, unlocked_cards)
	var result: Array[CardData] = []
	for card in available:
		if _effective_rarity(card) == rarity:
			result.append(card)
	return result

## UNCOMMON is cancelled — treat as COMMON everywhere.
static func _effective_rarity(card: CardData) -> CardData.CardRarity:
	if card.rarity == CardData.CardRarity.UNCOMMON:
		return CardData.CardRarity.COMMON
	return card.rarity

# Weighted pick for rewards/shop.
# Order: Legendary → Epic → Rare → Common (fallback).
# uncommon_chance kept as deprecated alias for epic_chance (old call sites).
func pick_weighted_cards(
	count: int,
	rare_card_chance: float,
	player_class: ClassData = null,
	player_subclass: SubclassData = null,
	unlocked_cards: Array[String] = [],
	epic_card_chance: float = 0.05,
	legendary_card_chance: float = 0.02
) -> Array[CardData]:
	var available = get_available_cards(player_class, player_subclass, unlocked_cards)
	if available.is_empty():
		return []

	var by_rarity: Dictionary = {}
	for card in available:
		var r = _effective_rarity(card)
		if not by_rarity.has(r):
			by_rarity[r] = []
		by_rarity[r].append(card)

	var common: Array = (by_rarity.get(CardData.CardRarity.COMMON, [])).duplicate()
	var rare: Array = (by_rarity.get(CardData.CardRarity.RARE, [])).duplicate()
	var epic: Array = (by_rarity.get(CardData.CardRarity.EPIC, [])).duplicate()
	var legendary: Array = (by_rarity.get(CardData.CardRarity.LEGENDARY, [])).duplicate()

	var result: Array[CardData] = []
	for i in range(count):
		var roll = randf()
		var pool: Array = common
		if roll < legendary_card_chance and not legendary.is_empty():
			pool = legendary
		elif roll < legendary_card_chance + epic_card_chance and not epic.is_empty():
			pool = epic
		elif roll < legendary_card_chance + epic_card_chance + rare_card_chance and not rare.is_empty():
			pool = rare
		if pool.is_empty():
			pool = common if not common.is_empty() else available
		if pool.is_empty():
			continue
		var card: CardData = pool.pick_random()
		result.append(card)
		pool.erase(card)
	return result
