# ===================================================================
# Soubor: res://data/classes/SubclassData.gd (AKTUALIZOVANÁ VERZE)
# POPIS: Místo pole karet nyní používáme pole našich nových DeckEntry.
# To nám umožní v editoru snadno nastavit počet kopií pro každou kartu.
# ===================================================================
class_name SubclassData
extends Resource

@export var subclass_id: String = "unique_subclass_id"
@export var subclass_name: String = "Název Podtřídy"
@export_multiline var description: String = "Popis podtřídy."

@export var parent_class: ClassData

@export var starting_deck: Array[DeckEntry] = []

# Můžeme mít specifickou jednotku pro podtřídu, pokud se liší od základní.
@export var specific_unit_data: UnitData

func _init(p_id: String = "", p_name: String = "Podtřída"):
	subclass_id = p_id
	subclass_name = p_name

@export var passive_skill_tree: PassiveSkillTreeData
