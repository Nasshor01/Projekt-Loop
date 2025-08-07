# Soubor: res://data/skills/PassiveSkillTreeData.gd
extends Resource
class_name PassiveSkillTreeData

## Pole obsahující všechny uzly dovedností pro tento strom.
@export var skill_nodes: Array[PassiveSkillNode] = []

## Slovník pro rychlé vyhledávání uzlů podle jejich ID. Vytvoří se automaticky.
var nodes_by_id: Dictionary = {}

func _init():
	call_deferred("_build_lookup_dictionary")

func _build_lookup_dictionary():
	nodes_by_id.clear()
	for node in skill_nodes:
		if is_instance_valid(node) and node.id != &"":
			nodes_by_id[node.id] = node

func get_node_by_id(id: StringName) -> PassiveSkillNode:
	return nodes_by_id.get(id, null)
