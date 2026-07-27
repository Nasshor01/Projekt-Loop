# Soubor: scripts/data/MetaProgress.gd
class_name MetaProgress
extends Resource

@export var total_xp: int = 0
@export var player_level: int = 1

# Legacy — pasivní skill tree je vypnutý; pole se při loadu čistí.
@export var skill_points: int = 0
@export var allocated_skills: Dictionary = {}

@export var unlocked_cards: Array[String] = []

## Loop Vesnice meta currency (Střepy).
@export var shards: int = 0
## building_id -> level (int)
@export var building_levels: Dictionary = {}

func clear_skill_tree_progress() -> bool:
	var had_data := skill_points != 0 or not allocated_skills.is_empty()
	skill_points = 0
	allocated_skills.clear()
	return had_data

func get_building_level(building_id: String) -> int:
	return int(building_levels.get(building_id, 0))

func set_building_level(building_id: String, level: int) -> void:
	building_levels[building_id] = max(0, level)
