# ===================================================================
# Soubor: res://scripts/DeckEntry.gd
# ===================================================================
class_name DeckEntry
extends Resource

# Odkaz na soubor s definicí karty (např. attack_card.tres)
@export var card: CardData

# Počet kopií této karty v balíčku
@export var count: int = 1
