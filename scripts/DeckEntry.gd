# ===================================================================
# Soubor: res://scripts/DeckEntry.gd
# ===================================================================
class_name DeckEntry
extends Resource

# Odkaz na soubor s definicí karty (např. attack_card.tres)
@export var card: CardData

# Cesta ke kartě, načtená až při skládání balíčku. Pro karty s required_subclass
# na tutéž subclassu — přímý odkaz by vytvořil cyklický load (Paladin.tres <-> karta).
@export_file("*.tres") var card_path: String = ""

# Počet kopií této karty v balíčku
@export var count: int = 1

func get_card() -> CardData:
	if is_instance_valid(card):
		return card
	if card_path != "" and ResourceLoader.exists(card_path):
		return load(card_path) as CardData
	return null
