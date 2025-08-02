# ===================================================================
# Soubor: res://data/cards/CardEffectData.gd
# ===================================================================
class_name CardEffectData
extends Resource

enum EffectType {
	DEAL_DAMAGE,            # Způsobí poškození
	DEAL_DAMAGE_FROM_BLOCK, # Způsobí poškození dle bloku
	GAIN_BLOCK,             # Získá blok
	DRAW_CARDS,             # Lízne karty
	GAIN_ENERGY,            # Získá energii
	APPLY_STATUS,           # Aplikuje stavový efekt
	SUMMON_UNIT,            # Vyvolá jednotku
	HEAL_UNIT,              # Vyléčí jednotku
	HEAL_TO_FULL,           # Vyléčí do plných životů
	EXHAUST,                # Karta zmizí
	GAIN_EXTRA_MOVE,         # Získá další pohybovou akci v tomto kole
	DEAL_DOUBLE_DAMAGE_FROM_BLOCK #způsobí double požkození z aktuálního bloku
}

enum TargetType {
	SELF_UNIT,
	SELECTED_ENEMY_UNIT,
	SELECTED_ALLY_UNIT,
	ALL_ENEMY_UNITS,
	ALL_ALLY_UNITS,
	EMPTY_GRID_CELL,
	ANY_GRID_CELL
}

enum AreaOfEffectType {
	SINGLE_TARGET,
	ROW,
	COLUMN,
	SQUARE_X_BY_Y,
	ALL_ON_GRID
}

@export var effect_type: EffectType = EffectType.DEAL_DAMAGE
@export var value: int = 0
@export var string_value: String = ""
@export var target_type: TargetType = TargetType.SELECTED_ENEMY_UNIT
@export var area_of_effect_type: AreaOfEffectType = AreaOfEffectType.SINGLE_TARGET
@export var aoe_param_x: int = 1
@export var aoe_param_y: int = 1
