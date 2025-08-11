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
	_log_system_info()

func _write_header():
	var separator = ""
	for i in range(80):
		separator += "="
	_write_line(separator)
	_write_line("NOVÁ SESSION ZAHÁJENA: %s" % session_start_time)
	_write_line(separator)

func _log_system_info():
	log_info("=== SYSTEM INFO ===")
	log_info("Godot verze: %s" % Engine.get_version_info().string)
	log_info("OS: %s" % OS.get_name())
	log_info("Procesor: %s cores" % OS.get_processor_count())
	log_info("Video adapter: %s" % RenderingServer.get_video_adapter_name())
	log_info("Screen size: %s" % DisplayServer.screen_get_size())
	log_info("User data dir: %s" % OS.get_user_data_dir())
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
		"effects": effects
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

func log_system_info():
	_log_system_info()

# === PERFORMANCE LOGGING ===

var performance_timers: Dictionary = {}

func start_performance_timer(label: String):
	performance_timers[label] = Time.get_ticks_msec()

func end_performance_timer(label: String):
	if label in performance_timers:
		var elapsed = Time.get_ticks_msec() - performance_timers[label]
		log_debug("Performance [%s]: %d ms" % [label, elapsed], "PERF")
		performance_timers.erase(label)

# === CLEANUP ===

func _on_tree_exiting():
	log_info("Ukončuji hru...")
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
