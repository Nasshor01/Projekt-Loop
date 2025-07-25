# ===================================================================
# Soubor: res://data/encounters/EncounterEntry.gd
# POPIS: Malá datová třída, která definuje jednu jednotku v souboji
# a její startovní pozici na mřížce.
# ===================================================================
class_name EncounterEntry
extends Resource

# Odkaz na data jednotky (např. goblin.tres)
@export var unit_data: UnitData

# Startovní pozice na mřížce
@export var grid_position: Vector2i = Vector2i.ZERO
