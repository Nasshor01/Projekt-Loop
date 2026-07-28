# Soubor: res://scripts/autoload/DebugLogger.gd
extends Node

const LOG_FILE_NAME = "game_debug_log.txt"
const MAX_LOG_SIZE_MB = 10
const MAX_BACKUP_FILES = 3
const SECRETS_CONFIG_PATH = "res://secrets.cfg"
var feedback_webhook_url: String = ""
var crash_webhook_url: String = ""
const DISCORD_COLOR_INFO = 0x0000FF
const DISCORD_COLOR_WARNING = 0xF1C40F
const DISCORD_COLOR_ERROR = 0xFF0000
const SESSION_LOCK_PATH = "user://session.lock"

var log_file_path: String
var log_file: FileAccess
var session_start_time: String
@export var log_level: LogLevel = LogLevel.INFO
@export var discord_enabled: bool = true
@export var discord_feedback_includes_state: bool = true
@export var discord_feedback_includes_system_info: bool = true
@export var is_quitting_legally: bool = false
@export var can_send_reports: bool = true
var report_consent_known: bool = false
var _pending_reports_processed: bool = false

var _discord_http: HTTPRequest

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

	_load_webhook_secrets()
	_setup_discord()
	
	log_info("DebugLogger inicializován")
	log_info("Log soubor: %s" % OS.get_user_data_dir() + "/" + LOG_FILE_NAME)
	
	# Zaloguj základní system info
	log_system_info()
	
	can_send_reports = _load_report_preference()
	if report_consent_known and can_send_reports:
		call_deferred("_process_pending_crash_reports")
	
	# Debug-only crash simulation
	if OS.is_debug_build():
		set_process_input(true)

func _input(event):
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F10:
			CrashReporter.generate_crash_report("SIMULATED_CRASH_TEST")

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
	if message.begins_with("[PLAYER_FEEDBACK]"):
		var feedback_text = message.replace("[PLAYER_FEEDBACK]", "").strip_edges()
		var body = "Player feedback:\n%s" % feedback_text
		if discord_feedback_includes_system_info:
			body += "\n\n" + _build_system_info_text()
		if discord_feedback_includes_state:
			body += "\n\n" + _build_full_game_state_text()
		_send_to_discord(feedback_webhook_url, "Player Feedback", body, DISCORD_COLOR_INFO)
	
	if log_level <= LogLevel.INFO:
		var formatted = _format_message("INFO", category, message)
		_write_line(formatted)
		print(formatted)

func log_warning(message: String, category: String = "GAME"):
	if log_level <= LogLevel.WARNING:
		var formatted = _format_message("WARN", category, message)
		_write_line(formatted)
		push_warning(formatted)

func log_error(message: String, category: String = "GAME", force_discord: bool = false):
	if log_level <= LogLevel.ERROR:
		var formatted = _format_message("ERROR", category, message)
		_write_line(formatted)
		push_error(formatted)
		_write_line("Stack trace:")
		_write_line(str(get_stack()))
		
		if force_discord:
			# Stejná úroveň detailů jako u kritických chyb
			log_full_game_state()
			var full_state_text = _build_full_game_state_text()
			var body = formatted + "\n\n" + full_state_text
			_send_to_discord(crash_webhook_url, "Error", body, DISCORD_COLOR_ERROR, true)
			_send_crash_log_file()

func log_critical(message: String, category: String = "GAME"):
	var formatted = _format_message("CRITICAL", category, message)
	_log_critical_internal(formatted, "Critical Error")

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
	var message = "EXCEPTION: %s | Context: %s" % [exception, context]
	var formatted = _format_message("CRITICAL", "EXCEPTION", message)
	_log_critical_internal(formatted, "Exception")

func _log_critical_internal(formatted_message: String, title: String):
	_write_line(formatted_message)
	push_error(formatted_message)
	_write_line("Stack trace:")
	_write_line(str(get_stack()))
	
	# Při kritické chybě okamžitě flush
	if log_file:
		log_file.flush()
	
	# Kompletní stav hry do logu i na Discord
	log_full_game_state()
	var full_state_text = _build_full_game_state_text()
	var body = formatted_message + "\n\n" + full_state_text
	_send_to_discord(crash_webhook_url, title, body, DISCORD_COLOR_ERROR, true)
	_send_crash_log_file()

# === NOVÉ ROZŠÍŘENÉ LOGGING FUNKCE ===

func log_skill_tree_state():
	"""Loguje kompletní stav skill tree včetně odemčených/zamčených skillů"""
	log_info("=== SKILL TREE STATE ===", "SKILLS")

	if not PlayerData or not is_instance_valid(PlayerData.active_skill_tree):
		log_warning("Žádný aktivní skill tree!", "SKILLS")
		return

	var tree = PlayerData.active_skill_tree
	var allocated_skills: Dictionary = SaveManager.meta_progress.allocated_skills if SaveManager else {}

	log_info("Skill tree nodes: %d" % tree.skill_nodes.size(), "SKILLS")
	log_info("Unlocked skills: %d" % allocated_skills.size(), "SKILLS")

	# Detailní info o každém skillu
	for node in tree.skill_nodes:
		if not is_instance_valid(node):
			continue

		# ----- ZDE JE OPRAVA -----
		var node_id_str = String(node.id)
		var allocation_count = allocated_skills.get(node_id_str, 0)
		var is_unlocked = allocation_count > 0
		var status = "✅ UNLOCKED (%d)" % allocation_count if is_unlocked else "🔒 LOCKED"

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
				# OPRAVENO: Používáme správné properties
				log_debug("  - %s (Cost: %d)" % [card.card_name, card.cost], "DECK")

	log_info("=== END DECK STATE ===", "DECK")


func log_artifacts():
	"""Loguje všechny artefakty hráče"""
	if not PlayerData or PlayerData.artifacts.is_empty():
		log_info("No artifacts", "ARTIFACTS")
		return
		
	log_info("=== ARTIFACTS (%d) ===" % PlayerData.artifacts.size(), "ARTIFACTS")
	for artifact in PlayerData.artifacts:
		if is_instance_valid(artifact):
			# OPRAVENO: Používáme nové properties
			var effect_name = "UNKNOWN"
			if artifact.effect_type >= 0 and artifact.effect_type < ArtifactsData.EffectType.size():
				effect_name = ArtifactsData.EffectType.keys()[artifact.effect_type]
			
			log_info("- %s: %s (value: %d, stacks: %d/%d)" % [
				artifact.artifact_name,
				effect_name,
				artifact.primary_value,
				artifact.current_stacks,
				artifact.max_stacks
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
	var allocated_skills: Dictionary = SaveManager.meta_progress.allocated_skills if SaveManager else {}
	for skill_id in allocated_skills.keys():
		var allocation_count = allocated_skills.get(skill_id, 0)
		log_info("  - %s (x%d)" % [skill_id, allocation_count], "RUN_SUMMARY")
	
	log_info("=== END RUN SUMMARY ===", "RUN_SUMMARY")

func log_meta_progress():
	"""Loguje meta progress (XP, odemčené třídy atd.)"""
	if not SaveManager:
		return
		
	log_info("=== META PROGRESS ===", "META")
	var hero_progress: Dictionary = SaveManager.meta_progress.hero_progress
	if hero_progress.is_empty():
		log_info("Legacy Total XP: %d / Level: %d" % [
			SaveManager.meta_progress.total_xp,
			SaveManager.meta_progress.player_level
		], "META")
	else:
		for hero_id in hero_progress.keys():
			log_info(
				"Hero %s — Level %d, XP %d" % [
					hero_id,
					SaveManager.meta_progress.get_hero_level(hero_id),
					SaveManager.meta_progress.get_hero_xp(hero_id)
				],
				"META"
			)
	var allocated_skills = SaveManager.meta_progress.allocated_skills
	log_info("Unlocked skills: %d" % allocated_skills.size(), "META")
	
	# Seznam všech odemčených skillů
	for skill_id in allocated_skills.keys():
		var allocation_count = allocated_skills.get(skill_id, 0)
		log_debug("  - Skill: %s (x%d)" % [skill_id, allocation_count], "META")
	
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
	
	# Pokud je aktivní battle scene, přidej stav boje a gridu
	var active_battle = _get_active_battle_scene()
	if active_battle:
		log_battle_state(active_battle)
	
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
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_remove_session_lock()
		log_info("Ukončení přes okno/Alt+F4.", "SYSTEM")
		if log_file:
			log_file.flush()
			log_file.close()
	elif what == NOTIFICATION_CRASH:
		CrashReporter.generate_crash_report("AUTOMATIC_CRASH_REPORT")
		log_critical("Aplikace se nečekaně ukončuje!", "SYSTEM")
		log_player_stats()
		log_deck_state()
		
		if log_file:
			log_file.flush()
			log_file.close()

# === DISCORD INTEGRATION ===

func _setup_discord():
	if not discord_enabled:
		return
	if not has_node("DiscordHTTPRequest"):
		_discord_http = HTTPRequest.new()
		_discord_http.name = "DiscordHTTPRequest"
		add_child(_discord_http)
	else:
		_discord_http = get_node("DiscordHTTPRequest")

func _send_to_discord(webhook_url: String, title: String, body: String, color: int, high_priority: bool = false):
	if not discord_enabled:
		return
	if not can_send_reports:
		return
	if webhook_url.is_empty():
		return
	
	if high_priority:
		var urgent_request = HTTPRequest.new()
		add_child(urgent_request)
		urgent_request.request_completed.connect(func(_result, _code, _headers, _body):
			urgent_request.queue_free()
		)
		
		var urgent_payload = {
			"embeds": [
				{
					"title": title,
					"description": _truncate_embed_text(body),
					"color": color,
					"timestamp": _get_iso_timestamp()
				}
			]
		}
		
		var urgent_headers = ["Content-Type: application/json"]
		var urgent_json_body = JSON.stringify(urgent_payload)
		urgent_request.request(webhook_url, urgent_headers, HTTPClient.METHOD_POST, urgent_json_body)
		return
	
	if not _discord_http:
		_setup_discord()
	if not _discord_http:
		return
	if _discord_http.get_http_client_status() == HTTPClient.STATUS_REQUESTING:
		return
	
	var payload = {
		"embeds": [
			{
				"title": title,
				"description": _truncate_embed_text(body),
				"color": color,
				"timestamp": _get_iso_timestamp()
			}
		]
	}
	
	var headers = ["Content-Type: application/json"]
	var json_body = JSON.stringify(payload)
	_discord_http.request(webhook_url, headers, HTTPClient.METHOD_POST, json_body)

func _send_file_to_discord(webhook_url: String, filename: String, bytes: PackedByteArray, title: String, body: String, color: int):
	if not discord_enabled:
		return
	if not can_send_reports:
		return
	if webhook_url.is_empty():
		return
	var file_request = HTTPRequest.new()
	add_child(file_request)
	file_request.request_completed.connect(func(_result, _code, _headers, _body):
		file_request.queue_free()
	)
	
	var payload = {
		"embeds": [
			{
				"title": title,
				"description": _truncate_embed_text(body),
				"color": color,
				"timestamp": _get_iso_timestamp()
			}
		]
	}
	var boundary = "----GodotDiscordBoundary" + str(Time.get_ticks_msec())
	var headers = ["Content-Type: multipart/form-data; boundary=%s" % boundary]
	var body_bytes = PackedByteArray()
	
	var payload_part = ""
	payload_part += "--%s\r\n" % boundary
	payload_part += "Content-Disposition: form-data; name=\"payload_json\"\r\n"
	payload_part += "Content-Type: application/json\r\n\r\n"
	payload_part += JSON.stringify(payload) + "\r\n"
	body_bytes.append_array(payload_part.to_utf8_buffer())
	
	var file_header = ""
	file_header += "--%s\r\n" % boundary
	file_header += "Content-Disposition: form-data; name=\"files[0]\"; filename=\"%s\"\r\n" % filename
	file_header += "Content-Type: text/plain\r\n\r\n"
	body_bytes.append_array(file_header.to_utf8_buffer())
	body_bytes.append_array(bytes)
	body_bytes.append_array("\r\n".to_utf8_buffer())
	
	var closing = "--%s--\r\n" % boundary
	body_bytes.append_array(closing.to_utf8_buffer())
	
	file_request.request_raw(webhook_url, headers, HTTPClient.METHOD_POST, body_bytes)

func _get_iso_timestamp() -> String:
	var timestamp = Time.get_datetime_string_from_system()
	return timestamp.replace(" ", "T")

func _truncate_embed_text(text: String, limit: int = 3900) -> String:
	if text.length() <= limit:
		return text
	return text.substr(0, limit) + "\n... [truncated]"

func _build_system_info_text() -> String:
	var lines = []
	lines.append("=== SYSTEM INFO ===")
	lines.append("Godot: %s" % Engine.get_version_info().string)
	lines.append("OS: %s" % OS.get_name())
	lines.append("CPU cores: %d" % OS.get_processor_count())
	lines.append("Video adapter: %s" % RenderingServer.get_video_adapter_name())
	lines.append("Screen size: %s" % str(DisplayServer.screen_get_size()))
	lines.append("FPS Limit: %d" % Engine.max_fps)
	lines.append("VSync: %s" % DisplayServer.window_get_vsync_mode())
	lines.append("Memory Usage: %.2f MB" % (OS.get_static_memory_usage() / 1048576.0))
	lines.append("User data dir: %s" % OS.get_user_data_dir())
	lines.append("===================")
	return "\n".join(lines)

func _build_full_game_state_text() -> String:
	var lines = []
	var battle_scene = _get_active_battle_scene()
	var in_battle = battle_scene != null
	lines.append("=== FULL GAME STATE DUMP ===")
	lines.append("Time: %s" % Time.get_datetime_string_from_system())
	lines.append("")
	
	# Player stats
	lines.append("=== PLAYER STATS ===")
	if PlayerData:
		lines.append("HP: %d/%d" % [PlayerData.current_hp, PlayerData.max_hp])
		lines.append("Energy: %d/%d" % [PlayerData.current_energy, PlayerData.max_energy])
		lines.append("Gold: %d" % PlayerData.gold)
		lines.append("Floors cleared: %d" % PlayerData.floors_cleared)
	else:
		lines.append("PlayerData not available")
	lines.append("")
	
	# Skill tree
	lines.append("=== SKILL TREE ===")
	if PlayerData and is_instance_valid(PlayerData.active_skill_tree) and SaveManager:
		var allocated_skills: Dictionary = SaveManager.meta_progress.allocated_skills
		lines.append("Skill nodes: %d" % PlayerData.active_skill_tree.skill_nodes.size())
		lines.append("Allocated skills: %d" % allocated_skills.size())
		for skill_id in allocated_skills.keys():
			lines.append("  - %s (x%d)" % [skill_id, allocated_skills.get(skill_id, 0)])
	else:
		lines.append("No active skill tree")
	lines.append("")
	
	# Deck state
	lines.append("=== DECK STATE ===")
	if PlayerData:
		lines.append("Master deck: %d" % PlayerData.master_deck.size())
		if in_battle:
			lines.append("Hand: %d" % PlayerData.current_hand.size())
			lines.append("Draw pile: %d" % PlayerData.draw_pile.size())
			lines.append("Discard pile: %d" % PlayerData.discard_pile.size())
			lines.append("Exhaust pile: %d" % PlayerData.exhaust_pile.size())
		else:
			lines.append("Hand: %d" % PlayerData.current_hand.size())
			lines.append("Draw pile: %d" % PlayerData.draw_pile.size())
			lines.append("Discard pile: %d" % PlayerData.discard_pile.size())
			lines.append("Exhaust pile: %d" % PlayerData.exhaust_pile.size())
		
		if in_battle:
			var hand_names = _get_card_names(PlayerData.current_hand)
			var draw_names = _get_card_names(PlayerData.draw_pile)
			var discard_names = _get_card_names(PlayerData.discard_pile)
			if not hand_names.is_empty():
				lines.append("Hand cards: %s" % ", ".join(hand_names))
			if not draw_names.is_empty():
				lines.append("Draw pile cards: %s" % ", ".join(draw_names))
			if not discard_names.is_empty():
				lines.append("Discard pile cards: %s" % ", ".join(discard_names))
	else:
		lines.append("PlayerData not available")
	lines.append("")
	
	# Artifacts
	lines.append("=== ARTIFACTS ===")
	if PlayerData and not PlayerData.artifacts.is_empty():
		for artifact in PlayerData.artifacts:
			if is_instance_valid(artifact):
				lines.append("- %s (stacks: %d/%d)" % [artifact.artifact_name, artifact.current_stacks, artifact.max_stacks])
	else:
		lines.append("No artifacts")
	lines.append("")
	
	# Map and progression
	lines.append("=== MAP ===")
	if GameManager and GameManager.current_map_data:
		lines.append("Seed: %d" % GameManager.current_seed)
		var path_count = PlayerData.path_taken.size() if PlayerData else 0
		lines.append("Path taken: %d nodes" % path_count)
		if PlayerData:
			lines.append("Current floor: %d" % (PlayerData.floors_cleared + 1))
		if PlayerData and PlayerData.get_current_node():
			var column_index = _extract_column_index(PlayerData.get_current_node())
			if column_index != null:
				lines.append("Current column: %d" % column_index)
	else:
		lines.append("No map data available")
	lines.append("")
	
	lines.append("=== META PROGRESS ===")
	if SaveManager:
		var hero_progress: Dictionary = SaveManager.meta_progress.hero_progress
		if hero_progress.is_empty():
			lines.append("Total XP: %d" % SaveManager.meta_progress.total_xp)
			lines.append("Player level: %d" % SaveManager.meta_progress.player_level)
		else:
			for hero_id in hero_progress.keys():
				lines.append("Hero %s — Level %d, XP %d" % [
					hero_id,
					SaveManager.meta_progress.get_hero_level(hero_id),
					SaveManager.meta_progress.get_hero_xp(hero_id)
				])
		lines.append("Skill points: %d" % SaveManager.meta_progress.skill_points)
	else:
		lines.append("Meta progress not available")
	lines.append("")
	
	# Battle and grid state
	lines.append("=== BATTLE/GRID ===")
	if battle_scene:
		var grid = battle_scene.get("battle_grid_instance")
		if not grid and battle_scene.has_node("BattleGrid"):
			grid = battle_scene.get_node("BattleGrid")
		if grid:
			lines.append("Grid size: %dx%d" % [grid.grid_columns, grid.grid_rows])
		
		if PlayerData:
			lines.append("Energy: %d/%d" % [PlayerData.current_energy, PlayerData.max_energy])
		
		var turn_number = battle_scene.get("_current_turn_number")
		if turn_number != null:
			lines.append("Turn: %d" % turn_number)
		
		var player_unit = battle_scene.get("_player_unit_node")
		if is_instance_valid(player_unit):
			lines.append("Player [ %s ]" % str(player_unit.grid_position))
		
		var enemy_units = battle_scene.get("_enemy_units")
		if enemy_units is Array:
			lines.append("Enemy units: %d" % enemy_units.size())
			for unit in enemy_units:
				if is_instance_valid(unit):
					var enemy_name = unit.unit_data.unit_name if unit.unit_data else "Enemy"
					lines.append("%s [%s]" % [enemy_name, str(unit.grid_position)])
	else:
		lines.append("No active battle scene")
	lines.append("")
	
	lines.append("=== END FULL GAME STATE DUMP ===")
	return "\n".join(lines)

func _get_active_battle_scene():
	var candidates = []
	if GameManager and GameManager.current_scene:
		candidates.append(GameManager.current_scene)
	if GameManager and GameManager.scene_container:
		for child in GameManager.scene_container.get_children():
			if not candidates.has(child):
				candidates.append(child)
	if get_tree() and get_tree().current_scene:
		var tree_scene = get_tree().current_scene
		if tree_scene and not candidates.has(tree_scene):
			candidates.append(tree_scene)
	
	for scene in candidates:
		if not scene:
			continue
		if scene.get("battle_grid_instance") or scene.get("_player_unit_node") or scene.get("_enemy_units"):
			return scene
		if scene.has_node("BattleGrid"):
			return scene
	return null

func _get_card_names(cards: Array) -> Array:
	var names: Array = []
	for card in cards:
		if is_instance_valid(card):
			var name = card.get("card_name")
			if name != null:
				names.append(String(name))
	return names

func _extract_column_index(node) -> Variant:
	if node == null:
		return null
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("column"):
			return int(node["column"]) + 1
		if node.has("position") and node["position"] is Vector2:
			return int(node["position"].x) + 1
	if node.get("column") != null:
		return int(node.get("column")) + 1
	var pos = node.get("position")
	if pos is Vector2:
		return int(pos.x) + 1
	return null

func send_crash_report_to_discord(report_text: String):
	var body = "=== CRASH REPORT ===\n" + report_text
	_send_to_discord(crash_webhook_url, "Crash Report", body, DISCORD_COLOR_ERROR, true)
	_send_crash_log_file()
	await get_tree().create_timer(0.25).timeout

func mark_quitting_legally():
	is_quitting_legally = true

func _load_report_preference() -> bool:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK and config.has_section_key("settings", "can_send_reports"):
		report_consent_known = true
		return bool(config.get_value("settings", "can_send_reports", true))
	report_consent_known = false
	return false

func _load_webhook_secrets():
	var config = ConfigFile.new()
	var err = config.load(SECRETS_CONFIG_PATH)
	if err != OK:
		feedback_webhook_url = ""
		crash_webhook_url = ""
		return
	feedback_webhook_url = String(config.get_value("discord", "feedback_webhook", ""))
	crash_webhook_url = String(config.get_value("discord", "crash_webhook", ""))
	if feedback_webhook_url == "YOUR_WEBHOOK_HERE":
		feedback_webhook_url = ""
	if crash_webhook_url == "YOUR_WEBHOOK_HERE":
		crash_webhook_url = ""

func _save_report_preference(value: bool):
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err != OK:
		config = ConfigFile.new()
	config.set_value("settings", "can_send_reports", value)
	config.save("user://settings.cfg")

func apply_report_consent(value: bool):
	can_send_reports = value
	report_consent_known = true
	_save_report_preference(value)
	if can_send_reports and not _pending_reports_processed:
		_process_pending_crash_reports()

func _process_pending_crash_reports():
	if _pending_reports_processed:
		return
	_pending_reports_processed = true
	var dir = DirAccess.open("user://")
	if not dir:
		return
	var files = dir.get_files()
	for file_name in files:
		if file_name.begins_with("crash_report_") and file_name.ends_with(".txt"):
			var path = "user://" + file_name
			var file = FileAccess.open(path, FileAccess.READ)
			if not file:
				continue
			var report_text = file.get_as_text()
			file.close()
			await send_crash_report_to_discord(report_text)
			DirAccess.remove_absolute(path)

func _remove_session_lock():
	if FileAccess.file_exists(SESSION_LOCK_PATH):
		DirAccess.remove_absolute(SESSION_LOCK_PATH)

func _send_crash_log_file():
	var path = "user://" + LOG_FILE_NAME
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var bytes: PackedByteArray
	var size_bytes = file.get_length()
	if size_bytes > 5 * 1024 * 1024:
		# Fallback: ořízni na posledních 500 řádků
		var last_lines: Array = []
		while not file.eof_reached():
			last_lines.append(file.get_line())
			if last_lines.size() > 500:
				last_lines.pop_front()
		var trimmed_text = "\n".join(last_lines)
		bytes = trimmed_text.to_utf8_buffer()
	else:
		bytes = file.get_buffer(size_bytes)
	file.close()
	_send_file_to_discord(crash_webhook_url, LOG_FILE_NAME, bytes, "Crash Log File", "Attached game_debug_log.txt", DISCORD_COLOR_ERROR)

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
