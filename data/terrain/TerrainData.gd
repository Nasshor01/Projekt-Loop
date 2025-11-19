# Soubor: data/terrain/TerrainData.gd
class_name TerrainData
extends Resource

# --- Základní vlastnosti ---
@export var terrain_id: String = "unique_terrain_id"
@export var terrain_name: String = "Název Terénu"
@export_multiline var description: String = "Popis, co tento terén dělá."
@export var sprite: Texture2D 

# --- 3D VIZUÁL (NOVÉ) ---
@export_group("3D Visuals")
@export var is_flat_on_ground: bool = true 
# TRUE = Bahno, Louže, Past (leží na podlaze jako textura)
# FALSE = Kámen, Strom, Zeď (stojí kolmo a otáčí se na kameru)

# --- Herní pravidla ---
@export_group("Rules")
@export var is_walkable: bool = true 
@export var blocks_line_of_sight: bool = false 
@export var movement_cost: int = 1 

# --- Efekty ---
enum TerrainEffect {
	NONE,
	APPLY_STATUS_ON_ENTER, 
	MODIFY_DEFENSE_ON_TILE, 
	MODIFY_ATTACK_ON_TILE, 
	CHANCE_TO_MISS_TARGET, 
	IMPASSABLE 
}
@export_group("Effects")
@export var effect_type: TerrainEffect = TerrainEffect.NONE
@export var effect_string_value: String = "" 
@export var effect_numeric_value: int = 0 
@export var effect_duration: int = 1
