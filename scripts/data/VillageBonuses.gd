# Soubor: scripts/data/VillageBonuses.gd
# Loop Vesnice — definice budov, ceny, bonusy do runu.
class_name VillageBonuses
extends RefCounted

const WELL := "well"
const MARKET := "market"
const LIBRARY := "library"
const CHAPEL := "chapel"

const BUILDING_ORDER: Array[String] = [WELL, MARKET, LIBRARY, CHAPEL]

const DEFS := {
	WELL: {"max_level": 5, "base_cost": 8, "hp_per_level": 4},
	MARKET: {"max_level": 5, "base_cost": 6, "gold_per_level": 8},
	LIBRARY: {"max_level": 5, "base_cost": 10},
	CHAPEL: {"max_level": 3, "base_cost": 12, "block_per_level": 2},
}

const BASE_REWARD_CARDS := 3
const BASE_SHOP_CARDS := 3
const BASE_RARE_CHANCE := 0.1
const BASE_EPIC_CHANCE := 0.05
const BASE_LEGENDARY_CHANCE := 0.02

static func get_def(building_id: String) -> Dictionary:
	return DEFS.get(building_id, {})

static func get_level(building_id: String) -> int:
	if not SaveManager or not SaveManager.meta_progress:
		return 0
	return SaveManager.meta_progress.get_building_level(building_id)

static func get_max_level(building_id: String) -> int:
	return int(get_def(building_id).get("max_level", 0))

static func get_upgrade_cost(building_id: String) -> int:
	var level := get_level(building_id)
	var max_lv := get_max_level(building_id)
	if level >= max_lv:
		return 0
	var base_cost := int(get_def(building_id).get("base_cost", 10))
	return base_cost * (level + 1)

static func can_upgrade(building_id: String) -> bool:
	if not SaveManager or not SaveManager.meta_progress:
		return false
	var level := get_level(building_id)
	if level >= get_max_level(building_id):
		return false
	return SaveManager.meta_progress.shards >= get_upgrade_cost(building_id)

static func try_upgrade(building_id: String) -> bool:
	if not can_upgrade(building_id):
		return false
	var cost := get_upgrade_cost(building_id)
	if not SaveManager.spend_shards(cost):
		return false
	SaveManager.meta_progress.set_building_level(building_id, get_level(building_id) + 1)
	SaveManager.save_meta_progress()
	return true

static func get_max_hp_bonus() -> int:
	return get_level(WELL) * int(get_def(WELL).get("hp_per_level", 4))

static func get_starting_gold_bonus() -> int:
	return get_level(MARKET) * int(get_def(MARKET).get("gold_per_level", 8))

static func get_battle_start_block() -> int:
	return get_level(CHAPEL) * int(get_def(CHAPEL).get("block_per_level", 2))

static func get_reward_card_count() -> int:
	var lib := get_level(LIBRARY)
	if lib >= 5:
		return 5
	if lib >= 1:
		return 4
	return BASE_REWARD_CARDS

static func get_shop_card_count() -> int:
	if get_level(LIBRARY) >= 3:
		return BASE_SHOP_CARDS + 1
	return BASE_SHOP_CARDS

static func get_rare_card_chance() -> float:
	var chance := BASE_RARE_CHANCE
	var lib := get_level(LIBRARY)
	if lib >= 2:
		chance += 0.05
	if lib >= 4:
		chance += 0.05
	return chance

static func get_epic_card_chance() -> float:
	var chance := BASE_EPIC_CHANCE
	if get_level(LIBRARY) >= 4:
		chance += 0.03
	return chance

static func get_legendary_card_chance() -> float:
	var chance := BASE_LEGENDARY_CHANCE
	if get_level(LIBRARY) >= 5:
		chance += 0.02
	return chance

## DEPRECATED alias — Uncommon rarity cancelled; maps to epic chance for old call sites.
static func get_uncommon_chance() -> float:
	return get_epic_card_chance()

static func shards_for_encounter(encounter_type: int) -> int:
	match encounter_type:
		EncounterData.EncounterType.ELITE:
			return 3
		EncounterData.EncounterType.BOSS:
			return 8
		_:
			return 1

static func _tr(key: String) -> String:
	return TranslationServer.translate(key)

static func get_building_name(building_id: String) -> String:
	return _tr("village.building.%s.name" % building_id)

static func get_current_effect_text(building_id: String) -> String:
	var level := get_level(building_id)
	if level <= 0:
		return _tr("village.effect.none")
	match building_id:
		WELL:
			return TranslationHelper.tr_format("village.effect.well_current", {"value": get_max_hp_bonus()})
		MARKET:
			return TranslationHelper.tr_format("village.effect.market_current", {"value": get_starting_gold_bonus()})
		LIBRARY:
			return _library_current_text(level)
		CHAPEL:
			return TranslationHelper.tr_format("village.effect.chapel_current", {"value": get_battle_start_block()})
	return ""

static func get_next_effect_text(building_id: String) -> String:
	var level := get_level(building_id)
	var max_lv := get_max_level(building_id)
	if level >= max_lv:
		return _tr("village.effect.maxed")
	match building_id:
		WELL:
			return TranslationHelper.tr_format("village.effect.well_next", {"value": int(get_def(WELL).get("hp_per_level", 4))})
		MARKET:
			return TranslationHelper.tr_format("village.effect.market_next", {"value": int(get_def(MARKET).get("gold_per_level", 8))})
		LIBRARY:
			return _library_next_text(level + 1)
		CHAPEL:
			return TranslationHelper.tr_format("village.effect.chapel_next", {"value": int(get_def(CHAPEL).get("block_per_level", 2))})
	return ""

static func _library_current_text(level: int) -> String:
	var parts: PackedStringArray = []
	if level >= 1:
		parts.append(TranslationHelper.tr_format("village.effect.library_choices", {"value": get_reward_card_count()}))
	if level >= 2:
		parts.append(TranslationHelper.tr_format("village.effect.library_rare", {"value": int(round(get_rare_card_chance() * 100))}))
	if level >= 3:
		parts.append(TranslationHelper.tr_format("village.effect.library_shop", {"value": get_shop_card_count()}))
	if level >= 4:
		parts.append(TranslationHelper.tr_format("village.effect.library_epic", {"value": int(round(get_epic_card_chance() * 100))}))
	return ", ".join(parts)

static func _library_next_text(next_level: int) -> String:
	match next_level:
		1:
			return _tr("village.effect.library_next_1")
		2:
			return _tr("village.effect.library_next_2")
		3:
			return _tr("village.effect.library_next_3")
		4:
			return _tr("village.effect.library_next_4")
		5:
			return _tr("village.effect.library_next_5")
	return ""
