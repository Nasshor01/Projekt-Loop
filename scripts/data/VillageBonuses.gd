# Soubor: scripts/data/VillageBonuses.gd
# Loop Vesnice — definice budov, ceny, bonusy do runu.
class_name VillageBonuses
extends RefCounted

const WELL := "well"
const MARKET := "market"
const LIBRARY := "library"
const CHAPEL := "chapel"
const TAVERN := "tavern"
const HUNTERS_LODGE := "hunters_lodge"
const HUNTER_DOSSIER_EVENT_ID := "hunter_dossier"

const BUILDING_ORDER: Array[String] = [WELL, MARKET, LIBRARY, CHAPEL, TAVERN]

const DEFS := {
	WELL: {"max_level": 5, "base_cost": 8, "heal_per_level": 2},
	MARKET: {"max_level": 5, "base_cost": 6, "gold_per_level": 8},
	LIBRARY: {"max_level": 3, "base_cost": 10},
	CHAPEL: {
		"max_level": 5,
		"base_cost": 12,
		"block_per_level": 2,
		"hero_id": "paladin",
		"required_hero_levels": [1, 3, 5, 8, 12],
	},
	TAVERN: {"max_level": 1, "base_cost": 15},
}

const CLASS_HERO := {
	CHAPEL: "paladin",
	HUNTERS_LODGE: "trapper",
}

const CHAPEL_UNLOCK_CARD_ID := "pious_defense"
const CHAPEL_UNLOCK_CARD_PATH := "res://data/cards/paladin/pious_defense.tres"

const BASE_REWARD_CARDS := 3
const BASE_SHOP_CARDS := 3
const BASE_SHOP_ARTIFACTS := 1
## STS2-ish combat reward bands (Common ≈ remainder).
## Rare≈STS Uncommon, Epic≈STS Rare, Legendary above Rare.
const BASE_RARE_CHANCE := 0.30
const BASE_EPIC_CHANCE := 0.12
const BASE_LEGENDARY_CHANCE := 0.03

static func is_meta_building(building_id: String) -> bool:
	return building_id in DEFS


static func get_required_hero_id(building_id: String) -> String:
	if CLASS_HERO.has(building_id):
		return String(CLASS_HERO[building_id])
	return String(get_def(building_id).get("hero_id", ""))


static func is_hero_unlocked(hero_id: String) -> bool:
	if hero_id.is_empty() or hero_id == "paladin":
		return true
	if not SaveManager or not SaveManager.meta_progress:
		return false
	if SaveManager.meta_progress.has_method("is_hero_unlocked"):
		return SaveManager.meta_progress.is_hero_unlocked(hero_id)
	return false


static func is_line_unlocked(building_id: String) -> bool:
	var hero_id := get_required_hero_id(building_id)
	if hero_id.is_empty():
		return true
	return is_hero_unlocked(hero_id)


static func get_current_hero_id() -> String:
	if PlayerData and is_instance_valid(PlayerData.selected_subclass) and "subclass_id" in PlayerData.selected_subclass:
		var sid := String(PlayerData.selected_subclass.subclass_id)
		if not sid.is_empty():
			return sid
	if SaveManager:
		return SaveManager.resolve_hero_id()
	return "paladin"


static func get_required_hero_level_for_next(building_id: String) -> int:
	var reqs: Variant = get_def(building_id).get("required_hero_levels", [])
	if not reqs is Array or reqs.is_empty():
		return 1
	var next_lv := get_level(building_id) + 1
	var idx := next_lv - 1
	if idx < 0 or idx >= reqs.size():
		return 1
	return int(reqs[idx])


static func meets_hero_level_gate(building_id: String) -> bool:
	var hero_id := get_required_hero_id(building_id)
	if hero_id.is_empty():
		return true
	if not SaveManager or not SaveManager.meta_progress:
		return false
	return SaveManager.meta_progress.get_hero_level(hero_id) >= get_required_hero_level_for_next(building_id)


static func is_reward_gated_card(card_id: String) -> bool:
	return card_id == CHAPEL_UNLOCK_CARD_ID


static func is_gated_card_unlocked(card_id: String) -> bool:
	if card_id == CHAPEL_UNLOCK_CARD_ID:
		return get_level(CHAPEL) >= 3
	return true


static func get_def(building_id: String) -> Dictionary:
	return DEFS.get(building_id, {})

static func get_level(building_id: String) -> int:
	if not SaveManager or not SaveManager.meta_progress:
		return 0
	var level := SaveManager.meta_progress.get_building_level(building_id)
	var max_lv := get_max_level(building_id)
	if max_lv > 0:
		return mini(level, max_lv)
	return level

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
	if not is_line_unlocked(building_id):
		return false
	var level := get_level(building_id)
	if level >= get_max_level(building_id):
		return false
	if not meets_hero_level_gate(building_id):
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

static func has_any_upgrades() -> bool:
	for building_id in BUILDING_ORDER:
		if get_level(building_id) > 0:
			return true
	return false

static func get_spent_shards_for_building(building_id: String) -> int:
	var level := get_level(building_id)
	if level <= 0:
		return 0
	var base_cost := int(get_def(building_id).get("base_cost", 10))
	return base_cost * level * (level + 1) / 2

static func get_total_spent_shards() -> int:
	var total := 0
	for building_id in BUILDING_ORDER:
		total += get_spent_shards_for_building(building_id)
	return total

static func try_reset_all_upgrades() -> int:
	if not has_any_upgrades():
		return 0
	if not SaveManager or not SaveManager.meta_progress:
		return 0
	var refund := get_total_spent_shards()
	for building_id in BUILDING_ORDER:
		SaveManager.meta_progress.set_building_level(building_id, 0)
	if refund > 0:
		SaveManager.add_shards(refund)
	else:
		SaveManager.save_meta_progress()
	return refund

static func get_max_hp_bonus() -> int:
	var hero := get_current_hero_id()
	if hero == "paladin":
		return get_chapel_hp_bonus(get_level(CHAPEL))
	return 0

static func get_chapel_hp_bonus(chapel_level: int) -> int:
	var hp := 0
	if chapel_level >= 1:
		hp += 8
	if chapel_level >= 5:
		hp += 8
	return hp

static func get_starting_gold_bonus() -> int:
	return get_level(MARKET) * int(get_def(MARKET).get("gold_per_level", 8))

static func get_battle_start_block() -> int:
	if get_current_hero_id() != "paladin":
		return 0
	return get_level(CHAPEL) * int(get_def(CHAPEL).get("block_per_level", 2))

static func get_battle_start_heal() -> int:
	return get_level(WELL) * int(get_def(WELL).get("heal_per_level", 2))

static func get_movement_bonus() -> int:
	if get_current_hero_id() != "paladin":
		return 0
	if get_level(CHAPEL) >= 4:
		return 1
	return 0

static func get_reward_card_count() -> int:
	return get_reward_card_count_at(get_level(LIBRARY))

static func get_reward_card_count_at(lib: int) -> int:
	## RewardScene has 4 CardSlots — never offer more than layout.
	if lib >= 1:
		return 4
	return BASE_REWARD_CARDS

static func get_shop_card_count() -> int:
	return get_shop_card_count_at(get_level(LIBRARY))

static func get_shop_card_count_at(lib: int) -> int:
	## ShopScene has 6 CardSlots — Library fills them gradually.
	if lib >= 3:
		return 6
	if lib >= 2:
		return 5
	if lib >= 1:
		return 4
	return BASE_SHOP_CARDS

## How many relic icons the shop fills (scene has 3 ArtifactSlots). Market unlocks more.
static func get_shop_artifact_count() -> int:
	return get_shop_artifact_count_at(get_level(MARKET))

static func get_shop_artifact_count_at(market: int) -> int:
	if market >= 3:
		return 3
	if market >= 1:
		return 2
	return BASE_SHOP_ARTIFACTS

static func get_rare_card_chance() -> float:
	return get_rare_card_chance_at(get_level(LIBRARY))

static func get_rare_card_chance_at(_lib: int = 0) -> float:
	return BASE_RARE_CHANCE

static func get_epic_card_chance() -> float:
	return get_epic_card_chance_at(get_level(LIBRARY))

static func get_epic_card_chance_at(_lib: int = 0) -> float:
	return BASE_EPIC_CHANCE

static func get_legendary_card_chance() -> float:
	return get_legendary_card_chance_at(get_level(LIBRARY))

static func get_legendary_card_chance_at(_lib: int = 0) -> float:
	return BASE_LEGENDARY_CHANCE

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

static func is_shop_stock_below_max() -> bool:
	return get_shop_card_count() < 6 or get_shop_artifact_count() < 3

static func is_reward_choices_below_max() -> bool:
	return get_reward_card_count() < 4

static func get_shop_village_hint_text() -> String:
	if not is_shop_stock_below_max():
		return ""
	var lib_level := get_level(LIBRARY)
	var market_level := get_level(MARKET)
	var needs_library := lib_level < get_max_level(LIBRARY)
	var needs_market := market_level < get_max_level(MARKET)
	if needs_library and needs_market:
		return _tr("ui.shop.village_hint_both")
	if needs_market:
		return _tr("ui.shop.village_hint_market")
	if needs_library:
		return _tr("ui.shop.village_hint_library")
	return ""

static func get_shop_empty_hint_text() -> String:
	return _tr("ui.shop.empty_stock")

static func get_reward_village_hint_text() -> String:
	if not is_reward_choices_below_max():
		return ""
	return _tr("ui.reward.village_hint_library")

static func _tr(key: String) -> String:
	return TranslationServer.translate(key)

static func get_building_name(building_id: String) -> String:
	return _tr("village.building.%s.name" % building_id)

static func get_current_effect_text(building_id: String) -> String:
	var level := get_level(building_id)
	if level <= 0:
		if building_id == MARKET:
			return TranslationHelper.tr_format("village.effect.market_relics", {"value": get_shop_artifact_count()})
		return _tr("village.effect.none")
	match building_id:
		WELL:
			return TranslationHelper.tr_format("village.effect.well_heal_current", {"value": get_battle_start_heal()})
		MARKET:
			return _market_current_text()
		LIBRARY:
			return _library_current_text(level)
		CHAPEL:
			return TranslationHelper.tr_format("village.effect.chapel_current", {"value": get_battle_start_block()})
		TAVERN:
			return ", ".join(_tavern_current_lines(level))
	return ""

static func get_next_effect_text(building_id: String) -> String:
	var level := get_level(building_id)
	var max_lv := get_max_level(building_id)
	if level >= max_lv:
		return _tr("village.effect.maxed")
	match building_id:
		WELL:
			return TranslationHelper.tr_format("village.effect.well_heal_next", {"value": int(get_def(WELL).get("heal_per_level", 2))})
		MARKET:
			return _market_next_text(level + 1)
		LIBRARY:
			return _library_next_text(level + 1)
		CHAPEL:
			return TranslationHelper.tr_format("village.effect.chapel_next", {"value": int(get_def(CHAPEL).get("block_per_level", 2))})
		TAVERN:
			return " · ".join(_tavern_gain_lines(level + 1))
	return ""

static func _market_current_text() -> String:
	var parts: PackedStringArray = []
	var gold_bonus := get_starting_gold_bonus()
	if gold_bonus > 0:
		parts.append(TranslationHelper.tr_format("village.effect.market_current", {"value": gold_bonus}))
	parts.append(TranslationHelper.tr_format("village.effect.market_relics", {"value": get_shop_artifact_count()}))
	return ", ".join(parts)

static func _market_next_text(next_level: int) -> String:
	var parts: PackedStringArray = []
	parts.append(TranslationHelper.tr_format("village.effect.market_next", {"value": int(get_def(MARKET).get("gold_per_level", 8))}))
	match next_level:
		1:
			parts.append(_tr("village.effect.market_next_relics_2"))
		3:
			parts.append(_tr("village.effect.market_next_relics_3"))
	return ", ".join(parts)

static func _library_current_text(level: int) -> String:
	return ", ".join(_library_snapshot_lines(level))

static func _library_next_text(next_level: int) -> String:
	return " · ".join(_library_gain_lines(next_level))

static func _library_snapshot_lines(lib_level: int) -> PackedStringArray:
	if lib_level <= 0:
		return PackedStringArray([_tr("village.effect.none")])
	return PackedStringArray([
		TranslationHelper.tr_format("village.effect.library_choices", {"value": get_reward_card_count_at(lib_level)}),
		TranslationHelper.tr_format("village.effect.library_shop", {"value": get_shop_card_count_at(lib_level)}),
	])

static func _library_gain_lines(next_level: int) -> PackedStringArray:
	match next_level:
		1:
			return PackedStringArray([_tr("village.effect.library_gain_1")])
		2:
			return PackedStringArray([_tr("village.effect.library_gain_2")])
		3:
			return PackedStringArray([_tr("village.effect.library_gain_3")])
	return PackedStringArray()

static func _current_bonus_lines(building_id: String) -> PackedStringArray:
	var level := get_level(building_id)
	match building_id:
		WELL:
			if level <= 0:
				return PackedStringArray([_tr("village.effect.none")])
			return PackedStringArray([
				TranslationHelper.tr_format("village.effect.well_heal_current", {"value": get_battle_start_heal()})
			])
		MARKET:
			var parts: PackedStringArray = []
			var gold_bonus := get_starting_gold_bonus()
			if gold_bonus > 0:
				parts.append(TranslationHelper.tr_format("village.effect.market_current", {"value": gold_bonus}))
			parts.append(TranslationHelper.tr_format("village.effect.market_relics", {"value": get_shop_artifact_count()}))
			return parts
		LIBRARY:
			return _library_snapshot_lines(level)
		CHAPEL:
			return _chapel_current_lines(level)
		TAVERN:
			return _tavern_current_lines(level)
	return PackedStringArray([_tr("village.effect.none")])

static func _next_bonus_lines(building_id: String) -> PackedStringArray:
	var level := get_level(building_id)
	var max_lv := get_max_level(building_id)
	if level >= max_lv:
		return PackedStringArray([_tr("village.effect.maxed")])
	var next_level := level + 1
	match building_id:
		WELL:
			var gain := int(get_def(WELL).get("heal_per_level", 2))
			var total := next_level * gain
			return PackedStringArray([
				TranslationHelper.tr_format("village.effect.well_heal_next_detail", {"gain": gain, "total": total})
			])
		MARKET:
			var parts: PackedStringArray = []
			parts.append(TranslationHelper.tr_format("village.effect.market_gold_gain", {
				"value": int(get_def(MARKET).get("gold_per_level", 8))
			}))
			var relics_now := get_shop_artifact_count_at(level)
			var relics_next := get_shop_artifact_count_at(next_level)
			if relics_next > relics_now:
				parts.append(TranslationHelper.tr_format("village.effect.market_relics", {"value": relics_next}))
			return parts
		LIBRARY:
			return _library_gain_lines(next_level)
		CHAPEL:
			return _chapel_gain_lines(next_level)
		TAVERN:
			return _tavern_gain_lines(next_level)
	return PackedStringArray()

static func _tavern_current_lines(level: int) -> PackedStringArray:
	if level <= 0:
		return PackedStringArray([_tr("village.effect.none")])
	if is_hero_unlocked("trapper"):
		return PackedStringArray([_tr("village.effect.tavern_restored")])
	return PackedStringArray([_tr("village.effect.tavern_dossier_open")])


static func _tavern_gain_lines(next_level: int) -> PackedStringArray:
	if next_level == 1:
		return PackedStringArray([_tr("village.effect.tavern_gain_1")])
	return PackedStringArray()


static func get_trapper_lock_hint() -> String:
	if is_hero_unlocked("trapper"):
		return ""
	if get_level(TAVERN) < 1:
		return _tr("ui.char_select.trapper_locked_tavern")
	return _tr("ui.char_select.trapper_locked_dossier")


static func _chapel_current_lines(level: int) -> PackedStringArray:
	if level <= 0:
		return PackedStringArray([_tr("village.effect.none")])
	var parts: PackedStringArray = []
	var hp := get_chapel_hp_bonus(level)
	if hp > 0:
		parts.append(TranslationHelper.tr_format("village.effect.chapel_hp", {"value": hp}))
	parts.append(TranslationHelper.tr_format("village.effect.chapel_current", {
		"value": level * int(get_def(CHAPEL).get("block_per_level", 2))
	}))
	if level >= 2:
		parts.append(_tr("village.effect.chapel_starter_plus"))
	if level >= 3:
		parts.append(TranslationHelper.tr_format("village.effect.chapel_unlock_card", {
			"card": _tr("card.pious_defense")
		}))
	if level >= 4:
		parts.append(_tr("village.effect.chapel_move"))
	if level >= 5:
		parts.append(_tr("village.effect.chapel_relic_later"))
	return parts

static func _chapel_gain_lines(next_level: int) -> PackedStringArray:
	var block := int(get_def(CHAPEL).get("block_per_level", 2))
	var total_block := next_level * block
	var parts: PackedStringArray = [
		TranslationHelper.tr_format("village.effect.chapel_next_detail", {"gain": block, "total": total_block})
	]
	match next_level:
		1:
			parts.append(TranslationHelper.tr_format("village.effect.chapel_hp", {"value": 8}))
		2:
			parts.append(_tr("village.effect.chapel_starter_plus"))
		3:
			parts.append(TranslationHelper.tr_format("village.effect.chapel_unlock_card", {
				"card": _tr("card.pious_defense")
			}))
		4:
			parts.append(_tr("village.effect.chapel_move"))
		5:
			parts.append(TranslationHelper.tr_format("village.effect.chapel_hp", {"value": 8}))
			parts.append(_tr("village.effect.chapel_relic_later"))
	return parts

static func apply_starting_deck_bonuses(deck: Array) -> void:
	if get_current_hero_id() != "paladin":
		return
	var lv := get_level(CHAPEL)
	if lv >= 2:
		for i in range(deck.size()):
			var card: CardData = deck[i] as CardData
			if not is_instance_valid(card):
				continue
			if card.card_id == "defend" and is_instance_valid(card.upgraded_version):
				deck[i] = PlayerData.duplicate_card_for_deck(card.upgraded_version)
				break
	if lv >= 3:
		var already := false
		for card in deck:
			if card is CardData and (card as CardData).card_id == CHAPEL_UNLOCK_CARD_ID:
				already = true
				break
		if not already:
			var template: CardData = load(CHAPEL_UNLOCK_CARD_PATH) as CardData
			if is_instance_valid(template):
				deck.append(PlayerData.duplicate_card_for_deck(template))

static func _bbcode_escape(text: String) -> String:
	return text.replace("[", " ").replace("]", " ")

static func _bbcode_bullets(lines: PackedStringArray) -> String:
	var out: PackedStringArray = []
	for line in lines:
		if not line.is_empty():
			out.append("• %s" % _bbcode_escape(line))
	return "\n".join(out)

static func format_building_bbcode(building_id: String, detailed: bool) -> String:
	var name := _bbcode_escape(get_building_name(building_id))
	var parts: PackedStringArray = []
	if not detailed:
		parts.append("[b][color=#f0d060][font_size=30]%s[/font_size][/color][/b]" % name)
	if not is_line_unlocked(building_id):
		var desc := _tr("village.building.%s.desc" % building_id)
		if desc != "village.building.%s.desc" % building_id:
			parts.append("[color=#c5c9d6]%s[/color]" % _bbcode_escape(desc))
		var hero_id := get_required_hero_id(building_id)
		parts.append("[color=#e8b86a]%s[/color]" % _bbcode_escape(
			TranslationHelper.tr_format("village.line_locked", {"hero": _hero_display_name(hero_id)})
		))
		return "\n".join(parts)
	if not is_meta_building(building_id):
		var desc := _tr("village.building.%s.desc" % building_id)
		if desc != "village.building.%s.desc" % building_id:
			parts.append("[color=#c5c9d6]%s[/color]" % _bbcode_escape(desc))
		parts.append("[color=#e8b86a]%s[/color]" % _bbcode_escape(_tr("village.building.coming_soon")))
		return "\n".join(parts)

	var level := get_level(building_id)
	var max_lv := get_max_level(building_id)
	if not detailed:
		parts.append("[color=#c5c9d6]%s[/color]" % _bbcode_escape(
			TranslationHelper.tr_format("village.level", {"current": level, "max": max_lv})
		))
	if detailed:
		var desc := _tr("village.building.%s.desc" % building_id)
		if desc != "village.building.%s.desc" % building_id:
			parts.append("[color=#aeb4c4]%s[/color]" % _bbcode_escape(desc))

	parts.append("")
	parts.append("[color=#9aa3b5][b]%s[/b][/color]" % _bbcode_escape(_tr("village.ui.current")))
	parts.append(_bbcode_bullets(_current_bonus_lines(building_id)))

	parts.append("")
	if level >= max_lv:
		parts.append("[color=#9aa3b5][b]%s[/b][/color]" % _bbcode_escape(_tr("village.ui.next")))
		parts.append("[color=#a8e6a0]%s[/color]" % _bbcode_escape(_tr("village.effect.maxed")))
	else:
		var cost := get_upgrade_cost(building_id)
		parts.append("[color=#a8e6a0][b]%s[/b][/color]" % _bbcode_escape(
			TranslationHelper.tr_format("village.ui.next_cost", {"cost": cost})
		))
		if not meets_hero_level_gate(building_id):
			var hero_id := get_required_hero_id(building_id)
			parts.append("[color=#e8b86a]%s[/color]" % _bbcode_escape(
				TranslationHelper.tr_format("village.requires_hero_level", {
					"hero": _hero_display_name(hero_id),
					"level": get_required_hero_level_for_next(building_id)
				})
			))
		parts.append(_bbcode_bullets(_next_bonus_lines(building_id)))

	if not detailed:
		parts.append("")
		parts.append("[color=#8a90a0][i]%s[/i][/color]" % _bbcode_escape(_tr("village.ui.click_details")))
	return "\n".join(parts)


static func _hero_display_name(hero_id: String) -> String:
	var key := "class.%s" % hero_id
	var name := _tr(key)
	if name == key:
		return hero_id.capitalize()
	return name
