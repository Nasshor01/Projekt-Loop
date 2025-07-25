# Soubor: data/terrain/TerrainData.gd
# POPIS: Základní datová struktura pro všechny typy terénu na bojišti.
class_name TerrainData
extends Resource

# --- Základní vlastnosti ---
@export var terrain_id: String = "unique_terrain_id"
@export var terrain_name: String = "Název Terénu"
@export_multiline var description: String = "Popis, co tento terén dělá."
@export var sprite: Texture2D # Jak terén vypadá na mřížce

# --- Herní pravidla ---
@export var is_walkable: bool = true # Může se přes to chodit?
@export var blocks_line_of_sight: bool = false # Blokuje to výhled? (pro budoucí střely)

# --- Efekty (to nejdůležitější!) ---
# Seznam efektů, které terén může mít. Můžeme jich později přidat více.
enum TerrainEffect {
	NONE,
	APPLY_STATUS_ON_ENTER, # Aplikuje status na jednotku, která na políčko vstoupí
	MODIFY_DEFENSE_ON_TILE, # Přidá bonus/postih k obraně, dokud jednotka stojí na políčku
	MODIFY_ATTACK_ON_TILE, # Přidá bonus/postih k útoku
	CHANCE_TO_MISS_TARGET # Zvyšuje šanci, že útok na jednotku na tomto políčku mine
}
@export var effect_type: TerrainEffect = TerrainEffect.NONE

# Hodnoty pro efekty
@export var effect_string_value: String = "" # Např. ID statusu jako "vulnerable" nebo "haste"
@export var effect_numeric_value: int = 0 # Např. +2 k bloku, nebo 20% šance na minutí
@export var effect_duration: int = 1 # Jak dlouho status trvá (v kolech)
