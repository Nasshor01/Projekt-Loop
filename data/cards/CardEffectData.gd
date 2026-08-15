# ===================================================================
# Soubor: res://data/cards/CardEffectData.gd
# ===================================================================
class_name CardEffectData
extends Resource

# ENUM INTEGRITY RULE: NEVER insert new elements into the middle of this enum.
# New effects MUST ALWAYS be added at the end to preserve integer indexes in existing .tres resources.
# If reorganizing, manually update all affected .tres files.
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
	DEAL_DOUBLE_DAMAGE_FROM_BLOCK,  #způsobí double požkození z aktuálního bloku
	MODIFY_INITIATIVE_NEXT_ROUND,
	PLACE_TERRAIN,            # Položí TerrainData na prázdné políčko (string_value = resource path)
	PUSH,                     # Odstrčí cíl o `value` polí pryč od castera (hráče)
	PULL,                     # Přitáhne cíl o `value` polí k casterovi (pathing / closest step)
	TAUNT,                    # Pull `value` (min 1) + status "taunted" (duration = aoe_param_x, default 1)
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

# Typ poškození pro systém efektivity
enum DamageType {
	NORMAL,     # Běžné fyzické poškození
	HOLY,       # Svaté poškození (silné proti UNDEAD, DEMON)
	FIRE,       # Ohnivé poškození
	ICE,        # Ledové poškození
	LIGHTNING,  # Bleskové poškození
	POISON,     # Jedovaté poškození
	ARCANE      # Tajemné/arčanské poškození
}
@export var damage_type: DamageType = DamageType.NORMAL

enum EffectTrigger {
	ON_PLAY,
	ON_DRAW,
	END_OF_TURN,
}
@export var trigger: EffectTrigger = EffectTrigger.ON_PLAY

# Podmíněné efekty
@export var has_condition: bool = false
@export var condition_type: String = ""  # "block_above", "block_below", "health_below_percent", "health_above_percent", "target_has_debuff", "damage_per_block", "took_damage_last_turn", "target_health_above_percent"
@export var condition_value: int = 0  # Hodnota pro podmínku (např. 20 bloku, 50% zdraví)
@export var conditional_bonus_value: int = 0  # Bonusová hodnota, pokud je podmínka splněna
