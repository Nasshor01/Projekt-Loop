# Soubor: res://data/skills/PassiveSkillNode.gd (FINÁLNÍ OPRAVENÁ VERZE)
extends Resource
class_name PassiveSkillNode

@export var id: StringName = &""
@export var skill_name: String = "Nová dovednost"
@export_multiline var description: String = "Popis dovednosti."
@export var icon: Texture2D
@export var position: Vector2 = Vector2.ZERO
@export var is_notable: bool = false
@export var cost: int = 1
@export var connected_nodes: PackedStringArray = []

## Místo slovníku zde máme pole našich nových, čistých efektů.
@export var effects: Array[PassiveEffectData] = []

var is_unlocked: bool = false
