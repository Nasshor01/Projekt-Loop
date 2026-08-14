# Soubor: scripts/autoload/GameManager.gd (Kombinace funkčního základu a nové logiky)
extends Node

var village_scene = "res://scenes/ui/VillageScene.tscn"
var main_menu_scene = "res://scenes/ui/MainMenu.tscn"
var character_select_scene = "res://scenes/CharSelect/CharacterSelectScreen.tscn"
var run_prep_scene = "res://scenes/CharSelect/RunPrepScreen.tscn"
var end_of_run_scene = "res://scenes/ui/EndOfRunScreen.tscn"
var map_scene = "res://scenes/map/Map.tscn"
var battle_scene = "res://scenes/battle/BattleScene.tscn"
var reward_scene = "res://scenes/rewards/RewardScene.tscn"
var game_over_scene = "res://scenes/ui/GameOver.tscn"
var treasure_scene = "res://scenes/rewards/TreasureScene.tscn"
var shop_scene = "res://scenes/shop/ShopScene.tscn"
var rest_scene = "res://scenes/camp/RestScene.tscn"
var global_ui_scene = preload("res://scenes/ui/GlobalUI.tscn")
var event_scene = "res://scenes/events/EventScene.tscn"
var tutorial_scene = "res://scenes/ui/Tutorial.tscn"
var settings_scene = "res://scenes/ui/Settings.tscn"
var lobby_scene = "res://scenes/ui/CoopLobby.tscn"
var consent_popup_scene = preload("res://scenes/ui/ConsentPopup.tscn")

const TUTORIAL_STEP_BATTLE_1 = "battle_1"
const TUTORIAL_STEP_REWARD_1 = "reward_1"
const TUTORIAL_STEP_MAP_CAMP = "map_camp"
const TUTORIAL_STEP_CAMP_UPGRADE = "camp_upgrade"
const TUTORIAL_STEP_MAP_FINAL = "map_final"
const TUTORIAL_STEP_FINAL_BATTLE = "final_battle"
const TUTORIAL_STEP_FINAL_REWARD = "final_reward"
const TUTORIAL_STEP_COMPLETE = "complete"

var current_scene: Node = null
var current_seed: int
var is_coop_run: bool = false
# Coop: třída/subtřída druhého hráče (cesty k resource), nastaví host při výběru postavy
var coop_client_class_path: String = ""
var coop_client_subclass_path: String = ""
var coop_my_nickname: String = ""
var current_encounter: EncounterData
var current_map_data: MapData = null
var has_saved_camera_state: bool = false
var saved_camera_position: Vector2 = Vector2.ZERO
var saved_camera_zoom: Vector2 = Vector2(1.0, 1.0)
var global_ui_instance: CanvasLayer = null
var consent_popup_instance: Control = null
var last_battle_gold_reward: int = 0
var last_run_xp_earned: int = 0
var scene_container: Node = null
var last_run_was_victory: bool = false
var _is_post_boss_reward: bool = false

var selected_class_data: ClassData = null
var selected_subclass_data: SubclassData = null

# Use load() instead of preload() to avoid script resolution issues at parse time
var CARD_REWARD_POOL = null
var ELITE_ARTIFACT_POOL = null
var rare_card_chance: float = 0.1
var BOSS_ARTIFACT_POOL = null

var last_battle_rewards := {}
const SESSION_LOCK_PATH = "user://session.lock"
var crash_recovery_dialog: ConfirmationDialog = null
var tutorial_active: bool = false
var tutorial_step: String = ""

func _ready():
	if has_node("/root/DebugLogger"):
		DebugLogger.log_info("=== GAME MANAGER STARTED ===")
	else:
		print("=== GAME MANAGER STARTED ===")
	DebugLogger.log_system_info() # Zaloguje system info
	
	# Načteme preferenci jazyka při startu (před crash dialogem a UI)
	_load_language_preference()
	_setup_crash_recovery()
	# Aplikujeme uloženou preferenci fullscreen
	_apply_saved_fullscreen()
	
	# Load resource pools at runtime to avoid script resolution issues
	CARD_REWARD_POOL = load("res://data/cards/reward_card_pool.tres")
	ELITE_ARTIFACT_POOL = load("res://data/artifacts/pool/elite_reward_pool.tres")
	BOSS_ARTIFACT_POOL = load("res://data/artifacts/pool/boss_reward_pool.tres")
	
	scene_container = Node.new()
	scene_container.name = "SceneContainer"
	add_child(scene_container)
	
	global_ui_instance = global_ui_scene.instantiate()
	add_child(global_ui_instance)
	_show_report_consent_if_needed()
	go_to_main_menu()

func _show_report_consent_if_needed():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK and config.has_section_key("settings", "can_send_reports"):
		return
	if consent_popup_instance and is_instance_valid(consent_popup_instance):
		return
	consent_popup_instance = consent_popup_scene.instantiate()
	add_child(consent_popup_instance)
	consent_popup_instance.open()

func _setup_crash_recovery():
	var had_lock = FileAccess.file_exists(SESSION_LOCK_PATH)
	if had_lock:
		_show_crash_recovery_dialog()
		_remove_session_lock()
	_create_session_lock()

func _create_session_lock():
	var file = FileAccess.open(SESSION_LOCK_PATH, FileAccess.WRITE)
	if file:
		file.store_string(Time.get_datetime_string_from_system())

func _remove_session_lock():
	if FileAccess.file_exists(SESSION_LOCK_PATH):
		DirAccess.remove_absolute(SESSION_LOCK_PATH)

func _show_crash_recovery_dialog():
	crash_recovery_dialog = ConfirmationDialog.new()
	crash_recovery_dialog.dialog_text = tr("ui.crash_recovery.message")
	crash_recovery_dialog.ok_button_text = tr("ui.crash_recovery.yes")
	crash_recovery_dialog.cancel_button_text = tr("ui.crash_recovery.no")
	crash_recovery_dialog.confirmed.connect(_on_crash_recovery_confirmed)
	get_tree().root.call_deferred("add_child", crash_recovery_dialog)
	crash_recovery_dialog.call_deferred("popup_centered")

func _on_crash_recovery_confirmed():
	if has_node("/root/DebugLogger"):
		DebugLogger.log_critical("AUTOMATIC_CRASH_REPORT", "SYSTEM")

func reset_tutorial_state() -> void:
	tutorial_active = false
	tutorial_step = ""

func restart_tutorial() -> void:
	"""Restart from battle 1 — used when player hits Restart during tutorial."""
	SaveManager.delete_saved_run()
	reset_tutorial_state()
	go_to_tutorial()

func start_new_run(rng_seed = null):
	SaveManager.delete_saved_run()
	reset_tutorial_state()
	if is_coop_run:
		# Coop: seed už byl nastaven v start_coop_run(), nepřepisujeme
		pass
	elif rng_seed == null:
		randomize()
		current_seed = randi()
	else:
		current_seed = rng_seed
	
	_is_post_boss_reward = false
	DebugLogger.log_info("=== STARTING NEW RUN ===", "GAME_FLOW")
	DebugLogger.log_info("Seed: %d" % current_seed, "GAME_FLOW")
	
	has_saved_camera_state = false
	current_map_data = null
	
	PlayerData.start_new_run_state()
	
	DebugLogger.log_full_game_state()
	
	_change_scene(map_scene)
	
	if has_node("/root/MusicManager"):
		MusicManager.play_run()
	
	# Coop: klient musí taky přejít na mapu (se stejným seedem už má)
	if is_coop_run and has_node("/root/MultiplayerManager"):
		MultiplayerManager.rpc("receive_go_to_map")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_remove_session_lock()

func start_new_game_plus(rng_seed = null):
	reset_tutorial_state()
	if rng_seed == null:
		randomize()
		current_seed = randi()
	else:
		current_seed = rng_seed
	
	print("Zahajuji NOVOU SMYČKU se seedem: ", current_seed)
	PlayerData.loop_level += 1
	
	has_saved_camera_state = false
	current_map_data = null
	# NEVOLÁME initialize_player, protože postava zůstává
	PlayerData.start_loop_state() # Volá částečný reset
	
	_change_scene(map_scene)
	
	if has_node("/root/MusicManager"):
		MusicManager.play_run()
	
func start_battle(encounter: EncounterData):
	DebugLogger.log_info("=== STARTING BATTLE ===", "BATTLE")
	DebugLogger.log_info("Encounter: %s" % encounter.resource_path, "BATTLE")
	DebugLogger.log_info("Encounter type: %s" % str(encounter.encounter_type), "BATTLE")
	
	# Loguj stav před bitvou
	DebugLogger.log_player_stats()
	DebugLogger.log_deck_state()
	
	current_encounter = encounter
	_change_scene(battle_scene)
	# V coope klient už přešel do bitvy přes receive_coop_node_action (z mapy). Neposílat receive_start_battle,
	# aby klient nenačítal bitvu podruhé – druhé načtení by spotřebovalo RNG znovu a grid by byl jiný.

func battle_finished(player_won: bool, final_hp: int = -1, final_shield: int = -1):
	DebugLogger.log_info("=== BATTLE FINISHED ===", "BATTLE")
	DebugLogger.log_battle_event("battle_result", {
		"won": player_won,
		"floors_cleared": PlayerData.floors_cleared,
		"hp_remaining": PlayerData.current_hp,
	})
	
	DebugLogger.log_player_stats()
	DebugLogger.log_artifacts()
	
	if player_won:
		if final_hp != -1:
			PlayerData.current_hp = final_hp
		if final_shield != -1:
			PlayerData.global_shield = final_shield
			print("GLOBÁLNÍ ŠTÍT uložen, nová hodnota: %d" % PlayerData.global_shield)

		var gained_xp = current_encounter.xp_reward
		if PlayerData.loop_level > 0:
			gained_xp = int(gained_xp * (1.0 + (PlayerData.loop_level * 0.3)))
		PlayerData.current_run_xp += gained_xp
		DebugLogger.log_info("XP gained from encounter: %d (Total this run: %d)" % [gained_xp, PlayerData.current_run_xp], "PROGRESSION")

		# Loop Vesnice: střepy za vyhraný fight
		var shard_enc_type = current_encounter.encounter_type if is_instance_valid(current_encounter) else EncounterData.EncounterType.NORMAL
		SaveManager.add_shards(VillageBonuses.shards_for_encounter(shard_enc_type))

		if is_instance_valid(current_encounter) and current_encounter.encounter_type == EncounterData.EncounterType.BOSS:
			_is_post_boss_reward = true
			last_run_was_victory = true
			# Meč nekonečna: bonus z zabíjení se resetuje po bossovi
			if has_node("/root/ArtifactManager"):
				ArtifactManager.reset_scaling_damage_after_boss()

		_prepare_battle_rewards()
		_change_scene(reward_scene)
		if is_coop_run and has_node("/root/MultiplayerManager"):
			var enc_type = int(current_encounter.encounter_type) if is_instance_valid(current_encounter) else 0
			var gold = last_battle_rewards.get("gold", 0)
			var card_paths: Array = []
			for c in last_battle_rewards.get("cards", []):
				if is_instance_valid(c):
					card_paths.append(c.resource_path)
			MultiplayerManager.rpc("receive_go_to_reward", gold, enc_type, card_paths)
	else:
		SaveManager.delete_saved_run()
		last_run_was_victory = false
		last_run_xp_earned = PlayerData.current_run_xp
		SaveManager.add_xp(last_run_xp_earned)
		
		DebugLogger.log_info("XP earned: %d" % last_run_xp_earned, "PROGRESSION")
		DebugLogger.log_meta_progress()
		
		_change_scene(end_of_run_scene)

func go_to_main_menu():
	reset_tutorial_state()
	is_coop_run = false
	coop_client_class_path = ""
	coop_client_subclass_path = ""
	# Zavři případné staré spojení
	if has_node("/root/MultiplayerManager") and MultiplayerManager.has_active_connection():
		MultiplayerManager.close_connection()
	_change_scene(main_menu_scene)

func go_to_character_select():
	_change_scene(character_select_scene)

func go_to_tutorial():
	SaveManager.delete_saved_run()
	tutorial_active = true
	tutorial_step = TUTORIAL_STEP_BATTLE_1
	current_map_data = null
	last_battle_rewards.clear()
	_is_post_boss_reward = false
	PlayerData.path_taken.clear()
	_change_scene(tutorial_scene)

func go_to_settings():
	_change_scene(settings_scene)

func go_to_village():
	_change_scene(village_scene)

func go_to_lobby():
	_change_scene(lobby_scene)

func start_coop_run():
	"""Volá jen host z lobby. Nastaví coop režim, vygeneruje seed a pošle ho klientovi."""
	is_coop_run = true
	randomize()
	current_seed = randi()
	seed(current_seed)
	DebugLogger.log_info("Coop run started, seed: %d" % current_seed, "GAME_FLOW")
	if has_node("/root/MultiplayerManager"):
		MultiplayerManager.rpc("receive_run_seed", current_seed)

func coop_client_go_to_map():
	"""Volá se na klientovi přes RPC – stejný stav jako start_new_run, ale seed už je nastaven."""
	SaveManager.delete_saved_run()
	_is_post_boss_reward = false
	has_saved_camera_state = false
	current_map_data = null
	PlayerData.start_new_run_state()
	DebugLogger.log_info("Coop client going to map, seed: %d" % current_seed, "GAME_FLOW")
	_change_scene(map_scene)
	if has_node("/root/MusicManager"):
		MusicManager.play_run()

func coop_client_follow_node(node_index: int, action_type: String, encounter_path: String):
	"""Klient: stejný krok na mapě jako host (path_taken + přechod)."""
	if not is_instance_valid(current_scene) or not "map_data" in current_scene:
		return
	var md = current_scene.map_data
	if node_index < 0 or node_index >= md.all_nodes.size():
		return
	var node_data = md.all_nodes[node_index]
	PlayerData.path_taken.append(node_data)
	PlayerData.floors_cleared = PlayerData.path_taken.size()
	match action_type:
		"battle":
			if encounter_path != "":
				var enc = load(encounter_path) as EncounterData
				if enc:
					current_encounter = enc
					_change_scene(battle_scene)
		"shop":
			_change_scene(shop_scene)
		"rest":
			_change_scene(rest_scene)
		"event":
			_change_scene(event_scene)
		"treasure":
			_change_scene(treasure_scene)
		_:
			push_error("Coop unknown action_type: %s" % action_type)

func coop_client_go_to_battle(encounter_path: String):
	"""Klient: načti bitvu se stejným encounterem jako host."""
	if encounter_path.is_empty():
		return
	var enc = load(encounter_path) as EncounterData
	if enc:
		current_encounter = enc
		_change_scene(battle_scene)

func coop_client_return_to_map():
	"""Klient: návrat na mapu (po obchodě/eventu/pokladu)."""
	_change_scene(map_scene)

func coop_host_on_battle_ended_by_client(gold: int, final_hp: int, final_shield: int, encounter_type: int, card_paths: Array = []):
	"""Host: klient vyhrál bitvu – aplikovat stav, přejít na reward a poslat klientovi receive_go_to_reward."""
	PlayerData.current_hp = final_hp
	if final_shield != -1:
		PlayerData.global_shield = final_shield
	if is_instance_valid(current_encounter):
		var gained_xp = current_encounter.xp_reward
		if PlayerData.loop_level > 0:
			gained_xp = int(gained_xp * (1.0 + (PlayerData.loop_level * 0.3)))
		PlayerData.current_run_xp += gained_xp
	# Loop Vesnice střepy (coop host)
	SaveManager.add_shards(VillageBonuses.shards_for_encounter(encounter_type))
	# Použij karty od klienta (aby byly stejné)
	if not card_paths.is_empty():
		var cards: Array = []
		for cp in card_paths:
			var c = load(cp) as CardData
			if is_instance_valid(c):
				cards.append(c)
		last_battle_rewards["cards"] = cards
	else:
		_prepare_battle_rewards()
	last_battle_rewards["gold"] = gold
	last_battle_rewards["encounter_type"] = encounter_type
	_change_scene(reward_scene)
	var host_card_paths: Array = []
	for c in last_battle_rewards.get("cards", []):
		if is_instance_valid(c):
			host_card_paths.append(c.resource_path)
	MultiplayerManager.rpc("receive_go_to_reward", gold, encounter_type, host_card_paths)

func coop_client_go_to_reward(gold: int, encounter_type: int, card_paths: Array = []):
	"""Klient: po bitvě přechod na reward – sdílené karty s hostem."""
	last_battle_rewards["gold"] = gold
	last_battle_rewards["encounter_type"] = encounter_type
	if not card_paths.is_empty():
		var cards: Array = []
		for cp in card_paths:
			var c = load(cp) as CardData
			if is_instance_valid(c):
				cards.append(c)
		last_battle_rewards["cards"] = cards
	else:
		last_battle_rewards["cards"] = []
	last_battle_rewards["artifacts"] = []
	_change_scene(reward_scene)

func coop_add_card_to_deck(card_path: String):
	"""Coop: druhý hráč vybral kartu – přidáme ji do master_deck (sync)."""
	if card_path.is_empty():
		return
	var card = load(card_path) as CardData
	if is_instance_valid(card):
		PlayerData.master_deck.append(card)
		PlayerData.emit_signal("deck_changed")

func _load_language_preference():
	"""Načte preferenci jazyka z ConfigFile při startu"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		var locale = config.get_value("settings", "language", "en")
		if locale != "":
			TranslationServer.set_locale(locale)
			DebugLogger.log_info("Language preference loaded: %s" % locale)

func _apply_saved_fullscreen():
	"""Aplikuje uloženou preferenci fullscreen při startu hry"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK and config.has_section_key("settings", "fullscreen"):
		var fullscreen = bool(config.get_value("settings", "fullscreen", false))
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func go_to_run_prep_screen(p_class: ClassData, p_subclass: SubclassData):
	selected_class_data = p_class
	selected_subclass_data = p_subclass
	
	# Loguj výběr postavy
	DebugLogger.log_info("=== CHARACTER SELECTED ===", "CHAR_SELECT")
	DebugLogger.log_info("Class: %s" % p_class.resource_path, "CHAR_SELECT")
	var subclass_name = "Unknown"
	if "subclass_name" in p_subclass:
		subclass_name = p_subclass.subclass_name
	DebugLogger.log_info("Subclass: %s" % subclass_name, "CHAR_SELECT")
	
	_change_scene(run_prep_scene)

func reward_chosen():
	if _is_post_boss_reward:
		SaveManager.delete_saved_run()
		print("Odměna po bossovi vybrána, přecházím na obrazovku konce.")
		_is_post_boss_reward = false
		last_run_xp_earned = PlayerData.current_run_xp
		SaveManager.add_xp(last_run_xp_earned)
		DebugLogger.log_info("XP earned: %d" % last_run_xp_earned, "PROGRESSION")
		DebugLogger.log_meta_progress()
		_change_scene(end_of_run_scene)
	else:
		print("Odměna vybrána, vracím se na mapu.")
		_change_scene(map_scene)
		# Coop: reward/rest scény mají vlastní ready systém – oba peery volají reward_chosen lokálně.
		# Nepotřebujeme posílat receive_return_to_map.

func show_treasure_node():
	print("Hráč vstoupil na pole s pokladem.")
	_change_scene(treasure_scene)

func treasure_collected():
	print("Poklad sebrán, vracím se na mapu.")
	_change_scene(map_scene)
	# Coop: treasure má vlastní ready systém – oba peery volají treasure_collected lokálně.

func go_to_shop():
	print("Vstup do obchodu.")
	_change_scene(shop_scene)

func leave_shop():
	print("Odchod z obchodu, návrat na mapu.")
	_change_scene(map_scene)
	# Coop: shop má vlastní ready systém – oba peery volají leave_shop lokálně.
	# Nepotřebujeme posílat receive_return_to_map.
	
func go_to_rest_scene():
	print("Vstup do scény odpočinku.")
	_change_scene(rest_scene)

func go_to_event_scene():
	print("Vstup do event scény")
	DebugLogger.log_info("Entering event scene", "GAME_FLOW")
	_change_scene(event_scene)

func event_completed():
	print("Event dokončen, návrat na mapu")
	DebugLogger.log_info("Event completed, returning to map", "GAME_FLOW")
	var event_xp = 10
	if PlayerData.loop_level > 0:
		event_xp = int(event_xp * (1.0 + (PlayerData.loop_level * 0.3)))
	PlayerData.current_run_xp += event_xp
	DebugLogger.log_info("XP gained from event: %d (Total this run: %d)" % [event_xp, PlayerData.current_run_xp], "PROGRESSION")
	_change_scene(map_scene)
	if is_coop_run and has_node("/root/MultiplayerManager"):
		MultiplayerManager.rpc("receive_return_to_map")

func _change_scene(scene_path: String):
	DebugLogger.log_scene_change(str(current_scene.scene_file_path) if current_scene else "none", scene_path)
	print("DEBUG: Pokouším se změnit scénu na: ", scene_path)

	if is_instance_valid(global_ui_instance):
		# GlobalUI se skrývá jen v menu/nastavení/tutoriálu/výběru postavy/přípravě runu
		var hide_scenes = [main_menu_scene, character_select_scene, run_prep_scene, tutorial_scene, settings_scene, lobby_scene, village_scene, end_of_run_scene, game_over_scene]
		if scene_path in hide_scenes:
			global_ui_instance.hide()
		else:
			global_ui_instance.show()

	if is_instance_valid(current_scene):
		current_scene.queue_free()

	var new_scene_resource = load(scene_path)
	if new_scene_resource:
		current_scene = new_scene_resource.instantiate()
		
		# DEBUG: Zkontrolujeme typ scény před přiřazováním vlastností
		print("DEBUG: Načtená scéna - typ: ", current_scene.get_class())
		print("DEBUG: Načtená scéna - název: ", current_scene.name)
		
		if is_instance_valid(current_scene):
			# Nejdřív přidáme do stromu, pak nastavujeme vlastnosti
			scene_container.add_child(current_scene)
			
			# Nastavení vlastností scény
			if scene_path == reward_scene:
				print("DEBUG: Nastavujem reward scene properties...")
				print("DEBUG: gold_reward = ", last_battle_rewards.get("gold", 0))
				print("DEBUG: card_choices count = ", last_battle_rewards.get("cards", []).size())
				print("DEBUG: artifact_rewards count = ", last_battle_rewards.get("artifacts", []).size())
				
				# Zkontrolujeme, že current_scene má tyto vlastnosti
				if "gold_reward" in current_scene:
					current_scene.gold_reward = last_battle_rewards.get("gold", 0)
				else:
					print("VAROVÁNÍ: current_scene nemá vlastnost 'gold_reward'")
				
				if "card_choices" in current_scene:
					current_scene.card_choices = last_battle_rewards.get("cards", [])
				else:
					print("VAROVÁNÍ: current_scene nemá vlastnost 'card_choices'")
				
				if "artifact_rewards" in current_scene:
					current_scene.artifact_rewards = last_battle_rewards.get("artifacts", [])
				else:
					print("VAROVÁNÍ: current_scene nemá vlastnost 'artifact_rewards'")
				
				if "encounter_type" in current_scene:
					current_scene.encounter_type = last_battle_rewards.get("encounter_type", EncounterData.EncounterType.NORMAL)
				
				current_scene.setup_ui()
			
			if scene_path == end_of_run_scene:
				if current_scene.has_method("setup"):
					current_scene.setup(last_run_xp_earned, last_run_was_victory)
				else:
					print("VAROVÁNÍ: EndOfRunScene nemá metodu setup()")
			
			if "encounter_data" in current_scene:
				current_scene.encounter_data = current_encounter
		else:
			printerr("FATÁLNÍ CHYBA: Selhalo instancování scény: ", scene_path)
	else:
		printerr("FATÁLNÍ CHYBA: Nepodařilo se načíst zdroj scény: ", scene_path)

func _prepare_battle_rewards():
	last_battle_rewards.clear()
	var reward_card_count := VillageBonuses.get_reward_card_count()
	var effective_rare_chance := VillageBonuses.get_rare_card_chance()
	var epic_chance := VillageBonuses.get_epic_card_chance()
	var legendary_chance := VillageBonuses.get_legendary_card_chance()
	if tutorial_active and tutorial_step == TUTORIAL_STEP_FINAL_BATTLE:
		var available_cards: Array = []
		if is_instance_valid(CARD_REWARD_POOL):
			available_cards = CARD_REWARD_POOL.pick_weighted_cards(
				reward_card_count,
				effective_rare_chance,
				PlayerData.selected_class,
				PlayerData.selected_subclass,
				PlayerData.unlocked_cards,
				epic_chance,
				legendary_chance
			)
		last_battle_rewards["gold"] = 0
		last_battle_rewards["cards"] = available_cards
		last_battle_rewards["artifacts"] = []
		last_battle_rewards["tutorial_hint_text"] = tr("ui.tutorial.complete_hint")
		tutorial_step = TUTORIAL_STEP_FINAL_REWARD
		return

	var encounter_type = current_encounter.encounter_type if current_encounter else EncounterData.EncounterType.NORMAL

	print("DEBUG: Připravuji odměny pro encounter typu: ", encounter_type)

	# 1. Odměna za zlato
	var gold = 0
	match encounter_type:
		EncounterData.EncounterType.NORMAL:
			gold = randi_range(18, 28)
		EncounterData.EncounterType.ELITE:
			gold = randi_range(40, 55)
		EncounterData.EncounterType.BOSS:
			gold = randi_range(95, 110)
	if has_node("/root/ArtifactManager"):
		gold = ArtifactManager.modify_gold_reward(gold)
	last_battle_rewards["gold"] = gold
	last_battle_rewards["encounter_type"] = encounter_type

	# 2. Odměna karet (pro všechny typy kromě bosse) – weighted by rarity + Village library
	if encounter_type != EncounterData.EncounterType.BOSS:
		if is_instance_valid(CARD_REWARD_POOL):
			var reward_cards = CARD_REWARD_POOL.pick_weighted_cards(
				reward_card_count,
				effective_rare_chance,
				PlayerData.selected_class,
				PlayerData.selected_subclass,
				PlayerData.unlocked_cards,
				epic_chance,
				legendary_chance
			)
			last_battle_rewards["cards"] = reward_cards
			if reward_cards.is_empty():
				print("VAROVÁNÍ: Žádné dostupné karty pro hráče")
		else:
			print("VAROVÁNÍ: CARD_REWARD_POOL je prázdný nebo neexistuje")
			last_battle_rewards["cards"] = []
	else:
		last_battle_rewards["cards"] = []

	# 3. Odměna artefaktů (jen pro elity a bossy)
	var artifact_reward = []
	if encounter_type == EncounterData.EncounterType.ELITE:
		# Elite always grants one artifact (pool may still be empty if player owns everything).
		var artifact = _get_random_elite_artifact()
		if artifact:
			artifact_reward.append(artifact)
	
	elif encounter_type == EncounterData.EncounterType.BOSS:
		if is_instance_valid(BOSS_ARTIFACT_POOL) and BOSS_ARTIFACT_POOL.artifacts != null and not BOSS_ARTIFACT_POOL.artifacts.is_empty():
			var available_boss_artifacts = BOSS_ARTIFACT_POOL.artifacts.filter(func(art): return PlayerData.can_gain_artifact(art))
			if not available_boss_artifacts.is_empty():
				available_boss_artifacts.shuffle()
				var choices_count = min(3, available_boss_artifacts.size())
				artifact_reward = available_boss_artifacts.slice(0, choices_count)
			else:
				print("INFO: Hráč již vlastní všechny boss artefakty. Nabízím náhradní elite artefakt.")
				var fallback_artifact = _get_random_elite_artifact()
				if fallback_artifact:
					artifact_reward = [fallback_artifact]
		else:
			print("VAROVÁNÍ: BOSS_ARTIFACT_POOL je prázdný nebo neexistuje")
	
	last_battle_rewards["artifacts"] = artifact_reward
	print("DEBUG: Připravené odměny: ", last_battle_rewards)
	
func _get_random_elite_artifact() -> ArtifactsData:
	if not is_instance_valid(ELITE_ARTIFACT_POOL) or ELITE_ARTIFACT_POOL.artifacts == null or ELITE_ARTIFACT_POOL.artifacts.is_empty():
		print("VAROVÁNÍ: ELITE_ARTIFACT_POOL je prázdný nebo neexistuje")
		return null
		
	var available = ELITE_ARTIFACT_POOL.artifacts.filter(func(art): return PlayerData.can_gain_artifact(art))
	if available.is_empty():
		print("DEBUG: Žádné dostupné elite artefakty")
		return null

	# Live elite pool is mostly Rare + Legendary — never target empty rarities.
	var legendary = available.filter(func(art): return art.artifact_type == ArtifactsData.ArtifactType.LEGENDARY)
	var rare = available.filter(func(art): return art.artifact_type == ArtifactsData.ArtifactType.RARE)
	var uncommon = available.filter(func(art): return art.artifact_type == ArtifactsData.ArtifactType.UNCOMMON)
	var common = available.filter(func(art): return art.artifact_type == ArtifactsData.ArtifactType.COMMON)

	var roll = randf()
	if not legendary.is_empty() and roll < 0.15:
		return legendary.pick_random()
	if not rare.is_empty():
		return rare.pick_random()
	if not legendary.is_empty():
		return legendary.pick_random()
	if not uncommon.is_empty():
		return uncommon.pick_random()
	if not common.is_empty():
		return common.pick_random()
	return available.pick_random()

#==============================================================================
# Popup Menu Logic
#==============================================================================

func _on_popup_restart_run():
	if tutorial_active:
		restart_tutorial()
		return
	SaveManager.delete_saved_run()
	start_new_run()

func _on_popup_save_run():
	SaveManager.save_run(PlayerData)
	# Optionally, provide feedback to the player, e.g., a small notification.
	print("Hra uložena.")

func _on_popup_back_to_char_select():
	SaveManager.delete_saved_run()
	reset_tutorial_state()
	go_to_character_select()

func _on_popup_save_and_quit():
	SaveManager.save_run(PlayerData)
	if has_node("/root/DebugLogger"):
		DebugLogger.mark_quitting_legally()
	get_tree().quit()

func _on_popup_back_to_menu():
	# NESMAŽEME uložený run při návratu do hlavního menu
	# Run se smaže jen při restartu nebo výběru nové postavy
	go_to_main_menu()

func load_and_start_saved_run():
	reset_tutorial_state()
	var loaded_data = SaveManager.load_run()
	if loaded_data.is_empty():
		DebugLogger.log_error("Failed to load run data or no save file found.", "SAVE")
		return

	# Obnovíme seed
	current_seed = loaded_data.get("current_seed", 0)
	if current_seed > 0:
		seed(current_seed)
		DebugLogger.log_info("Seed restored: %d" % current_seed, "GAME_FLOW")

	# Obnovíme třídu a podtřídu
	var class_path = loaded_data.get("selected_class_path", "")
	var subclass_path = loaded_data.get("selected_subclass_path", "")
	
	if class_path != "" and subclass_path != "":
		var loaded_class = load(class_path) as ClassData
		var loaded_subclass = load(subclass_path) as SubclassData
		
		if is_instance_valid(loaded_class) and is_instance_valid(loaded_subclass):
			selected_class_data = loaded_class
			selected_subclass_data = loaded_subclass
			PlayerData.initialize_player(loaded_class, loaded_subclass)
			DebugLogger.log_info("Class and subclass restored: %s / %s" % [class_path, subclass_path], "GAME_FLOW")
		else:
			DebugLogger.log_error("Failed to load class or subclass from save file.", "SAVE")
			return
	else:
		DebugLogger.log_error("No class or subclass data in save file.", "SAVE")
		return

	# Clear run-only fields so abandoned in-session state cannot leak, then restore from save.
	# (initialize_player does not wipe these — explicit reset is required before Continue.)
	PlayerData.sealed_card_id = ""
	PlayerData.sealed_card_source_path = ""
	PlayerData.card_usage_count.clear()
	PlayerData.shop_card_removals_count = 0
	PlayerData.global_shield = 0

	# Restore PlayerData state (kromě HP - to načteme až po aplikaci pasivních skillů)
	PlayerData.gold = loaded_data.get("gold", 0)
	PlayerData.floors_cleared = loaded_data.get("floors_cleared", 0)
	PlayerData.loop_level = loaded_data.get("loop_level", loaded_data.get("ng_plus_level", 0))
	PlayerData.current_run_xp = loaded_data.get("current_run_xp", 0)
	PlayerData.sealed_card_id = str(loaded_data.get("sealed_card_id", ""))
	PlayerData.sealed_card_source_path = str(loaded_data.get("sealed_card_source_path", ""))
	PlayerData.shop_card_removals_count = int(loaded_data.get("shop_card_removals_count", 0))
	PlayerData.global_shield = int(loaded_data.get("global_shield", 0))
	var usage_raw = loaded_data.get("card_usage_count", {})
	if usage_raw is Dictionary:
		for usage_key in usage_raw:
			PlayerData.card_usage_count[str(usage_key)] = int(usage_raw[usage_key])

	# Obnovíme balíček (duplicates lose resource_path — SaveManager resolves source_path)
	PlayerData.master_deck = []
	var loaded_cards: Array[CardData] = SaveManager.load_card_instances(loaded_data.get("master_deck", []))
	for card in loaded_cards:
		PlayerData.master_deck.append(card)
	DebugLogger.log_info("Deck restored: %d cards" % PlayerData.master_deck.size(), "GAME_FLOW")

	# Obnovíme artefakty (duplicates lose resource_path — SaveManager resolves source_path)
	PlayerData.artifacts.clear()
	var loaded_artifacts: Array[ArtifactsData] = SaveManager.load_artifact_instances(loaded_data.get("artifacts", []))
	for artifact in loaded_artifacts:
		PlayerData.artifacts.append(artifact)
	PlayerData.emit_signal("artifacts_changed")
	if has_node("/root/ArtifactManager"):
		ArtifactManager._refresh_artifact_cache()
	DebugLogger.log_info("Artifacts restored: %d" % PlayerData.artifacts.size(), "GAME_FLOW")

	# Tablet seal + Oathbreaker: sync PlayerData / behavior runtime from restored card metas.
	# Do NOT call on_acquired (would re-pick seal / re-roll oathbroken cards).
	var sealed_from_deck: CardData = null
	var oathbroken_ids: Array = []
	for card in PlayerData.master_deck:
		if not is_instance_valid(card):
			continue
		if card.has_meta("artifact_sealed") and bool(card.get_meta("artifact_sealed")):
			sealed_from_deck = card
		if card.has_meta("artifact_oathbroken") and bool(card.get_meta("artifact_oathbroken")):
			oathbroken_ids.append(str(card.card_id))

	if sealed_from_deck != null:
		var saved_seal_id := str(loaded_data.get("sealed_card_id", ""))
		var saved_seal_path := str(loaded_data.get("sealed_card_source_path", ""))
		PlayerData.sealed_card_id = saved_seal_id if not saved_seal_id.is_empty() else str(sealed_from_deck.card_id)
		if not saved_seal_path.is_empty():
			PlayerData.sealed_card_source_path = saved_seal_path
		else:
			var seal_src: String = sealed_from_deck.resource_path
			if seal_src.is_empty() and sealed_from_deck.has_meta("source_path"):
				seal_src = str(sealed_from_deck.get_meta("source_path"))
			PlayerData.sealed_card_source_path = seal_src

	if not oathbroken_ids.is_empty() and has_node("/root/ArtifactManager"):
		var has_oathbreaker := false
		for art in PlayerData.artifacts:
			if is_instance_valid(art) and str(art.artifact_id) == "oathbreaker_seal":
				has_oathbreaker = true
				break
		if has_oathbreaker:
			ArtifactManager.restore_behavior_runtime("oathbreaker_seal", {
				"applied": true,
				"oathbroken_card_ids": oathbroken_ids,
			})

	# Regenerujeme mapu se stejným seedem, aby se uzly shodovaly
	# Vytvoříme dočasnou instanci MapGeneratoru pro regeneraci
	var MapGeneratorClass = load("res://scripts/map/MapGenerator.gd")
	var temp_generator = MapGeneratorClass.new()
	current_map_data = temp_generator.generate_map(current_seed)
	temp_generator.queue_free()
	DebugLogger.log_info("Map regenerated with seed: %d" % current_seed, "GAME_FLOW")
	
	# Obnovíme path_taken - najdeme uzly podle row a column v regenerované mapě
	PlayerData.path_taken = []
	var path_taken_data = loaded_data.get("path_taken", [])
	
	for node_data in path_taken_data:
		var row = node_data.get("row", -1)
		var column = node_data.get("column", -1)
		if row >= 0 and column >= 0:
			# Najdeme uzel s odpovídajícím row a column
			for node in current_map_data.all_nodes:
				if node.row == row and node.column == column:
					PlayerData.path_taken.append(node)
					break
	
	DebugLogger.log_info("Path taken restored: %d nodes" % PlayerData.path_taken.size(), "GAME_FLOW")

	# Aplikujeme pasivní skilly (aby se správně nastavily staty)
	# POZNÁMKA: Toto resetuje max_hp na 50, takže musíme načíst HP až poté
	PlayerData.apply_passive_skills()
	
	# Nyní načteme HP z uložených dat (PO aplikaci pasivních skillů)
	# Uložíme si původní max_hp z uložených dat
	var saved_max_hp = loaded_data.get("max_hp", 50)
	var saved_current_hp = loaded_data.get("current_hp", 50)
	
	# Pokud je uložené max_hp jiné než aktuální (po aplikaci skillů),
	# znamená to, že bylo změněno eventem nebo jinak
	if saved_max_hp != PlayerData.max_hp:
		# Vypočítáme rozdíl a aplikujeme ho
		var max_hp_difference = saved_max_hp - PlayerData.max_hp
		PlayerData.change_max_hp(max_hp_difference)
		DebugLogger.log_info("Max HP restored from save: %d (difference: %d)" % [saved_max_hp, max_hp_difference], "GAME_FLOW")
	
	# Načteme current_hp (ale zajistíme, že nepřesáhne max_hp)
	PlayerData.current_hp = min(saved_current_hp, PlayerData.max_hp)
	DebugLogger.log_info("Current HP restored from save: %d/%d" % [PlayerData.current_hp, PlayerData.max_hp], "GAME_FLOW")

	# Emitujeme signály pro aktualizaci UI
	PlayerData.emit_deck_changed()
	PlayerData.emit_all_signals()

	DebugLogger.log_info("=== SAVED RUN LOADED ===", "GAME_FLOW")
	DebugLogger.log_full_game_state()

	_change_scene(map_scene)
	if has_node("/root/MusicManager"):
		MusicManager.play_run()

# ===================== COOP SCENE SYNC =====================

var _coop_ready_peers: Dictionary = {}  # scene_name -> Array[peer_id]

func coop_client_game_over():
	"""Klient: run skončil prohrou."""
	SaveManager.delete_saved_run()
	last_run_was_victory = false
	last_run_xp_earned = PlayerData.current_run_xp
	SaveManager.add_xp(last_run_xp_earned)
	_change_scene(end_of_run_scene)

func coop_client_go_to_shop(shop_items: Array):
	"""Klient: host vygeneroval shop – uloží data. Scéna se načte přes coop_client_follow_node."""
	_coop_pending_shop_items = shop_items
	# Pokud scéna ještě není shop, přejdi (fallback)
	if not is_instance_valid(current_scene) or not current_scene is Node2D or not current_scene.has_method("_is_coop_run"):
		_change_scene(shop_scene)

func coop_client_go_to_event(event_path: String):
	"""Klient: host vybral event – uloží data. Scéna se načte přes coop_client_follow_node."""
	_coop_pending_event_path = event_path
	# Pokud scéna ještě není event, přejdi (fallback)
	if not is_instance_valid(current_scene) or not current_scene.has_method("display_event"):
		_change_scene(event_scene)

func coop_client_go_to_rest():
	"""Klient: přechod do rest scény."""
	_change_scene(rest_scene)

func coop_client_go_to_treasure(artifact_paths: Array):
	"""Klient: host vygeneroval treasure – uloží data. Scéna se načte přes coop_client_follow_node."""
	_coop_pending_treasure_paths = artifact_paths
	# Pokud scéna ještě není treasure, přejdi (fallback)
	if not is_instance_valid(current_scene) or not current_scene.has_method("_generate_from_host_data"):
		_change_scene(treasure_scene)

func coop_peer_scene_ready(peer_id: int, scene_name: String):
	"""Peer je připravený v dané scéně. Čekáme na oba."""
	if not _coop_ready_peers.has(scene_name):
		_coop_ready_peers[scene_name] = []
	if peer_id not in _coop_ready_peers[scene_name]:
		_coop_ready_peers[scene_name].append(peer_id)

func coop_are_both_ready(scene_name: String) -> bool:
	"""Vrátí true pokud oba peery jsou ready v dané scéně."""
	if not _coop_ready_peers.has(scene_name):
		return false
	return _coop_ready_peers[scene_name].size() >= 2

func coop_clear_ready(scene_name: String):
	"""Vyčistí ready stav pro danou scénu."""
	_coop_ready_peers.erase(scene_name)

# Pending data pro klientovy scény
var _coop_pending_shop_items: Array = []
var _coop_pending_event_path: String = ""
var _coop_pending_treasure_paths: Array = []
