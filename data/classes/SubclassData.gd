class_name SubclassData
extends Resource

@export var subclass_id: String = "unique_subclass_id"
@export var subclass_name: String = "Název Podtřídy"
@export_multiline var description: String = "Popis podtřídy."
@export var parent_class: ClassData
@export var starting_deck: Array[DeckEntry] = []
@export var specific_unit_data: UnitData
@export var passive_skill_tree: PassiveSkillTreeData = null

func _init(p_id: String = "", p_name: String = "Podtřída"):
	subclass_id = p_id
	subclass_name = p_name
