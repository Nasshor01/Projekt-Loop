# Soubor: res://data/cards/StartingDeckPool.gd (NOVÝ SOUBOR)
# POPIS: Tento Resource drží pohromadě seznam všech základních karet,
# ze kterých si hráč může na začátku sestavit balíček.
class_name StartingDeckPool
extends Resource

@export_group("Dostupné karty")
# Do těchto polí v editoru přetáhnete vaše .tres soubory pro základní karty.
@export var attack_cards: Array[CardData] = []
@export var defend_cards: Array[CardData] = []
@export var utility_cards: Array[CardData] = []
