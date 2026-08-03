# Soubor: data/artifacts/ArtifactsData.gd
@tool
class_name ArtifactsData
extends Resource

## Stable id (snake_case) used by behaviors, saves, DevConsole.
@export var artifact_id: String = ""

## Základní informace
@export var artifact_name: String = "Unknown Artifact"
@export_multiline var description: String = ""
@export var texture: Texture2D

## Path to ArtifactBehavior script, e.g. res://data/artifacts/behaviors/forbidden_apple.gd
@export_file("*.gd") var behavior_script: String = ""

enum ArtifactType {
	COMMON,
	UNCOMMON,
	RARE,
	LEGENDARY,
	CURSED,
	BOSS,
	EVENT
}
@export var artifact_type: ArtifactType = ArtifactType.COMMON

## Legacy trigger/effect fields kept for .tres compatibility; behaviors own logic.
enum TriggerType {
	PASSIVE,
	START_OF_COMBAT,
	START_OF_TURN,
	END_OF_TURN,
	ON_CARD_PLAYED,
	ON_DAMAGE_TAKEN,
	ON_DAMAGE_DEALT,
	ON_BLOCK_GAINED,
	ON_HEAL,
	ON_ENEMY_DEATH,
	ON_HEALTH_LOW,
	ON_ENERGY_SPENT,
	ON_DRAW_CARDS,
	CONDITIONAL,
	BEHAVIOR
}
@export var trigger_type: TriggerType = TriggerType.BEHAVIOR

enum EffectType {
	MODIFY_MAX_HP,
	MODIFY_MAX_ENERGY,
	MODIFY_CARD_DAMAGE,
	MODIFY_BLOCK_GAIN,
	MODIFY_HEAL_AMOUNT,
	GAIN_BLOCK,
	GAIN_ENERGY,
	DEAL_DAMAGE,
	HEAL_HP,
	DRAW_CARDS,
	THORNS_DAMAGE,
	CRITICAL_CHANCE,
	EXTRA_TURN_DRAW,
	RETAIN_ENERGY,
	DUPLICATE_CARD,
	CURSE_DRAW,
	REDUCE_HAND_SIZE,
	ENERGY_LOSS,
	FRAIL_EFFECT,
	VULNERABLE_EFFECT,
	TRANSFORM_CARDS,
	COPY_LAST_PLAYED,
	RANDOM_CARD_COST,
	CHAIN_LIGHTNING,
	RESURRECT_ONCE,
	ARTIFACT_SYNERGY,
	SCALING_EFFECT,
	CONDITIONAL_TRIGGER,
	BEHAVIOR
}
@export var effect_type: EffectType = EffectType.BEHAVIOR

@export var primary_value: int = 0
@export var secondary_value: int = 0
@export var percentage_based: bool = false

@export_group("Podmínky a Vlastnosti")
@export var uses_per_combat: int = -1
@export var current_uses: int = 0
@export var is_stackable: bool = false
@export var max_stacks: int = 1
@export var current_stacks: int = 1
@export var synergy_set_id: String = ""
@export var condition_type: String = ""
@export var condition_value: int = 0
@export var custom_effect_id: String = ""
@export var effect_description: String = ""
## If false, excluded from live reward/shop pools (co-op fusion / cut content).
@export var in_live_pool: bool = true

func can_trigger() -> bool:
	if uses_per_combat > 0 and current_uses >= uses_per_combat:
		return false
	return true

func use_artifact() -> void:
	if uses_per_combat > 0:
		current_uses += 1

func reset_for_new_combat() -> void:
	current_uses = 0

func add_stack() -> bool:
	if current_stacks < max_stacks:
		current_stacks += 1
		return true
	return false

func get_effective_value() -> int:
	var base_value = primary_value * current_stacks
	if percentage_based and PlayerData:
		return int((PlayerData.max_hp * base_value) / 100.0)
	return base_value

func get_effective_secondary_value() -> int:
	var base_value = secondary_value * current_stacks
	if percentage_based and PlayerData:
		return int((PlayerData.max_hp * base_value) / 100.0)
	return base_value

func get_localized_name() -> String:
	return tr(artifact_name)

func get_localized_description() -> String:
	return tr(description)

func check_condition(context: Dictionary = {}) -> bool:
	if condition_type.is_empty():
		return true
	match condition_type:
		"health_below":
			var current_hp = context.get("current_hp", PlayerData.current_hp if PlayerData else 0)
			var max_hp = context.get("max_hp", PlayerData.max_hp if PlayerData else 1)
			return (current_hp * 100 / maxi(1, max_hp)) <= condition_value
		"health_above":
			var current_hp = context.get("current_hp", PlayerData.current_hp if PlayerData else 0)
			var max_hp = context.get("max_hp", PlayerData.max_hp if PlayerData else 1)
			return (current_hp * 100 / maxi(1, max_hp)) >= condition_value
		"energy_below":
			return int(context.get("current_energy", 0)) <= condition_value
		"energy_above":
			return int(context.get("current_energy", 0)) >= condition_value
		"cards_in_hand":
			return int(context.get("hand_size", 0)) >= condition_value
		"enemies_alive":
			return int(context.get("enemy_count", 0)) >= condition_value
		"turn_number":
			var turn = maxi(int(context.get("current_turn", 0)), int(context.get("turn_number", 0)))
			return turn > 0 and condition_value > 0 and (turn % condition_value) == 0
		"critical_hit":
			return bool(context.get("critical_hit", false))
		"start_of_combat":
			return bool(context.get("is_first_turn", false))
		_:
			return true

func get_formatted_description() -> String:
	var desc = tr(description)
	desc = desc.replace("{value}", str(get_effective_value()))
	desc = desc.replace("{value2}", str(get_effective_secondary_value()))
	desc = desc.replace("{stacks}", str(current_stacks))
	if max_stacks > 1:
		desc += " " + TranslationHelper.tr_format("artifact.stacks", {"current": current_stacks, "max": max_stacks})
	if uses_per_combat > 0:
		var remaining = uses_per_combat - current_uses
		desc += " " + TranslationHelper.tr_format("artifact.uses", {"current": remaining, "max": uses_per_combat})
	return desc

func get_rarity_color() -> Color:
	match artifact_type:
		ArtifactType.COMMON: return Color.WHITE
		ArtifactType.UNCOMMON: return Color.LIME_GREEN
		ArtifactType.RARE: return Color.DODGER_BLUE
		ArtifactType.LEGENDARY: return Color.ORANGE
		ArtifactType.CURSED: return Color.PURPLE
		ArtifactType.BOSS: return Color.CRIMSON
		ArtifactType.EVENT: return Color.GOLD
		_: return Color.WHITE

func is_negative() -> bool:
	return artifact_type == ArtifactType.CURSED

func create_behavior() -> ArtifactBehavior:
	if behavior_script.is_empty():
		return null
	var script_res = load(behavior_script)
	if script_res == null:
		push_warning("ArtifactBehavior script missing: %s" % behavior_script)
		return null
	var behavior: ArtifactBehavior = script_res.new()
	behavior.setup(self)
	return behavior
