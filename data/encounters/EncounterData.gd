# ===================================================================
# Soubor: res://data/encounters/EncounterData.gd
# POPIS: Tento Resource definuje celou skupinu nepřátel pro jeden
# ===================================================================
class_name EncounterData
extends Resource

# Pole jednotlivých nepřátel v tomto souboji
@export var enemies: Array[EncounterEntry] = []
