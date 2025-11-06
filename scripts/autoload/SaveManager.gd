# Soubor: scripts/autoload/SaveManager.gd (Optimalizovaná verze)
extends Node

signal meta_progress_changed

const META_SAVE_PATH = "user://meta_progress.res"
const RUN_SAVE_PATH = "user://current_run.sav"

var meta_progress: MetaProgress

func _ready():
	load_meta_progress()

#==============================================================================
# Meta Progress
#==============================================================================

func get_xp_for_next_level() -> int:
	return meta_progress.player_level * 100

func _check_for_level_up():
	var xp_needed = get_xp_for_next_level()
	while meta_progress.total_xp >= xp_needed:
		meta_progress.total_xp -= xp_needed
		meta_progress.player_level += 1
		meta_progress.skill_points += 1
		print("GRATULACE! Hráč postoupil na level %d." % meta_progress.player_level)
		xp_needed = get_xp_for_next_level()

func save_meta_progress():
	var error = ResourceSaver.save(meta_progress, META_SAVE_PATH)
	if error != OK:
		DebugLogger.log_error("Failed to save meta progress! Error: %d" % error, "SAVE")
	else:
		DebugLogger.log_save_load("save_meta_progress", true, "Level: %d, XP: %d" % [meta_progress.player_level, meta_progress.total_xp])
	emit_signal("meta_progress_changed")

func load_meta_progress():
	if ResourceLoader.exists(META_SAVE_PATH):
		meta_progress = ResourceLoader.load(META_SAVE_PATH)
	else:
		meta_progress = MetaProgress.new()
		print("Žádná uložená data nenalezena, vytvářím nová.")
	emit_signal("meta_progress_changed")

func add_xp(amount: int):
	if amount <= 0: return
	
	meta_progress.total_xp += amount
	_check_for_level_up()
	save_meta_progress()

#==============================================================================
# Run Progress
#==============================================================================

func save_run(player_data: PlayerData):
	var file = FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		DebugLogger.log_error("Failed to open save file for writing.", "SAVE")
		return

	var data_to_save = {
		"health": player_data.health,
		"max_health": player_data.max_health,
		"gold": player_data.gold,
		"master_deck": player_data.master_deck.map(func(card): return card.resource_path),
		"artifacts": player_data.artifacts.map(func(artifact): return artifact.resource_path),
		"floors_cleared": player_data.floors_cleared,
		"ng_plus_level": player_data.ng_plus_level,
		"current_run_xp": player_data.current_run_xp,
	}

	var json_string = JSON.stringify(data_to_save, "\t")
	file.store_string(json_string)
	file.close()
	DebugLogger.log_save_load("save_run", true, "Run data saved.")

func load_run() -> Dictionary:
	if not has_saved_run():
		return {}

	var file = FileAccess.open(RUN_SAVE_PATH, FileAccess.READ)
	if file == null:
		DebugLogger.log_error("Failed to open save file for reading.", "SAVE")
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		DebugLogger.log_error("Failed to parse run save JSON. Error: %d" % error, "SAVE")
		return {}

	DebugLogger.log_save_load("load_run", true, "Run data loaded.")
	return json.get_data()

func has_saved_run() -> bool:
	return FileAccess.file_exists(RUN_SAVE_PATH)

func delete_saved_run():
	if not has_saved_run():
		return

	var dir = DirAccess.open("user://")
	var error = dir.remove(RUN_SAVE_PATH.replace("user://", ""))
	if error != OK:
		DebugLogger.log_error("Failed to delete saved run file! Error: %d" % error, "SAVE")
	else:
		DebugLogger.log_save_load("delete_saved_run", true, "Saved run deleted.")
