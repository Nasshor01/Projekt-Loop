# ===================================================================
# DamageCalculator.gd - Central damage calculation for v0.2.0
# Additive logic: no multipliers, all bonuses are flat additions.
# ===================================================================
extends Node

## Returns display damage for card UI (base + global + artifact bonus only).
## Does NOT include Holy/Vulnerable/Critical/DefensiveStance (target-dependent).
func get_display_damage(base_value: int) -> int:
	if Engine.is_editor_hint():
		return base_value
	var total = base_value + PlayerData.global_card_damage_bonus
	if has_node("/root/ArtifactManager"):
		var context = {
			"current_hp": PlayerData.current_hp,
			"max_hp": PlayerData.max_hp,
			"current_energy": PlayerData.current_energy
		}
		total += ArtifactManager.get_card_damage_bonus(context)
	return max(0, total)

## Returns final damage using strictly additive logic.
## base_value: raw damage before any modifiers
## attacker: Unit or null (for card damage, pass player unit)
## target: Unit receiving damage (can be null for display-only)
## damage_type: CardEffectData.DamageType (HOLY=1, NORMAL=0, etc.)
## is_critical: if true, adds floor(base_value/2)
## include_card_bonuses: if true, adds global_card_damage_bonus + artifact bonus
## extra_additive: optional flat bonus (e.g. for Berserker rush, Archer aim)
func get_final_damage(
	base_value: int,
	attacker: Node,
	target: Node,
	damage_type: int,
	is_critical: bool = false,
	include_card_bonuses: bool = true,
	extra_additive: int = 0
) -> int:
	if not is_instance_valid(target):
		return base_value + extra_additive

	var total = base_value + extra_additive

	# Card bonuses (player skills + artifacts)
	if include_card_bonuses and not Engine.is_editor_hint():
		total += PlayerData.global_card_damage_bonus
		if has_node("/root/ArtifactManager"):
			var context = {
				"current_hp": PlayerData.current_hp,
				"max_hp": PlayerData.max_hp,
				"current_energy": PlayerData.current_energy
			}
			total += ArtifactManager.get_card_damage_bonus(context)

	# Holy damage: base +5 vs Undead/Demon (UnitData) + skill tree bonus (vždy při Holy útoku)
	if damage_type == 1:  # CardEffectData.DamageType.HOLY
		total += PlayerData.holy_damage_bonus
	if target and target is Unit and target.has_method("get_unit_data"):
		var target_data = target.get_unit_data()
		if target_data:
			var ut = target_data.unit_type
			if ut in [UnitData.UnitType.UNDEAD, UnitData.UnitType.DEMON]:
				var holy_bonus = UnitData.get_holy_damage_bonus(damage_type, ut)
				total += holy_bonus

	# Vulnerable: +50% incoming damage (Excommunication etc.)
	if target is Unit and target.active_statuses.has("vulnerable"):
		total = int(total * 1.5)

	# Critical: +floor(base_value/2)
	if is_critical:
		total += base_value / 2

	# Defensive Stance: 50% less damage (card description: "The next attack against you deals 50% less damage")
	if target is Unit and target.active_statuses.has("defensive_stance"):
		total = int(total * 0.5)

	return max(1, total)
