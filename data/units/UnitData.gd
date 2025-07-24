# ===================================================================
# Soubor: res://data/units/UnitData.gd (UPRAVENÁ VERZE)
# POPIS: Odstraněna proměnná max_action_points.
# ===================================================================
class_name UnitData
extends Resource

enum Faction {
	PLAYER,
	ENEMY,
	NEUTRAL
}

@export var unit_id: String = "unique_unit_id"
@export var unit_name: String = "Název Jednotky"
@export_multiline var description: String = "Popis jednotky."

@export var faction: Faction = Faction.PLAYER

@export var max_health: int = 10
@export var attack_damage: int = 2
@export var movement_range: int = 3
@export var attack_range: int = 1
# max_action_points bylo odstraněno

@export var sprite_texture: Texture2D

func _init(p_id: String = "", p_name: String = "Jednotka", p_max_health: int = 10, p_sprite: Texture2D = null):
	unit_id = p_id
	unit_name = p_name
	max_health = p_max_health
	sprite_texture = p_sprite
