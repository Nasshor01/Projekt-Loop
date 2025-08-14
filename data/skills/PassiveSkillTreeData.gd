# Nahraď celý soubor res://data/skills/PassiveSkillTreeData.gd
@tool
extends Resource
class_name PassiveSkillTreeData

@export var skill_nodes: Array[PassiveSkillNode] = []
var nodes_by_id: Dictionary = {}

func _init():
	call_deferred("_build_lookup_dictionary")

func _build_lookup_dictionary():  # ← OPRAVENO: bez hvězdiček!
	nodes_by_id.clear()
	for node in skill_nodes:
		if is_instance_valid(node) and node.id != &"":
			nodes_by_id[String(node.id)] = node

func get_node_by_id(id) -> PassiveSkillNode:
	var key = String(id) if id is StringName else id
	return nodes_by_id.get(key, null)
