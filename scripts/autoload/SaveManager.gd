# Soubor: scripts/autoload/SaveManager.gd (Optimalizovaná verze)
extends Node

signal meta_progress_changed

const META_SAVE_PATH = "user://meta_progress.res"
const RUN_SAVE_PATH = "user://current_run.sav"
const VERSION_FILE_PATH = "user://last_version.cfg"

## Bump JEN když se mění formát / pravidla levelů nebo village (střepy, budovy).
## Bumpnutí game version (0.3.x) meta NEmaže.
const META_SCHEMA_VERSION: int = 1

var meta_progress: MetaProgress

func _ready():
	_check_version_migration()
	load_meta_progress()

#==============================================================================
# Version / schema migration
#==============================================================================

func _check_version_migration():
	"""Sleduje game version (bez wipe) a meta schema (wipe jen při záměrném bumpnutí)."""
	var current_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var config = ConfigFile.new()
	var had_config := config.load(VERSION_FILE_PATH) == OK
	var saved_version: String = config.get_value("version", "game_version", "") if had_config else ""
	# Chybějící klíč = starý save z éry „wipe při každé verzi“ → ber jako aktuální schema (nemazat).
	var saved_meta_schema: int = int(config.get_value("version", "meta_schema", META_SCHEMA_VERSION)) if had_config else META_SCHEMA_VERSION

	if saved_version != "" and saved_version != current_version:
		print("=== VERSION UPDATE ===")
		print("Old version: %s -> New version: %s (meta kept)" % [saved_version, current_version])
	elif saved_version == "":
		print("First launch detected (version %s)." % current_version)

	if saved_meta_schema != META_SCHEMA_VERSION:
		print("=== META SCHEMA MIGRATION ===")
		print("Old meta schema: %d -> New: %d" % [saved_meta_schema, META_SCHEMA_VERSION])
		print("Wiping meta progress (levels / village) only...")
		_wipe_meta_progress()

	_save_version_config(current_version)

func _save_version_config(version: String):
	"""Uloží game version + meta schema (settings / run save se nemění)."""
	var config = ConfigFile.new()
	config.load(VERSION_FILE_PATH)  # merge if exists
	config.set_value("version", "game_version", version)
	config.set_value("version", "meta_schema", META_SCHEMA_VERSION)
	config.set_value("version", "migration_date", Time.get_datetime_string_from_system())
	config.save(VERSION_FILE_PATH)

func _wipe_meta_progress():
	"""Smaže jen meta (levely, XP, střepy, village). Run save a settings nechá."""
	if not FileAccess.file_exists(META_SAVE_PATH):
		print("  No meta_progress.res to delete.")
		return
	var dir = DirAccess.open("user://")
	if dir == null:
		printerr("SaveManager: Cannot open user:// to wipe meta!")
		return
	var err = dir.remove("meta_progress.res")
	if err == OK:
		print("  Deleted: meta_progress.res")
	else:
		printerr("  Failed to delete meta_progress.res (error: %d)" % err)

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
		"artifacts": _serialize_artifacts(player_data.artifacts),
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
# Artifact save helpers (duplicates lose resource_path)
#==============================================================================

func _serialize_artifacts(artifacts: Array) -> Array:
	var out: Array = []
	for artifact in artifacts:
		if not is_instance_valid(artifact):
			continue
		var path: String = get_artifact_source_path(artifact)
		if path.is_empty():
			DebugLogger.log_warning("Save: artifact '%s' has no source path — skipped" % str(artifact.artifact_name), "SAVE")
			continue
		out.append({
			"path": path,
			"stacks": int(artifact.current_stacks),
		})
	return out

func get_artifact_source_path(artifact: ArtifactsData) -> String:
	if not is_instance_valid(artifact):
		return ""
	var path: String = artifact.resource_path
	if _is_valid_res_path(path):
		return path
	if artifact.has_meta("source_path"):
		path = str(artifact.get_meta("source_path"))
		if _is_valid_res_path(path):
			return path
	return _find_artifact_path_by_name(str(artifact.artifact_name))

func _is_valid_res_path(path: String) -> bool:
	return not path.is_empty() and path != "res://" and ResourceLoader.exists(path)

func _find_artifact_path_by_name(artifact_name: String) -> String:
	if artifact_name.is_empty():
		return ""
	var roots: Array[String] = [
		"res://data/artifacts/common",
		"res://data/artifacts/uncommon",
		"res://data/artifacts/rare",
		"res://data/artifacts/legendary",
		"res://data/artifacts/boss",
		"res://data/artifacts/event",
	]
	for root in roots:
		var dir := DirAccess.open(root)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full: String = root.path_join(file_name)
				var res = load(full)
				if res is ArtifactsData and res.artifact_name == artifact_name:
					return full
			file_name = dir.get_next()
		dir.list_dir_end()
	return ""

func load_artifact_instances(raw_list: Array) -> Array[ArtifactsData]:
	"""Supports legacy [path, ...] and new [{path, stacks}, ...]."""
	var out: Array[ArtifactsData] = []
	for entry in raw_list:
		var path: String = ""
		var stacks: int = 1
		if entry is String:
			path = entry
		elif entry is Dictionary:
			path = str(entry.get("path", ""))
			stacks = int(entry.get("stacks", 1))
		if not _is_valid_res_path(path):
			DebugLogger.log_warning("Load: skipping invalid artifact path '%s'" % path, "SAVE")
			continue
		var base = load(path) as ArtifactsData
		if not is_instance_valid(base):
			DebugLogger.log_warning("Load: failed to load artifact '%s'" % path, "SAVE")
			continue
		var inst: ArtifactsData = base.duplicate()
		inst.set_meta("source_path", path)
		inst.current_stacks = maxi(1, stacks)
		out.append(inst)
	return out

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
