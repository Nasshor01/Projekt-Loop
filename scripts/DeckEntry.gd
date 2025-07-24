# ===================================================================
# Soubor: res://scripts/DeckEntry.gd (NOVÝ SOUBOR)
# POPIS: Malá datová třída, která reprezentuje jeden typ karty
# a její počet v balíčku.
# ===================================================================
class_name DeckEntry
extends Resource

# Odkaz na soubor s definicí karty (např. attack_card.tres)
@export var card: CardData

# Počet kopií této karty v balíčku
@export var count: int = 1
