class_name ClassData
extends Resource

@export var class_id: String = "unique_class_id"
@export var display_name: String = "Název Třídy"
@export_multiline var description: String = "Popis hlavní třídy."
@export var base_unit_data: UnitData 

func _init(p_id: String = "", p_name: String = "Třída", p_desc: String = ""):
	class_id = p_id
	display_name = p_name
	description = p_desc
