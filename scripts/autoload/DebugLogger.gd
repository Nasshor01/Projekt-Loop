# Soubor: res://scripts/autoload/DebugLogger.gd
extends Node

const LOG_FILE_NAME = "game_debug_log.txt"
const MAX_LOG_SIZE_MB = 10
const MAX_BACKUP_FILES = 3

var log_file_path: String
var log_file: FileAccess
var session_start_time: String
var log_level: LogLevel = LogLevel.DEBUG

enum LogLevel {
	DEBUG,
	INFO,
	WARNING,
	ERROR,
	CRITICAL
}

func _ready():
	# Inicializuj cestu k log souboru
	log_file_path = "user://" + LOG_FILE_NAME
	
	# Vytvoř backup starých logů pokud existují
	_rotate_logs()
	
	# Otevři soubor pro zápis (append mode)
	log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
	
	# Zapiš hlavičku session
	session_start_time = Time.get_datetime_string_from_system()
	_write_header()
	
	# Zachyť system signály
	#get_tree().tree_exiting.connect(_on_tree_exiting)
	
	# Připoj se na globální error handler
	if not Engine.is_editor_hint():
		# Zachytávej printy a errory
		OS.set_environment("GODOT_LOG_LEVEL", "verbose")
	
	log_info("DebugLogger inicializován")
	log_info("Log soubor: %s" % OS.get_user_data_dir() + "/" + LOG_FILE_NAME)
	
	# Zaloguj základní system info
	log_system_info()

func _write_header():
	var separator = ""
	for i in range(80):
		separator += "="
	_write_line(separator)
	_write_line("NOVÁ SESSION ZAHÁJENA: %s" % session_start_time)
	_write_line(separator)

func log_system_info():
	log_info("=== SYSTEM INFO ===")
	log_info("Godot verze: %s" % Engine.get_version_info().string)
	log_info("OS: %s" % OS.get_name())
	log_info("Procesor: %s cores" % OS.get_processor_count())
	log_info("Video adapter: %s" % RenderingServer.get_video_adapter_name())
	log_info("Screen size: %s" % DisplayServer.screen_get_size())
	log_info("User data dir: %s" % OS.get_user_data_dir())
	log_info("FPS Limit: %d" % Engine.max_fps)
	log_info("VSync: %s" % DisplayServer.window_get_vsync_mode())
	log_info("Memory Usage: %.2f MB" % (OS.get_static_memory_usage() / 1048576.0))
	log_info("==================")

func _rotate_logs():
	# Zkontroluj velikost současného logu
	if FileAccess.file_exists(log_file_path):
		var file = FileAccess.open(log_file_path, FileAccess.READ)
		if file:
			var size_mb = file.get_length() / 1048576.0  # Convert to MB
			file.close()
			
			if size_mb > MAX_LOG_SIZE_MB:
				# Rotuj logy
				for i in range(MAX_BACKUP_FILES - 1, 0, -1):
					var old_path = "user://%s.%d" % [LOG_FILE_NAME, i]
					var new_path = "user://%s.%d" % [LOG_FILE_NAME, i + 1]
					if FileAccess.file_exists(old_path):
						DirAccess.rename_absolute(old_path, new_path)
				
				# Přesuň současný log na .1
				DirAccess.rename_absolute(log_file_path, "user://%s.1" % LOG_FILE_NAME)

func _write_line(text: String):
	if log_file:
		log_file.store_line(text)
		log_file.flush()  # Okamžitě zapsat na disk

func _format_message(level: String, category: String, message: String) -> String:
	var timestamp = Time.get_time_string_from_system()
	return "[%s] [%s] [%s] %s" % [timestamp, level, category, message]

# === PUBLIC LOGGING FUNKCE ===

func log_debug(message: String, category: String = "GAME"):
	if log_level <= LogLevel.DEBUG:
		var formatted = _format_message("DEBUG", category, message)
		_write_line(formatted)
		print(formatted)

func log_info(message: String, category: String = "GAME"):
	if log_level <= LogLevel.INFO:
		var formatted = _format_message("INFO", category, message)
		_write_line(formatted)
		print(formatted)

func log_warning(message: String, category: String = "GAME"):
	if log_level <= LogLevel.WARNING:
		var formatted = _format_message("WARN", category, message)
		_write_line(formatted)
		push_warning(formatted)

func log_error(message: String, category: String = "GAME"):
	if log_level <= LogLevel.ERROR:
		var formatted = _format_message("ERROR", category, message)
		_write_line(formatted)
		push_error(formatted)
		_write_line("Stack trace:")
		_write_line(str(get_stack()))

func log_critical(message: String, category: String = "GAME"):
	var formatted = _format_message("CRITICAL", category, message)
	_write_line(formatted)
	push_error(formatted)
	_write_line("Stack trace:")
	_write_line(str(get_stack()))
	
	# Při kritické chybě okamžitě flush
	if log_file:
		log_file.flush()

# === SPECIALIZOVANÉ LOGGING FUNKCE ===

func log_battle_event(event: String, details: Dictionary = {}):
	var msg = "Battle: %s" % event
	if not details.is_empty():
		msg += " | Details: %s" % str(details)
	log_info(msg, "BATTLE")

func log_player_action(action: String, details: Dictionary = {}):
	var msg = "Player action: %s" % action
	if not details.is_empty():
		msg += " | %s" % str(details)
	log_info(msg, "PLAYER")

func log_card_played(card_name: String, target = null, effects: Array = []):
	var details = {
		"card": card_name,
		"target": str(target) if target else "none",
		"effects": effects,
		"energy_cost": "unknown",
		"current_energy": PlayerData.current_energy if PlayerData else 0
	}
	log_info("Card played: %s" % str(details), "CARDS")

func log_enemy_action(enemy_name: String, action: String, details: Dictionary = {}):
	var msg = "Enemy [%s] action: %s" % [enemy_name, action]
	if not details.is_empty():
		msg += " | %s" % str(details)
	log_info(msg, "ENEMY")

func log_save_load(action: String, success: bool, details: String = ""):
	var msg = "Save/Load: %s - %s" % [action, "SUCCESS" if success else "FAILED"]
	if details:
		msg += " | %s" % details
	if success:
		log_info(msg, "SAVE")
	else:
		log_error(msg, "SAVE")

func log_scene_change(from_scene: String, to_scene: String):
	log_info("Scene change: %s -> %s" % [from_scene, to_scene], "SCENE")

func log_resource_loaded(resource_path: String, success: bool):
	if success:
		log_debug("Resource loaded: %s" % resource_path, "RESOURCE")
	else:
		log_error("Failed to load resource: %s" % resource_path, "RESOURCE")

func log_exception(exception: String, context: String = ""):
	log_critical("EXCEPTION: %s | Context: %s" % [exception, context], "EXCEPTION")

# === NOVÉ ROZŠÍŘENÉ LOGGING FUNKCE ===

func log_skill_tree_state():
	"""Loguje kompletní stav skill tree včetně odemčených/zamčených skillů"""
	log_info("=== SKILL TREE STATE ===", "SKILLS")

	if not PlayerData or not is_instance_valid(PlayerData.active_skill_tree):
		log_warning("Žádný aktivní skill tree!", "SKILLS")
		return

	var tree = PlayerData.active_skill_tree
	var unlocked_ids = SaveManager.meta_progress.unlocked_skill_ids if SaveManager else []

	log_info("Skill tree nodes: %d" % tree.skill_nodes.size(), "SKILLS")
	log_info("Unlocked skills: %d" % unlocked_ids.size(), "SKILLS")

	# Detailní info o každém skillu
	for node in tree.skill_nodes:
		if not is_instance_valid(node):
			continue

		# ----- ZDE JE OPRAVA -----
		var is_unlocked = node.id in unlocked_ids
		var status = "✅ UNLOCKED" if is_unlocked else "🔒 LOCKED"

		var skill_info = {
			"id": node.id, # <-- OPRAVENO Z node.skill_id
			"name": node.skill_name,
			"tier": node.tier,
			"status": status,
			"cost": node.cost, # Použijeme cost, ne unlock_cost
			"effects": []
		}
		# -------------------------

		# Přidej efekty
		for effect in node.effects:
			if is_instance_valid(effect):
				skill_info.effects.append({
					"type": PassiveEffectData.EffectType.keys()[effect.effect_type],
					"value": effect.value
				})

		log_debug("Skill: %s" % str(skill_info), "SKILLS")

	log_info("=== END SKILL TREE STATE ===", "SKILLS")
func log_player_stats():
	"""Loguje všechny aktuální staty hráče"""
	if not PlayerData:
		log_warning("PlayerData není dostupná!", "PLAYER_STATS")
		return
		
	log_info("=== PLAYER STATS ===", "PLAYER_STATS")
	
	# Základní staty
	log_info("HP: %d/%d" % [PlayerData.current_hp, PlayerData.max_hp], "PLAYER_STATS")
	log_info("Energy: %d/%d" % [PlayerData.current_energy, PlayerData.max_energy], "PLAYER_STATS")
	log_info("Gold: %d" % PlayerData.gold, "PLAYER_STATS")
	log_info("Floors cleared: %d" % PlayerData.floors_cleared, "PLAYER_STATS")
	
	# Třída a podtřída
	if PlayerData.selected_class:
		log_info("Class: %s" % PlayerData.selected_class.resource_path, "PLAYER_STATS")
	if PlayerData.selected_subclass:
		var subclass_name = "Unknown"
		if "subclass_name" in PlayerData.selected_subclass:
			subclass_name = PlayerData.selected_subclass.subclass_name
		log_info("Subclass: %s" % subclass_name, "PLAYER_STATS")
	
	# Pasivní efekty
	log_info("=== PASSIVE EFFECTS ===", "PLAYER_STATS")
	log_info("Card damage bonus: +%d" % PlayerData.global_card_damage_bonus, "PLAYER_STATS")
	log_info("Starting retained block: %d" % PlayerData.starting_retained_block, "PLAYER_STATS")
	log_info("Critical chance: %d%%" % PlayerData.critical_chance, "PLAYER_STATS")
	log_info("Heal per turn: %d" % PlayerData.heal_end_of_turn, "PLAYER_STATS")
	log_info("Aura enhancement: %d%%" % PlayerData.aura_enhancement, "PLAYER_STATS")
	log_info("Avatar block multiplier: %dx" % PlayerData.avatar_starting_block_multiplier, "PLAYER_STATS")
	log_info("Thorns damage: %d" % PlayerData.thorns_damage, "PLAYER_STATS")
	log_info("Healing bonus: %d%%" % PlayerData.double_healing_bonus, "PLAYER_STATS")
	log_info("Energy on kill: %d" % PlayerData.energy_on_kill, "PLAYER_STATS")
	log_info("Block per card: %d" % PlayerData.block_on_card_play, "PLAYER_STATS")
	log_info("Has revive: %s" % str(PlayerData.has_revive), "PLAYER_STATS")
	
	log_info("=== END PLAYER STATS ===", "PLAYER_STATS")

func log_deck_state():
	"""Loguje stav všech balíčků karet"""
	if not PlayerData:
		return

	log_info("=== DECK STATE ===", "DECK")
	log_info("Master deck: %d cards" % PlayerData.master_deck.size(), "DECK")
	log_info("Hand: %d cards" % PlayerData.current_hand.size(), "DECK")
	log_info("Draw pile: %d cards" % PlayerData.draw_pile.size(), "DECK")
	log_info("Discard pile: %d cards" % PlayerData.discard_pile.size(), "DECK")
	log_info("Exhaust pile: %d cards" % PlayerData.exhaust_pile.size(), "DECK")

	# Detailní seznam karet v ruce
	if not PlayerData.current_hand.is_empty():
		log_debug("Cards in hand:", "DECK")
		for card in PlayerData.current_hand:
			if is_instance_valid(card):
				# ----- ZDE JE OPRAVA -----
				log_debug("  - %s (Cost: %d)" % [card.card_name, card.cost], "DECK")
				# -------------------------

	log_info("=== END DECK STATE ===", "DECK")

func log_artifacts():
	"""Loguje všechny artefakty hráče"""
	if not PlayerData or PlayerData.artifacts.is_empty():
		log_info("No artifacts", "ARTIFACTS")
		return
		
	log_info("=== ARTIFACTS (%d) ===" % PlayerData.artifacts.size(), "ARTIFACTS")
	for artifact in PlayerData.artifacts:
		if is_instance_valid(artifact):
			log_info("- %s: %s (value: %d)" % [
				artifact.artifact_name,
				artifact.effect_id,
				artifact.value
			], "ARTIFACTS")
	log_info("=== END ARTIFACTS ===", "ARTIFACTS")

func log_battle_state(battle_scene = null):
	"""Loguje kompletní stav bitvy"""
	log_info("=== BATTLE STATE ===", "BATTLE_STATE")
	
	if not battle_scene:
		log_warning("Battle scene not provided", "BATTLE_STATE")
		return
	
	# Loguj jednotky
	if "player_units" in battle_scene:
		log_info("Player units: %d" % battle_scene.player_units.size(), "BATTLE_STATE")
		for unit in battle_scene.player_units:
			if is_instance_valid(unit):
				_log_unit_details(unit)
	
	if "enemy_units" in battle_scene:
		log_info("Enemy units: %d" % battle_scene.enemy_units.size(), "BATTLE_STATE")
		for unit in battle_scene.enemy_units:
			if is_instance_valid(unit):
				_log_unit_details(unit)
	
	# Loguj grid stav
	if "grid_manager" in battle_scene and battle_scene.grid_manager:
		var grid = battle_scene.grid_manager
		log_info("Grid size: %s" % str(grid.grid_size), "BATTLE_STATE")
	
	log_info("=== END BATTLE STATE ===", "BATTLE_STATE")

func _log_unit_details(unit):
	"""Helper funkce pro logování detailů jednotky"""
	if not is_instance_valid(unit):
		return
		
	var unit_info = {
		"name": unit.unit_data.unit_name if unit.unit_data else "Unknown",
		"hp": "%d/%d" % [unit.current_health, unit.unit_data.max_health if unit.unit_data else 0],
		"block": unit.current_block,
		"retained_block": unit.retained_block,
		"position": str(unit.grid_position),
		"statuses": unit.active_statuses.keys() if not unit.active_statuses.is_empty() else []
	}
	log_debug("  Unit: %s" % str(unit_info), "BATTLE_STATE")

func log_map_state():
	"""Loguje stav mapy"""
	if not GameManager or not GameManager.current_map_data:
		log_info("No map data available", "MAP")
		return
		
	log_info("=== MAP STATE ===", "MAP")
	log_info("Current seed: %d" % GameManager.current_seed, "MAP")
	log_info("Path taken: %d nodes" % PlayerData.path_taken.size(), "MAP")
	
	if PlayerData.get_current_node():
		var node = PlayerData.get_current_node()
		log_info("Current node: %s at %s" % [
			node.node_type if "node_type" in node else "Unknown",
			str(node.position) if "position" in node else "Unknown"
		], "MAP")
	
	log_info("=== END MAP STATE ===", "MAP")

func log_run_summary():
	"""Loguje souhrn běhu při jeho ukončení"""
	log_info("=== RUN SUMMARY ===", "RUN_SUMMARY")
	log_info("Floors cleared: %d" % PlayerData.floors_cleared, "RUN_SUMMARY")
	log_info("Gold collected: %d" % PlayerData.gold, "RUN_SUMMARY")
	log_info("Cards in deck: %d" % PlayerData.master_deck.size(), "RUN_SUMMARY")
	log_info("Artifacts collected: %d" % PlayerData.artifacts.size(), "RUN_SUMMARY")
	log_info("Final HP: %d/%d" % [PlayerData.current_hp, PlayerData.max_hp], "RUN_SUMMARY")
	
	# Loguj aktivní skilly
	log_info("Active skills:", "RUN_SUMMARY")
	var unlocked_ids = SaveManager.meta_progress.unlocked_skill_ids if SaveManager else []
	for skill_id in unlocked_ids:
		log_info("  - %s" % skill_id, "RUN_SUMMARY")
	
	log_info("=== END RUN SUMMARY ===", "RUN_SUMMARY")

func log_meta_progress():
	"""Loguje meta progress (XP, odemčené třídy atd.)"""
	if not SaveManager:
		return
		
	log_info("=== META PROGRESS ===", "META")
	log_info("Total XP: %d" % SaveManager.meta_progress.total_xp, "META")
	log_info("Unlocked skills: %d" % SaveManager.meta_progress.unlocked_skill_ids.size(), "META")
	
	# Seznam všech odemčených skillů
	for skill_id in SaveManager.meta_progress.unlocked_skill_ids:
		log_debug("  - Skill: %s" % skill_id, "META")
	
	log_info("=== END META PROGRESS ===", "META")

func log_full_game_state():
	"""Loguje kompletní stav hry - volat při důležitých momentech"""
	log_info("==========================================", "FULL_STATE")
	log_info("=== FULL GAME STATE DUMP ===", "FULL_STATE")
	log_info("Time: %s" % Time.get_datetime_string_from_system(), "FULL_STATE")
	log_info("==========================================", "FULL_STATE")
	
	log_player_stats()
	log_skill_tree_state()
	log_deck_state()
	log_artifacts()
	log_map_state()
	log_meta_progress()
	
	log_info("==========================================", "FULL_STATE")
	log_info("=== END FULL GAME STATE DUMP ===", "FULL_STATE")
	log_info("==========================================", "FULL_STATE")

# === PERFORMANCE LOGGING ===

var performance_timers: Dictionary = {}
var performance_stats: Dictionary = {}

func start_performance_timer(label: String):
	performance_timers[label] = Time.get_ticks_msec()

func end_performance_timer(label: String):
	if label in performance_timers:
		var elapsed = Time.get_ticks_msec() - performance_timers[label]
		log_debug("Performance [%s]: %d ms" % [label, elapsed], "PERF")
		
		# Ukládej statistiky
		if not label in performance_stats:
			performance_stats[label] = {"total": 0, "count": 0, "max": 0, "min": 999999}
		
		performance_stats[label].total += elapsed
		performance_stats[label].count += 1
		performance_stats[label].max = max(performance_stats[label].max, elapsed)
		performance_stats[label].min = min(performance_stats[label].min, elapsed)
		
		performance_timers.erase(label)

func log_performance_summary():
	"""Loguje souhrn performance statistik"""
	if performance_stats.is_empty():
		return
		
	log_info("=== PERFORMANCE SUMMARY ===", "PERF")
	for label in performance_stats:
		var stats = performance_stats[label]
		var avg = stats.total / float(stats.count)
		log_info("%s: Avg: %.2fms, Min: %dms, Max: %dms, Count: %d" % [
			label, avg, stats.min, stats.max, stats.count
		], "PERF")
	log_info("=== END PERFORMANCE SUMMARY ===", "PERF")

# === CLEANUP ===

func _on_tree_exiting():
	log_info("Ukončuji hru...", "SYSTEM")
	
	# Zaloguj finální stav před ukončením
	log_full_game_state()
	log_performance_summary()
	
	var separator = ""
	for i in range(80):
		separator += "="
	_write_line(separator)
	_write_line("SESSION UKONČENA: %s" % Time.get_datetime_string_from_system())
	_write_line(separator)
	_write_line("")  # Prázdný řádek pro oddělení sessions
	
	if log_file:
		log_file.close()

func _notification(what):
	# Zachyť crash nebo force quit
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_CRASH:
		log_critical("Aplikace se nečekaně ukončuje!", "SYSTEM")
		
		# Pokus se zalogovat co nejvíc informací před crashem
		log_player_stats()
		log_deck_state()
		
		if log_file:
			log_file.flush()
			log_file.close()

# === HELPER FUNKCE ===

func get_log_file_path() -> String:
	return OS.get_user_data_dir() + "/" + LOG_FILE_NAME

func open_log_folder():
	OS.shell_open(OS.get_user_data_dir())

func get_last_n_lines(n: int = 100) -> String:
	if not FileAccess.file_exists(log_file_path):
		return "Log soubor neexistuje"
	
	var file = FileAccess.open(log_file_path, FileAccess.READ)
	if not file:
		return "Nelze otevřít log soubor"
	
	var lines = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	
	var start = max(0, lines.size() - n)
	var result = ""
	for i in range(start, lines.size()):
		result += lines[i] + "\n"
	
	return result

# === DEBUG COMMANDS ===

func execute_debug_command(command: String):
	"""Spustí debug příkaz - můžeš volat z konzole nebo debug UI"""
	var parts = command.split(" ")
	if parts.is_empty():
		return
		
	match parts[0]:
		"dump":
			log_full_game_state()
		"skills":
			log_skill_tree_state()
		"stats":
			log_player_stats()
		"deck":
			log_deck_state()
		"perf":
			log_performance_summary()
		"clear":
			if log_file:
				log_file.close()
				log_file = FileAccess.open(log_file_path, FileAccess.WRITE)
				_write_header()
		_:
			log_warning("Unknown debug command: %s" % command, "DEBUG")
