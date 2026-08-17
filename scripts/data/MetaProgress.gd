# Soubor: scripts/data/MetaProgress.gd
class_name MetaProgress
extends Resource

## Legacy shared XP/level — kept for save migration; prefer hero_progress.
@export var total_xp: int = 0
@export var player_level: int = 1

## Per-hero meta XP. Keys = subclass_id ("paladin", "trapper", ...).
## Value = { "level": int, "xp": int }
@export var hero_progress: Dictionary = {}

# Legacy — pasivní skill tree je vypnutý; pole se při loadu čistí.
@export var skill_points: int = 0
@export var allocated_skills: Dictionary = {}

@export var unlocked_cards: Array[String] = []

## Loop Vesnice meta currency (Střepy).
@export var shards: int = 0
## building_id -> level (int)
@export var building_levels: Dictionary = {}

## Hero ids that may be dispatched. Paladin is always treated as unlocked.
@export var unlocked_heroes: Array[String] = ["paladin"]
## Unique story events the player already went through (never spawn again).
@export var consumed_one_shot_events: Array[String] = []

## 0 = legacy save (před village splitem). Musí sedět se SaveManager.META_SCHEMA_VERSION.
@export var schema_version: int = 0

const DEFAULT_HERO_IDS: PackedStringArray = ["paladin", "trapper"]

func clear_skill_tree_progress() -> bool:
	var had_data := skill_points != 0 or not allocated_skills.is_empty()
	skill_points = 0
	allocated_skills.clear()
	return had_data

## One-time: copy old shared level into each known hero so nothing is lost.
func migrate_legacy_hero_progress() -> bool:
	if not hero_progress.is_empty():
		return false
	if player_level <= 1 and total_xp <= 0:
		return false
	for hero_id in DEFAULT_HERO_IDS:
		hero_progress[hero_id] = {"level": player_level, "xp": total_xp}
	return true

func migrate_unlocked_heroes() -> bool:
	if "paladin" in unlocked_heroes:
		return false
	unlocked_heroes.insert(0, "paladin")
	return true

func get_hero_entry(hero_id: String) -> Dictionary:
	if hero_id.is_empty():
		hero_id = "unknown"
	if not hero_progress.has(hero_id) or typeof(hero_progress[hero_id]) != TYPE_DICTIONARY:
		hero_progress[hero_id] = {"level": 1, "xp": 0}
	var entry: Dictionary = hero_progress[hero_id]
	if not entry.has("level"):
		entry["level"] = 1
	if not entry.has("xp"):
		entry["xp"] = 0
	hero_progress[hero_id] = entry
	return entry

func get_hero_level(hero_id: String) -> int:
	return int(get_hero_entry(hero_id).get("level", 1))

func get_hero_xp(hero_id: String) -> int:
	return int(get_hero_entry(hero_id).get("xp", 0))

func is_hero_unlocked(hero_id: String) -> bool:
	if hero_id.is_empty() or hero_id == "paladin":
		return true
	return hero_id in unlocked_heroes

func unlock_hero(hero_id: String) -> void:
	if hero_id.is_empty() or is_hero_unlocked(hero_id):
		return
	unlocked_heroes.append(hero_id)


func is_one_shot_event_consumed(event_id: String) -> bool:
	if event_id.is_empty():
		return false
	return event_id in consumed_one_shot_events


func consume_one_shot_event(event_id: String) -> bool:
	if event_id.is_empty() or is_one_shot_event_consumed(event_id):
		return false
	consumed_one_shot_events.append(event_id)
	return true

func set_hero_progress(hero_id: String, level: int, xp: int) -> void:
	hero_progress[hero_id] = {"level": max(1, level), "xp": max(0, xp)}

func get_building_level(building_id: String) -> int:
	return int(building_levels.get(building_id, 0))

func set_building_level(building_id: String, level: int) -> void:
	building_levels[building_id] = max(0, level)
