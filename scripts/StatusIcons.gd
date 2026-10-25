# Shared status id -> icon / stack number, used by UnitInfoPanel and the world HP bar.
class_name StatusIcons
extends RefCounted

const ICON_BURNING = preload("res://art/icons/status/Bleed.png")
const ICON_FREEZE = preload("res://art/icons/status/Freeze.png")
const ICON_SHOCKED = preload("res://art/icons/status/Stunned.png")
const ICON_SLOW = preload("res://art/icons/status/Slow_Down.png")
const ICON_STRENGTH = preload("res://art/icons/status/Strenght.png")
const ICON_REGENERATION = preload("res://art/icons/status/Regeneration.png")
const ICON_VULNERABLE = preload("res://art/icons/status/Vulnerable.png")
const ICON_AIMING = preload("res://art/icons/status/Aim.png")
const ICON_BLOCK = preload("res://art/icons/status/block.png")
const ICON_POISON = preload("res://art/icons/status/Poison.png")
const ICON_WEAKNESS = preload("res://art/icons/status/Weakness.png")
const ICON_THORNS = preload("res://art/icons/status/Thorns.png")
const ICON_RAGE = preload("res://art/icons/status/Rage_rush.png")
const ICON_LEECH = preload("res://art/icons/status/Leech.png")
const ICON_HOLY = preload("res://art/icons/status/holy_damage.png")
const ICON_BLOOD_ATTACK = preload("res://art/icons/status/Bleed_Atack.png")
const ICON_DISARM = preload("res://art/icons/status/Disarm.png")
const ICON_DEFAULT = preload("res://art/icons/status/Poison.png")

## Statuses whose meaningful number is the remaining turns, not the value.
const DURATION_COUNTED := ["shocked", "frozen", "entangled", "vulnerable", "taunted", "weakness", "silenced"]
## Statuses that are just on/off (aiming stores a damage percent + 999 duration).
const NO_COUNT := ["defensive_stance", "defensive_stance_turn", "aiming", "block_on_attack_carry", "radiance_vulnerable"]

static func get_icon(status_id: String) -> Texture2D:
	match status_id:
		"burning":
			return ICON_BURNING
		"chilled", "frozen":
			return ICON_FREEZE
		"shocked":
			return ICON_SHOCKED
		"entangled", "Slow":
			return ICON_SLOW
		"monk_blessing", "consecrated_weapon", "holy_edge":
			return ICON_STRENGTH
		"radiance_vulnerable":
			return ICON_HOLY
		"regeneration", "regeneration_permanent":
			return ICON_REGENERATION
		"vulnerable":
			return ICON_VULNERABLE
		"aiming":
			return ICON_AIMING
		"aura_devotion", "aura_devotion_plus", "defensive_stance", "defensive_stance_turn", "block_on_attack", "block_on_attack_carry":
			return ICON_BLOCK
		"weakness":
			return ICON_WEAKNESS
		"silenced":
			return ICON_DISARM
		"thorns":
			return ICON_THORNS
		"poison":
			return ICON_POISON
		"rage", "taunted", "fury":
			return ICON_RAGE
		"fury_engine":
			return ICON_BLOOD_ATTACK
		"radiance":
			return ICON_HOLY
		"leech":
			return ICON_LEECH
	return ICON_DEFAULT

## 0 = show the icon without a number.
static func get_stack_count(status_id: String, status_data: Dictionary) -> int:
	if NO_COUNT.has(status_id):
		return 0
	var value := int(status_data.get("value", 0))
	var duration := int(status_data.get("duration", 0))
	if DURATION_COUNTED.has(status_id):
		return maxi(0, duration)
	return value if value > 0 else maxi(0, duration)
