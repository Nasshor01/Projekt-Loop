# MapNodeResource.gd
# Opraveno: Přidán typ UNASSIGNED a správná inicializace polí.
extends Resource
class_name MapNodeResource

# ENUM pro definování všech možných typů místností.
# Přidán typ UNASSIGNED jako výchozí hodnota pro zjednodušení logiky generátoru.
enum NodeType {
	UNASSIGNED,
	MONSTER,
	ELITE,
	EVENT,
	REST,
	SHOP,
	TREASURE,
	BOSS
}

# Exportované proměnné, které se objeví v inspektoru Godotu.
@export var type: NodeType = NodeType.UNASSIGNED
@export var position: Vector2
@export var row: int
@export var column: int
# Chyba opravena: Pole musí být inicializována prázdným polem `[]`.
@export var connections: Array = [] # Odkazy na uzly v dalším patře
@export var incoming_connections: Array = [] # Odkazy na uzly v předchozím patře
