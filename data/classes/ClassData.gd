# ClassData.gd
# Resource pro definici hlavní třídy postavy.
# Uložte např. do res://data/classes/ClassData.gd
class_name ClassData
extends Resource

@export var class_id: String = "unique_class_id" # Např. "tank", "mage"
@export var display_name: String = "Název Třídy"
@export_multiline var description: String = "Popis hlavní třídy."

# Zde můžeme později přidat odkazy na dostupné podtřídy,
# nebo specifické pasivní schopnosti třídy.
# @export var available_subclasses: Array[SubclassData]

# Může odkazovat na základní UnitData, pokud má třída "hlavního hrdinu"
# nebo výchozí jednotku, kterou reprezentuje na bojišti.
@export var base_unit_data: UnitData 

# Může obsahovat seznam ID karet, které jsou pro tuto třídu základní nebo vždy dostupné
# @export var core_card_ids: Array[String]

func _init(p_id: String = "", p_name: String = "Třída", p_desc: String = ""):
	class_id = p_id
	display_name = p_name
	description = p_desc
