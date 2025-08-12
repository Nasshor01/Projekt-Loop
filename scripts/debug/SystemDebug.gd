# === AUTOMATICKÉ LOGOVÁNÍ CHECKPOINTŮ ===
# Přidej tento skript jako autoload: DebugSystem.gd
class_name DebugSystem
extends Node

var checkpoint_interval: float = 30.0  # Loguj stav každých 30 sekund
var checkpoint_timer: Timer

func _ready():
	# Nastav timer pro pravidelné checkpointy
	checkpoint_timer = Timer.new()
	checkpoint_timer.wait_time = checkpoint_interval
	checkpoint_timer.timeout.connect(_on_checkpoint_timer)
	checkpoint_timer.autostart = true
	add_child(checkpoint_timer)
	
	# Připoj se na důležité signály
	_connect_to_signals()
	
	# Zachyť kritické chyby
	if not Engine.is_editor_hint():
		_setup_error_handling()

func _connect_to_signals():
	# PlayerData signály
	if PlayerData:
		PlayerData.energy_changed.connect(_on_energy_changed)
		PlayerData.health_changed.connect(_on_health_changed)
		PlayerData.gold_changed.connect(_on_gold_changed)
		PlayerData.artifacts_changed.connect(_on_artifacts_changed)
		PlayerData.player_state_initialized.connect(_on_player_initialized)
	
	# SaveManager signály (pokud existují)
	if SaveManager and SaveManager.has_signal("save_completed"):
		SaveManager.save_completed.connect(_on_save_completed)
		SaveManager.save_failed.connect(_on_save_failed)

func _on_checkpoint_timer():
	"""Pravidelný checkpoint - loguje základní stav"""
	DebugLogger.log_debug("=== AUTO CHECKPOINT ===", "CHECKPOINT")
	
	if PlayerData:
		DebugLogger.log_debug("HP: %d/%d, Energy: %d/%d, Gold: %d, Floor: %d" % [
			PlayerData.current_hp,
			PlayerData.max_hp,
			PlayerData.current_energy,
			PlayerData.max_energy,
			PlayerData.gold,
			PlayerData.floors_cleared
		], "CHECKPOINT")
	
	# Zkontroluj paměť
	var memory_mb = OS.get_static_memory_usage() / 1048576.0
	if memory_mb > 500:  # Varování při použití více než 500MB
		DebugLogger.log_warning("High memory usage: %.2f MB" % memory_mb, "MEMORY")

func _on_energy_changed(new_amount: int):
	"""Loguj významné změny energie"""
	if new_amount < 0:
		DebugLogger.log_warning("Energy dropped below 0: %d" % new_amount, "ENERGY")
	elif new_amount > 10:
		DebugLogger.log_info("Unusual high energy: %d" % new_amount, "ENERGY")

func _on_health_changed(new_hp: int, max_hp: int):
	"""Loguj kritické změny HP"""
	var hp_percentage = (new_hp / float(max_hp)) * 100
	
	if new_hp <= 0:
		DebugLogger.log_critical("Player HP reached 0!", "HEALTH")
		DebugLogger.log_player_stats()
		DebugLogger.log_deck_state()
	elif hp_percentage < 20:
		DebugLogger.log_warning("Low HP warning: %d/%d (%.1f%%)" % [new_hp, max_hp, hp_percentage], "HEALTH")
	
	# Detekuj podezřelé healování
	if new_hp > max_hp:
		DebugLogger.log_error("HP exceeded max! Current: %d, Max: %d" % [new_hp, max_hp], "HEALTH")

func _on_gold_changed(new_amount: int):
	"""Loguj podezřelé změny zlata"""
	if new_amount < 0:
		DebugLogger.log_error("Gold went negative: %d" % new_amount, "ECONOMY")
	elif new_amount > 9999:
		DebugLogger.log_warning("Unusually high gold: %d" % new_amount, "ECONOMY")

func _on_artifacts_changed():
	"""Loguj změny artefaktů"""
	DebugLogger.log_info("Artifacts changed, new count: %d" % PlayerData.artifacts.size(), "ARTIFACTS")
	# Automaticky loguj všechny artefakty při změně
	DebugLogger.log_artifacts()

func _on_player_initialized():
	"""Loguj inicializaci hráče"""
	DebugLogger.log_info("=== PLAYER INITIALIZED ===", "INIT")
	DebugLogger.log_full_game_state()

func _on_save_completed():
	"""Loguj úspěšné uložení"""
	DebugLogger.log_info("Game saved successfully", "SAVE")

func _on_save_failed(reason: String):
	"""Loguj selhání uložení"""
	DebugLogger.log_error("Save failed: %s" % reason, "SAVE")
	DebugLogger.log_full_game_state()  # Dump stavu pro debugging

# === ERROR HANDLING ===

func _setup_error_handling():
	"""Nastav zachytávání chyb"""
	# Připoj se na unhandled exceptions
	if OS.has_feature("debug"):
		set_process_unhandled_input(true)

var last_error_time: float = 0
var error_count: int = 0

func log_error_with_context(error_msg: String, context: Dictionary = {}):
	"""Rozšířené logování chyb s kontextem"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Detekuj error spam
	if current_time - last_error_time < 0.1:  # Více než 10 errorů za sekundu
		error_count += 1
		if error_count > 10:
			DebugLogger.log_critical("ERROR SPAM DETECTED! %d errors in quick succession" % error_count, "ERROR_HANDLER")
			return
	else:
		error_count = 0
	
	last_error_time = current_time
	
	# Loguj error s kontextem
	DebugLogger.log_error("=== ERROR OCCURRED ===", "ERROR_HANDLER")
	DebugLogger.log_error("Message: %s" % error_msg, "ERROR_HANDLER")
	
	if not context.is_empty():
		DebugLogger.log_error("Context: %s" % str(context), "ERROR_HANDLER")
	
	# Přidej stav hry
	DebugLogger.log_error("Current scene: %s" % get_tree().current_scene.name if get_tree().current_scene else "none", "ERROR_HANDLER")
	
	# Pokud je to kritická chyba, dumpni celý stav
	if "critical" in error_msg.to_lower() or "fatal" in error_msg.to_lower():
		DebugLogger.log_full_game_state()
