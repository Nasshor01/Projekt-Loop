# MapData.gd
extends Resource
class_name MapData

# Chyba opravena: Pole musí být inicializována prázdným polem `[]`.
@export var all_nodes: Array = []
@export var starting_nodes: Array = []
@export var boss_node: MapNodeResource
