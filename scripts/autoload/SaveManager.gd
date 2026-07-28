# Soubor: scripts/autoload/SaveManager.gd (Optimalizovaná verze)
extends Node

signal meta_progress_changed

const META_SAVE_PATH = "user://meta_progress.res"
const RUN_SAVE_PATH = "user://current_run.sav"
const VERSION_FILE_PATH = "user://last_version.cfg"

var meta_progress: MetaProgress

func _ready():
	_check_version_migration()
	load_meta_progress()

#==============================================================================
# Version Migration - automatický clean při nové verzi
#==============================================================================

func _check_version_migration():
	"""Zkontroluje verzi hry a pokud se změnila, provede clean reset save dat."""
	var current_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var saved_version = _get_saved_version()
	
	if saved_version == "" or saved_version != current_version:
		# Nová verze nebo první spuštění
		if saved_version != "":
			print("=== VERSION MIGRATION ===")
			print("Old version: %s -> New version: %s" % [saved_version, current_version])
			print("Performing clean reset of save data...")
			_perform_clean_reset()
		else:
			print("First launch detected (version %s). No migration needed." % current_version)
		
		_save_current_version(current_version)

func _get_saved_version() -> String:
	"""Přečte uloženou verzi z konfiguračního souboru."""
	var config = ConfigFile.new()
	var err = config.load(VERSION_FILE_PATH)
	if err != OK:
		return ""
	return config.get_value("version", "game_version", "")

func _save_current_version(version: String):
	"""Uloží aktuální verzi do konfiguračního souboru."""
	var config = ConfigFile.new()
	config.set_value("version", "game_version", version)
	config.set_value("version", "migration_date", Time.get_datetime_string_from_system())
	config.save(VERSION_FILE_PATH)

func _perform_clean_reset():
	"""Vymaže všechna save data (meta progress, run save, session lock)."""
	var dir = DirAccess.open("user://")
	if dir == null:
		printerr("SaveManager: Cannot open user:// directory for clean reset!")
		return
	
	# Seznam souborů k vymazání
	var files_to_delete = [
		"meta_progress.res",
		"current_run.sav",
		"session.lock",
	]
	
	for file_name in files_to_delete:
		if FileAccess.file_exists("user://" + file_name):
			var err = dir.remove(file_name)
			if err == OK:
				print("  Deleted: %s" % file_name)
			else:
				printerr("  Failed to delete: %s (error: %d)" % [file_name, err])
	
	# Zachováme settings.cfg (jazyk, report consent) - to nemažeme
	# Zachováme last_version.cfg - to právě zapisujeme
	# Zachováme debug logy - ty nejsou problém
	
	print("Clean reset complete. All save data has been cleared.")

#==============================================================================
# Meta Progress
#==============================================================================

func resolve_hero_id(hero_id: String = "") -> String:
	if not hero_id.is_empty():
		return hero_id
	if has_node("/root/PlayerData") and is_instance_valid(PlayerData.selected_subclass):
		var sid: String = str(PlayerData.selected_subclass.subclass_id)
		if not sid.is_empty():
			return sid
	if has_node("/root/GameManager") and is_instance_valid(GameManager.selected_subclass_data):
		var sid2: String = str(GameManager.selected_subclass_data.subclass_id)
		if not sid2.is_empty():
			return sid2
	return "paladin"

func get_xp_for_next_level(hero_id: String = "") -> int:
	# Plynulejší progrese: L1->L2 = 80 XP, L5->L6 = 200 XP, L10->L11 = 350 XP
	hero_id = resolve_hero_id(hero_id)
	return 50 + meta_progress.get_hero_level(hero_id) * 30

func _check_for_level_up(hero_id: String = ""):
	hero_id = resolve_hero_id(hero_id)
	var level := meta_progress.get_hero_level(hero_id)
	var xp := meta_progress.get_hero_xp(hero_id)
	var xp_needed := 50 + level * 30
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		# Skill tree vypnutý — body se neudělují
		print("GRATULACE! %s postoupil na level %d." % [hero_id, level])
		xp_needed = 50 + level * 30
	meta_progress.set_hero_progress(hero_id, level, xp)
	# Legacy mirror (current hero) for old debug/UI readers
	meta_progress.player_level = level
	meta_progress.total_xp = xp

func save_meta_progress():
	var error = ResourceSaver.save(meta_progress, META_SAVE_PATH)
	if error != OK:
		DebugLogger.log_error("Failed to save meta progress! Error: %d" % error, "SAVE")
	else:
		var hero_id := resolve_hero_id()
		DebugLogger.log_save_load(
			"save_meta_progress",
			true,
			"Hero %s Level: %d, XP: %d" % [hero_id, meta_progress.get_hero_level(hero_id), meta_progress.get_hero_xp(hero_id)]
		)
	emit_signal("meta_progress_changed")

func load_meta_progress():
	if ResourceLoader.exists(META_SAVE_PATH):
		meta_progress = ResourceLoader.load(META_SAVE_PATH)
	else:
		meta_progress = MetaProgress.new()
		print("Žádná uložená data nenalezena, vytvářím nová.")
	var dirty := false
	if meta_progress and meta_progress.clear_skill_tree_progress():
		print("SaveManager: vyčištěn legacy skill tree progress.")
		dirty = true
	if meta_progress and meta_progress.migrate_legacy_hero_progress():
		print("SaveManager: migrován shared level na per-hero progress.")
		dirty = true
	if dirty:
		save_meta_progress()
	emit_signal("meta_progress_changed")

func add_xp(amount: int, hero_id: String = ""):
	if amount <= 0:
		return
	hero_id = resolve_hero_id(hero_id)
	var level := meta_progress.get_hero_level(hero_id)
	var xp := meta_progress.get_hero_xp(hero_id) + amount
	meta_progress.set_hero_progress(hero_id, level, xp)
	_check_for_level_up(hero_id)
	save_meta_progress()

func add_shards(amount: int) -> void:
	"""Přidá Střepy do meta progresu (Loop Vesnice). Tutoriál nic nepřidá."""
	if amount <= 0:
		return
	if has_node("/root/GameManager") and GameManager.tutorial_active:
		return
	if not meta_progress:
		return
	meta_progress.shards += amount
	if has_node("/root/PlayerData"):
		PlayerData.current_run_shards += amount
	DebugLogger.log_info("Shards +%d (total %d, run %d)" % [amount, meta_progress.shards, PlayerData.current_run_shards], "PROGRESSION")
	save_meta_progress()

func spend_shards(amount: int) -> bool:
	if amount <= 0:
		return true
	if not meta_progress or meta_progress.shards < amount:
		return false
	meta_progress.shards -= amount
	save_meta_progress()
	return true

func get_shards() -> int:
	if not meta_progress:
		return 0
	return meta_progress.shards

func recalculate_skill_points():
	"""Legacy no-op — skill tree je vypnutý."""
	if not meta_progress:
		return
	meta_progress.clear_skill_tree_progress()
	save_meta_progress()
	emit_signal("meta_progress_changed")

#==============================================================================
# Run Progress
#==============================================================================

func save_run(player_data: PlayerData):
	var file = FileAccess.open(RUN_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		DebugLogger.log_error("Failed to open save file for writing.", "SAVE")
		return

	# Uložíme resource paths pro třídu a podtřídu
	var class_path = ""
	var subclass_path = ""
	if is_instance_valid(player_data.selected_class):
		class_path = player_data.selected_class.resource_path
	if is_instance_valid(player_data.selected_subclass):
		subclass_path = player_data.selected_subclass.resource_path

	# Uložíme path_taken jako row a column každého uzlu
	var path_taken_data = []
	for node in player_data.path_taken:
		if is_instance_valid(node):
			path_taken_data.append({
				"row": node.row,
				"column": node.column
			})

	var data_to_save = {
		"current_hp": player_data.current_hp,
		"max_hp": player_data.max_hp,
		"gold": player_data.gold,
		"master_deck": player_data.master_deck.map(func(card): return card.resource_path),
		"artifacts": player_data.artifacts.map(func(artifact): return artifact.resource_path),
		"floors_cleared": player_data.floors_cleared,
		"loop_level": player_data.loop_level,  # Ukládáme jako loop_level, ale načítáme i staré "ng_plus_level" pro kompatibilitu
		"current_run_xp": player_data.current_run_xp,
		"selected_class_path": class_path,
		"selected_subclass_path": subclass_path,
		"current_seed": GameManager.current_seed,
		"path_taken": path_taken_data,
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

#==============================================================================
# Tutorial Progress
#==============================================================================

func is_tutorial_completed() -> bool:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err != OK:
		return false
	return bool(config.get_value("settings", "tutorial_completed", false))

func set_tutorial_completed(value: bool):
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err != OK:
		config = ConfigFile.new()
	config.set_value("settings", "tutorial_completed", value)
	config.save("user://settings.cfg")
